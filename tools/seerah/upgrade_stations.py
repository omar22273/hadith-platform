#!/usr/bin/env python3
"""يرقّي محطات السيرة الاثنتي عشرة إلى البنية الموسوعية ذات الطبقتين.

  python3 tools/seerah/upgrade_stations.py --ih <ابن هشام> --is <ابن سعد> --bk <البخاري> [--dataset assets/data/seerah_dataset.json]

يقرأ الملف القائم، ويكتب فيه: epochs، وlتكل محطة: epoch_id وcovenant وشريط البوصلة وcompass_basis
وprevious_link وnext_hook وhook وshura_question وchapters. نصوص الفصول والبوصلة مقتطعة حرفياً
من المدونات المثبّتة بمواصفة stations_spec.py، والباقي صياغة تحريرية قصيرة منها. يمكن تشغيله
مراراً: كل تشغيل يعيد البناء من الأصل ويعطي الملف نفسه.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import book  # noqa: E402
import corpora  # noqa: E402
import epochs  # noqa: E402
import passages  # noqa: E402
import stations_spec as spec  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUKHARI_BASIS = re.compile(r"^bk(\d+)$")


class Corpora:
    """المدونات الثلاث محمّلة مرة واحدة."""

    def __init__(self, ih: str | None, is_: str | None, bk: str | None):
        self.ih = corpora.load_book("ih", ih)
        self.is_ = corpora.load_book("is", is_)
        self.bk = corpora.load_bukhari(bk)
        for key, path in (("ih", ih), ("is", is_), ("bk", bk)):
            actual = corpora.sha256(corpora.resolve(key, path))
            if actual != corpora.KNOWN_SHA256[key]:
                print(f"تحذير: بصمة مدونة «{key}» ({actual[:12]}…) تخالف المعروفة؛ تُراجع الطبعة.", file=sys.stderr)


def part_passages(part: tuple, c: Corpora) -> list[dict]:
    kind = part[0]
    if kind == "ih":
        _, index, prefix = part
        return passages.from_section(corpora.SOURCE_IDS["ih"], c.ih.section(index, prefix))
    if kind == "is":
        _, first, last = part[:3]
        occ = part[3] if len(part) > 3 else None
        return passages.from_items(corpora.SOURCE_IDS["is"], c.is_.cut(first, last, occ))
    if kind == "bk":
        number = part[1]
        if number not in c.bk:
            raise SystemExit(f"الحديث {number} غير موجود في مدونة البخاري")
        return [passages.hadith(corpora.SOURCE_IDS["bk"], number, c.bk[number])]
    raise SystemExit(f"نوع مقطع مجهول: {kind}")


def build_chapters(chapters: list, c: Corpora) -> list[dict]:
    out: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for number, (title, parts) in enumerate(chapters, start=1):
        items: list[dict] = []
        for part in parts:
            items.extend(part_passages(part, c))
        fresh = []
        for item in passages.dedupe(items):
            key = (item["sourceId"], item["quote"])
            if key not in seen:
                seen.add(key)
                fresh.append(item)
        if not fresh:
            raise SystemExit(f"الفصل «{title}» بلا مقاطع")
        out.append({"id": f"c{number}", "title": title, "passages": fresh})
    return out


def basis_quote(entry: tuple[str, str], c: Corpora) -> dict:
    source, phrase = entry
    match = BUKHARI_BASIS.match(source)
    if match:
        number = int(match.group(1))
        return passages.hadith(corpora.SOURCE_IDS["bk"], number, corpora.vocalized_span(c.bk[number], phrase))
    if source in ("ih", "is"):
        target = c.ih if source == "ih" else c.is_
        ((text, para),) = target.cut(phrase)
        return {"sourceId": corpora.SOURCE_IDS[source], "locator": para.locator, "quote": text}
    raise SystemExit(f"مصدر بوصلة مجهول: {source}")


def upgrade(dataset: dict, c: Corpora) -> dict:
    by_id = {s["id"]: s for s in dataset["stations"]}
    missing = [i for i in spec.ORDER if i not in by_id]
    unknown = [i for i in by_id if i not in spec.STATIONS]
    if missing or unknown:
        raise SystemExit(f"عدم تطابق المحطات مع المواصفة: ناقص={missing} زائد={unknown}")
    ordered = sorted(by_id.values(), key=lambda s: s["order"])
    result = []
    for index, old in enumerate(ordered):
        plan = spec.STATIONS[old["id"]]
        station: dict = {}
        station["id"] = old["id"]
        station["order"] = old["order"]
        station["title"] = old["title"]
        station["epoch_id"] = plan["epoch"]
        station["covenant"] = old.get("covenant") or old["epoch"]
        station["timeLabel"] = old.get("timeLabel")
        if plan["year"]:
            station["year_label"] = plan["year"]
        if plan["age"]:
            station["age_label"] = plan["age"]
        if plan["year"] or plan["age"]:
            station["compass_basis"] = [basis_quote(entry, c) for entry in plan["compass_basis"]]
        station["place"] = old["place"]
        station["onRoute"] = old["onRoute"]
        is_first, is_last = index == 0, index == len(ordered) - 1
        if plan.get("previous_link") and not is_first:
            station["previous_link"] = plan["previous_link"]
        if plan.get("next_hook") and not is_last:
            station["next_hook"] = plan["next_hook"]
        station["hook"] = plan["hook"]
        station["shura_question"] = plan["shura_question"]
        for key in ("sceneDescription", "challenge", "propheticDecision"):
            station[key] = old[key]
        if "dilemma_options" in old:
            station["dilemma_options"] = old["dilemma_options"]
        station["evidence"] = old["evidence"]
        station["chapters"] = build_chapters(plan["chapters"], c)
        notes = [n for n in old["review"]["notes"] if n != spec.REVIEW_NOTE]
        station["review"] = {**old["review"], "notes": notes + [spec.REVIEW_NOTE]}
        result.append(station)
    return {
        "schemaVersion": dataset["schemaVersion"],
        "id": dataset["id"],
        "title": dataset["title"],
        "epochs": epochs.as_json(),
        "stations": result,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ih", help="ملف سيرة ابن هشام (OpenITI)")
    parser.add_argument("--is", dest="is_", help="ملف الطبقات الكبرى (OpenITI)")
    parser.add_argument("--bk", help="ملف ara-bukhari.json")
    parser.add_argument("--dataset", default=os.path.join(ROOT, "assets/data/seerah_dataset.json"))
    parser.add_argument("--dry-run", action="store_true", help="لا يكتب الملف؛ يطبع الأحجام فقط")
    args = parser.parse_args()
    c = Corpora(args.ih, args.is_, args.bk)
    with open(args.dataset, encoding="utf-8") as handle:
        dataset = json.load(handle)
    # الملف المرقّى سابقاً يستعمل covenant بدل epoch؛ نقبل الصيغتين.
    for station in dataset["stations"]:
        if "epoch" in station and "covenant" not in station:
            station["covenant"] = station.pop("epoch")
    upgraded = upgrade(dataset, c)
    total = 0
    for station in upgraded["stations"]:
        chars = sum(len(p["quote"]) for ch in station["chapters"] for p in ch["passages"])
        count = sum(len(ch["passages"]) for ch in station["chapters"])
        total += chars
        print(f"{station['order']:>2} {station['id']:<28} فصول={len(station['chapters']):>2} مقاطع={count:>3} حروف={chars}")
    print(f"المجموع: {total} حرفاً")
    if not args.dry_run:
        with open(args.dataset, "w", encoding="utf-8") as handle:
            json.dump(upgraded, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        print(f"كُتب {args.dataset}")


if __name__ == "__main__":
    main()
