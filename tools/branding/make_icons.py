"""Generates the «هَدْي» launcher icon set from one set of path definitions.

Outputs (all under android/app/src/main/res):
  * drawable/ic_launcher_foreground.xml   adaptive foreground (vector, 108dp canvas)
  * drawable/ic_launcher_monochrome.xml   Android 13+ themed icon layer
  * values/ic_launcher_background.xml     royal navy background colour
  * mipmap-anydpi-v26/ic_launcher.xml     adaptive icon (also reused as the round icon)
  * mipmap-{mdpi..xxxhdpi}/ic_launcher.png  legacy icons for API 24-25, rendered with Chromium
and tools/branding/hady_icon.svg (the master artwork, 1024px preview).

Design: navy #0F172A field, a mihrab arch outlined in amber #D97706, a deeper niche,
and an oil lamp (siraj) with a warm flame glowing inside it. Run: python3 tools/branding/make_icons.py
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

NAVY = '#0F172A'
NICHE = '#1E293B'
AMBER = '#D97706'
GLOW = '#FBBF24'
CORE = '#FEF3C7'

ARCH = 'M32,81 L32,58 C32,45 42,35 54,25 C66,35 76,45 76,58 L76,81'
NICHE_FILL = 'M37.5,81 L37.5,58.5 C37.5,48.5 45,40.5 54,32.5 C63,40.5 70.5,48.5 70.5,58.5 L70.5,81 Z'
FLAME = 'M54,41 C59,46.5 59.5,51 54,55.5 C48.5,51 49,46.5 54,41 Z'
FLAME_CORE = 'M54,47 C56.4,49.8 56.4,52 54,54 C51.6,52 51.6,49.8 54,47 Z'
LAMP_BODY = 'M44,62 L64,62 C64,69.5 60,74 54,74 C48,74 44,69.5 44,62 Z'
SPOUT = 'M64,62.5 C67.5,62.5 69,60.5 69.5,58'
BASE = 'M48.5,77.5 L59.5,77.5'


def foreground_svg_body(mono: bool = False) -> str:
    amber = '#000000' if mono else AMBER
    glow = '#000000' if mono else GLOW
    parts = []
    if not mono:
        parts.append('<path d="%s" fill="%s"/>' % (NICHE_FILL, NICHE))
    parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>' % (ARCH, amber))
    parts.append('<path d="%s" fill="%s"/>' % (FLAME, glow))
    if not mono:
        parts.append('<path d="%s" fill="%s"/>' % (FLAME_CORE, CORE))
    parts.append('<path d="%s" fill="%s"/>' % (LAMP_BODY, amber))
    parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % (SPOUT, amber))
    parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % (BASE, amber))
    return '\n  '.join(parts)


def full_svg(size: int, legacy: bool) -> str:
    # legacy square icon: rounded navy tile; the 108 canvas is scaled so the artwork fills it.
    radius = 24 if legacy else 0
    scale = 1.18 if legacy else 1.0
    offset = 54 * (1 - scale)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 108 108">\n'
        '  <rect width="108" height="108" rx="%d" fill="%s"/>\n'
        '  <g transform="translate(%.2f %.2f) scale(%.2f)">\n  %s\n  </g>\n</svg>\n'
        % (size, size, radius, NAVY, offset, offset, scale, foreground_svg_body())
    )


def vector_xml(mono: bool) -> str:
    def path(data: str, fill: str = None, stroke: str = None, width: float = 0, cap: bool = False) -> str:
        attrs = ['android:pathData="%s"' % data]
        if fill:
            attrs.append('android:fillColor="%s"' % fill)
        if stroke:
            attrs.append('android:strokeColor="%s"' % stroke)
            attrs.append('android:strokeWidth="%s"' % width)
            attrs.append('android:strokeLineCap="round"')
            attrs.append('android:strokeLineJoin="round"')
        return '    <path\n        ' + '\n        '.join(attrs) + '/>'

    amber = '#000000' if mono else AMBER
    glow = '#000000' if mono else GLOW
    items = []
    if not mono:
        items.append(path(NICHE_FILL, fill=NICHE))
    items.append(path(ARCH, stroke=amber, width=4.5))
    items.append(path(FLAME, fill=glow))
    if not mono:
        items.append(path(FLAME_CORE, fill=CORE))
    items.append(path(LAMP_BODY, fill=amber))
    items.append(path(SPOUT, stroke=amber, width=3))
    items.append(path(BASE, stroke=amber, width=3))
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n    android:height="108dp"\n'
        '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
        + '\n'.join(items)
        + '\n</vector>\n'
    )


def write(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(content)


def main() -> int:
    write(os.path.join(RES, 'drawable', 'ic_launcher_foreground.xml'), vector_xml(False))
    write(os.path.join(RES, 'drawable', 'ic_launcher_monochrome.xml'), vector_xml(True))
    write(
        os.path.join(RES, 'values', 'ic_launcher_background.xml'),
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">%s</color>\n</resources>\n' % NAVY,
    )
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n'
    )
    write(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), adaptive)
    write(os.path.join(ROOT, 'tools', 'branding', 'hady_icon.svg'), full_svg(1024, True))

    from playwright.sync_api import sync_playwright

    sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        for density, size in sizes.items():
            page = browser.new_page(viewport={'width': size, 'height': size}, device_scale_factor=1)
            page.set_content('<html><body style="margin:0;background:transparent">%s</body></html>' % full_svg(size, True))
            target = os.path.join(RES, 'mipmap-%s' % density, 'ic_launcher.png')
            page.screenshot(path=target, omit_background=True)
            page.close()
        browser.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
