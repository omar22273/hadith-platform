"""قارئ نصوص كتب السيرة: يحوّل ملف الكتاب النصي إلى أقسام وفقرات بصفحاتها.

الصيغ المدعومة (تُكتشف آلياً):
  * OpenITI mARkdown (الصيغة المثبّتة لابن هشام): عناوين `### | …` و`### || …`،
    وفقرات `# …` وسطور استمرار `~~…`، وعلامة نهاية الصفحة `PageV01P158`
    (الجزء ١ الصفحة ١٥٨ — العلامة تُغلق الصفحة التي قبلها).
  * نص عادي: عناوين بأسطر قصيرة تبدأ بـ «ذكر/أمر/باب/فصل/غزوة/سرية…»، وعلامات
    صفحة على نمط `[ص: ١٥٨]` أو `[الجزء: 1 ¦ الصفحة: 158]` إن وُجدت.

الخط الأحمر: لا يضيف هذا الملف حرفاً من خارج الكتاب. كل ما يخرج منه هو نص الكتاب
نفسه بعد إزالة علامات البنية فقط (علامات الصفحات والمعالم وأرقام الحواشي [n]
وتوحيد المسافات). `canon()` هي التعريف الوحيد لـ«الحرفي» في هذه الأدوات.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

HEADER_END = "#META#Header#End#"
OI_PAGE = re.compile(r"PageV(\d+)P(\d+)")
SHAMELA_PAGE = re.compile(r"\[(?:الجزء|ج)\s*:?\s*([0-9٠-٩]+)\s*[¦|،,-]?\s*(?:الصفحة|ص)\s*:?\s*([0-9٠-٩]+)\]")
SHAMELA_PAGE_ONLY = re.compile(r"\[(?:ص|الصفحة)\s*:?\s*([0-9٠-٩]+)\]")
MILESTONE = re.compile(r"\bms\d+\b")
FOOTNOTE_REF = re.compile(r"\[\d+\]")
HTML_TAG = re.compile(r"</?[A-Za-z][^>]*>")
TAGS = re.compile(r"\$RWY\$|@\w+@")
HEADING = re.compile(r"^#+\s*(\|+)\s*(.*?)\s*$")
HEADING_PLAIN = re.compile(
    r"^(?:ذكر|أمر|امر|باب|فصل|غزوة|سرية|بعث|حديث|قصة|مقتل|وفاة|هجرة|بيعة|فتح)\b[^.،؛:؟]{0,90}$"
)
TERMINAL = tuple(".:؟!؛»”)]")
ARABIC_INDIC = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def canon(text: str) -> str:
    """الصورة المعيارية للنص: بلا علامات البنية وبمسافات مفردة."""
    text = MILESTONE.sub(" ", text)
    text = TAGS.sub(" ", text)
    text = HTML_TAG.sub(" ", text)
    text = FOOTNOTE_REF.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()


def locator(vol: int, first: int, last: int) -> str:
    """موضع الصفحة بصيغة ملف البيانات: «ج1 ص158» أو «ج1 ص158–159»."""
    return f"ج{vol} ص{first}" if first == last else f"ج{vol} ص{first}–{last}"


@dataclass
class Para:
    """فقرة من الكتاب بنصها المعياري وصفحاتها."""

    text: str
    vol: int
    first_page: int
    last_page: int
    offset: int = 0  # موضعها في نص الكتاب المعياري، لترتيب المحطات بحسب الكتاب

    @property
    def locator(self) -> str:
        return locator(self.vol, self.first_page, self.last_page)


@dataclass
class Section:
    """قسم بعنوانه: مستواه ١ (عنوان كبير) أو ٢ أو ٣ (فرعي)."""

    level: int
    title: str
    index: int
    paras: list[Para] = field(default_factory=list)

    @property
    def chars(self) -> int:
        return sum(len(p.text) for p in self.paras)

    @property
    def first_page(self) -> tuple[int, int] | None:
        return (self.paras[0].vol, self.paras[0].first_page) if self.paras else None


@dataclass
class Book:
    """الكتاب مقسّماً: الأقسام بترتيبها، والنص المعياري الكامل للتحقق."""

    sections: list[Section]
    format: str
    full_text: str
    warnings: list[str] = field(default_factory=list)

    def paragraphs(self):
        for section in self.sections:
            yield from section.paras

    def section(self, index: int, title_prefix: str | None = None) -> Section:
        """القسم برقمه في الملف؛ ويتحقق من بداية عنوانه إن أُعطيت فلا يلتقط قسماً خطأً بعد تغيّر الطبعة."""
        section = self.sections[index]
        if title_prefix is not None and not section.title.lstrip("( ").startswith(title_prefix):
            raise LookupError(f"القسم {index} عنوانه «{section.title}» لا «{title_prefix}…»")
        return section

    def span(self, first: str, last: str | None = None, occ: int | None = None) -> list[Para]:
        """فقرات الكتاب من الفقرة التي تحوي `first` إلى التي تحوي `last` (وإلا فتلك وحدها).

        ترد `first` في الكتاب مرة واحدة ما لم يُعطَ `occ` (ترتيب الورود من الصفر) لاختيار موضع بعينه؛
        و`last` أول ورود لها بدءاً من فقرة `first`، ويشترط أن يتميز موضعها بذلك."""
        flat = list(self.paragraphs())
        a = _find_index(flat, canon(first), first, occ=occ)
        z = a if last is None else _find_index(flat, canon(last), last, start=a, first_hit=True)
        return flat[a : z + 1]

    def cut(self, first: str, last: str | None = None, occ: int | None = None) -> list[tuple[str, Para]]:
        """مقطع متصل من الكتاب يبدأ عند العبارة `first` وينتهي عند نهاية `last` (أو `first` إن لم تُعطَ).

        يعيد قائمة (نص، فقرة): الأولى مقتطعة من بدء العبارة والأخيرة إلى نهاية العبارة، وما بينهما كامل.
        النص المعاد تتابع حرفي من الكتاب لا أكثر."""
        paras = self.span(first, last, occ)
        a, z = canon(first), canon(last if last is not None else first)
        out: list[tuple[str, Para]] = []
        for i, para in enumerate(paras):
            text = para.text
            if i == 0:
                text = text[text.index(a):]
            if i == len(paras) - 1:
                tail = text.rfind(z) if i > 0 else text.find(z, text.index(a) if len(paras) == 1 else 0)
                if tail < 0:
                    raise LookupError(f"«{z[:30]}» ليست في الفقرة الأخيرة")
                text = text[: tail + len(z)]
            out.append((text, para))
        return out

    def verify(self, quote: str) -> int:
        """يعيد عدد مرات ورود `quote` في الكتاب بعد توحيدها؛ ٠ تعني أنها ليست منه."""
        needle = canon(quote)
        return self.full_text.count(needle) if needle else 0


def _find_index(
    paras: list[Para], needle: str, label: str, occ: int | None = None, start: int = 0, first_hit: bool = False
) -> int:
    hits = [i for i, p in enumerate(paras) if i >= start and needle in p.text]
    if not hits:
        raise LookupError(f"العبارة «{label[:40]}» ليست في الكتاب")
    if first_hit:
        return hits[0]
    if occ is not None:
        if occ >= len(hits):
            raise LookupError(f"العبارة «{label[:40]}» وردت {len(hits)} مرة فقط، لا موضع رقم {occ}")
        return hits[occ]
    if len(hits) != 1:
        raise LookupError(f"العبارة «{label[:40]}» وردت في {len(hits)} فقرة، والمطلوب فقرة واحدة")
    return hits[0]


def split_text(text: str, limit: int = 1500) -> list[str]:
    """يقسم نصاً طويلاً عند نهايات الجمل إلى مقاطع لا تتجاوز `limit` ما أمكن، دون حذف حرف.

    كل مقطع تتابع حرفي من النص الأصلي، فيبقى نصاً حرفياً من الكتاب."""
    if len(text) <= limit:
        return [text]
    sentences = re.split(r"(?<=[.؟!:]) ", text)
    pieces: list[str] = []
    current = ""
    for sentence in sentences:
        candidate = f"{current} {sentence}" if current else sentence
        if current and len(candidate) > limit:
            pieces.append(current)
            current = sentence
        else:
            current = candidate
    if current:
        pieces.append(current)
    return pieces


def _detect_format(raw: str) -> str:
    if OI_PAGE.search(raw) and re.search(r"(?m)^#{1,3}\s*\|", raw):
        return "openiti"
    return "plain"


def _arabic_int(value: str) -> int:
    return int(value.translate(ARABIC_INDIC))


def parse(raw: str) -> Book:
    """يحلّل نص الكتاب الخام إلى [Book]."""
    fmt = _detect_format(raw)
    if HEADER_END in raw:
        raw = raw.split(HEADER_END, 1)[1]
    return _parse_openiti(raw) if fmt == "openiti" else _parse_plain(raw)


# ----------------------------------------------------------------------------
# OpenITI
def _tokens_openiti(raw: str):
    """يحوّل الملف إلى رموز: ('heading', level, title) و('para', text) و('cont', text) و('page', vol, page)."""
    for line in raw.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        match = HEADING.match(stripped)
        if match and stripped.startswith("#"):
            level = min(len(match.group(1)), 3)
            title = match.group(2)
            if re.fullmatch(r"[A-Za-z]+\|?", title) or title.startswith("EDITOR"):
                continue
            yield ("heading", level, title)
            continue
        if stripped.startswith("~~"):
            kind, body = "cont", stripped[2:]
        elif stripped.startswith("#"):
            kind, body = "para", stripped.lstrip("#").strip()
        else:
            kind, body = "cont", stripped
        pieces = OI_PAGE.split(body)
        # split: [text, vol, page, text, vol, page, ..., text]
        for k in range(0, len(pieces), 3):
            if pieces[k].strip():
                yield (kind if k == 0 else "cont", pieces[k])
            if k + 2 < len(pieces):
                yield ("page", int(pieces[k + 1]), int(pieces[k + 2]))


class _OpenPara:
    """فقرة قيد البناء: صفحة كل قطعة منها هي صفحة أول علامة نهاية صفحة بعدها."""

    def __init__(self, section: Section):
        self.section = section
        self.pieces: list[str] = []
        self.pages: list[tuple[int, int]] = []

    @property
    def text(self) -> str:
        return canon(" ".join(self.pieces))


def _parse_openiti(raw: str) -> Book:
    sections: list[Section] = []
    current: Section | None = None
    built: list[_OpenPara] = []  # بترتيبها في الكتاب
    open_refs: list[_OpenPara] = []  # فقرات فيها نص لم تُغلق صفحته بعد
    last: _OpenPara | None = None
    last_page: tuple[int, int] = (1, 0)
    after_marker = False

    def touch(para: _OpenPara):
        if para not in open_refs:
            open_refs.append(para)

    def new_section(level: int, title: str):
        nonlocal current, last, after_marker
        current = Section(level=level, title=canon(title).rstrip(" :"), index=len(sections))
        sections.append(current)
        last = None
        after_marker = False

    for token in _tokens_openiti(raw):
        kind = token[0]
        if kind == "heading":
            new_section(token[1], token[2])
            continue
        if kind == "page":
            last_page = (token[1], token[2])
            for para in open_refs:
                para.pages.append(last_page)
            open_refs = []
            after_marker = True
            continue
        if current is None:
            new_section(1, "")
        if kind == "para":
            continues = (
                after_marker
                and last is not None
                and last.section is current
                and not last.text.endswith(TERMINAL)
            )
            if not continues:
                last = _OpenPara(current)
                built.append(last)
        elif last is None:
            last = _OpenPara(current)
            built.append(last)
        last.pieces.append(token[1])
        touch(last)
        after_marker = False

    for para in built:
        text = para.text
        if not text:
            continue
        pages = para.pages or [last_page]
        vol = pages[0][0]
        para.section.paras.append(
            Para(
                text=text,
                vol=vol,
                first_page=min(p for v, p in pages if v == vol),
                last_page=max(p for v, p in pages if v == vol),
            )
        )
    kept = [s for s in sections if s.paras or s.title]
    for i, section in enumerate(kept):
        section.index = i
    return _finish(kept, "openiti", [])


# ----------------------------------------------------------------------------
# نص عادي
def _parse_plain(raw: str) -> Book:
    sections: list[Section] = []
    current: Section | None = None
    warnings: list[str] = []
    vol, page = 1, 0
    has_pages = bool(SHAMELA_PAGE.search(raw) or SHAMELA_PAGE_ONLY.search(raw))
    if not has_pages:
        warnings.append(
            "لا علامات صفحات في الملف: مواضع الفقرات ستكون أرقام فقرات متسلسلة (ف١، ف٢…) لا أرقام صفحات."
        )
    counter = 0
    for line in raw.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        pm = SHAMELA_PAGE.search(stripped)
        if pm:
            vol, page = _arabic_int(pm.group(1)), _arabic_int(pm.group(2))
            stripped = SHAMELA_PAGE.sub(" ", stripped).strip()
        else:
            po = SHAMELA_PAGE_ONLY.search(stripped)
            if po:
                page = _arabic_int(po.group(1))
                stripped = SHAMELA_PAGE_ONLY.sub(" ", stripped).strip()
        if not stripped:
            continue
        body = stripped.lstrip("#").strip()
        if HEADING_PLAIN.match(body) or stripped.startswith("#"):
            current = Section(level=1, title=canon(body).rstrip(" :"), index=len(sections))
            sections.append(current)
            continue
        if current is None:
            current = Section(level=1, title="", index=0)
            sections.append(current)
        counter += 1
        text = canon(body)
        if not text:
            continue
        number = page if has_pages else counter
        current.paras.append(Para(text=text, vol=vol, first_page=number, last_page=number))
    return _finish(sections, "plain" if has_pages else "plain-nopages", warnings)


def _finish(sections: list[Section], fmt: str, warnings: list[str]) -> Book:
    offset = 0
    parts: list[str] = []
    for section in sections:
        for para in section.paras:
            para.offset = offset
            parts.append(para.text)
            offset += len(para.text) + 1
    return Book(sections=sections, format=fmt, full_text=" ".join(parts), warnings=warnings)


def read(path: str) -> Book:
    with open(path, encoding="utf-8") as handle:
        return parse(handle.read())
