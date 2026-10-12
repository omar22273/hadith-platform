"""Verify the APKs that CI built, before they are uploaded.

Usage: python3 tools/android/verify_apk.py <apk-or-folder> [<apk-or-folder> ...]

Exit status 0 only when every APK passes. For each APK it checks:

1. The zip is intact and holds AndroidManifest.xml, classes.dex and
   resources.arsc, with resources.arsc stored uncompressed and 4-byte aligned
   (Android 11+ refuses to install an app that targets API 30+ otherwise).
2. The compiled manifest (aapt2 dump xmltree) has the structure the installer
   expects: <uses-permission> and <queries> directly under <manifest>,
   components only under <application>, exactly one <application>, and the
   launcher activity exported.
3. The signature verifies (apksigner verify), v1, v2 and v3 are all present, and the
   certificate is the committed stable public key (stable_key.sha256), so every
   build can be installed over the previous one.

A readable report is printed; CI publishes it as an annotation so it can be read
from the run page.
"""

import glob
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import zipfile

MANIFEST_TOP_LEVEL = ('uses-permission', 'uses-permission-sdk-23', 'uses-feature', 'uses-sdk', 'queries', 'permission')
COMPONENTS = ('activity', 'activity-alias', 'service', 'receiver', 'provider')
MAIN_ACTION = 'android.intent.action.MAIN'


class Node:
    """An element of the dumped manifest tree."""

    def __init__(self, name: str, parent=None) -> None:
        self.name = name
        self.parent = parent
        self.attrs = {}
        self.children = []

    def find_all(self, name: str) -> list:
        found = [self] if self.name == name else []
        for child in self.children:
            found.extend(child.find_all(name))
        return found


_ATTRIBUTE = re.compile(r'^A:\s+([^\s(=]+)(?:\(0x[0-9a-fA-F]+\))?=(.*)$')
_ANDROID_URI = 'http://schemas.android.com/apk/res/android:'
_RAW = re.compile(r'\(Raw:\s*"(.*)"\)\s*$')


def parse_attribute_value(text: str) -> str:
    """Normalise an aapt2 attribute value: raw string, quoted string or boolean."""
    raw = _RAW.search(text)
    if raw is not None:
        return raw.group(1)
    value = text.strip()
    if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value in ('true', '(type 0x12)0xffffffff', '0xffffffff'):
        return 'true'
    if value in ('false', '(type 0x12)0x0', '0x0'):
        return 'false'
    return value


def parse_xmltree(text: str):
    """Parse `aapt2 dump xmltree` output into a Node tree (None when empty)."""
    root = None
    stack = []
    for line in text.splitlines():
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(' '))
        body = line.strip()
        if body.startswith('E: '):
            while stack and stack[-1][0] >= indent:
                stack.pop()
            node = Node(body[3:].split(' ', 1)[0], stack[-1][1] if stack else None)
            if stack:
                stack[-1][1].children.append(node)
            elif root is None:
                root = node
            stack.append((indent, node))
        elif body.startswith('A: ') and stack:
            match = _ATTRIBUTE.match(body)
            if match is not None:
                # aapt2 prints the namespace as its URI; compare by the usual prefix.
                key = match.group(1)
                if key.startswith(_ANDROID_URI):
                    key = 'android:' + key[len(_ANDROID_URI):]
                stack[-1][1].attrs[key] = parse_attribute_value(match.group(2))
    return root


def manifest_problems(root) -> list:
    """Structural problems in a parsed manifest tree (empty means sound)."""
    if root is None:
        return ['The compiled manifest could not be read.']
    if root.name != 'manifest':
        return ['The root element is <%s>, expected <manifest>.' % root.name]
    problems = []
    applications = [child for child in root.children if child.name == 'application']
    if len(applications) != 1:
        problems.append('Expected exactly one <application> under <manifest>, found %d.' % len(applications))

    def walk(node) -> None:
        for child in node.children:
            if child.name in MANIFEST_TOP_LEVEL and node is not root:
                problems.append('<%s> is nested under <%s>; it must be a direct child of <manifest>.' % (child.name, node.name))
            if child.name in COMPONENTS and node.name != 'application':
                problems.append('<%s> is under <%s>; it must be inside <application>.' % (child.name, node.name))
            walk(child)

    walk(root)
    launchers = []
    for activity in root.find_all('activity'):
        if any(action.attrs.get('android:name') == MAIN_ACTION for action in activity.find_all('action')):
            launchers.append(activity)
    if not launchers:
        problems.append('No activity handles %s (no launcher).' % MAIN_ACTION)
    for activity in launchers:
        if activity.attrs.get('android:exported') != 'true':
            problems.append('Launcher activity %s is not exported.' % activity.attrs.get('android:name'))
    for component in COMPONENTS:
        for node in root.find_all(component):
            if node.find_all('intent-filter') and 'android:exported' not in node.attrs:
                problems.append('<%s %s> has an intent-filter and no android:exported.' % (component, node.attrs.get('android:name')))
    return problems


def permissions_of(root) -> list:
    if root is None:
        return []
    return sorted(
        child.attrs.get('android:name', '?') for child in root.children if child.name == 'uses-permission'
    )


def data_offset(handle, info) -> int:
    """Offset of an entry's data in the archive, read from its local header.

    The central directory copy of the extra field can differ from the local one
    (zipalign pads the local header), so the local header is the authority.
    """
    handle.seek(info.header_offset)
    header = handle.read(30)
    if len(header) < 30 or header[:4] != b'PK\x03\x04':
        raise zipfile.BadZipFile('Bad local header for %s' % info.filename)
    name_length, extra_length = struct.unpack('<HH', header[26:30])
    return info.header_offset + 30 + name_length + extra_length


def zip_problems(path: str) -> list:
    problems = []
    try:
        with open(path, 'rb') as raw, zipfile.ZipFile(raw) as archive:
            broken = archive.testzip()
            if broken is not None:
                problems.append('Corrupt zip entry: %s' % broken)
            names = set(archive.namelist())
            for required in ('AndroidManifest.xml', 'classes.dex', 'resources.arsc'):
                if required not in names:
                    problems.append('The APK has no %s.' % required)
            if 'resources.arsc' in names:
                info = archive.getinfo('resources.arsc')
                if info.compress_type != zipfile.ZIP_STORED:
                    problems.append('resources.arsc is compressed; it must be stored uncompressed.')
                elif data_offset(raw, info) % 4 != 0:
                    problems.append('resources.arsc is not 4-byte aligned.')
    except zipfile.BadZipFile as error:
        problems.append('Not a valid zip/APK: %s' % error)
    return problems


def abis_of(path: str) -> list:
    with zipfile.ZipFile(path) as archive:
        return sorted({name.split('/')[1] for name in archive.namelist() if name.startswith('lib/') and name.count('/') >= 2})


def _version_key(path: str) -> tuple:
    return tuple(int(part) for part in re.findall(r'\d+', os.path.basename(os.path.dirname(path)))[:3])


def find_tool(name: str):
    """Locate an Android build-tools executable (PATH first, then the SDK)."""
    found = shutil.which(name)
    if found:
        return found
    roots = [os.environ.get('ANDROID_HOME'), os.environ.get('ANDROID_SDK_ROOT'), '/usr/local/lib/android/sdk']
    candidates = []
    for root in roots:
        if root:
            candidates.extend(glob.glob(os.path.join(root, 'build-tools', '*', name)))
    candidates = [c for c in candidates if os.access(c, os.X_OK)]
    return max(candidates, key=_version_key) if candidates else None


def run(command: list) -> tuple:
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.TimeoutExpired) as error:
        return 127, str(error)
    return done.returncode, (done.stdout or '') + (done.stderr or '')


PINNED_FINGERPRINT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stable_key.sha256')


def pinned_fingerprint():
    """SHA-256 of the committed stable signing certificate, or None when no file pins it."""
    try:
        with open(PINNED_FINGERPRINT_FILE, encoding='utf-8') as handle:
            value = handle.read().strip().lower()
    except OSError:
        return None
    return value or None


def signature_report(apksigner: str, path: str) -> tuple:
    """(problems, info lines) from `apksigner verify`."""
    # --min-sdk-version 23 makes apksigner demand (and report) the v1 JAR signature too,
    # which it would otherwise skip for an app whose minSdk is 24 or higher.
    code, output = run([apksigner, 'verify', '--verbose', '--print-certs', '--min-sdk-version', '23', path])
    info = [line.strip() for line in output.splitlines() if line.strip()][:14]
    if code != 0:
        return ['apksigner rejected the APK (exit %d): %s' % (code, ' | '.join(info[:4]) or 'no output')], info
    problems = []
    schemes = {m.group(1): m.group(2) for m in re.finditer(r'Verified using (v\d(?:\.\d)?) scheme[^:]*:\s*(true|false)', output)}
    if not any(schemes.get(v) == 'true' for v in ('v2', 'v3', 'v3.1', 'v4')):
        problems.append('The APK is not signed with the v2 or newer scheme (found: %s).' % (schemes or 'none'))
    for scheme in ('v1', 'v2', 'v3'):
        if schemes.get(scheme) != 'true':
            problems.append('The APK is not signed with the %s scheme (found: %s).' % (scheme, schemes or 'none'))
    if 'Number of signers: 0' in output:
        problems.append('The APK has no signer.')
    certificate = re.search(r'certificate SHA-256 digest:\s*([0-9a-fA-F]{64})', output)
    if certificate is None:
        problems.append('The signing certificate fingerprint could not be read.')
    else:
        fingerprint = certificate.group(1).lower()
        info.append('signing certificate sha256: %s' % fingerprint)
        expected = pinned_fingerprint()
        if expected is None:
            info.append('no pinned fingerprint file: certificate stability not checked')
        elif fingerprint != expected:
            problems.append(
                'The APK is signed with certificate %s, not the stable key %s: it could not be installed '
                'over a build signed with the stable key.' % (fingerprint, expected)
            )
        else:
            info.append('certificate matches the stable public key (builds install over each other)')
    return problems, info


def verify_apk(path: str, tools: dict) -> tuple:
    """(ok, report lines) for one APK."""
    lines = ['== %s' % os.path.basename(path)]
    failures = []
    manifest_dump = ''
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    lines.append('size: %d bytes, sha256: %s' % (os.path.getsize(path), digest.hexdigest()))

    problems = zip_problems(path)
    failures.extend(problems)
    if not problems:
        lines.append('zip: intact; native ABIs: %s' % (', '.join(abis_of(path)) or 'none (Dart only)'))

    aapt2 = tools.get('aapt2')
    if aapt2 is None:
        failures.append('aapt2 was not found, the manifest could not be checked.')
    else:
        code, badging = run([aapt2, 'dump', 'badging', path])
        if code != 0:
            failures.append('aapt2 could not parse the APK (exit %d): %s' % (code, badging.strip()[:300]))
        else:
            for key in ('package:', 'sdkVersion:', 'minSdkVersion:', 'targetSdkVersion:', 'application-label', 'native-code:', 'launchable-activity:'):
                for line in badging.splitlines():
                    if line.startswith(key):
                        lines.append(line.strip())
                        break
            if 'launchable-activity:' not in badging:
                failures.append('aapt2 finds no launchable activity.')
        code, tree = run([aapt2, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', path])
        if code != 0:
            failures.append('aapt2 could not dump AndroidManifest.xml (exit %d): %s' % (code, tree.strip()[:300]))
        else:
            root = parse_xmltree(tree)
            found = manifest_problems(root)
            manifest_dump = tree
            failures.extend(found)
            lines.append('manifest: %s' % ('structure sound' if not found else 'PROBLEMS'))
            lines.append('permissions: %s' % ', '.join(p.replace('android.permission.', '') for p in permissions_of(root)))

    apksigner = tools.get('apksigner')
    if apksigner is None:
        failures.append('apksigner was not found, the signature could not be checked.')
    else:
        problems, info = signature_report(apksigner, path)
        failures.extend(problems)
        lines.append('signature: %s' % ('verified' if not problems else 'PROBLEMS'))
        lines.extend('  ' + line for line in info)

    for failure in failures:
        lines.append('FAIL: %s' % failure)
    lines.append('RESULT: %s' % ('PASS' if not failures else 'FAIL'))
    if manifest_dump:
        lines.append('--- compiled AndroidManifest.xml (aapt2 dump xmltree)')
        lines.append(manifest_dump.rstrip())
    return not failures, lines


def collect(arguments: list) -> list:
    apks = []
    for argument in arguments:
        if os.path.isdir(argument):
            apks.extend(sorted(glob.glob(os.path.join(argument, '*.apk'))))
        elif argument.endswith('.apk'):
            apks.append(argument)
    return apks


def main(argv: list) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    apks = collect(argv[1:])
    if not apks:
        print('FAIL: no .apk file found in: %s' % ' '.join(argv[1:]))
        return 1
    tools = {name: find_tool(name) for name in ('aapt2', 'apksigner')}
    print('aapt2: %s' % tools['aapt2'])
    print('apksigner: %s' % tools['apksigner'])
    everything_ok = True
    for apk in apks:
        ok, lines = verify_apk(apk, tools)
        print('\n'.join(lines))
        everything_ok = everything_ok and ok
    print('\nOVERALL: %s (%d APK)' % ('PASS' if everything_ok else 'FAIL', len(apks)))
    return 0 if everything_ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
