"""أدوات نص الأربعين: التنظيف الموثق والتقسيم إلى كلمات وفحص الضبط.

تُستعمل في بناء ملفات الأحاديث من النص الرقمي المثبّت (ara-nawawi.json) دون
أي كتابة للمتن من الذاكرة؛ كل تعديل يُسجَّل في provenance.
عقد التقسيم إلى كلمات مطابق لـ MatnTokenizer في Dart.
"""

import re

PUNCT = set("\"'«»()[]{}:.,،؛؟!?…")
TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
BIDI = re.compile("[‎‏‪-‮⁦-⁩؜]")
KASRA = "ِ"
FATHA = "َ"
SUKUN = "ْ"
SHADDA = "ّ"
DIACRITICS = set("ًٌٍَُِّْٰ")


def plain(text):
    """النص بلا تشكيل ولا علامات، مع توحيد صور الألف والياء (للمطابقة فقط)."""
    text = TASHKEEL.sub("", text)
    for source, target in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"), ("ى", "ي")):
        text = text.replace(source, target)
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", text)).strip()


def tokenize(text):
    """يعيد (raw, leading, core, trailing) لكل كلمة بعقد MatnTokenizer."""
    tokens = []
    for raw in text.strip().split():
        start, end = 0, len(raw)
        while start < end and raw[start] in PUNCT:
            start += 1
        while end > start and raw[end - 1] in PUNCT:
            end -= 1
        tokens.append((raw, raw[:start], raw[start:end], raw[end:]))
    return tokens


def cores(text):
    return [token[2] for token in tokenize(text)]


def base_clean(raw):
    """التطبيع الموثق الذي لا يمس الحروف ولا الحركات (يُسجَّل في provenance)."""
    text = BIDI.sub("", raw).replace("<br>", " ")
    text = re.sub(r"صلى الله عليه و ?سلم", "ﷺ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def lint_candidates(text):
    """كلمات يحتمل أن يكون ضبطها معيباً، تُراجع ثم تُعالَج صراحةً."""
    found = []
    words = cores(text)
    for index, word in enumerate(words):
        if word == "ﷺ" or not re.search("[ء-ي]", word):
            continue
        letters = [c for c in word if c not in DIACRITICS]
        if word.startswith("إ") and len(word) > 1 and word[1] != KASRA and not word.startswith("إِ"):
            found.append((index, word, "hamza_below_without_kasra"))
        if "ا" + FATHA in word:
            found.append((index, word, "fatha_on_wasl_alif"))
        if word and word[-1] not in DIACRITICS and word[-1] not in "اىويةو" and len(letters) > 2:
            found.append((index, word, "missing_final_vowel?"))
        nxt = words[index + 1] if index + 1 < len(words) else ""
        if word.endswith(SUKUN) and nxt.startswith("ا"):
            found.append((index, word + " " + nxt, "sukun_before_wasl?"))
    return found


STATEMENT = re.compile(r"\[(رَوَاهُ[^\]]*)\]\s*،?\s*\[([^\]]*)\]|\[(رَوَاهُ[^\]]*)\]")


def split_statement(text):
    """يفصل عبارة «[رواه …]» عن المتن؛ تعيد (المتن، العبارة بلا معقوفين)."""
    match = STATEMENT.search(text)
    if match is None:
        raise ValueError("no compiler statement")
    if match.group(1):
        statement = f"{match.group(1)}، {match.group(2)}"
    else:
        statement = match.group(3)
    rest = text[: match.start()] + " " + text[match.end():]
    return re.sub(r"\s+", " ", rest).strip(), statement


_PLAIN_FORMS = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي"})


def _is_mark(char):
    return "ً" <= char <= "ٟ" or char in "ٰـ" or "ؐ" <= char <= "ؚ" or "ۖ" <= char <= "ۭ"


def _plain_stream(text):
    """(الحرف المعياري، موضعه في الأصل) لكل حرف باقٍ بعد حذف التشكيل والترقيم وتوحيد الألف والياء."""
    out = []
    for position, char in enumerate(text):
        if _is_mark(char):
            continue
        if not (char.isalnum() or char == "_"):
            char = " "
        char = char.translate(_PLAIN_FORMS)
        if char == " " and (not out or out[-1][0] == " "):
            continue
        out.append((char, position))
    return out


def locate_plain(haystack, query):
    """يعيد المقطع من haystack المطابق لـ query بلا تشكيل ولا ترقيم (بحروف المصدر وحركاته)، أو None.

    يُستعمل لاختيار موضع الاقتباس فقط؛ فالمعاد دائماً نص حرفي من المصدر، لا من الكاتب.
    """
    stream = _plain_stream(haystack)
    target = "".join(char for char, _ in _plain_stream(query)).strip()
    if not target:
        return None
    joined = "".join(char for char, _ in stream)
    at = joined.find(target)
    if at < 0:
        return None
    start = stream[at][1]
    end = stream[at + len(target) - 1][1] + 1
    while end < len(haystack) and _is_mark(haystack[end]):
        end += 1
    return haystack[start:end]
