#!/usr/bin/env python3
"""يستخرج آلياً النصوص التي أدخلها مالك المشروع في طلب v2.9.0 دون أن تمرّ على يد المحرر.

الخط الأحمر: لا يُكتب نص قرآني ولا نبوي باليد. هذه الأداة تقرأ ملف الطلب نفسه وتخرج منه:
1. quran_owner_text.json : الآيات الخمس المشكولة بنصها الحرفي بين ﴿ ﴾ (آية الكرسي، خواتيم البقرة،
   الإخلاص، الفلق، الناس) مع تسمية مواضعها كما كتبها المالك.
2. owner_adhkar_v290.json : عبارات «…» التي أوردها المالك في بندي «أزرار التبديل» (الأسطر ٢٣–٢٤: ألفاظ
   الصباح والمساء) و«استكمال أذكار الصباح والمساء والنوم» (الأسطر ٣٢–٤٤) بنصها المشكول، لتُقارَن بما يُقتطع من المدونة المثبّتة، ولتُستعمل شاهداً للنصين اللذين
   لا يردان في الكتب الستة (يا حي يا قيوم، أن أشرك بك وأنا أعلم).

الاستعمال:
    python3 tools/content/extract_owner_texts.py <ملف الطلب> [--out tools/content/sources]
"""
import argparse
import json
import os
import re
import sys

QURAN_KEYS = ["ayat_al_kursi", "khawatim_al_baqara", "al_ikhlas", "al_falaq", "an_nas"]
QURAN_LABEL = re.compile(r"\*\*(.+?)\*\*")
QURAN_SPAN = re.compile("﴿(.+?)﴾")
ADHKAR_SPAN = re.compile("«([^»]+)»")


def read_lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().replace("\r\n", "\n").split("\n")


def extract_quran(lines):
    found = []
    for number, line in enumerate(lines, start=1):
        match = QURAN_SPAN.search(line)
        if not match:
            continue
        label = None
        for back in range(number - 2, max(number - 5, -1), -1):
            m = QURAN_LABEL.search(lines[back])
            if m:
                label = m.group(1).strip().rstrip(":").strip()
                break
        found.append({"line": number, "label": label, "text": match.group(1).strip()})
    if len(found) != len(QURAN_KEYS):
        raise SystemExit(f"expected {len(QURAN_KEYS)} Quran passages, found {len(found)}")
    for key, item in zip(QURAN_KEYS, found):
        item["id"] = key
    return found


def extract_adhkar(lines, ranges):
    """عبارات «…» في الأسطر المحددة؛ لكل عبارة مفتاح: رقم السطر، ثم .ترتيبها إن تعدّدت في سطر واحد."""
    found = []
    for first_line, last_line in ranges:
        for number in range(first_line, last_line + 1):
            line = lines[number - 1]
            matches = list(ADHKAR_SPAN.finditer(line))
            for index, match in enumerate(matches):
                rest = line[match.end():]
                count = re.match(r"\s*\(([^)]*)\)", rest)
                found.append({
                    "key": str(number) if len(matches) == 1 else f"{number}.{index + 1}",
                    "line": number,
                    "index": index,
                    "text": match.group(1).strip(),
                    "count_note": count.group(1).strip() if count else None,
                    "abridged": "..." in match.group(1) or "…" in match.group(1),
                })
    return found


def parse_ranges(value):
    """«23-24,32-44» إلى [(23, 24), (32, 44)]."""
    ranges = []
    for part in value.split(","):
        first, _, last = part.partition("-")
        ranges.append((int(first), int(last or first)))
    return ranges


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("request")
    parser.add_argument("--out", default="tools/content/sources")
    parser.add_argument("--adhkar-lines", default="23-24,32-44")
    args = parser.parse_args()
    lines = read_lines(args.request)
    quran = extract_quran(lines)
    adhkar = extract_adhkar(lines, parse_ranges(args.adhkar_lines))
    os.makedirs(args.out, exist_ok=True)
    for name, payload in (
        ("quran_owner_text.json", {"source": "owner-request-v2.9.0", "passages": quran}),
        ("owner_adhkar_v290.json", {"source": "owner-request-v2.9.0", "spans": adhkar}),
    ):
        path = os.path.join(args.out, name)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print("wrote", path)
    print(f"{len(quran)} Quran passages, {len(adhkar)} adhkar spans")


if __name__ == "__main__":
    sys.exit(main())
