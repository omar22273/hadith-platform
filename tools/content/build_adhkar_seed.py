#!/usr/bin/env python3
"""Build the Adhkar seed (two items) from the pinned hadith-api editions.

Red line: no Prophetic wording is typed in this file. Every `quote` is cut out
of the edition files with structural rules (the n-th quoted span of a hadith),
and every `text` is cut out of its quote by word position. The script asserts
each cut and refuses to write anything it cannot prove is verbatim.

Usage:
    python3 tools/content/build_adhkar_seed.py <hadith-api checkout> [output]

The checkout must contain editions/ara-bukhari.json and editions/ara-muslim.json
at the commit recorded in assets/data/catalogs/sources.json
(fawazahmed0/hadith-api, df57907be35291c91ad6a6691180e22ca9920784).
"""
import json
import os
import re
import sys

COMMIT = "df57907be35291c91ad6a6691180e22ca9920784"
RLM = "‏"
TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
# A Prophetic statement inside a hadith is wrapped as: RLM, quote mark, RLM ... RLM, quote mark, RLM.
SPAN = re.compile(RLM + r'\s*"' + RLM + r"\s*(.+?)\s*" + RLM + '"' + RLM, re.S)


def plain(text):
    return TASHKEEL.sub("", text)


def load(root, edition):
    path = os.path.join(root, "editions", f"ara-{edition}.json")
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)["hadiths"]


def hadith(hadiths, number, arabicnumber=None):
    found = [h for h in hadiths if h["hadithnumber"] == number]
    assert len(found) == 1, f"hadith {number}: expected exactly one entry, got {len(found)}"
    if arabicnumber is not None:
        assert found[0].get("arabicnumber") == arabicnumber, (number, found[0].get("arabicnumber"))
    return found[0]["text"]


def quoted_span(full_text, index):
    spans = SPAN.findall(full_text)
    assert len(spans) > index, f"expected at least {index + 1} quoted spans, got {len(spans)}"
    span = spans[index].strip()
    assert RLM not in span and '"' not in span, "span must be one clean statement"
    assert span in full_text, "span must be a verbatim substring"
    return span


def after_word(span, stripped_marker):
    """The text after the first word whose unvocalized form equals the marker."""
    words = span.split(" ")
    for i, word in enumerate(words):
        if plain(word) == stripped_marker:
            return " ".join(words[i + 1:])
    raise AssertionError(f"marker {stripped_marker!r} not found")


def slice_words(span, first_plain, last_plain):
    """The exact run of words from the first word whose unvocalized form equals
    first_plain through the next word equal to last_plain (both included)."""
    words = span.split(" ")
    start = next((i for i, w in enumerate(words) if plain(w) == first_plain), None)
    assert start is not None, f"marker {first_plain!r} not found"
    end = next((i for i in range(start, len(words)) if plain(words[i]) == last_plain), None)
    assert end is not None, f"marker {last_plain!r} not found after {first_plain!r}"
    return " ".join(words[start:end + 1])


def review(notes):
    return {"status": "pending_scholarly_review", "reviewer": None, "reviewedAt": None, "notes": notes}


def main():
    root = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "assets/data/adhkar/adhkar_catalog.json"
    bukhari = load(root, "bukhari")
    muslim = load(root, "muslim")

    # سيد الاستغفار: أول عبارة نبوية في حديث البخاري 6306 هي الذكر كاملاً.
    b6306 = hadith(bukhari, 6306)
    sayyid_quote = quoted_span(b6306, 0)
    sayyid_text = after_word(sayyid_quote, "تقول")
    assert sayyid_text and sayyid_text in sayyid_quote
    # فضله: العبارة النبوية الثانية في الحديث نفسه كاملةً (من قالها موقناً ...).
    sayyid_virtue_quote = quoted_span(b6306, 1)
    assert sayyid_virtue_quote != sayyid_quote

    # التسبيح دبر الصلاة المكتوبة: العدد من مسلم 596 (حديث كعب بن عجرة)،
    # واللفظ من البخاري 843 (العبارة النبوية الثانية: «تقول ...»).
    m596 = hadith(muslim, 1349, arabicnumber="596.01")
    muslim_quote = quoted_span(m596, 0)
    b843 = hadith(bukhari, 843)
    bukhari_quote = quoted_span(b843, 1)
    tasbih_text = after_word(bukhari_quote, "تقول").split("،")[0].strip()
    assert tasbih_text and tasbih_text in bukhari_quote
    # فضله: مطلع شاهد مسلم من «معقبات» إلى «مكتوبة»، مقتطع بكلماته كما هي.
    tasbih_virtue = slice_words(muslim_quote, "معقبات", "مكتوبة")
    assert tasbih_virtue in muslim_quote

    provenance = (
        "النص والإحالة منقولان حرفياً بالاقتطاع الآلي من إصدار fawazahmed0/hadith-api المعتمد في "
        f"فهرس المصادر (الإيداع {COMMIT[:7]}) دون كتابة أي لفظ منه من الذاكرة "
        "(انظر tools/content/build_adhkar_seed.py)."
    )
    catalog = {
        "schemaVersion": "2.0.0",
        "id": "adhkar_seed",
        "title": "وِرد الأذكار",
        "items": [
            {
                "id": "sayyid_al_istighfar",
                "order": 1,
                "title": "سيّد الاستغفار",
                "text": sayyid_text,
                "count": 1,
                "virtue": sayyid_virtue_quote,
                "evidence": [
                    {"sourceId": "sahih_bukhari", "locator": "6306", "quote": sayyid_quote},
                    {"sourceId": "sahih_bukhari", "locator": "6306", "quote": sayyid_virtue_quote},
                ],
                "review": review([
                    provenance,
                    "الحديث لا يذكر عدداً؛ العدد (١) حدده مالك المنتج لبذرة الاختبار، ويتحقق المراجع من تقييد العدد في الروايات الأخرى.",
                    "الفضل: العبارة النبوية الثانية في الحديث نفسه منقولة كاملة، وهي شاهد ثانٍ بالموضع نفسه.",
                    "الضبط كما في الإصدار الرقمي دون تعديل؛ يراجعه مصحح قبل النشر.",
                ]),
            },
            {
                "id": "tasbih_dubur_al_salah",
                "order": 2,
                "title": "تسبيح دبر الصلاة المكتوبة",
                "text": tasbih_text,
                "count": 33,
                "virtue": tasbih_virtue,
                "evidence": [
                    {"sourceId": "sahih_muslim", "locator": "596", "quote": muslim_quote},
                    {"sourceId": "sahih_bukhari", "locator": "843", "quote": bukhari_quote},
                ],
                "review": review([
                    provenance,
                    "العدد ثلاث وثلاثون في نص الشاهدين؛ واللفظ المعدود مأخوذ من رواية البخاري. رقم مسلم بترقيم فؤاد عبد الباقي (الإصدار الرقمي: 596.01).",
                    "أُرجئ التحميد والتكبير والتهليل إلى حزمة المحتوى النهائية، وإن ذُكرت في نص الشاهد المنقول.",
                    "الفضل: مقتطع بكلماته من مطلع شاهد مسلم (من «معقبات» إلى «مكتوبة») دون تغيير.",
                    "الضبط كما في الإصدار الرقمي دون تعديل؛ يراجعه مصحح قبل النشر.",
                ]),
            },
        ],
    }
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(catalog, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print("wrote", out)
    for item in catalog["items"]:
        print(item["id"], item["count"], len(item["text"]), "chars of text;", len(item["evidence"]), "evidence")


if __name__ == "__main__":
    main()
