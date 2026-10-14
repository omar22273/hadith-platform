#!/usr/bin/env python3
"""تدقيق مستقل لملفات الأذكار الجاهزة مقابل المدونة المثبّتة.

لا يستعمل منطق القصّ في المُنشئ: يجرّد النص والمصدر إلى حروفهما العربية فقط ويتحقق أن
1. كل شاهد (quote) تتابع حرفي داخل نص الحديث الذي موضعه (locator) في الإصدار المسمّى،
2. كل نص ذكر وكل فضل تتابع حرفي داخل شاهد من شواهده،
3. كل عدد أكبر من واحد مدعوم بعبارته في شاهد،
4. لا علامة اتجاه ولا علامة اقتباس في أي نص.

الاستعمال: python3 tools/content/verify_adhkar_matrix.py <hadith-api checkout> [assets/data/adhkar]
"""
import glob
import json
import os
import re
import sys

LETTERS = re.compile("[^ء-ي]")
MARKS = re.compile("[ً-ٰٟـ]")
STRAY = re.compile("[‏‎\"«»{}]")
EDITION_FILES = {
    "sahih_bukhari": "bukhari", "sahih_muslim": "muslim", "sunan_tirmidhi": "tirmidhi",
    "sunan_ibn_majah": "ibnmajah", "sunan_nasai": "nasai", "sunan_abu_dawud": "abudawud",
}
NUMBER_WORDS = {"ثلاث مرات": 3, "مائة مرة": 100, "ثلاث مرار": 3, "ثلاثا وثلاثين": 33, "اربعا وثلاثين": 34}


def skeleton(text):
    """الحروف العربية فقط بلا حركات، مع توحيد الهمزات والياء والتاء المربوطة."""
    text = MARKS.sub("", text)
    for a, b in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"), ("ى", "ي"), ("ة", "ه")):
        text = text.replace(a, b)
    return LETTERS.sub("", text)


def load_edition(root, source_id, cache):
    if source_id not in cache:
        path = os.path.join(root, "editions", f"ara-{EDITION_FILES[source_id]}.json")
        with open(path, encoding="utf-8") as fh:
            cache[source_id] = json.load(fh)["hadiths"]
    return cache[source_id]


def hadith_texts(root, source_id, locator, cache):
    texts = []
    for entry in load_edition(root, source_id, cache):
        number = str(entry.get("arabicnumber")) if entry.get("arabicnumber") is not None else str(entry["hadithnumber"])
        if number.split(".")[0] == locator:
            texts.append(skeleton(entry["text"]))
    return texts


def main():
    root = sys.argv[1]
    folder = sys.argv[2] if len(sys.argv) > 2 else "assets/data/adhkar"
    cache = {}
    problems = []
    total = 0
    for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
        with open(path, encoding="utf-8") as fh:
            catalog = json.load(fh)
        if "items" not in catalog or catalog.get("id") == "adhkar_seed":
            continue
        for item in catalog["items"]:
            total += 1
            where = f"{os.path.basename(path)}:{item['id']}"
            quotes = [e["quote"] for e in item["evidence"]]
            for field in ("text", "virtue"):
                value = item.get(field)
                if value is None:
                    continue
                if STRAY.search(value):
                    problems.append(f"{where}: {field} has stray marks")
                if not any(skeleton(value) in skeleton(q) for q in quotes):
                    problems.append(f"{where}: {field} is not inside any evidence quote")
            for e in item["evidence"]:
                if STRAY.search(e["quote"]):
                    problems.append(f"{where}: quote has stray marks")
                texts = hadith_texts(root, e["sourceId"], e["locator"], cache)
                if not texts:
                    problems.append(f"{where}: {e['sourceId']} {e['locator']} not found")
                elif not any(skeleton(e["quote"]) in t for t in texts):
                    problems.append(f"{where}: quote not inside {e['sourceId']} {e['locator']}")
            if item["count"] > 1:
                joined = " ".join(re.sub(" +", " ", re.sub("[^ء-ي ]", "", MARKS.sub("", q))) for q in quotes)
                phrases = [p for p, n in NUMBER_WORDS.items() if n == item["count"]]
                if not any(skeleton(p) in skeleton(joined) for p in phrases):
                    problems.append(f"{where}: count {item['count']} has no stated number in quotes")
    print(f"checked {total} items")
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print("all adhkar items verified against the pinned editions")


if __name__ == "__main__":
    main()
