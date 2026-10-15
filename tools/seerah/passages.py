"""بناء مقاطع الفصول (passages) من المدونات: كلها اقتطاع حرفي مع موضعه، لا صياغة.

المقطع الواحد قاموس {sourceId, locator, quote} بصيغة SourceRef في ملف البيانات.
"""
from __future__ import annotations

import book
import corpora
from book import Book, Para, TERMINAL, locator, split_text

PASSAGE_LIMIT = 1500


def _merge_pages(a: Para, b: Para) -> tuple[int, int, int]:
    if a.vol != b.vol:
        return a.vol, a.first_page, a.last_page
    return a.vol, min(a.first_page, b.first_page), max(a.last_page, b.last_page)


def join_dangling(items: list[tuple[str, Para]]) -> list[tuple[str, Para]]:
    """يضم الفقرة التي لم تنتهِ بعلامة ترقيم نهائية إلى التي تليها، فلا تنقطع جملة في منتصفها.

    الفقرات المتتالية في الكتاب متصلة في نصه المعياري بمسافة واحدة، فالمضموم تتابع حرفي."""
    out: list[tuple[str, Para]] = []
    for text, para in items:
        if out and not out[-1][0].endswith(TERMINAL):
            prev_text, prev = out[-1]
            vol, first, last = _merge_pages(prev, para)
            merged = Para(text=f"{prev_text} {text}", vol=vol, first_page=first, last_page=last, offset=prev.offset)
            out[-1] = (merged.text, merged)
        else:
            out.append((text, para))
    return out


def from_items(source_id: str, items: list[tuple[str, Para]], limit: int = PASSAGE_LIMIT) -> list[dict]:
    result: list[dict] = []
    for text, para in join_dangling(items):
        for piece in split_text(text, limit):
            result.append({"sourceId": source_id, "locator": para.locator, "quote": piece})
    return result


def from_section(source_id: str, section) -> list[dict]:
    return from_items(source_id, [(p.text, p) for p in section.paras])


def hadith(source_id: str, number: int, text: str) -> dict:
    return {"sourceId": source_id, "locator": str(number), "quote": text}


def dedupe(passages: list[dict]) -> list[dict]:
    seen: set[tuple[str, str]] = set()
    out: list[dict] = []
    for item in passages:
        key = (item["sourceId"], item["quote"])
        if key not in seen:
            seen.add(key)
            out.append(item)
    return out
