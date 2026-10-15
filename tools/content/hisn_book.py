"""قارئ ملف «حصن المسلم» المرفق: فصول وأذكار بصيغة ch|chTitle|itemNo|text.

الملف نسخة رقمية بها شوائب نسخ وأخطاء إملائية (علامات اقتباس وأقواس حول النص، وكلمات
ملتصقة بعلامات الترقيم، وتشكيل ناقص أو غائب في أغلب الأذكار، وسهو في بعض الكلمات). لا يُعتمد
نصه لعرضٍ مشكول؛ يُقرأ ويُنظَّف ثم يُطابَق على المدونة المثبتة (الكتب الستة) فيؤخذ التشكيل من
المدونة وحدها (انظر hisn_align.py). كل ما يُعدَّل في الملف يُسجَّل باسم في hisn_fixes.py
ويُتحقق أنه طُبِّق مرة واحدة بالضبط، فلا يمرّ تعديل صامت.

الاستعمال:
    from hisn_book import load
    book = load("tools/content/sources/hisn_al_muslim.txt")
    entry = book.entry(27, 86)   # فصل أذكار الصباح والمساء، الذكر رقم ٨٦
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import adhkar_corpus as ac  # noqa: E402
import hisn_fixes  # noqa: E402

BOM = "﻿"

# أسماء الأعداد في الأقواس إلى قيمها. تُستعمل لمقارنة عدد الملف بعدد الشاهد، لا لتحديد العدد.
COUNT_WORDS = [
    ("ثلاثاً وثلاثين", 33),
    ("ثلاثا وثلاثين", 33),
    ("أربعاً وثلاثين", 34),
    ("اربعا وثلاثين", 34),
    ("مرة واحدة", 1),
    ("مرتين", 2),
    ("ثلاث مرات", 3),
    ("ثلاثاً", 3),
    ("ثلاثا", 3),
    ("أربع مرات", 4),
    ("أربعاً", 4),
    ("خمس مرات", 5),
    ("ست مرات", 6),
    ("سبع مرات", 7),
    ("عشر مرات", 10),
    ("مائة مرة", 100),
    ("مئة مرة", 100),
    ("مائة", 100),
    ("مئة", 100),
]

_PAREN = re.compile(r"\(\s*([^()]*?)\s*\)")
_WRAP = re.compile(r'^[\s"“”«»]+|[\s"“”«».]+$')
_SPACE = re.compile(r"\s+")
_BEFORE_PUNCT = re.compile(r"\s+([،,.:؛!؟])")
_AFTER_COMMA = re.compile(r"([،,؛])(?=[^\s\d])")


class HisnError(Exception):
    """خلل في الملف أو في قائمة الإصلاحات: لا يُعتمد شيء حين يقع."""


class HisnEntry:
    """ذكر واحد من الملف بعد التنظيف."""

    def __init__(self, chapter, chapter_title, number, raw, text, count_words, count, is_quran):
        self.chapter = chapter
        self.chapter_title = chapter_title
        self.number = number
        self.raw = raw
        self.text = text
        self.count_words = count_words
        self.count = count
        self.is_quran = is_quran

    @property
    def tokens(self):
        """جواهر كلمات النص بلا تشكيل ولا ترقيم، للمطابقة."""
        return [c for c in (ac.core(t) for t in self.text.split()) if c]

    def __repr__(self):
        return f"HisnEntry({self.chapter}:{self.number} {self.text[:30]!r})"


class HisnBook:
    def __init__(self, entries, applied):
        self.entries = entries
        self.applied = applied
        self._by_key = {}
        for e in entries:
            self._by_key.setdefault((e.chapter, e.number), []).append(e)

    def entry(self, chapter, number):
        found = self._by_key.get((chapter, number), [])
        if len(found) != 1:
            raise HisnError(f"hisn {chapter}:{number}: expected one entry, got {len(found)}")
        return found[0]

    def chapter(self, chapter):
        return [e for e in self.entries if e.chapter == chapter]

    def chapters(self):
        seen = {}
        for e in self.entries:
            seen.setdefault(e.chapter, e.chapter_title)
        return seen


def read_rows(path):
    """الصفوف الخام بلا أي تعديل: (فصل، عنوان، رقم، نص)."""
    with open(path, encoding="utf-8") as fh:
        data = fh.read()
    data = data.lstrip(BOM).replace("\r\n", "\n").replace("\r", "\n")
    rows = []
    for number, line in enumerate(data.split("\n"), start=1):
        if not line.strip():
            continue
        parts = line.split("|", 3)
        if len(parts) != 4:
            raise HisnError(f"line {number}: expected 4 fields, got {len(parts)}")
        try:
            rows.append((int(parts[0]), parts[1].strip(), int(parts[2]), parts[3]))
        except ValueError:
            raise HisnError(f"line {number}: chapter/item numbers must be integers")
    return rows


def split_count(text):
    """يفصل الأقواس التي تحمل عدداً أو شرطاً (ثلاث مرات، إذا أصبح) عن نص الذكر.

    يعيد (النص بلا الأقواس، قائمة محتويات الأقواس التي هي أعداد أو شروط، العدد الأول إن وُجد)."""
    notes = []
    count = None

    def take(match):
        nonlocal count
        inner = match.group(1).strip()
        for word, value in COUNT_WORDS:
            if word in inner:
                if count is None:
                    count = value
                notes.append(inner)
                return " "
        if re.search(r"إذا|اذا|مرة|مرات|يفعل|كل صلاة|بعد|في اليوم", inner):
            notes.append(inner)
            return " "
        return match.group(0)

    stripped = _PAREN.sub(take, text)
    return stripped, notes, count


def clean(text):
    """التنظيف العام المسمّى: علامات الاقتباس والأقواس المعقوفة والمسافات والترقيم الملتصق."""
    out = text
    is_quran = "{" in out and "}" in out
    out = out.replace("{", " ").replace("}", " ")
    out = out.replace("[", " ").replace("]", " ")
    out = out.replace("*", " ")
    out = _BEFORE_PUNCT.sub(r"\1", out)
    out = _AFTER_COMMA.sub(r"\1 ", out)
    out = _SPACE.sub(" ", out).strip()
    out = _WRAP.sub("", out)
    out = _SPACE.sub(" ", out).strip()
    return out, is_quran


def load(path, fixes=None):
    """يقرأ الملف وينظفه ويطبّق الإصلاحات المسمّاة، ويتحقق أن كلاً منها طُبِّق مرة واحدة."""
    fixes = hisn_fixes.FIXES if fixes is None else fixes
    rows = read_rows(path)
    applied = {}
    entries = []
    for chapter, title, number, raw in rows:
        text = raw
        for fix in fixes.get((chapter, number), ()):
            hits = text.count(fix.find)
            if hits != 1:
                raise HisnError(
                    f"fix {fix.name} ({chapter}:{number}): {fix.find!r} occurs {hits} times, expected exactly 1"
                )
            text = text.replace(fix.find, fix.replace)
            applied[fix.name] = applied.get(fix.name, 0) + 1
        text, notes, count = split_count(text)
        text, is_quran = clean(text)
        entries.append(HisnEntry(chapter, title, number, raw, text, notes, count, is_quran))
    expected = {fix.name for group in fixes.values() for fix in group}
    missing = expected - set(applied)
    if missing:
        raise HisnError(f"fixes never applied: {sorted(missing)}")
    return HisnBook(entries, applied)
