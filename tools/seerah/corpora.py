"""تحميل المدونات المثبّتة التي تُقتطع منها فصول السيرة وتُدقَّق عليها.

المصادر (إيداعاتها مثبّتة في assets/data/catalogs/sources.json):
  * sira_ibn_hisham  — OpenITI، سيرة ابن هشام (طبعة السقا والأبياري والشلبي).
  * tabaqat_ibn_sad  — OpenITI، الطبقات الكبرى لابن سعد.
  * sahih_bukhari    — fawazahmed0/hadith-api، ara-bukhari.json.

لا تُنزّل الأدوات شيئاً من الشبكة: تُعطى مسارات الملفات المحلية صراحةً أو عبر
متغيرات البيئة SEERAH_IH وSEERAH_IS وSEERAH_BK، وتحذّر إن اختلفت بصمة الملف عن المعروفة.
"""
from __future__ import annotations

import hashlib
import json
import os
import re

import book

BIDI = "‪‫‬‭‮‎‏⁦⁧⁨⁩"

# بصمات SHA-256 للملفات كما قُرئت يوم بناء الفصول (٢٠٢٦-١٠-١٥)؛ اختلافها تحذير لا خطأ.
KNOWN_SHA256 = {
    "ih": "8e0d274c7bf5433d0c160aceca7e446f545be02a054035239b2dd349b5c399cd",
    "is": "723d6227f43a6a7a9871065ba5f486dcc2ef3301b53c531cc6391498daa42d66",
    "bk": "e34a3402889ca378871da3c5984b7875c680920e93f1c8738ac7afe502179562",
}

SOURCE_IDS = {"ih": "sira_ibn_hisham", "is": "tabaqat_ibn_sad", "bk": "sahih_bukhari"}


def sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve(key: str, explicit: str | None) -> str:
    path = explicit or os.environ.get(f"SEERAH_{key.upper()}")
    if not path or not os.path.isfile(path):
        raise SystemExit(
            f"ملف المدونة «{key}» غير موجود: مرّر مساره أو اضبط SEERAH_{key.upper()} (المعطى: {path!r})."
        )
    return path


def load_book(key: str, explicit: str | None = None) -> book.Book:
    return book.read(resolve(key, explicit))


def strip_bidi(text: str) -> str:
    for ch in BIDI:
        text = text.replace(ch, "")
    return text


def norm_hadith(text: str) -> str:
    """نص الحديث كما يُخزَّن في الملف: بلا علامات اتجاه وبمسافات مفردة."""
    return re.sub(r"\s+", " ", strip_bidi(text)).strip()


def load_bukhari(explicit: str | None = None) -> dict[int, str]:
    with open(resolve("bk", explicit), encoding="utf-8") as handle:
        data = json.load(handle)
    return {int(h["hadithnumber"]): norm_hadith(h["text"]) for h in data["hadiths"]}


_MARKS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")


def plain(text: str) -> str:
    """الصورة المجرّدة من التشكيل والتطويل؛ تبقى الحروف كما هي لتتطابق المواضع."""
    return _MARKS.sub("", text)


def vocalized_span(haystack: str, typed: str) -> str:
    """المقطع المشكول من `haystack` الذي يطابق `typed` (مجرداً من التشكيل)، حرفياً كما في المصدر.

    يرمي LookupError إن لم يرد أو ورد أكثر من مرة."""
    indexes: list[int] = []
    chars: list[str] = []
    for i, ch in enumerate(haystack):
        if _MARKS.match(ch):
            continue
        chars.append(ch)
        indexes.append(i)
    flat = "".join(chars)
    needle = plain(typed)
    first = flat.find(needle)
    if first < 0:
        raise LookupError(f"العبارة «{typed[:40]}» ليست في النص")
    if flat.find(needle, first + 1) >= 0:
        raise LookupError(f"العبارة «{typed[:40]}» وردت أكثر من مرة")
    start = indexes[first]
    end = indexes[first + len(needle) - 1] + 1
    while end < len(haystack) and _MARKS.match(haystack[end]):
        end += 1
    return haystack[start:end]
