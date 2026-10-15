#!/usr/bin/env python3
"""تدقيق مستقل لملفات الأذكار الجاهزة مقابل المصادر المثبّتة.

لا يستعمل منطق القصّ في المُنشئ: يجرّد النص والمصدر إلى حروفهما العربية فقط ويتحقق أن
1. كل شاهد (quote) تتابع حرفي داخل نص مصدره الذي موضعه (locator): حديث في الكتب الستة المثبّتة،
   أو آية في quran_owner_text، أو عبارة في owner_adhkar_v290، أو ذكر في حصن المسلم المرفق،
2. كل نص ذكر وكل فضل تتابع حرفي داخل شاهد من شواهده، وإن كان للذكر اشتقاق فبعد ردّ الكلمة
   المبدَّلة إلى أصلها، وبشرط أن تكون الكلمة المبدَّلة بتشكيلها حرفاً بحرف في شاهد آخر،
3. كل عدد أكبر من واحد مدعوم بعبارته في شاهد، أو بما ينص عليه حصن المسلم المقابل،
4. لا علامة اتجاه ولا علامة اقتباس في أي نص،
5. المسارات (tracks): إن وُجدت لذكر في ملف وُجدت لكل أذكاره، بلا تكرار، وبعدد مسارين لا أكثر،
6. كل ذكر ضعّفه الألباني في شواهده له caution وgrading يذكران ذلك،
7. ملف السنن المهجورة (assets/data/sunan): بطاقاته بلا count ولا tracks، لكل بطاقة bab معروف،
   ولكل باب من أبواب الشريط بطاقة، وعدد البطاقات ثلاثون فأكثر، وكل شاهد غير الصحيحين ليس ضعيفاً عند الألباني.

الاستعمال: python3 tools/content/verify_adhkar_matrix.py <hadith-api checkout> [مجلد ...]
(الافتراضي: assets/data/adhkar ثم assets/data/sunan)
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import hisn_book  # noqa: E402

LETTERS = re.compile("[^ء-ي]")
MARKS = re.compile("[ً-ٰٟـ]")
STRAY = re.compile("[‏‎\"«»{}]")
EDITION_FILES = {
    "sahih_bukhari": "bukhari", "sahih_muslim": "muslim", "sunan_tirmidhi": "tirmidhi",
    "sunan_ibn_majah": "ibnmajah", "sunan_nasai": "nasai", "sunan_abu_dawud": "abudawud",
}
NUMBER_WORDS = {
    3: ("ثلاث",), 4: ("اربع",), 7: ("سبع",), 10: ("عشر",), 33: ("ثلاثا وثلاثين",), 34: ("اربعا وثلاثين",),
    100: ("مائه", "ماءه", "مئه"),
}
HISN_NOTE = re.compile(r"حصن المسلم \((الباب \d+، الذكر \d+)")
HISN_LOCATOR = re.compile(r"^الباب (\d+)، الذكر (\d+)$")
OWNER_LOCATOR = re.compile(r"^طلب المالك، السطر (\d+)$")
ALBANI_WEAK = re.compile(r"الألباني: (ضعيف|موضوع|منكر)")
SUNAN_BABS = ("purity_prayer", "food_drink", "home_going_out", "sleep_clothing", "gatherings_manners")
MIN_SUNAN = 30


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


def read_json(name):
    with open(os.path.join(HERE, "sources", name), encoding="utf-8") as fh:
        return json.load(fh)


class Extras:
    """المصادر الإضافية المثبّتة في tools/content/sources."""

    def __init__(self):
        self.quran = read_json("quran_owner_text.json")["passages"]
        self.owner = read_json("owner_adhkar_v290.json")["spans"]
        self.hisn = hisn_book.load(os.path.join(HERE, "sources", "hisn_al_muslim.txt"))

    def texts(self, source_id, locator):
        if source_id == "quran_owner_text":
            return [skeleton(p["text"]) for p in self.quran if p["label"] == locator]
        if source_id == "owner_adhkar_v290":
            match = OWNER_LOCATOR.match(locator)
            return [skeleton(s["text"]) for s in self.owner if match and s["line"] == int(match.group(1))]
        if source_id == "hisn_al_muslim":
            match = HISN_LOCATOR.match(locator)
            if not match:
                return []
            chapter, number = int(match.group(1)), int(match.group(2))
            return [skeleton(e.text) for e in self.hisn.entries if e.chapter == chapter and e.number == number]
        return None

    def hisn_count(self, locator):
        match = HISN_LOCATOR.match(locator)
        if not match:
            return None
        chapter, number = int(match.group(1)), int(match.group(2))
        counts = {e.count for e in self.hisn.entries if e.chapter == chapter and e.number == number}
        return counts.pop() if len(counts) == 1 else None


def hadith_texts(root, source_id, locator, cache, extras):
    own = extras.texts(source_id, locator)
    if own is not None:
        return own
    texts = []
    for entry in load_edition(root, source_id, cache):
        number = str(entry.get("arabicnumber")) if entry.get("arabicnumber") is not None else str(entry["hadithnumber"])
        if number.split(".")[0] == locator:
            texts.append(skeleton(entry["text"]))
    return texts


def tokens_of(text):
    return [t for t in re.split(r"\s+", text.strip()) if t]


def check_derivation(where, item, problems):
    derivation = item.get("derivation")
    if not derivation:
        return
    to_word, from_word = skeleton(derivation["toWord"]), skeleton(derivation["fromWord"])
    quotes = [e["quote"] for e in item["evidence"]]
    swapped = [t for t in tokens_of(item["text"]) if skeleton(t) == to_word]
    if len(swapped) != 1:
        problems.append(f"{where}: derivation word {derivation['toWord']} must occur exactly once in the text")
        return
    if not any(swapped[0] in tokens_of(q) for q in quotes):
        problems.append(f"{where}: derived word {swapped[0]} is not taken with its vocalization from an evidence")
    rebuilt = "".join(from_word if skeleton(t) == to_word else skeleton(t) for t in tokens_of(item["text"]))
    if not any(rebuilt in skeleton(q) for q in quotes):
        problems.append(f"{where}: text with the original word restored is not inside any evidence quote")


def weak_in_grading(item):
    return bool(ALBANI_WEAK.search(item.get("grading") or ""))


def check_sunan_file(name, catalog, problems):
    """ملف السنن: بطاقات بأبواب، بلا عدّ ولا مسارات، وكل باب من أبواب الشريط ممثَّل."""
    used = set()
    for item in catalog["items"]:
        where = f"{name}:{item['id']}"
        if "count" in item or item.get("tracks"):
            problems.append(f"{where}: a sunnah card carries no count and no tracks")
        if item.get("bab") not in SUNAN_BABS:
            problems.append(f"{where}: unknown bab {item.get('bab')!r}")
        used.add(item.get("bab"))
    for bab in SUNAN_BABS:
        if bab not in used:
            problems.append(f"{name}: bab {bab} has no cards")
    if len(catalog["items"]) < MIN_SUNAN:
        problems.append(f"{name}: expected at least {MIN_SUNAN} sunan, got {len(catalog['items'])}")
    orders = [i["order"] for i in catalog["items"]]
    if orders != list(range(1, len(orders) + 1)):
        problems.append(f"{name}: orders must run 1..n without gaps")


def main():
    root = sys.argv[1]
    folders = sys.argv[2:] or ["assets/data/adhkar", "assets/data/sunan"]
    cache = {}
    extras = Extras()
    problems = []
    total = 0
    weak_items = 0
    paths = sorted(p for folder in folders for p in glob.glob(os.path.join(folder, "*.json")))
    for path in paths:
        with open(path, encoding="utf-8") as fh:
            catalog = json.load(fh)
        if "items" not in catalog or catalog.get("id") == "adhkar_seed":
            continue
        is_sunan = os.path.basename(os.path.dirname(os.path.abspath(path))) == "sunan"
        if is_sunan:
            check_sunan_file(os.path.basename(path), catalog, problems)
        tracked = [bool(i.get("tracks")) for i in catalog["items"]]
        if any(tracked) and not all(tracked):
            problems.append(f"{os.path.basename(path)}: tracks must be set on every item or on none")
        track_ids = set()
        for item in catalog["items"]:
            total += 1
            where = f"{os.path.basename(path)}:{item['id']}"
            tracks = item.get("tracks") or []
            if len(set(tracks)) != len(tracks):
                problems.append(f"{where}: duplicate tracks")
            track_ids.update(tracks)
            quotes = [e["quote"] for e in item["evidence"]]
            derived = item.get("derivation") is not None
            for field in ("text", "virtue"):
                value = item.get(field)
                if value is None:
                    continue
                if STRAY.search(value):
                    problems.append(f"{where}: {field} has stray marks")
                if field == "text" and derived:
                    continue
                if not any(skeleton(value) in skeleton(q) for q in quotes):
                    problems.append(f"{where}: {field} is not inside any evidence quote")
            check_derivation(where, item, problems)
            hisn_counts = []
            for e in item["evidence"]:
                if STRAY.search(e["quote"]):
                    problems.append(f"{where}: quote has stray marks")
                texts = hadith_texts(root, e["sourceId"], e["locator"], cache, extras)
                if not texts:
                    problems.append(f"{where}: {e['sourceId']} {e['locator']} not found")
                elif not any(skeleton(e["quote"]) in t for t in texts):
                    problems.append(f"{where}: quote not inside {e['sourceId']} {e['locator']}")
                if e["sourceId"] == "hisn_al_muslim":
                    hisn_counts.append(extras.hisn_count(e["locator"]))
            if is_sunan:
                if weak_in_grading(item):
                    problems.append(f"{where}: a sunnah card may not rest on a narration Albani weakened")
            elif item["count"] > 1:
                joined = " ".join(re.sub(" +", " ", re.sub("[^ء-ي ]", "", MARKS.sub("", q))) for q in quotes)
                stated = any(skeleton(p) in skeleton(joined) for p in NUMBER_WORDS.get(item["count"], ()))
                for note in item["review"]["notes"]:
                    match = HISN_NOTE.search(note)
                    if match:
                        hisn_counts.append(extras.hisn_count(match.group(1)))
                if not stated and item["count"] not in hisn_counts:
                    problems.append(f"{where}: count {item['count']} has no stated number in quotes or in Hisn")
            weak = bool(ALBANI_WEAK.search(item.get("grading") or ""))
            if weak:
                weak_items += 1
                if not item.get("caution"):
                    problems.append(f"{where}: weak narration without a caution banner")
            if item.get("caution") and not item.get("grading"):
                problems.append(f"{where}: caution without grading")
            if any(e["sourceId"] == "owner_adhkar_v290" for e in item["evidence"]) and not item.get("grading"):
                problems.append(f"{where}: owner-only text must carry a grading line")
        if track_ids and len(track_ids) != 2:
            problems.append(f"{os.path.basename(path)}: a toggle file needs exactly two tracks, got {sorted(track_ids)}")
    print(f"checked {total} items ({weak_items} weak per Albani in the edition)")
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print("all adhkar items verified against the pinned sources")


if __name__ == "__main__":
    main()
