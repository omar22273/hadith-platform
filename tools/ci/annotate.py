"""Publish a text report as GitHub Actions annotations.

Usage:
  python3 tools/ci/annotate.py <notice|warning|error> "<title>" --file report.txt
  python3 tools/ci/annotate.py notice "<title>" --text "some text"

Annotations stay readable from the run page and from the REST API
(check-runs/{id}/annotations) after the job finishes, so a failing analyze or
test step can be diagnosed without downloading the raw job log.
"""

import sys

CHUNK = 12000
MAX_CHUNKS = 8


def encode(value: str) -> str:
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def encode_property(value: str) -> str:
    return encode(value).replace(':', '%3A').replace(',', '%2C')


def main(argv: list) -> int:
    if len(argv) < 5 or argv[1] not in ('notice', 'warning', 'error'):
        print(__doc__)
        return 2
    level, title, mode, payload = argv[1], argv[2], argv[3], argv[4]
    if mode == '--file':
        with open(payload, encoding='utf-8', errors='replace') as handle:
            text = handle.read()
    elif mode == '--text':
        text = payload
    else:
        print(__doc__)
        return 2
    text = text.strip() or '(empty output)'
    chunks = [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)]
    if len(chunks) > MAX_CHUNKS:
        dropped = len(chunks) - MAX_CHUNKS
        chunks = chunks[:MAX_CHUNKS - 1] + [chunks[-1]]
        chunks[-2] += '\n... (%d middle chunk(s) omitted) ...' % dropped
    for index, chunk in enumerate(chunks, start=1):
        label = title if len(chunks) == 1 else '%s (%d/%d)' % (title, index, len(chunks))
        print('::%s title=%s::%s' % (level, encode_property(label), encode(chunk)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
