#!/usr/bin/env python3
"""يبني ملفات الأحاديث ٢١–٤٢ من الأربعين النووية ويحدّث فهرس المنهج.

يستعمل آلة البناء نفسها المستعملة للأحاديث ١١–٢٠ (build_nawawi_batch2.py) بمبادئها كلها:
المتن من النص الرقمي المثبّت، وكل اقتباس يُتحقق حرفياً، والغريب والشرح الميسر من
«التحفة الربانية» نصاً، وكل تعديل يُسجَّل في provenance.

الاستعمال:
  python3 tools/content/build_nawawi_batch3.py --editions DIR --jami FILE [--root .] [--only 21,22]
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_nawawi_batch2 as b2  # noqa: E402
import nawawi_batch3_a  # noqa: E402
import nawawi_batch3_b  # noqa: E402
import nawawi_batch3_c  # noqa: E402

FIRST, LAST = 21, 42
CATALOG = {**nawawi_batch3_a.HADITHS, **nawawi_batch3_b.HADITHS, **nawawi_batch3_c.HADITHS}

if __name__ == "__main__":
    try:
        b2.main(catalog=CATALOG, first=FIRST, last=LAST)
    except b2.BuildError as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
