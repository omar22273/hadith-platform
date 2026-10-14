"""مدونة الأحاديث المثبّتة وأدوات القصّ الحرفي لبناء ملفات الأذكار.

الخط الأحمر: لا يُكتب لفظ نبوي في أي ملف بناء. كل نص يخرج إلى ملفات الأذكار مقتطَع آلياً
من إصدارات fawazahmed0/hadith-api المثبّتة (الإيداع المسجَّل في assets/data/catalogs/sources.json)،
واختيار حدود القصّ يتم بكلمات مفتاحية مجرّدة من التشكيل تُقرأ من المدونة نفسها.

هذه الوحدة لا تعرف شيئاً عن الأذكار؛ تقدّم أمرين:
1. البحث: أين ترد عبارة مجرّدة في إصدار ما (لاختيار الحديث).
2. القصّ: مقطع من نص حديث بين كلمتين مفتاحيتين، مع إثبات أنه تتابع كلمات حرفي من المصدر.
"""
import json
import os
import re

COMMIT = "df57907be35291c91ad6a6691180e22ca9920784"

# مفتاح الإصدار المختصر -> (اسم الملف، معرّف المصدر في فهرس المصادر)
EDITIONS = {
    "b": ("bukhari", "sahih_bukhari"),
    "m": ("muslim", "sahih_muslim"),
    "t": ("tirmidhi", "sunan_tirmidhi"),
    "i": ("ibnmajah", "sunan_ibn_majah"),
    "n": ("nasai", "sunan_nasai"),
    "d": ("abudawud", "sunan_abu_dawud"),
}

RLM = "\u200f"
# الحركات والألف الخنجرية والتطويل وعلامات القرآن الصغيرة.
_MARKS = re.compile("[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]")
# علامات الترقيم وعلامات الاقتباس التي تلتصق بالكلمات في الإصدار الرقمي.
_EDGE = re.compile(
    r"^[\s\"'\u00ab\u00bb()\[\]{}<>\u200f\u200e\u2013\u2014\-:;,.!?\u061f\u060c\u061b]+"
    r"|[\s\"'\u00ab\u00bb()\[\]{}<>\u200f\u200e\u2013\u2014\-:;,.!?\u061f\u060c\u061b]+$"
)
_QUOTE_NOISE = re.compile("[\u200f\u200e\"\u00ab\u00bb{}]")


class CutError(Exception):
    """فشل قصّ أو تحقق: لا يُكتب شيء حين يقع."""


def plain(text):
    """الصورة المجرّدة: بلا تشكيل ولا تطويل، وتوحيد الألفات والياء والتاء المربوطة."""
    out = _MARKS.sub("", text)
    out = out.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
    out = out.replace("ى", "ي").replace("ة", "ه")
    return out


def core(token):
    """جوهر الكلمة للمطابقة: مجرّدة ومنزوع عنها الترقيم الطرفي."""
    return _EDGE.sub("", _QUOTE_NOISE.sub("", plain(token)))


def tokens(text):
    return [t for t in text.split() if t]


def clean_noise(text):
    """يزيل علامات الاتجاه وعلامات الاقتباس التي يضعها الإصدار الرقمي حول العبارات."""
    return re.sub(r"\s+", " ", _QUOTE_NOISE.sub("", text)).strip()


def strip_edges(text):
    """يزيل الترقيم الطرفي من مقطع مقتطع (فاصلة أو نقطتان أو شرطة في أول المقطع أو آخره)."""
    return _EDGE.sub("", text)


def find_sequence(toks, words, start=0):
    """مواضع (بداية، نهاية شاملة) لتتابع كلمات مفتاحية في قائمة الكلمات.

    الكلمات التي جوهرها فارغ (شرطة منفردة مثلاً) تُتجاوز عند المطابقة."""
    wanted = [core(w) for w in words]
    wanted = [w for w in wanted if w]
    if not wanted:
        raise CutError("no keywords")
    results = []
    for i in range(start, len(toks)):
        if not core(toks[i]) or core(toks[i]) != wanted[0]:
            continue
        j = i
        k = 0
        last = i
        while j < len(toks) and k < len(wanted):
            c = core(toks[j])
            if not c:
                j += 1
                continue
            if c != wanted[k]:
                break
            last = j
            k += 1
            j += 1
        if k == len(wanted):
            results.append((i, last))
    return results


class Corpus:
    def __init__(self, root):
        self.root = root
        self._cache = {}

    def edition(self, key):
        if key not in self._cache:
            name = EDITIONS[key][0]
            path = os.path.join(self.root, "editions", f"ara-{name}.json")
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
            by_number = {}
            for h in data["hadiths"]:
                by_number.setdefault(h["hadithnumber"], []).append(h)
            self._cache[key] = (data, by_number)
        return self._cache[key]

    def entries(self, key):
        return self.edition(key)[0]["hadiths"]

    def entry(self, key, number, arabicnumber=None):
        by_number = self.edition(key)[1]
        found = by_number.get(number, [])
        if arabicnumber is not None:
            found = [h for h in found if str(h.get("arabicnumber")) == str(arabicnumber)]
        if len(found) != 1:
            raise CutError(f"{key}:{number}: expected exactly one entry, got {len(found)}")
        return found[0]

    def _cores(self, key):
        if ("cores", key) not in self._cache:
            self._cache[("cores", key)] = [
                [c for c in (core(t) for t in tokens(h["text"])) if c] for h in self.entries(key)
            ]
        return self._cache[("cores", key)]

    def search(self, key, words, limit=40):
        """كل الأحاديث التي ترد فيها العبارة المفتاحية: [(رقم، arabicnumber، موضع الكلمة)]."""
        wanted = [c for c in (core(w) for w in words) if c]
        if not wanted:
            raise CutError("no keywords")
        size = len(wanted)
        hits = []
        for h, cores in zip(self.entries(key), self._cores(key)):
            for i in range(len(cores) - size + 1):
                if cores[i] == wanted[0] and cores[i:i + size] == wanted:
                    hits.append((h["hadithnumber"], h.get("arabicnumber"), i))
                    break
            if len(hits) >= limit:
                break
        return hits

    def grades(self, key, number, arabicnumber=None):
        entry = self.entry(key, number, arabicnumber)
        return [(g.get("name"), g.get("grade")) for g in entry.get("grades", [])]


def cut(text, first, last=None, occurrence=0, last_after_first=True, last_occurrence=0):
    """يقتطع من [text] مقطعاً من أول كلمة مفتاحية إلى آخر كلمة مفتاحية (شاملتين).

    [first] و[last] قائمتا كلمات (أو نص تُقسَّم كلماته). إن لم يُعطَ [last] فالمقطع هو
    [first] نفسها. يعيد (المقطع بعد إزالة علامات الاتجاه والاقتباس وبلا ترقيم طرفي، موضع البداية،
    موضع النهاية). يُثبت أن المقطع المُعاد تتابع حرفي من كلمات المصدر.
    """
    toks = tokens(text)
    first_words = first.split() if isinstance(first, str) else list(first)
    found = find_sequence(toks, first_words)
    if len(found) <= occurrence:
        raise CutError(f"start keywords {' '.join(first_words)!r}: found {len(found)} (wanted occurrence {occurrence})")
    s, first_end = found[occurrence]
    if last is None:
        e = first_end
    else:
        last_words = last.split() if isinstance(last, str) else list(last)
        after = first_end + 1 if last_after_first else s
        ends = find_sequence(toks, last_words, start=after)
        if len(ends) <= last_occurrence:
            raise CutError(f"end keywords {' '.join(last_words)!r}: found {len(ends)} after start")
        e = ends[last_occurrence][1]
    raw_slice = toks[s:e + 1]
    result = strip_edges(clean_noise(" ".join(raw_slice)))
    # إثبات الحرفية: كلمات المقطع (بعد التنقية) هي كلمات المصدر في الموضعين نفسيهما.
    produced = [core(w) for w in result.split()]
    produced = [w for w in produced if w]
    source = [core(w) for w in raw_slice]
    source = [w for w in source if w]
    if produced != source:
        raise CutError("cut words differ from the source slice")
    if result not in clean_noise(" ".join(toks)):
        raise CutError("cut is not a substring of the cleaned source text")
    if not result:
        raise CutError("empty cut")
    return result, s, e


def contains_plain(haystack, needle):
    """هل ترد العبارة (مجرّدة) داخل النص (مجرّداً) على حدود كلمات؟"""
    h = " ".join(core(t) for t in tokens(haystack) if core(t))
    n = " ".join(core(t) for t in tokens(needle) if core(t))
    return f" {n} " in f" {h} "
