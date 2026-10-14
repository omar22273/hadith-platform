"""قارئ «التحفة الربانية في شرح الأربعين النووية» لإسماعيل بن محمد الأنصاري.

المصدر الحصري للمتن والشرح الميسر في المشروع: ملف نصي ناتج عن OCR
(tools/content/sources/tuhfa_rabbaniyya_ocr.txt) أرفقه مالك المشروع. لكل حديث ثلاثة أقسام:
المتن المشكول، ثم «المفردات»، ثم «يستفاد منه».

ما يفعله هذا الملف:
  1. يقطع الكتاب إلى أقسام الأحاديث 1–42.
  2. ينظّف شكل OCR فقط: فواصل الصفحات وأرقامها وأسطر الزخرفة ووصل الأسطر المقطوعة.
  3. يقسم «المفردات» إلى (لفظة، بيان) و«يستفاد منه» إلى فوائد.
  4. يطبّق قائمة أخطاء OCR المحددة في tuhfa_fixes.py (كل إصلاح مسمّى ومتحقَّق أنه ينطبق).

لا يُضاف نص من خارج الملف. وكل نص معروض يمكن إرجاعه إلى موضعه في الكتاب.
"""

import re
from pathlib import Path

import tuhfa_fixes as fixes

DEFAULT_SOURCE = Path(__file__).resolve().parent / "sources" / "tuhfa_rabbaniyya_ocr.txt"
SOURCE_ID = "tuhfa_rabbaniyya"

ORDINALS = {
    "الأول": 1, "الثاني": 2, "الثالث": 3, "الرابع": 4, "الخامس": 5, "السادس": 6, "السابع": 7,
    "الثامن": 8, "التاسع": 9, "العاشر": 10, "الحادى عشر": 11, "الثاني عشر": 12, "الثالث عشر": 13,
    "الرابع عشر": 14, "الخامس عشر": 15, "السادس عشر": 16, "السابع عشر": 17, "الثامن عشر": 18,
    "التاسع عشر": 19, "العشرون": 20, "الحادى والعشرون": 21, "الثاني والعشرون": 22,
    "الثالث والعشرون": 23, "الرابع والعشرون": 24, "الخامس والعشرون": 25, "السادس والعشرون": 26,
    "السابع والعشرون": 27, "الثامن والعشرون": 28, "التاسع والعشرون": 29, "الثلاثون": 30,
    "الحادي والثلاثون": 31, "الثاني والثلاثون": 32, "الثالث والثلاثون": 33, "الرابع والثلاثون": 34,
    "الخامس والثلاثون": 35, "السادس والثلاثون": 36, "السابع والثلاثون": 37, "الثامن والثلاثون": 38,
    "التاسع والثلاثون": 39, "الأربعون": 40, "الحادى والأربعون": 41, "الثاني والأربعون": 42,
    # ملحق الكتاب: تتمة الخمسين (الأحاديث 43–50) التي ألحقها الحافظ ابن رجب بأحاديث النووي.
    "الثالث والأربعون": 43, "الرابع والأربعون": 44, "الخامس والأربعون": 45, "السادس والأربعون": 46,
    "السابع والأربعون": 47, "الثامن والأربعون": 48, "التاسع والأربعون": 49, "الخمسون": 50,
}
LAST_HADITH = 50
COLOPHON = re.compile(r"^تم بحمد الله وحسن توفيقه")

DIACRITICS = re.compile("[\u064b-\u065f\u0670\u0640\u06d6-\u06ed]")
ARABIC_LETTER = re.compile("[\u0621-\u064a\u0671-\u06d3]")
STRAY_CHARS = re.compile("[\u0f00-\u0fff\ufffd\u200c-\u200f\u2015<>{}|+#]")
PAGE_FOOTER = re.compile(r"\(\s*[\d٠-٩۰-۹]*\s*ال?ت[حج]فة\s*\)")
NUMBER_MARK = r"(?:[\d٠-٩۰-۹]+|[Vvهـدا])"
TERM_STOP = re.compile(r"[\.،؛»«]")
PAIRS = (("«", "»"), ("(", ")"))


def plain(text):
    """هيكل الحروف: بلا تشكيل ولا تفريق بين صور الهمزة والألف المقصورة."""
    text = DIACRITICS.sub("", text)
    text = re.sub("[إأآٱ]", "ا", text).replace("ى", "ي").replace("ؤ", "و").replace("ئ", "ي")
    return re.sub(r"\s+", " ", text).strip()


def squash(text):
    return re.sub(r"\s+", " ", text).strip()


class Section:
    """قسم حديث واحد من الكتاب."""

    def __init__(self, number, matn_raw, takhrij_raw, vocabulary, benefits, raw_lines):
        self.number = number
        self.matn_raw = matn_raw          # المتن كما في الكتاب (OCR خام، بلا فواصل الصفحات)
        self.takhrij_raw = takhrij_raw    # عبارة العزو في آخر المتن
        self.vocabulary = vocabulary      # [(لفظة، بيان)]
        self.benefits = benefits          # [نص]
        self.raw_lines = raw_lines

    def searchable(self):
        """نص الشرح كله (مفردات + فوائد) بعد الإصلاحات، للتحقق من الاقتباسات."""
        parts = [f"{term} : {meaning}" for term, meaning in self.vocabulary] + list(self.benefits)
        return " ".join(parts)


def _read_lines(path):
    return Path(path).read_text(encoding="utf-8").replace("\r", "").split("\n")


def _find_headings(lines):
    seen = {}
    for index, line in enumerate(lines):
        match = re.match(r"^الحديث (.+?)\s*$", line.strip())
        if match and match.group(1) in ORDINALS:
            seen.setdefault(ORDINALS[match.group(1)], index)
    return sorted(seen.items(), key=lambda item: item[1])


def _normalize_chars(text):
    """حروف OCR الشاذة فقط: ياء/كاف فارسيتان وحروف تبتية ورموز زائدة وعلامات الاتجاه."""
    text = STRAY_CHARS.sub("", text)
    text = re.sub(r"(?<=\s)\u0640+(?=\s)", "-", text)
    text = text.replace("\u0640", "")
    return text.replace("\u06cc", "\u064a").replace("\u06a9", "\u0643")


def _drop_unpaired(text, opening, closing):
    stack, drop = [], set()
    for index, char in enumerate(text):
        if char == opening:
            stack.append(index)
        elif char == closing:
            if stack:
                stack.pop()
            else:
                drop.add(index)
    drop.update(stack)
    return "".join(char for index, char in enumerate(text) if index not in drop)


def _collapse_dots(match):
    return "..." if match.group(0).count(".") >= 3 else "."


def tidy(text):
    """ترتيب علامات الترقيم فقط (لا يمسّ الحروف): مسافات قبل الفواصل، نقاط مكررة، أقواس يتيمة، ذيل مقطوع."""
    text = PAGE_FOOTER.sub(" ", text)
    text = squash(text)
    text = re.sub(r"(?<![\w])[A-Za-z]{1,2}(?![\w])", " ", text)
    text = re.sub(r"\s+ـ\s+", " - ", text)
    text = re.sub(r"\s+([\.،؛:؟!])", r"\1", text)
    text = re.sub(r"\.(?:\s*\.)+", _collapse_dots, text)
    text = re.sub(r"،(?:\s*،)+", "،", text)
    text = re.sub(r"،\s*\.", ".", text)
    text = re.sub(r"،(?=[^\s،])", "، ", text)
    for opening, closing in PAIRS:
        text = _drop_unpaired(text, opening, closing)
    text = re.sub(r"[\s،:؛\-–ـ]+$", "", text)
    text = re.sub(r"^[\s،:؛\-–ـ\.]+", "", text)
    text = re.sub(r"\(\s+", "(", text)
    text = re.sub(r"\s+\)", ")", text)
    return squash(text)


def _clean(lines, drop=()):
    out = []
    dropped = set()
    for raw in lines:
        text = squash(_normalize_chars(raw))
        if not text or text == "PAGE_SEPARATOR":
            continue
        if text in drop:
            dropped.add(text)
            continue
        if text in (":", "："):
            if out:
                out[-1] += " :"
            continue
        text = squash(PAGE_FOOTER.sub(" ", text))
        if not ARABIC_LETTER.search(text):
            continue
        out.append(text)
    return out, dropped


def _cut_colophon(lines):
    """خاتمة المطبعة بعد آخر حديث (تاريخ الطبع والتصحيح) ليست من الشرح: تُقطع عند أول سطر لها."""
    for index, line in enumerate(lines):
        if COLOPHON.match(line.strip()):
            return lines[:index]
    return lines


def _marker_index(lines, prefix, start=0):
    for index in range(start, len(lines)):
        line = lines[index].strip()
        if line.startswith(prefix) or (prefix == "يستفاد" and line.startswith("ما يستفاد")):
            return index
    return None


def _split_takhrij(text):
    words = text.split()
    for index in range(len(words) - 1, -1, -1):
        if plain(words[index]).strip(".،") in ("رواه", "رواة"):
            return " ".join(words[:index]), " ".join(words[index:])
    return text, ""


def _vocabulary_entries(lines):
    """يقسم «المفردات» إلى (لفظة، بيان): كل سطر أو جزء منه يبدأ بـ «لفظة : بيان» يفتح مدخلاً."""
    entries = []
    for line in lines:
        pieces = re.split(r"(?<=[\.،؛])\s+(?=[^\.:،؛]{1,50}?\s:\s)", line)
        for piece in pieces:
            match = re.match(r"^\s*([^:]{1,50}?)\s*:\s*(.*)$", piece)
            term_ok = match and len(match.group(1).split()) <= 7 and not TERM_STOP.search(match.group(1))
            continuation = bool(term_ok and re.match(r"^(?:و?قيل|و?قال|و?قد|و?أيضا|و?ذكر)\b", match.group(1)))
            if term_ok and not continuation:
                entries.append([match.group(1).strip(), match.group(2).strip()])
            elif entries:
                entries[-1][1] += " " + piece.strip()
            else:
                entries.append(["", piece.strip()])
    return [(term, squash(meaning)) for term, meaning in entries]


def _benefit_items(lines):
    """يقسم «يستفاد منه» إلى فوائد بحسب علامات الترقيم «١ -» أو «-» أول السطر أو وسطه."""
    joined = []
    for line in lines:
        if re.match(rf"^\s*(?:{NUMBER_MARK})?\s*[-ـ–]\s*\S", line) or re.match(r"^\s*[\d٠-٩۰-۹]+\s*[-ـ–.]", line):
            joined.append(line)
        elif joined:
            joined[-1] += " " + line
        else:
            joined.append(line)
    items = []
    for chunk in joined:
        for part in re.split(rf"(?<=[\.،؛ ])\s(?={NUMBER_MARK}\s-\s)", chunk):
            part = re.sub(rf"^\s*(?:{NUMBER_MARK})?\s*[-ـ–.]\s*", "", part)
            if part.strip():
                items.append(squash(part))
    return items


def _apply_entry_fixes(number, vocabulary, benefits, matn_text):
    """إصلاحات OCR على المداخل بعد التقسيم؛ كل إصلاح لا ينطبق يوقف البناء."""
    vocab = [[tidy(term), tidy(meaning)] for term, meaning in vocabulary]
    items = [tidy(item) for item in benefits]
    for old, new in fixes.FIX.get(number, []):
        done = False
        for entry in vocab:
            for column in (0, 1):
                if old in entry[column]:
                    entry[column] = entry[column].replace(old, new, 1)
                    done = True
                    break
            if done:
                break
        if not done:
            for index, item in enumerate(items):
                if old in item:
                    items[index] = item.replace(old, new, 1)
                    done = True
                    break
        if not done and old in matn_text:
            matn_text = matn_text.replace(old, new, 1)
            done = True
        if not done:
            raise ValueError(f"إصلاح OCR غير منطبق في الحديث {number}: «{old[:40]}»")
    for marker in fixes.BENEFIT_SPLIT.get(number, []):
        for index, item in enumerate(items):
            at = item.find(marker)
            if at > 0:
                tail = re.sub(rf"^\s*(?:{NUMBER_MARK})?\s*[-ـ–.]\s*", "", item[at:])
                items[index:index + 1] = [squash(item[:at]), squash(tail)]
                break
        else:
            raise ValueError(f"علامة تقسيم الفوائد غير موجودة في الحديث {number}: «{marker[:40]}»")
    for marker in fixes.VOCAB_SPLIT.get(number, []):
        for index, entry in enumerate(vocab):
            at = entry[1].find(marker)
            if at > 0:
                head, tail = squash(entry[1][:at]), squash(entry[1][at:])
                m = re.match(r"^([^:]{1,50}?)\s*:\s*(.*)$", tail)
                if not m:
                    raise ValueError(f"علامة تقسيم المفردات لا تحمل «لفظة : بيان» في الحديث {number}: «{marker[:40]}»")
                vocab[index:index + 1] = [[entry[0], head], [m.group(1).strip(), m.group(2).strip()]]
                break
        else:
            raise ValueError(f"علامة تقسيم المفردات غير موجودة في الحديث {number}: «{marker[:40]}»")
    for marker in fixes.BENEFIT_DROP.get(number, []):
        kept = [item for item in items if marker not in item]
        if len(kept) == len(items):
            raise ValueError(f"الفائدة المراد حذفها غير موجودة في الحديث {number}: «{marker[:40]}»")
        items = kept
    for old_term, replacements in fixes.VOCAB_REPLACE.get(number, {}).items():
        for index, entry in enumerate(vocab):
            if entry[0] == old_term:
                vocab[index:index + 1] = [[term, meaning] for term, meaning in replacements]
                break
        else:
            raise ValueError(f"مدخل المفردات المراد استبداله غير موجود في الحديث {number}: «{old_term}»")
    for term in fixes.VOCAB_MERGE.get(number, []):
        for index, entry in enumerate(vocab):
            if entry[0] == term and index > 0:
                previous = vocab[index - 1]
                joiner = " " if previous[1].endswith((".", "؛", "؟")) else "، "
                previous[1] = previous[1].rstrip(" ،") + joiner + term + ": " + entry[1]
                del vocab[index]
                break
        else:
            raise ValueError(f"مدخل المفردات المراد ضمّه لسابقه غير موجود في الحديث {number}: «{term}»")
    for term in fixes.VOCAB_DROP.get(number, []):
        kept = [entry for entry in vocab if entry[0] != term]
        if len(kept) == len(vocab):
            raise ValueError(f"مدخل المفردات المراد حذفه غير موجود في الحديث {number}: «{term}»")
        vocab = kept
    items = list(fixes.BENEFIT_EXTRA.get(number, [])) + items
    vocab = [(tidy(t), tidy(m)) for t, m in vocab]
    return [(t, m) for t, m in vocab if t and m], [tidy(i) for i in items if tidy(i)], matn_text


def load_sections(path=DEFAULT_SOURCE, errors=None):
    lines = _read_lines(path)
    headings = _find_headings(lines)
    sections = {}
    for position, (number, start) in enumerate(headings):
        end = headings[position + 1][1] if position + 1 < len(headings) else len(lines)
        body = _cut_colophon(lines[start + 1:end])
        wanted = set(fixes.DROP_LINES.get(number, ()))
        cleaned, dropped = _clean(body, wanted)
        if wanted - dropped:
            raise ValueError(f"سطر الحذف غير موجود في الحديث {number}: {sorted(wanted - dropped)}")
        vocab_at = _marker_index(cleaned, "المفردات")
        benefit_at = _marker_index(cleaned, "يستفاد", vocab_at or 0)
        matn_end = vocab_at if vocab_at is not None else benefit_at
        matn_text = squash(" ".join(cleaned[:matn_end]))
        vocab_lines = cleaned[(vocab_at or 0) + 1:benefit_at] if vocab_at is not None else []
        benefit_lines = cleaned[benefit_at + 1:] if benefit_at is not None else []
        if number in fixes.VOCAB_OVERRIDE:
            vocabulary = list(fixes.VOCAB_OVERRIDE[number])
        else:
            vocabulary = _vocabulary_entries(vocab_lines)
        if number in fixes.BENEFIT_OVERRIDE:
            benefits = list(fixes.BENEFIT_OVERRIDE[number])
        else:
            benefits = _benefit_items(benefit_lines)
        vocabulary = list(fixes.VOCAB_EXTRA.get(number, [])) + vocabulary
        try:
            vocabulary, benefits, matn_text = _apply_entry_fixes(number, vocabulary, benefits, matn_text)
        except ValueError as error:
            if errors is None:
                raise
            errors.append(str(error))
            continue
        matn_only, takhrij = _split_takhrij(matn_text)
        sections[number] = Section(number, matn_only, takhrij, vocabulary, benefits, body)
    return sections
