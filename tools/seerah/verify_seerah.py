#!/usr/bin/env python3
"""يدقق ملف رحلة السيرة: بنيته، وحرفية كل مقطع فيه مقابل المدونات المثبّتة.

  python3 tools/seerah/verify_seerah.py --ih <ابن هشام> --is <ابن سعد> --bk <البخاري>
  python3 tools/seerah/verify_seerah.py --structure-only          (بلا مدونات: للبنية وحدها)

ينتهي برمز خروج ١ عند أي مشكلة.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import checks  # noqa: E402
import corpora  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dataset", default=os.path.join(ROOT, "assets/data/seerah_dataset.json"))
    parser.add_argument("--ih")
    parser.add_argument("--is", dest="is_")
    parser.add_argument("--bk")
    parser.add_argument("--structure-only", action="store_true")
    args = parser.parse_args()
    with open(args.dataset, encoding="utf-8") as handle:
        dataset = json.load(handle)
    issues = checks.structure_issues(dataset)
    refs = sum(1 for _ in checks._refs(dataset))
    if not args.structure_only:
        books = {"ih": corpora.load_book("ih", args.ih), "is": corpora.load_book("is", args.is_)}
        bukhari = corpora.load_bukhari(args.bk)
        issues += checks.quote_issues(dataset, books, bukhari)
    for issue in issues:
        print("FAIL", issue)
    stations = len(dataset["stations"])
    print(
        f"{'FAIL' if issues else 'OK'}: {stations} محطة، {refs} شاهداً ومقطعاً"
        f"{' (بنية فقط)' if args.structure_only else ' دُققت حرفيتها على المدونات'}، {len(issues)} مشكلة"
    )
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
