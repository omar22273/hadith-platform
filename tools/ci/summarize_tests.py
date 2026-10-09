"""Summarize `flutter test --reporter json` output into a short text report.

Usage: python3 tools/ci/summarize_tests.py test.json [test.err]

The report lists the totals, then every failing or erroring test with its
error message and the first frames of its stack trace. Load failures
(compile errors in a test file) are reported as errors of the "loading" test.
"""

import json
import sys

STACK_LINES = 12


def main(argv: list) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    names = {}
    errors = {}
    prints = {}
    results = {}
    hidden = set()
    other = []
    with open(argv[1], encoding='utf-8', errors='replace') as handle:
        for raw in handle:
            raw = raw.strip()
            if not raw:
                continue
            try:
                event = json.loads(raw)
            except ValueError:
                other.append(raw)
                continue
            if not isinstance(event, dict):
                continue
            kind = event.get('type')
            if kind == 'testStart':
                test = event.get('test', {})
                names[test.get('id')] = test.get('name', '?')
            elif kind == 'error':
                errors.setdefault(event.get('testID'), []).append(
                    (event.get('error', ''), event.get('stackTrace', '')))
            elif kind == 'print':
                prints.setdefault(event.get('testID'), []).append(event.get('message', ''))
            elif kind == 'testDone':
                test_id = event.get('testID')
                results[test_id] = event.get('result')
                if event.get('hidden'):
                    hidden.add(test_id)
    visible = [t for t in results if t not in hidden]
    passed = sum(1 for t in visible if results[t] == 'success')
    failed = [t for t in results if results[t] in ('failure', 'error')]
    lines = ['tests: %d visible, %d passed, %d failing (incl. hidden loaders)'
             % (len(visible), passed, len(failed))]
    for test_id in failed:
        lines.append('')
        lines.append('FAIL: %s' % names.get(test_id, test_id))
        for message in prints.get(test_id, [])[:20]:
            lines.append('  print: %s' % message)
        for error, stack in errors.get(test_id, []):
            lines.append('  error: %s' % error.strip())
            frames = [f for f in stack.splitlines() if f.strip()][:STACK_LINES]
            lines.extend('    %s' % f for f in frames)
    if other:
        lines.append('')
        lines.append('non-json output:')
        lines.extend('  %s' % line for line in other[:80])
    if len(argv) > 2:
        try:
            with open(argv[2], encoding='utf-8', errors='replace') as handle:
                err = handle.read().strip()
        except OSError:
            err = ''
        if err:
            lines.append('')
            lines.append('stderr:')
            lines.extend('  %s' % line for line in err.splitlines()[:120])
    print('\n'.join(lines))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
