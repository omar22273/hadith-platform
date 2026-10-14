"""دمج «التحفة الربانية» في ملفات الأحاديث: غريب الألفاظ وحقل concise_explanation.

الخط الأحمر المعرفي: لا يُكتب هنا بيان لفظة ولا فائدة من الذاكرة؛ كلها تُنقل من مفردات
الكتاب وفوائده (بعد تنظيف أخطاء المسح الضوئي المسمّاة في tuhfa_fixes.py) نصاً حرفياً.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nawawi_text import cores, plain  # noqa: E402
from tuhfa_picks import PICKS  # noqa: E402

TUHFA_ID = "tuhfa_rabbaniyya"
MIN_GHARIB, MAX_GHARIB = 2, 4

SOURCE_NOTE = (
    "غريب الألفاظ والشرح الميسر (concise_explanation) منقولان نصاً من «التحفة الربانية في شرح الأربعين النووية» "
    "للشيخ إسماعيل الأنصاري، من ملف نصي ناتج عن مسح ضوئي (OCR) أرفقه مالك المشروع؛ صُحّحت أخطاء المسح الظاهرة "
    "بتعديلات مسمّاة في tools/content/tuhfa_fixes.py، وقد يبقى سهو لم يُكتشف فيُراجَع على المطبوع."
)
SHARH_NOTE = (
    "الكتاب لا يضع عنواناً باسم «المعنى الإجمالي»؛ فحقل concise_explanation يجمع مفردات الحديث ثم «يستفاد منه» "
    "كما وردا في الكتاب، كلٌّ في بابه."
)


def locator(number):
    return f"الحديث {number}"


def source_ref(number, quote=None):
    return {"sourceId": TUHFA_ID, "locator": locator(number), "quote": quote}


def concise_block(section, number):
    """الشرح الميسر للحديث: مفردات الكتاب ثم فوائده، بنصهما."""
    if not section.benefits:
        raise ValueError(f"الحديث {number}: لا فوائد في الكتاب")
    return {
        "source": source_ref(number),
        "vocabulary": [{"term": term, "explanation": meaning} for term, meaning in section.vocabulary],
        "benefits": list(section.benefits),
    }


def lookup(section, term, nth=0):
    """بيان لفظة من مفردات الكتاب (مطابقة معيارية)، ويعيد (اللفظ، البيان)."""
    key = plain(term)
    hits = [(t, m) for t, m in section.vocabulary if plain(t) == key]
    if len(hits) <= nth:
        raise ValueError(f"الحديث: لفظ المفردات غير موجود في الكتاب: «{term}» (الظهور {nth})")
    return hits[nth]


def find_anchor(segments, phrase):
    """أول موضع للعبارة في مقاطع المتن؛ يعيد مرساة TokenAnchor."""
    words = [plain(word) for word in phrase.split()]
    for segment in segments:
        token_cores = cores(segment["text"])
        plains = [plain(core) for core in token_cores]
        for index in range(len(plains) - len(words) + 1):
            if plains[index:index + len(words)] == words:
                return {
                    "segmentId": segment["id"],
                    "tokenIndex": index,
                    "length": len(words),
                    "surface": " ".join(token_cores[index:index + len(words)]),
                }
    raise ValueError(f"العبارة غير موجودة في المتن: «{phrase}»")


def gharib_entries(number, section, segments):
    """غريب الألفاظ للحديث من مفردات الكتاب، بحسب PICKS."""
    picks = PICKS[number]
    if not picks:
        # لا مفردات في الكتاب تنطبق على لفظ الحديث المعتمد: لا غريب يُولَّد من غيره.
        return []
    if not MIN_GHARIB <= len(picks) <= MAX_GHARIB:
        raise ValueError(f"الحديث {number}: عدد الألفاظ {len(picks)} خارج {MIN_GHARIB}–{MAX_GHARIB}")
    entries = []
    seen = set()
    for order, pick in enumerate(picks):
        phrase = pick[0]
        term = pick[1] if len(pick) > 1 and pick[1] else phrase
        nth = pick[2] if len(pick) > 2 else 0
        try:
            _, meaning = lookup(section, term, nth)
            anchor = find_anchor(segments, phrase)
        except ValueError as error:
            raise ValueError(f"الحديث {number}: {error}") from None
        key = (anchor["segmentId"], anchor["tokenIndex"], anchor["length"])
        if key in seen:
            raise ValueError(f"الحديث {number}: لفظتان على موضع واحد: «{phrase}»")
        seen.add(key)
        entries.append({
            "id": f"g{order + 1}",
            "anchor": anchor,
            "headword": anchor["surface"],
            "meaning": meaning,
            "sources": [source_ref(number, meaning)],
        })
    return entries


def apply_to_hadith(hadith, section):
    """يضع الغريب والشرح الميسر في كائن الحديث (إعادة بناء ترتيب المفاتيح)، ويعيد الكائن."""
    number = hadith["sequence"]
    hadith["matn"]["gharib"] = gharib_entries(number, section, hadith["matn"]["segments"])
    block = concise_block(section, number)
    ordered = {}
    for key, value in hadith.items():
        if key == "concise_explanation":
            continue
        ordered[key] = value
        if key == "matn":
            ordered["concise_explanation"] = block
    hadith.clear()
    hadith.update(ordered)
    notes = hadith["review"]["notes"]
    for note in (SHARH_NOTE, SOURCE_NOTE):
        if note not in notes:
            notes.insert(1, note)
    return hadith
