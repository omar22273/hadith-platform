#!/usr/bin/env python3
"""يبني ملفات الأحاديث ١١–٢٠ من الأربعين النووية ويحدّث فهرس المنهج.

المبدأ (الخط الأحمر المعرفي): لا يُكتب متن حديث ولا بيان من الذاكرة.
- المتن يُقتطع من نص الأربعين الرقمي المثبّت (fawazahmed0/hadith-api، ara-nawawi).
- يُقابَل ضبط كل كلمة معيبة بالمتن المشكول للحديث نفسه في مصدره المثبّت (الصحيحان
  والسنن)، ولا يُقبل التعديل إلا إذا طابقت الكلمةُ رسماً وجاء الفرق إضافةَ
  الحركة المفقودة فقط؛ وكل تعديل يُسجَّل في provenance بقاعدته ومصدره.
- كل اقتباس (غريب، سياق، أثر) يُتحقق آلياً من أنه نص حرفي في موضعه:
  جامع العلوم والحكم (OpenITI Shamela0004268) أو نسخ الصحيحين والسنن المثبّتة.
  أي اقتباس غير مطابق يوقف البناء.
- التقطيع للتدريب بالعبارات التامة: يحدد كل مقطع بدايته فقط، وتنتهي العبارة
  حيث تبدأ التالية في المقطع نفسه، فلا تبقى كلمات خارج العبارات.

الاستعمال:
  python3 tools/content/build_nawawi_batch2.py --editions DIR --jami FILE [--root .] [--only 11,12]
  python3 tools/content/build_nawawi_batch3.py ...   (الأحاديث ٢١–٤٢، ويستعمل هذه الآلة نفسها)

يُضاف كتاب «التحفة الربانية» مصدراً رابعاً (النوع "k")، فتُتحقق اقتباساته حرفياً من ملفه النصي،
ويُستعمل متنه المشكول لإكمال الحركات المفقودة بالقواعد نفسها (لا يُغيَّر حرف ولا حركة موجودة).
حيث DIR فيه ara-nawawi/bukhari/muslim/tirmidhi/ibnmajah/nasai.json بالإصدار المثبّت
في assets/data/catalogs/sources.json، وFILE ملف OpenITI لجامع العلوم والحكم.
"""

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_nawawi_batch1 as b1  # noqa: E402
import nawawi_batch2_a  # noqa: E402
import nawawi_batch2_b  # noqa: E402
import tuhfa_book  # noqa: E402
import tuhfa_integration  # noqa: E402
from nawawi_text import (  # noqa: E402
    BIDI, DIACRITICS, FATHA, KASRA, SUKUN, base_clean, cores, lint_candidates, locate_plain, plain, tokenize,
)

_find_phrase = b1.find_phrase


def _find_plain(token_cores, phrase, start=0):
    """يبحث عن العبارة بصورتها المعيارية (إلى = الى)، فتُكتب بالإملاء المعتاد."""
    return _find_phrase(token_cores, " ".join(plain(word) for word in phrase.split()), start)


b1.find_phrase = _find_plain
BuildError = b1.BuildError
squash = b1.squash
canon = b1.canon

FIRST, LAST = 11, 20
MATN_SOURCE = "arbaun_nawawiyya"
JAMI = "jami_ulum_hikam"
SOURCE_IDS = {
    "b": "sahih_bukhari",
    "m": "sahih_muslim",
    "t": "sunan_tirmidhi",
    "i": "sunan_ibn_majah",
    "n": "sunan_nasai",
    "k": "tuhfa_rabbaniyya",
}
KIND_OF = {value: key for key, value in SOURCE_IDS.items()}
KIND_OF[MATN_SOURCE] = "a"
SHORT_VOWELS = "َُِ"
ID_RE = b1.ID_RE
MIN_CHUNKS, MAX_CHUNKS = 3, 16
ARABIC_LETTER = re.compile("[ء-ي]")
ANY_MARK = re.compile("[ً-ٰٟ]")


# ----------------------------------------------------------------------------
# المصادر
# ----------------------------------------------------------------------------
class Corpus(b1.Corpus):
    """المصادر مع السنن؛ كل نص يُنظَّف من محارف الاتجاه الخفية قبل المطابقة."""

    def __init__(self, editions, jami_file):
        super().__init__(editions, jami_file)

        def load(name):
            return json.load(open(Path(editions) / name, encoding="utf-8"))["hadiths"]

        self.sunan = {
            "t": {str(h["hadithnumber"]): h["text"] for h in load("ara-tirmidhi.json")},
            "i": {str(h["hadithnumber"]): h["text"] for h in load("ara-ibnmajah.json")},
            "n": {str(h["hadithnumber"]): h["text"] for h in load("ara-nasai.json")},
        }
        self.tuhfa = tuhfa_book.load_sections()

    def parts(self, kind, locator):
        """نصوص الحديث في المصدر (قد تتعدد في مسلم: 1676.01 ...)."""
        number = str(locator)
        if kind == "k":
            section = self.tuhfa.get(int(number))
            texts = [section.matn_raw + " " + section.takhrij_raw] if section else []
        elif kind == "b":
            texts = [self.bukhari.get(number, "")]
        elif kind == "m":
            texts = [text for key, text in self.muslim.items() if key == number or key.startswith(number + ".")]
        elif kind in self.sunan:
            texts = [self.sunan[kind].get(number, "")]
        else:
            raise BuildError(f"نوع مصدر مجهول: {kind}")
        return [squash(BIDI.sub("", text)) for text in texts if text]

    def book_texts(self, number):
        """نصوص الكتاب التي يجوز الاقتباس منها: المتن والعزو والمفردات والفوائد."""
        section = self.tuhfa.get(int(number))
        if section is None:
            return []
        texts = [section.matn_raw + " " + section.takhrij_raw]
        texts += [meaning for _, meaning in section.vocabulary]
        texts += list(section.benefits)
        return [squash(BIDI.sub("", text)) for text in texts if text]

    def has_number(self, kind, number):
        if kind == "a":
            return int(number) in self.nawawi
        return bool(self.parts(kind, number))

    def verify(self, kind, locator, quote):
        """يتحقق أن الاقتباس نص حرفي في موضعه، ويعيده بحروف المصدر وحركاته.

        المطابقة أولاً حرفية (مع حركات الكاتب)، فإن لم تقع طُوبق بلا تشكيل ولا ترقيم؛
        والمعاد في الحالتين مقطع المصدر نفسه، فلا يدخل المتن شيء من كتابة الكاتب.
        """
        if kind == "j":
            try:
                return super().verify(kind, locator, quote)
            except BuildError:
                page = self.pages.get(int(locator))
                found = locate_plain(page, quote) if page else None
                if found is None:
                    raise
                return found
        needle = squash(BIDI.sub("", quote))
        haystacks = self.book_texts(locator) if kind == "k" else self.parts(kind, locator)
        for haystack in haystacks:
            found = b1.locate_verbatim(haystack, needle)
            if found is not None:
                return found
        for haystack in haystacks:
            found = locate_plain(haystack, needle)
            if found is not None:
                return squash(found)
        raise BuildError(f"اقتباس غير حرفي ({kind} {locator}): {quote}")

    def verify_exact(self, kind, locator, quote):
        """مطابقة حرفية بالحركات فقط (دون المطابقة المجرّدة)؛ تُستعمل لإثبات ضبط ما يُدخل في المتن."""
        needle = squash(BIDI.sub("", quote))
        haystacks = self.book_texts(locator) if kind == "k" else self.parts(kind, locator)
        for haystack in haystacks:
            found = b1.locate_verbatim(haystack, needle)
            if found is not None:
                return found
        raise BuildError(f"ضبط غير حرفي في المصدر ({kind} {locator}): {quote}")

    def ref(self, spec):
        kind, locator, quote = spec
        found = self.verify(kind, locator, quote)
        if kind == "j":
            return {"sourceId": JAMI, "locator": f"ج1 ص{locator}", "quote": found}
        if kind == "k":
            return tuhfa_integration.source_ref(int(locator), found)
        return {"sourceId": SOURCE_IDS[kind], "locator": str(locator), "quote": found}

    def edit_source(self, spec):
        source_id, number, quote = spec
        found = self.verify(KIND_OF[source_id], number, quote)
        return {"sourceId": source_id, "locator": str(number), "quote": found}


# ----------------------------------------------------------------------------
# تنظيف المتن
# ----------------------------------------------------------------------------
def clean_statement(raw):
    text = re.sub(r"\[رقم:\s*\d*\]", "", raw)
    text = re.sub(r"\[[^\[\]]*[\d٠-٩][^\[\]]*\]", "", text)
    text = text.replace("[", "").replace("]", "")
    text = re.sub(r"\s+[ً-ٰٟ]+", "", text)  # حركة شاردة بعد مسافة (خطأ في المصدر الرقمي)
    text = re.sub(r'"([^"]*)"', r"«\1»", text).replace('"', "")
    text = re.sub(r"\s+([،.:])", r"\1", text)
    text = re.sub(r"([،:])\s*([،:])", r"\1", text)
    text = squash(text).rstrip(".").strip()
    return text


def normalise(raw, data, corpus=None):
    """يعيد (المتن المنظّف، عبارة المصنف، التطبيعات المطبّقة)."""
    applied = []
    text = raw
    if re.search("[‎‏‪-‮⁦-⁩؜]", text):
        applied.append("حذف محارف الاتجاه الخفية (Unicode bidi controls).")
    if "<br>" in text:
        applied.append("حذف وسم <br> الزائد من المصدر الرقمي.")
    text = base_clean(text)
    if "ﷺ" in text:
        applied.append("توحيد صيغة الصلاة على النبي إلى الرمز ﷺ.")
    for entry in data.get("pre", []):
        old, new, note = entry[:3]
        if old not in text:
            # المصدر الرقمي يرتّب الشدة والحركة ترتيباً مغايراً أحياناً؛ فتُطابَق الصورة المعيارية ويُستبدل المقطع الأصلي.
            canonical, spans = b1.canon_map(text)
            wanted = canon(old)
            at = canonical.find(wanted)
            if at < 0 or not wanted:
                raise BuildError(f"تعديل تمهيدي غير مطابق: «{old}»")
            old = text[spans[at][0]:spans[at + len(wanted) - 1][1]]
        if len(entry) > 3:
            # ضبط الكلمات الداخلة في المتن يُثبَت حرفياً بحركاته في مصدر مثبّت.
            kind, locator, quote = entry[3]
            corpus.verify_exact(kind, locator, quote)
            if canon(quote) not in canon(new):
                raise BuildError(f"إثبات التعديل التمهيدي لا يوافق النص الجديد: «{quote}»")
        text = text.replace(old, new, 1)
        applied.append(note)
    statement = None
    if data.get("statement") is not None:
        start_marker, end_marker = data["statement"]
        start = text.find(start_marker)
        if start < 0:
            raise BuildError(f"بداية عبارة المصنف غير موجودة: «{start_marker}»")
        end = len(text) if end_marker is None else text.find(end_marker, start)
        if end < 0:
            raise BuildError(f"نهاية عبارة المصنف غير موجودة: «{end_marker}»")
        statement = clean_statement(text[start:end])
        text = squash(text[:start] + " " + text[end:])
        applied.append("نقل عبارة العزو («رواه …») إلى takhrij.compilerStatement دون المعقوفين ولا أرقام التعليق «[رقم: …]».")
    cut_from = data.get("truncate_from")
    if cut_from:
        position = text.find(cut_from)
        if position < 0:
            raise BuildError(f"علامة القطع غير موجودة: «{cut_from}»")
        text = squash(text[:position])
        applied.append(data["truncate_note"])
    if "-" in text:
        text, count = re.subn(r"-(\S[^-]*?\S)-", r"(\1)", text)
        if count:
            applied.append("استبدال الشرطتين المحيطتين بجملة معترضة بقوسين؛ لأن الشرطة تلتصق بالكلمة في التقسيم.")
    quotes = [m.start() for m in re.finditer('"', text)]
    if quotes:
        if len(quotes) % 2:
            raise BuildError("علامات تنصيص فردية")
        chars = list(text)
        nested = data.get("nested_quotes", False)
        inner = quotes[1:-1] if nested else []
        for position in (quotes if not nested else (quotes[0], quotes[-1])):
            chars[position] = ""
        for order, position in enumerate(inner):
            chars[position] = "«" if order % 2 == 0 else "»"
        text = "".join(chars)
        applied.append("حذف علامات التنصيص حول كلام النبي ﷺ والراوي؛ إذ يحدده حقل voice.")
    before = text
    text = re.sub(r"\s+([.،؛:؟!])", r"\1", text)
    text = re.sub(r"([؟!])\.", r"\1", text)
    text = squash(text)
    if text != squash(before):
        applied.append("ضبط المسافات قبل علامات الترقيم.")
    return text, statement, applied


# ----------------------------------------------------------------------------
# تصحيح الضبط بمقابلة المصدر المشكول
# ----------------------------------------------------------------------------
def flagged(tokens):
    """مواضع الكلمات المعيبة: {الفهرس: القاعدة}."""
    found = {}
    text = " ".join(token[0] for token in tokens)
    for index, _word, rule in lint_candidates(text):
        rule = rule.rstrip("?")
        if rule == "hamza_below_without_kasra":
            continue
        found.setdefault(index, rule)
    for index, token in enumerate(tokens):
        core = token[2]
        if ARABIC_LETTER.search(core) and not ANY_MARK.search(core):
            found[index] = "missing_final_vowel"
        elif core.endswith("ك") and ARABIC_LETTER.search(core[:-1]):
            # كاف الخطاب العارية بعد كلمة مشكولة: نقص حركتها الأخيرة.
            found[index] = "missing_final_vowel"
    return found


def source_tokens(text):
    cleaned = squash(BIDI.sub("", text)).replace("صلى الله عليه وسلم", "ﷺ").replace('"', " ")
    return [token for token in tokenize(cleaned) if ARABIC_LETTER.search(token[2])]


LAM_ALIF_MARKS = re.compile("(ل)(ا)([\u064b-\u065f\u0670]+)")


def lam_alif(core):
    """يوحّد موضع الحركة في «لا»: ضبط الصحيحين يضعها بعد الألف، وضبط الأربعين قبلها."""
    return LAM_ALIF_MARKS.sub(r"\1\3\2", core)


def _letters_and_marks(text):
    """[(حرف، مجموعة حركاته)] لنص معياري تتقدم فيه الشدة."""
    pairs = []
    for char in canon(text):
        if ANY_MARK.match(char):
            if not pairs:
                return None
            pairs[-1][1].add(char)
        else:
            pairs.append((char, set()))
    return pairs


def only_missing_marks(before, src_core):
    """src_core إن لم يزد على before إلا بحركات ناقصة (الحروف نفسها، وحركات before كلها باقية)."""
    left, right = _letters_and_marks(before), _letters_and_marks(src_core)
    if left is None or right is None or len(left) != len(right):
        return None
    for (letter, marks), (other, source_marks) in zip(left, right):
        if letter != other or not marks <= source_marks:
            return None
    return src_core if canon(before) != canon(src_core) else None


def propose(before, rule, src_core):
    """يعيد الكلمة المصحّحة إن كان الفرق هو الحركة المفقودة فقط، وإلا None."""
    if canon(before) == canon(src_core):
        return None
    if rule == "missing_final_vowel":
        if not ANY_MARK.search(before):
            return src_core if ANY_MARK.search(src_core) else None
        if canon(src_core).startswith(canon(before)) and len(canon(src_core)) - len(canon(before)) == 1:
            vowel = canon(src_core)[-1]
            if vowel in SHORT_VOWELS:
                return before + vowel
        tail = canon(src_core)[-2:]
        if before.endswith("ك") and len(tail) == 2 and tail[0] == "ك" and tail[1] in SHORT_VOWELS:
            # كاف الخطاب: حركتها الأخيرة في المصدر تُستكمل، ولو اختلف ضبط ما قبلها بين الروايتين.
            return before + tail[1]
        return only_missing_marks(before, src_core)
    if rule == "sukun_before_wasl":
        if before.endswith(SUKUN) and canon(src_core) == canon(before[:-1]) + canon(src_core)[-1] \
                and canon(src_core)[-1] in SHORT_VOWELS:
            return before[:-1] + canon(src_core)[-1]
        return None
    if rule == "fatha_on_wasl_alif":
        fixed = before.replace("ا" + FATHA, "ا")
        return fixed if canon(fixed) == canon(src_core) else None
    return None


def align_edits(tokens, flags, align, corpus, number):
    """يقترح تعديلات الضبط من مقابلة المصادر؛ يعيد (التعديلات، غير المحلول)."""
    wanted = dict(flags)
    edits = {}
    plains = [plain(token[2]) for token in tokens]
    for kind, locator in align:
        for text in corpus.parts(kind, locator):
            src = source_tokens(text)
            src_plains = [plain(token[2]) for token in src]
            matcher = difflib.SequenceMatcher(None, plains, src_plains, autojunk=False)
            for tag, i1, i2, j1, j2 in matcher.get_opcodes():
                if tag != "equal":
                    continue
                for offset in range(i2 - i1):
                    index, other = i1 + offset, j1 + offset
                    if index not in wanted or index in edits:
                        continue
                    after = propose(tokens[index][2], wanted[index], lam_alif(src[other][2]))
                    if after is None:
                        continue
                    if kind == "k" and canon(after).endswith("ك" + KASRA) and not canon(tokens[index][2]).endswith(KASRA):
                        # كسر كاف الخطاب في ملف الكتاب الممسوح خطأ مسح محتمل في خطاب المذكر؛ لا يُنقل.
                        continue
                    source = None
                    for low, high in ((max(0, other - 1), min(len(src), other + 2)), (other, other + 1)):
                        quote = " ".join(token[0] for token in src[low:high])
                        try:
                            candidate = corpus.edit_source((SOURCE_IDS[kind], locator, quote))
                        except BuildError:
                            continue
                        if canon(src[other][2]) in canon(candidate["quote"]):
                            source = candidate
                            break
                    if source is not None:
                        edits[index] = (tokens[index][2], after, wanted[index], source)
    unresolved = sorted(index for index in wanted if index not in edits)
    return edits, unresolved


def apply_edits(tokens, flags, align, corpus, number):
    tokens = [list(token) for token in tokens]
    edits, unresolved = align_edits(tokens, flags, align, corpus, number)
    log = []
    for index, (before, after, rule, source) in sorted(edits.items()):
        if plain(before) != plain(after):
            raise BuildError(f"الحديث {number}: تعديل يغيّر الحروف: {before} → {after}")
        log.append((index, before, after, rule, "aligned_source", source))
        tokens[index][2] = after
    for index, token in enumerate(tokens):
        if re.search("إ(?!" + KASRA + ")", token[2]):
            fixed = re.sub("إ(?!" + KASRA + ")", "إ" + KASRA, token[2])
            earlier = next((i for i, entry in enumerate(log) if entry[0] == index), None)
            if earlier is None:
                log.append((index, token[2], fixed, "hamza_below_without_kasra", "orthographic_rule", None))
            else:
                # كلمة عُدّل ضبطها بالمقابلة ثم احتاجت كسرة الهمزة: تعديل واحد من الأصل إلى الصورة النهائية،
                # فيبقى كل تعديل في provenance مطابقاً للمتن المعروض.
                index_, before, _, rule, method, source = log[earlier]
                log[earlier] = (index_, before, fixed, rule, method, source)
            token[2] = fixed
    for token in tokens:
        token[0] = token[1] + token[2] + token[3]
    return [tuple(token) for token in tokens], sorted(log, key=lambda item: item[0]), unresolved


# ----------------------------------------------------------------------------
# بناء حديث واحد
# ----------------------------------------------------------------------------
COMMON_NOTES = [
    "نص الأربعين في المصدر الرقمي غير منسوب إلى طبعة ورقية بعينها؛ يُقابَل المتن المعروض بطبعة محققة.",
    "الموقف السلوكي والخلاصة والآثار صياغة تحريرية مستندة إلى الشروح المذكورة في حقول المصادر.",
    "طبقة طالب العلم (الأسانيد ومقارنة الروايات) لم تُملأ بعد لهذا الحديث؛ تُضاف مع تراجم رواته في دفعة لاحقة.",
    "التلاوة الصوتية لم تُسجَّل بعد.",
]
ALIGNED_NOTE = (
    "صُحّح ضبط بعض الكلمات بمطابقتها رسماً في المتن المشكول للحديث نفسه من مصدره المثبّت، "
    "ولم يُغيَّر إلا ما سقط من الحركات؛ وهو مسجّل في provenance.vocalizationEdits وتُراجع على طبعة محققة."
)


def build_hadith(number, data, corpus):
    raw = data.get("raw") or corpus.nawawi.get(number)
    if raw is None:
        raise BuildError(f"لا حديث {number} في الأربعين الرقمي")
    for spec in data.get("pre_sources", []):
        corpus.verify(*spec)
    body, statement, normalizations = normalise(raw, data, corpus)
    tokens = tokenize(body)
    flags = flagged(tokens)
    tokens, edit_log, unresolved = apply_edits(tokens, flags, data["align"], corpus, number)
    strict = lint_strict(tokens)
    if strict:
        raise BuildError(f"الحديث {number}: ضبط معيب متبقٍّ: {strict}")

    segments = b1.build_segments(tokens, data["segments"])
    by_id = {segment["id"]: segment for segment in segments}

    def seg_cores(segment_id):
        return [token[2] for token in by_id[segment_id]["tokens"]]

    matn_segments = [{
        "id": segment["id"],
        "voice": segment["voice"],
        "text": " ".join(token[0] for token in segment["tokens"]),
    } for segment in segments]
    for segment in matn_segments:
        if cores(segment["text"]) != seg_cores(segment["id"]):
            raise BuildError(f"الحديث {number}: عدم اتساق التقسيم في {segment['id']}")
    joined = " ".join(segment["text"] for segment in matn_segments)
    if plain(joined) != plain(body):
        raise BuildError(f"الحديث {number}: المتن المجزّأ لا يطابق المصدر")

    def anchor(segment_id, phrase):
        token_cores = seg_cores(segment_id)
        index = b1.find_phrase(token_cores, phrase)
        length = len(phrase.split())
        return {
            "segmentId": segment_id,
            "tokenIndex": index,
            "length": length,
            "surface": " ".join(token_cores[index:index + length]),
        }

    gharib = []
    for entry in data["gharib"]:
        if not ID_RE.match(entry["id"]):
            raise BuildError(f"معرّف غريب غير صالح: {entry['id']}")
        gharib.append({
            "id": entry["id"],
            "anchor": anchor(entry["seg"], entry["phrase"]),
            "headword": entry["headword"],
            "meaning": entry["meaning"],
            "sources": [corpus.ref(spec) for spec in entry["sources"]],
        })
    if data["gharib"] and not 2 <= len(gharib) <= 4:
        raise BuildError(f"الحديث {number}: الغريب يجب أن يكون بين 2 و4")

    takhrij = data["takhrij"]
    references = []
    for source_id, hadith_number, locator, system in takhrij["refs"]:
        if not corpus.has_number(KIND_OF[source_id], hadith_number):
            raise BuildError(f"الحديث {number}: رقم التخريج غير موجود {source_id} {hadith_number}")
        references.append({
            "sourceId": source_id,
            "hadithNumber": hadith_number,
            "numberingSystem": system,
            "digitalLocator": locator,
        })
    matn = {
        "segments": matn_segments,
        "gharib": gharib,
        "audio": {
            "status": "not_recorded", "remoteUrl": None, "reciter": None,
            "durationMs": None, "timings": [],
        },
        "takhrij": {
            "displayLabel": takhrij["label"],
            "references": references,
            "compilerStatement": {"text": statement, "sourceId": MATN_SOURCE} if statement else None,
            "gradings": [],
        },
    }

    chunks = build_chunks(number, data["chunks"], segments, seg_cores)
    practice = {
        "chunks": chunks,
        "reconstruction": {"chunkIds": [chunk["id"] for chunk in chunks], "shuffleStrategy": "per_user_per_day"},
        "vanishing": {
            "levels": [
                {"level": 1, "hidePercent": 25},
                {"level": 2, "hidePercent": 50},
                {"level": 3, "hidePercent": 80},
            ],
            "priorityAnchors": [anchor(segment_id, phrase) for segment_id, phrase in data["anchors"]],
        },
    }

    context_data = data["context"]
    context = {
        "narrative": context_data["narrative"],
        "humanMotive": context_data["humanMotive"],
        "place": None,
        "sources": [corpus.ref(spec) for spec in context_data["sources"]],
        "cautions": [{
            "text": text,
            "sources": [corpus.ref(spec) for spec in specs],
        } for text, specs in context_data["cautions"]],
    }

    scenario_data = data["scenario"]
    options = [{
        "id": f"o{order + 1}", "alignment": alignment, "text": text, "feedback": feedback,
    } for order, (alignment, text, feedback) in enumerate(scenario_data["options"])]
    if sum(option["alignment"] == "aligned" for option in options) != 1:
        raise BuildError(f"الحديث {number}: يجب خيار واحد موافق بالضبط")
    reflection = {
        "scenario": {
            "situation": scenario_data["situation"],
            "question": scenario_data["question"],
            "options": options,
            "takeaway": scenario_data["takeaway"],
            "basis": [corpus.ref(spec) for spec in scenario_data["basis"]],
        },
        "impacts": [{
            "text": text,
            "sources": [corpus.ref(spec) for spec in specs],
        } for text, specs in data["impacts"]],
    }

    def locate(index):
        for segment in segments:
            if segment["start"] <= index < segment["start"] + len(segment["tokens"]):
                return segment["id"], index - segment["start"]
        raise BuildError(f"كلمة خارج المقاطع: {index}")

    edits = []
    for index, before, after, rule, method, source in edit_log:
        segment_id, local = locate(index)
        edits.append({
            "segmentId": segment_id, "tokenIndex": local, "before": before, "after": after,
            "rule": rule, "method": method, "source": source,
        })
    notes = list(data["base_notes"]) if "base_notes" in data else list(COMMON_NOTES[:1])
    notes += data["notes"]
    if any(edit["method"] == "aligned_source" for edit in edits):
        notes.append(ALIGNED_NOTE)
    if unresolved:
        words = "، ".join(tokens[index][2] for index in unresolved[:12])
        more = "" if len(unresolved) <= 12 else f" … (و{len(unresolved) - 12} أخرى)"
        notes.append(
            f"بقي ضبط {len(unresolved)} موضعاً من المتن كما في المصدر الرقمي لعدم وجود مقابل مشكول موثق لها "
            f"في المصادر المثبّتة (آخر الكلمة أو السكون قبل همزة الوصل): {words}{more}؛ تُراجع على طبعة محققة."
        )
    notes += COMMON_NOTES[1:]

    hadith = {
        "schemaVersion": "2.0.0",
        "id": f"nawawi40_{number:03d}",
        "sequence": number,
        "collection": data.get("collection") or {
            "id": "arbaun_nawawiyya", "title": "الأربعون النووية", "numberInCollection": number},
        "title": data["title"],
        "teaser": {"text": data["teaser"]},
        "milestone": data["milestone"],
        "context": context,
        "matn": matn,
        "practice": practice,
        "reflection": reflection,
        "scholar": {"chains": [], "variants": []},
        "provenance": {
            "matnSource": data.get("matn_source") or {
                "sourceId": MATN_SOURCE, "locator": f"الحديث {number}", "quote": None},
            "normalizations": normalizations + list(data.get("extra_normalizations", [])),
            "vocalizationEdits": edits,
        },
        "review": {"status": "pending_scholarly_review", "reviewer": None, "reviewedAt": None, "notes": notes},
    }
    # الغريب والشرح الميسر من «التحفة الربانية» (يحلّان محل غريب المواصفات إن وُجد).
    try:
        return tuhfa_integration.apply_to_hadith(hadith, corpus.tuhfa[number])
    except (KeyError, ValueError) as error:
        raise BuildError(f"الحديث {number}: {error}") from None


def lint_strict(tokens):
    """عيوب لا يُسمح ببقائها: همزة تحت بلا كسرة، وفتحة على ألف وصل، وكلمة بلا أي حركة."""
    problems = []
    for index, token in enumerate(tokens):
        core = token[2]
        if not ARABIC_LETTER.search(core):
            continue
        if re.search("إ(?![ً-ٟ]*" + KASRA + ")", core):
            problems.append((index, core, "hamza_below_without_kasra"))
        if "ا" + FATHA in core:
            problems.append((index, core, "fatha_on_wasl_alif"))
        if not ANY_MARK.search(core):
            problems.append((index, core, "unvocalized"))
    return problems


def build_chunks(number, specs, segments, seg_cores):
    """عبارات التدريب: لكل عبارة بدايتها فقط، وتنتهي عند بداية التالية في المقطع نفسه."""
    starts = []
    last_segment, cursor = None, 0
    for label, segment_id, first in specs:
        token_cores = seg_cores(segment_id)
        begin = cursor + 1 if segment_id == last_segment else 0
        index = b1.find_phrase(token_cores, first, begin)
        if segment_id == last_segment and index <= starts[-1][2]:
            raise BuildError(f"الحديث {number}: عبارات غير مرتبة عند «{label}»")
        starts.append((label, segment_id, index))
        last_segment, cursor = segment_id, index
    chunks = []
    for order, (label, segment_id, index) in enumerate(starts):
        following = starts[order + 1] if order + 1 < len(starts) else None
        end = (following[2] - 1) if following and following[1] == segment_id else len(seg_cores(segment_id)) - 1
        length = end - index + 1
        segment_length = len(seg_cores(segment_id))
        if length < 2 and segment_length > 1:
            raise BuildError(f"الحديث {number}: العبارة «{label}» كلمة واحدة وليست عبارة")
        if len(label) > 40:
            raise BuildError(f"الحديث {number}: عنوان العبارة أطول من 40 حرفاً: {label}")
        chunks.append({
            "id": f"c{order + 1}", "segmentId": segment_id,
            "startToken": index, "endToken": end, "label": label,
        })
    if not MIN_CHUNKS <= len(chunks) <= MAX_CHUNKS:
        raise BuildError(f"الحديث {number}: عدد العبارات {len(chunks)} خارج {MIN_CHUNKS}–{MAX_CHUNKS}")
    return chunks


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(catalog=None, first=FIRST, last=LAST):
    parser = argparse.ArgumentParser()
    parser.add_argument("--editions", required=True)
    parser.add_argument("--jami", required=True)
    parser.add_argument("--root", default=".")
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    root = Path(args.root)
    corpus = Corpus(args.editions, args.jami)
    if catalog is None:
        catalog = {**nawawi_batch2_a.HADITHS, **nawawi_batch2_b.HADITHS}
    wanted = [int(n) for n in args.only.split(",") if n] or list(range(first, last + 1))
    full = not args.only
    if full and sorted(catalog) != list(range(first, last + 1)):
        raise BuildError(f"الأحاديث المعرّفة: {sorted(catalog)}")
    out_dir = root / "assets/data/hadith/nawawi40"
    sources = json.loads((root / "assets/data/catalogs/sources.json").read_text(encoding="utf-8"))
    known = {entry["id"] for entry in sources["sources"]}
    items = []
    for number in wanted:
        if number not in catalog:
            continue
        hadith = build_hadith(number, catalog[number], corpus)
        text = json.dumps(hadith, ensure_ascii=False)
        for source_id in set(re.findall(r'"sourceId": "([a-z0-9_]+)"', text)):
            if source_id not in known:
                raise BuildError(f"الحديث {number}: مصدر غير معرّف في الفهرس: {source_id}")
        path = out_dir / f"{hadith['id']}.json"
        write_json(path, hadith)
        items.append({
            "hadithId": hadith["id"],
            "number": number,
            "title": hadith["title"],
            "assetPath": f"assets/data/hadith/nawawi40/{hadith['id']}.json",
        })
        print(f"OK  {path.name}  chunks={len(hadith['practice']['chunks'])} gharib={len(hadith['matn']['gharib'])}"
              f" edits={len(hadith['provenance']['vocalizationEdits'])}")
    if full:
        curriculum_path = root / "assets/data/curriculum/nawawi40_curriculum.json"
        curriculum = json.loads(curriculum_path.read_text(encoding="utf-8"))
        kept = [item for item in curriculum["items"] if item["number"] < first]
        curriculum["items"] = kept + items
        write_json(curriculum_path, curriculum)
        print(f"OK  {curriculum_path}  items={len(curriculum['items'])}")


if __name__ == "__main__":
    try:
        main()
    except BuildError as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
