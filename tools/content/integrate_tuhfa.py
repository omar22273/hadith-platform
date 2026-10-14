#!/usr/bin/env python3
"""يدمج «التحفة الربانية» في ملفات الأحاديث ١–٤٢ الموجودة: الغريب وconcise_explanation.

- يستبدل غريب الألفاظ بما اختير من مفردات الكتاب (tuhfa_picks.py) بنصها الحرفي.
- يضيف حقل concise_explanation (مفردات الكتاب وفوائده).
- يطبّق تصحيحات المتن التي أظهرتها مقابلة الكتاب والتي لا تغيّر عدد الكلمات (MATN_PATCHES)،
  بعد التحقق الآلي من أن اللفظ الجديد نص حرفي في المصادر المثبّتة المذكورة.
العملية متكافئة (idempotent): إعادة التشغيل لا تغيّر شيئاً.

الاستعمال:
  python3 tools/content/integrate_tuhfa.py --editions DIR --jami FILE [--root .] [--only 1,2]
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_nawawi_batch2 as b2  # noqa: E402
import tuhfa_integration  # noqa: E402

# ----------------------------------------------------------------------------
# تصحيحات المتن: رقم الحديث -> قائمة (المقطع، القديم، الجديد، مصادر التحقق، سبب)
# ----------------------------------------------------------------------------
MATN_PATCHES = {
    4: [
        dict(
            segment="s2",
            old="وَشَقِيٍّ أَمْ سَعِيدٍ",
            new="وَشَقِيٌّ أَوْ سَعِيدٌ",
            sources=[
                ("b", "3208", "وَشَقِيٌّ أَوْ سَعِيدٌ"),
                ("m", "2643", "وَشَقِيٌّ أَوْ سَعِيدٌ"),
            ],
            note=(
                "اعتُمد لفظ «وَشَقِيٌّ أَوْ سَعِيدٌ» (الرفع و«أَوْ»)؛ فهو لفظ الكتاب ومفرداته تنص على الرفع "
                "(«بالرفع خبر مبتدأ محذوف»)، وهو لفظ البخاري (3208) ومسلم (2643) المثبّتين. "
                "وكان المصدر الرقمي للأربعين «وَشَقِيٍّ أَمْ سَعِيدٍ»."
            ),
        ),
    ],
}


def patch_matn(hadith, corpus, patches):
    """يطبّق تصحيحات المتن مرة واحدة، ويسجّلها في provenance والملاحظات."""
    number = hadith["sequence"]
    for patch in patches:
        segment = next(s for s in hadith["matn"]["segments"] if s["id"] == patch["segment"])
        if patch["new"] in segment["text"] and patch["old"] not in segment["text"]:
            continue
        if patch["old"] not in segment["text"]:
            raise b2.BuildError(f"الحديث {number}: النص القديم غير موجود: «{patch['old']}»")
        for kind, locator, quote in patch["sources"]:
            corpus.verify(kind, locator, quote)
        before = len(b2.tokenize(segment["text"]))
        segment["text"] = segment["text"].replace(patch["old"], patch["new"], 1)
        if len(b2.tokenize(segment["text"])) != before:
            raise b2.BuildError(f"الحديث {number}: التصحيح يغيّر عدد الكلمات")
        hadith["provenance"]["normalizations"].append(patch["note"])
        hadith["review"]["notes"].insert(1, patch["note"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--editions", required=True)
    parser.add_argument("--jami", required=True)
    parser.add_argument("--root", default=".")
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    root = Path(args.root)
    corpus = b2.Corpus(args.editions, args.jami)
    wanted = [int(n) for n in args.only.split(",") if n] or list(range(1, 43))
    directory = root / "assets/data/hadith/nawawi40"
    for number in wanted:
        path = directory / f"nawawi40_{number:03d}.json"
        hadith = json.loads(path.read_text(encoding="utf-8"))
        patch_matn(hadith, corpus, MATN_PATCHES.get(number, []))
        try:
            tuhfa_integration.apply_to_hadith(hadith, corpus.tuhfa[number])
        except (KeyError, ValueError) as error:
            raise b2.BuildError(f"الحديث {number}: {error}") from None
        b2.write_json(path, hadith)
        print(f"OK  {path.name}  gharib={len(hadith['matn']['gharib'])}"
              f" vocab={len(hadith['concise_explanation']['vocabulary'])}"
              f" benefits={len(hadith['concise_explanation']['benefits'])}")


if __name__ == "__main__":
    try:
        main()
    except b2.BuildError as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
