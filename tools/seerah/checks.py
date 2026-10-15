"""فحوص سلامة ملف رحلة السيرة، مرآة لما يفرضه التطبيق عند التحميل (seerah_integrity.dart).

  structure_issues(dataset)             بنية الملف: الأطوار والترتيب وطبقتا المحطة والبوصلة والروابط.
  quote_issues(dataset, books, bukhari)  حرفية كل مقطع: وجوده في المدونة المثبّتة وموضعه.
"""
from __future__ import annotations

import re

import book
import corpora

LOCATOR = re.compile(r"^ج(\d+) ص(\d+)(?:–(\d+))?$")
SCENES = ("setting", "challenge", "decision")
LAYER1 = ("sceneDescription", "challenge", "propheticDecision")


def blank(value) -> bool:
    return value is None or not str(value).strip()


def structure_issues(dataset: dict) -> list[str]:
    issues: list[str] = []
    epochs = dataset.get("epochs", [])
    stations = dataset.get("stations", [])
    if not 8 <= len(epochs) <= 10:
        issues.append(f"epochs: عددها {len(epochs)} والمطلوب من ٨ إلى ١٠")
    epoch_ids = [e["id"] for e in epochs]
    numbers = [e["number"] for e in epochs]
    if len(set(epoch_ids)) != len(epoch_ids):
        issues.append("epochs: معرّفات مكررة")
    if len(set(numbers)) != len(numbers) or numbers != sorted(numbers):
        issues.append("epochs: أرقام مكررة أو غير مرتبة")
    rank = {e["id"]: e["number"] for e in epochs}
    ids: set[str] = set()
    orders: set[int] = set()
    chronological = sorted(stations, key=lambda s: s["order"])
    for position, station in enumerate(chronological):
        sid = station["id"]
        path = f"{sid}"
        if sid in ids:
            issues.append(f"{path}: معرّف مكرر")
        ids.add(sid)
        if station["order"] in orders:
            issues.append(f"{path}: ترتيب مكرر {station['order']}")
        orders.add(station["order"])
        if station["epoch_id"] not in rank:
            issues.append(f"{path}: epoch_id مجهول «{station['epoch_id']}»")
        elif position and station["epoch_id"] in rank and chronological[position - 1]["epoch_id"] in rank:
            if rank[station["epoch_id"]] < rank[chronological[position - 1]["epoch_id"]]:
                issues.append(f"{path}: طورها يسبق طور المحطة التي قبلها في الترتيب الزمني")
        if blank(station.get("title")):
            issues.append(f"{path}: العنوان فارغ")
        filled = [k for k in LAYER1 if not blank(station.get(k))]
        if filled and len(filled) != len(LAYER1):
            issues.append(f"{path}: طبقة المعايشة ناقصة؛ تُكتب المشهد والمأزق والقرار معاً أو لا تُكتب")
        has_layer1 = len(filled) == len(LAYER1)
        scenes = {e["scene"] for e in station.get("evidence", [])}
        if has_layer1:
            for scene in SCENES:
                if scene not in scenes:
                    issues.append(f"{path}: لا شاهد للمشهد «{scene}»")
        elif station.get("evidence"):
            issues.append(f"{path}: شواهد مشاهد بلا طبقة معايشة")
        for key in ("hook", "shura_question"):
            if station.get(key) is not None and not has_layer1:
                issues.append(f"{path}: {key} بلا طبقة معايشة")
            if key in station and blank(station[key]):
                issues.append(f"{path}: {key} فارغ")
        options = station.get("dilemma_options")
        if options is not None:
            challenge_quotes = [e["source"].get("quote") or "" for e in station.get("evidence", []) if e["scene"] == "challenge"]
            if len(options) < 2 or len(set(options)) != len(options):
                issues.append(f"{path}: dilemma_options تحتاج خيارين متمايزين")
            for option in options:
                if not any(option.strip() and option.strip() in quote for quote in challenge_quotes):
                    issues.append(f"{path}: خيار «{option[:30]}» ليس جزءاً حرفياً من شاهد المأزق")
        if (station.get("year_label") or station.get("age_label")) and not station.get("compass_basis"):
            issues.append(f"{path}: سنة أو عمر بلا compass_basis")
        if station.get("compass_basis") and not (station.get("year_label") or station.get("age_label")):
            issues.append(f"{path}: compass_basis بلا سنة ولا عمر")
        if position == 0 and station.get("previous_link"):
            issues.append(f"{path}: previous_link في أول محطة")
        if position == len(chronological) - 1 and station.get("next_hook"):
            issues.append(f"{path}: next_hook في آخر محطة")
        chapters = station.get("chapters", [])
        if not chapters:
            issues.append(f"{path}: بلا فصول")
        chapter_ids: set[str] = set()
        for chapter in chapters:
            if chapter["id"] in chapter_ids:
                issues.append(f"{path}: معرّف فصل مكرر {chapter['id']}")
            chapter_ids.add(chapter["id"])
            if blank(chapter.get("title")):
                issues.append(f"{path}/{chapter['id']}: عنوان الفصل فارغ")
            if not chapter.get("passages"):
                issues.append(f"{path}/{chapter['id']}: فصل بلا مقاطع")
            for index, passage in enumerate(chapter.get("passages", [])):
                where = f"{path}/{chapter['id']}[{index}]"
                if blank(passage.get("quote")):
                    issues.append(f"{where}: المقطع بلا نص")
                if blank(passage.get("locator")):
                    issues.append(f"{where}: المقطع بلا موضع")
    return issues


def _pages(locator: str):
    match = LOCATOR.match(locator)
    if not match:
        return None
    first = int(match.group(2))
    return int(match.group(1)), first, int(match.group(3) or first)


def _refs(dataset: dict):
    for station in dataset["stations"]:
        sid = station["id"]
        for k, item in enumerate(station.get("evidence", [])):
            yield f"{sid}/evidence[{k}]", item["source"]
        for k, ref in enumerate(station.get("compass_basis", []) or []):
            yield f"{sid}/compass_basis[{k}]", ref
        for chapter in station.get("chapters", []):
            for k, ref in enumerate(chapter["passages"]):
                yield f"{sid}/{chapter['id']}[{k}]", ref


def _occurrences(b: book.Book, needle: str):
    start = b.full_text.find(needle)
    while start >= 0:
        yield start
        start = b.full_text.find(needle, start + 1)


def _paragraph_pages(b: book.Book, start: int, end: int):
    """نطاق صفحات الفقرات التي يمر بها المقطع [start, end)."""
    pages = []
    for para in b.paragraphs():
        if para.offset <= end and start <= para.offset + len(para.text):
            pages.append((para.vol, para.first_page, para.last_page))
    return pages


def quote_issues(
    dataset: dict,
    books: dict[str, book.Book],
    bukhari: dict[int, str] | None = None,
    only_sources: set[str] | None = None,
) -> list[str]:
    """يدقق حرفية كل مقطع في الملف مقابل مدوناته.

    books     : كتب النصوص مفتاحها «ih» أو «is» أو معرّف المصدر نفسه (للطبعات الأخرى).
    bukhari   : نصوص البخاري برقم الحديث؛ بدونها تُترك مقاطع البخاري بلا تدقيق.
    only_sources: إن أُعطيت دُقّقت مقاطع هذه المصادر وحدها."""
    by_source = {corpora.SOURCE_IDS.get(key, key): value for key, value in books.items()}
    issues: list[str] = []
    for where, ref in _refs(dataset):
        source, quote, loc = ref["sourceId"], ref.get("quote") or "", ref.get("locator") or ""
        if only_sources is not None and source not in only_sources:
            continue
        if source == corpora.SOURCE_IDS["bk"]:
            if bukhari is None:
                continue
            if not loc.isdigit() or int(loc) not in bukhari:
                issues.append(f"{where}: رقم حديث البخاري «{loc}» غير موجود")
            elif corpora.norm_hadith(quote) not in bukhari[int(loc)]:
                issues.append(f"{where}: نص ليس من حديث البخاري {loc}: {quote[:40]}")
            continue
        b = by_source.get(source)
        if b is None:
            issues.append(f"{where}: مصدر لا مدونة له هنا «{source}»")
            continue
        needle = book.canon(quote)
        if needle != quote.strip() and book.canon(needle) != needle:
            issues.append(f"{where}: نص غير معياري")
        starts = list(_occurrences(b, needle))
        if not starts:
            # عنوان قسم من الكتاب نفسه (شاهد زمني مأخوذ من عناوين الطبعة).
            if any(book.canon(sec.title) == needle for sec in b.sections):
                continue
            issues.append(f"{where}: النص ليس في {source}: {quote[:50]}")
            continue
        wanted = _pages(loc)
        if wanted is None:
            issues.append(f"{where}: موضع بصيغة غير معروفة «{loc}»")
            continue
        vol, first, last = wanted
        ok = False
        for start in starts:
            for pvol, pfirst, plast in _paragraph_pages(b, start, start + len(needle)):
                if pvol == vol and pfirst <= last and first <= plast:
                    ok = True
        if not ok:
            issues.append(f"{where}: صفحة المقطع لا تطابق الموضع «{loc}»")
    return issues
