#!/usr/bin/env python3
"""يستوعب نص «سيرة ابن هشام» الكامل فيولّد محطات رحلة السيرة آلياً ويدمجها في ملف البيانات.

  python3 tools/seerah/ingest_ibn_hisham.py --book <ملف الكتاب النصي> --dry-run --report report.md
  python3 tools/seerah/ingest_ibn_hisham.py --book <ملف الكتاب النصي>

صيغة الملف تُكتشف آلياً (OpenITI mARkdown أو نص عادي بعناوين «ذكر/أمر/غزوة…» وعلامات صفحات
`[ص: ١٥٨]` أو `[الجزء: 1 ¦ الصفحة: 158]`)؛ انظر book.py.

ما تفعله الأداة، بالترتيب:
  ١. تقسم الكتاب إلى «وحدات» (كل عنوان كبير مع عناوينه الفرعية).
  ٢. تتخطى وحدات لا تصلح محطات (شعر، قوائم أسماء، أنساب، تفسير آيات، وما قبل بداية المنهج)
     بقواعد ingest_config.json، وتسجّل كل تخطٍّ وسببه في التقرير.
  ٣. تسند كل وحدة إلى طورها بمراسي العناوين (epoch_anchors)، وعهدها (قبل البعثة/المكي/المدني).
  ٤. تضم الوحدات الصغيرة المتجاورة في المحطة الواحدة، وتقسم الوحدة الضخمة أجزاء.
  ٥. تبني لكل محطة فصولاً من أقسام الكتاب نفسها ومقاطع حرفية (≤ ١٥٠٠ حرف) بالجزء والصفحة.
  ٦. تشتق شريط البوصلة من عنوان القسم إن نص على «سنة كذا»، ويكون العنوان نفسه شاهدها.
  ٧. تدمجها مع المحطات المحررة (التي لا يبدأ معرّفها بـ ih_) بترتيب الطور فموضعها من الكتاب، وتعيد
     ترقيم order، وتبطل روابط previous_link/next_hook المحررة التي تغيّر جارها وتعوّضها بروابط آلية.
  ٨. تدقق الناتج بنية وحرفية على الكتاب الذي استُوعب، ولا تكتب الملف إن وُجدت مشكلة.

الخط الأحمر: لا تضيف الأداة حرفاً من خارج الكتاب إلى الفصول ولا إلى البوصلة. عنوان المحطة وفصولها من
عناوين الكتاب، والروابط الآلية تقتبس عناوين الكتاب نفسها. أما طبقة المعايشة والموقف (التمهيد والمشهد
والمأزق والقرار وسؤال الشورى) فلا تُولَّد آلياً ولا تُكتب من الذاكرة: تبقى المحطة المولّدة بفصولها حتى
يحررها محرر من نصوصها. المحطات المحررة لا تُمس إلا في ترتيبها وروابطها.

الأداة قابلة لإعادة التشغيل: تحذف المولَّد سابقاً (ih_…) وتولّده من جديد فيخرج الملف نفسه.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import book  # noqa: E402
import checks  # noqa: E402
import corpora  # noqa: E402
import epochs  # noqa: E402
import passages  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))

GENERATED_PREFIX = "ih_"
PREV_PREFIX = "قبلها في الكتاب: "
NEXT_PREFIX = "وتليها في الكتاب: "
STATUS = "pending_scholarly_review"

_ARABIC_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")
_TASHKEEL = re.compile("[ً-ٰٟۖ-ۭـ]")
_FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": "ه"})
_YEAR_IN_TITLE = re.compile(r"(?:\bفي\s+)?((?:[^\s،()]+\s+){0,2}سنة\s+[^\s،().]+)")


def norm(text: str) -> str:
    """توحيد العناوين للمطابقة وحدها: بلا تشكيل ولا أقواس، وألف وياء وهاء موحدة."""
    text = _TASHKEEL.sub("", text).translate(_FOLD)
    return re.sub(r"\s+", " ", text.replace("(", " ").replace(")", " ")).strip()


def ar(number: int) -> str:
    return str(number).translate(_ARABIC_DIGITS)


def clean_title(title: str) -> str:
    """عنوان القسم للعرض: بلا أقواس إحاطة ولا ترقيم ختامي زائد."""
    title = book.canon(title).strip()
    if title.startswith("(") and title.rstrip(" .:").endswith(")"):
        title = title.rstrip(" .:")[1:-1].strip()
    return title.rstrip(" .:").strip()


# ---------------------------------------------------------------------------
# الإعدادات
@dataclass
class Config:
    source_id: str
    anchors: list[tuple[str, re.Pattern]]
    hijra: re.Pattern | None
    skips: list[tuple[str, re.Pattern]]
    min_chars: int
    max_chars: int
    chapter_chars: int
    bridges: str
    verse_separator: str
    verse_min_paragraphs: int
    verse_min_ratio: float
    verse_min_char_ratio: float

    @staticmethod
    def load(path: str) -> "Config":
        with open(path, encoding="utf-8") as handle:
            raw = json.load(handle)
        limits = raw.get("limits", {})
        verse = raw.get("verse", {})
        if raw.get("bridges", "mechanical") not in ("mechanical", "none"):
            raise SystemExit("bridges في الإعدادات إما mechanical أو none")
        try:
            return Config(
                source_id=raw.get("source_id", corpora.SOURCE_IDS["ih"]),
                anchors=[(a["epoch"], re.compile(a["title"])) for a in raw["epoch_anchors"]],
                hijra=re.compile(raw["hijra_anchor"]) if raw.get("hijra_anchor") else None,
                skips=[(s["reason"], re.compile(s["title"])) for s in raw.get("skip", [])],
                min_chars=int(limits.get("min_station_chars", 3000)),
                max_chars=int(limits.get("max_station_chars", 45000)),
                chapter_chars=int(limits.get("target_chapter_chars", 5000)),
                bridges=raw.get("bridges", "mechanical"),
                verse_separator=verse.get("separator", " ... "),
                verse_min_paragraphs=int(verse.get("min_paragraphs", 3)),
                verse_min_ratio=float(verse.get("min_ratio", 0.5)),
                verse_min_char_ratio=float(verse.get("min_char_ratio", 0.6)),
            )
        except (KeyError, re.error) as error:
            raise SystemExit(f"إعدادات الاستيعاب غير صالحة: {error!r}")


@dataclass
class Gazetteer:
    defaults: dict[str, str]
    places: list[dict]
    patterns: list[list[re.Pattern]]

    @staticmethod
    def load(path: str) -> "Gazetteer":
        with open(path, encoding="utf-8") as handle:
            raw = json.load(handle)
        places = raw["places"]
        names = {p["name"] for p in places}
        for covenant, name in raw["defaults"].items():
            if name not in names:
                raise SystemExit(f"موضع العهد {covenant} الافتراضي «{name}» ليس في قائمة المواضع")
        return Gazetteer(
            defaults=raw["defaults"],
            places=places,
            patterns=[[re.compile(m) for m in p.get("match", [])] for p in places],
        )

    def by_name(self, name: str) -> dict:
        return next(p for p in self.places if p["name"] == name)

    def place_for(self, title: str, covenant: str) -> tuple[dict, bool]:
        """الموضع وهل اشتُق من العنوان (True) أم افتراضي بحسب العهد (False)."""
        key = norm(title)
        for place, patterns in zip(self.places, self.patterns):
            if any(p.search(key) for p in patterns):
                return place, True
        return self.by_name(self.defaults[covenant]), False


# ---------------------------------------------------------------------------
# الوحدات
@dataclass
class Unit:
    """عنوان كبير مع أقسامه الفرعية."""

    index: int
    title: str
    sections: list[book.Section]
    chars: int
    offset: int
    vol: int
    page: int
    epoch: str | None = None
    after_hijra: bool = False
    skip: str | None = None

    @property
    def paras(self) -> list[book.Para]:
        return [p for s in self.sections for p in s.paras]


def is_verse(section: book.Section, cfg: Config) -> bool:
    """قسم أبياته أكثر فقراته: تُفصل الأبيات في هذا النص بين شطريها بفاصل ثابت (« ... »)."""
    if len(section.paras) < cfg.verse_min_paragraphs:
        return False
    verses = [p for p in section.paras if cfg.verse_separator in p.text]
    chars = sum(len(p.text) for p in verses)
    return (
        len(verses) / len(section.paras) >= cfg.verse_min_ratio
        and chars / max(1, section.chars) >= cfg.verse_min_char_ratio
    )


def build_units(b: book.Book, cfg: Config, report: "Report") -> list[Unit]:
    """الوحدات الكبرى بأقسامها، بعد استبعاد أقسام الشعر (وتسجيلها في التقرير)."""
    units: list[Unit] = []
    current: list[book.Section] = []

    def flush() -> None:
        if not current:
            return
        head = clean_title(current[0].title) or next((clean_title(s.title) for s in current if clean_title(s.title)), "")
        kept: list[book.Section] = []
        for section in current:
            if not section.paras:
                continue
            if is_verse(section, cfg):
                report.verse.append((head, clean_title(section.title) or head, section.chars))
            else:
                kept.append(section)
        paras = [p for s in kept for p in s.paras]
        if paras:
            units.append(
                Unit(
                    index=len(units),
                    title=head,
                    sections=kept,
                    chars=sum(len(p.text) for p in paras),
                    offset=paras[0].offset,
                    vol=paras[0].vol,
                    page=paras[0].first_page,
                )
            )
        elif any(s.paras for s in current):
            report.verse_units.append(head)
        current.clear()

    for section in b.sections:
        if section.level == 1:
            flush()
        current.append(section)
    flush()
    return units


def assign_epochs(units: list[Unit], cfg: Config, report: "Report") -> None:
    """يسند الأطوار بمراسي العناوين، ويعلّم ما قبل أول مرساة بأنه خارج المنهج."""
    pointer = 0
    boundaries: list[tuple[int, str]] = []
    for epoch_id, pattern in cfg.anchors:
        found = next((i for i in range(pointer, len(units)) if pattern.search(norm(units[i].title))), None)
        if found is None:
            report.errors.append(f"مرساة الطور {epoch_id} ({pattern.pattern}) غير موجودة بعد الوحدة {pointer}")
            continue
        boundaries.append((found, epoch_id))
        report.anchors.append((epoch_id, units[found].title, units[found].vol, units[found].page))
        pointer = found + 1
    hijra_at = None
    if cfg.hijra is not None:
        hijra_at = next((i for i, u in enumerate(units) if cfg.hijra.search(norm(u.title))), None)
        if hijra_at is None:
            report.errors.append(f"مرساة الهجرة ({cfg.hijra.pattern}) غير موجودة")
        else:
            report.hijra = (units[hijra_at].title, units[hijra_at].vol, units[hijra_at].page)
    for i, unit in enumerate(units):
        epoch = None
        for start, epoch_id in boundaries:
            if i >= start:
                epoch = epoch_id
        unit.epoch = epoch
        unit.after_hijra = hijra_at is not None and i >= hijra_at
        if epoch is None:
            unit.skip = "قبل بداية المنهج"
        else:
            for reason, pattern in cfg.skips:
                if pattern.search(norm(unit.title)):
                    unit.skip = reason
                    break


# ---------------------------------------------------------------------------
# المحطات
@dataclass
class Draft:
    """محطة قيد البناء: وحدة أو أكثر متجاورة، أو جزء من وحدة ضخمة."""

    units: list[Unit]
    sections: list[book.Section]
    epoch: str
    after_hijra: bool
    part: tuple[int, int] | None = None  # (رقم الجزء، عدد الأجزاء)

    @property
    def chars(self) -> int:
        return sum(len(p.text) for s in self.sections for p in s.paras)

    @property
    def paras(self) -> list[book.Para]:
        return [p for s in self.sections for p in s.paras]

    @property
    def title(self) -> str:
        base = self.units[0].title
        if self.part:
            return f"{base} ({ar(self.part[0])}/{ar(self.part[1])})"
        return base


def split_unit(unit: Unit, max_chars: int) -> list[Draft]:
    """الوحدة الضخمة أجزاءً متساوية تقريباً تنقطع عند حدود الأقسام."""
    parts = max(2, math.ceil(unit.chars / max_chars))
    target = unit.chars / parts
    groups: list[list[book.Section]] = [[]]
    size = 0
    for section in unit.sections:
        groups[-1].append(section)
        size += sum(len(p.text) for p in section.paras)
        if size >= target * len(groups) and len(groups) < parts:
            groups.append([])
    groups = [g for g in groups if any(s.paras for s in g)]
    return [
        Draft([unit], g, unit.epoch or "", unit.after_hijra, (n, len(groups)))
        for n, g in enumerate(groups, start=1)
    ]


def group_units(units: list[Unit], cfg: Config) -> list[Draft]:
    """يضم الوحدات الصغيرة المتجاورة (في طور واحد وعهد واحد) حتى يبلغ ضمها الحد الأدنى."""
    drafts: list[Draft] = []
    run: list[Unit] = []

    def close() -> None:
        if run:
            drafts.append(Draft(list(run), [s for u in run for s in u.sections], run[0].epoch or "", run[0].after_hijra))
            run.clear()

    for unit in units:
        if unit.skip is not None:
            continue
        if unit.chars > cfg.max_chars:
            close()
            drafts.extend(split_unit(unit, cfg.max_chars))
            continue
        if run:
            same = run[0].epoch == unit.epoch and run[0].after_hijra == unit.after_hijra
            size = sum(u.chars for u in run)
            if not same or size >= cfg.min_chars or size + unit.chars > cfg.max_chars:
                close()
        run.append(unit)
    close()
    # الذيل الصغير في آخر الطور يُضم إلى ما قبله إن اتسع.
    merged: list[Draft] = []
    for draft in drafts:
        prev = merged[-1] if merged else None
        if (
            prev is not None
            and draft.chars < cfg.min_chars
            and prev.part is None
            and draft.part is None
            and prev.epoch == draft.epoch
            and prev.after_hijra == draft.after_hijra
            and prev.chars + draft.chars <= cfg.max_chars
        ):
            prev.units.extend(draft.units)
            prev.sections.extend(draft.sections)
        else:
            merged.append(draft)
    return merged


def contiguous_runs(paras: list[book.Para]) -> list[list[book.Para]]:
    """الفقرات متتالية في الكتاب؛ يقطعها حيث استُبعد قسم بينها فلا يُضم نص إلى نص ليس بعده في الكتاب."""
    runs: list[list[book.Para]] = []
    for para in paras:
        if runs and para.offset == runs[-1][-1].offset + len(runs[-1][-1].text) + 1:
            runs[-1].append(para)
        else:
            runs.append([para])
    return runs


def build_chapters(draft: Draft, cfg: Config) -> list[dict]:
    """فصول المحطة من أقسام الكتاب: تتجمع الأقسام المتجاورة حتى يبلغ الفصل حجمه المستهدف."""
    chapters: list[tuple[str, list[book.Section]]] = []
    for unit in draft.units:
        sections = [s for s in unit.sections if s in draft.sections and s.paras]
        buckets: list[list[book.Section]] = [[]]
        size = 0
        for section in sections:
            buckets[-1].append(section)
            size += sum(len(p.text) for p in section.paras)
            if size >= cfg.chapter_chars:
                buckets.append([])
                size = 0
        buckets = [b for b in buckets if b]
        for k, bucket in enumerate(buckets):
            titles = [clean_title(s.title) for s in bucket if clean_title(s.title)]
            head_is_unit = bucket[0] is unit.sections[0]
            if len(buckets) == 1 and head_is_unit:
                title = unit.title
            elif head_is_unit and k == 0:
                title = unit.title
            elif not titles:
                title = unit.title
            elif len(titles) == 1:
                title = titles[0]
            else:
                title = f"{titles[0]} … {titles[-1]}"
            chapters.append((title, bucket))
    result: list[dict] = []
    for number, (title, bucket) in enumerate(chapters, start=1):
        result.append(
            {
                "id": f"c{number}",
                "title": title,
                "passages": [
                    passage
                    for run in contiguous_runs([p for s in bucket for p in s.paras])
                    for passage in passages.from_items(cfg.source_id, [(p.text, p) for p in run])
                ],
            }
        )
    return result


def year_basis(draft: Draft, cfg: Config) -> tuple[str, dict] | None:
    """السنة المنصوص عليها في عنوان قسم من المحطة، وشاهدها العنوان نفسه بموضعه."""
    for unit in draft.units:
        for section in unit.sections:
            title = book.canon(section.title).rstrip(" :")
            match = _YEAR_IN_TITLE.search(title)
            if match and section.paras:
                para = section.paras[0]
                label = match.group(1).strip()
                if label.startswith("في "):
                    label = label[3:]
                return label, {"sourceId": cfg.source_id, "locator": para.locator, "quote": title}
    return None


def station_id(draft: Draft, taken: set[str]) -> str:
    first = draft.paras[0]
    base = f"{GENERATED_PREFIX}v{first.vol}_p{first.first_page:04d}"
    candidate, n = base, 1
    while candidate in taken:
        n += 1
        candidate = f"{base}_{n}"
    taken.add(candidate)
    return candidate


def make_station(draft: Draft, cfg: Config, gazetteer: Gazetteer, taken: set[str], report: "Report") -> dict:
    covenant = epochs.covenant_of(draft.epoch, draft.after_hijra)
    place, derived = gazetteer.place_for(draft.units[0].title, covenant)
    station: dict = {
        "id": station_id(draft, taken),
        "order": 0,
        "title": draft.title,
        "epoch_id": draft.epoch,
        "covenant": covenant,
        "timeLabel": None,
    }
    basis = year_basis(draft, cfg)
    if basis is not None:
        station["year_label"], quote = basis
        station["compass_basis"] = [quote]
        report.years += 1
    station["place"] = {
        "name": place["name"],
        "latitude": place["latitude"],
        "longitude": place["longitude"],
        "coordinatesApproximate": True,
    }
    station["onRoute"] = bool(place.get("onRoute", True))
    station["evidence"] = []
    station["chapters"] = build_chapters(draft, cfg)
    notes = [
        "محطة مولّدة آلياً من نص الكتاب: عنوانها وفصولها ومقاطعها من عناوين الطبعة ونصها حرفياً. "
        "ولم تُكتب لها طبقة المعايشة والموقف بعد (تمهيد ومشهد ومأزق وقرار)، فتُعرض روايتها المطولة وحدها.",
        "الطور والعهد وموضع الخريطة اشتقاق آلي من قواعد tools/seerah/ingest_config.json وplaces.json، "
        + ("والموضع مشتق من عنوان القسم." if derived else "والموضع افتراضي بحسب العهد.")
        + " وتُراجع كلها قبل الاعتماد.",
    ]
    if len(draft.units) > 1:
        titles = [u.title for u in draft.units]
        shown = "، ".join(titles[:6]) + (f"، وأقسام أخرى عددها {ar(len(titles) - 6)}" if len(titles) > 6 else "")
        notes.append(f"جُمعت في هذه المحطة أقسام الكتاب المتجاورة: {shown}.")
        report.grouped += 1
    if draft.part:
        notes.append(f"قسم الكتاب «{draft.units[0].title}» ضخم فقُسم إلى {ar(draft.part[1])} أجزاء عند حدود أقسامه.")
        report.split += 1
    if not derived:
        report.default_places += 1
    station["review"] = {"status": STATUS, "reviewer": None, "reviewedAt": None, "notes": notes}
    return station


# ---------------------------------------------------------------------------
# الدمج
def curated_anchor(station: dict, b: book.Book, source_id: str) -> int | None:
    """موضع المحطة المحررة من الكتاب: أقل موضع لمقطع منها فيه، أو None إن لم يرد فيه شيء."""
    best = None
    refs = [e["source"] for e in station.get("evidence", [])]
    refs += [p for c in station.get("chapters", []) for p in c.get("passages", [])]
    for ref in refs:
        if ref["sourceId"] != source_id:
            continue
        at = b.full_text.find(book.canon(ref.get("quote") or ""))
        if at >= 0 and (best is None or at < best):
            best = at
    return best


def merge(dataset: dict, generated: list[tuple[dict, int, int]], b: book.Book, cfg: Config, report: "Report") -> dict:
    """المحررة مع المولّدة بترتيب الطور، وداخل الطور المولّدة بموضعها بين المحررة."""
    old_order = sorted(dataset["stations"], key=lambda s: s["order"])
    curated = [s for s in old_order if not s["id"].startswith(GENERATED_PREFIX)]
    old_neighbors = {
        s["id"]: (old_order[i - 1]["id"] if i else None, old_order[i + 1]["id"] if i + 1 < len(old_order) else None)
        for i, s in enumerate(old_order)
    }
    number = {e: n for e, n, _ in epochs.EPOCHS}
    anchors = {s["id"]: curated_anchor(s, b, cfg.source_id) for s in curated}
    final: list[dict] = []
    for epoch_id, _, _ in epochs.EPOCHS:
        mine = [s for s in curated if s["epoch_id"] == epoch_id]
        pending = sorted((g for g in generated if g[0]["epoch_id"] == epoch_id), key=lambda g: g[1])
        queue = list(pending)
        for station in mine:
            at = anchors[station["id"]]
            while queue and at is not None and queue[0][1] < at:
                final.append(queue.pop(0)[0])
            final.append(station)
        final.extend(g[0] for g in queue)
    unknown = [s["id"] for s in curated if s["epoch_id"] not in number]
    if unknown:
        raise SystemExit(f"محطات محررة بطور مجهول: {unknown}")
    for i, station in enumerate(final, start=1):
        station["order"] = i
    relink(final, old_neighbors, cfg, report)
    return {**dataset, "epochs": epochs.as_json(), "stations": final}


def relink(final: list[dict], old_neighbors: dict, cfg: Config, report: "Report") -> None:
    """الروابط بين المحطات: الآلية تُعاد من الجيران الحاليين، والمحررة تبقى إن لم يتغير جارها وإلا أُبطلت."""
    for i, station in enumerate(final):
        prev_id = final[i - 1]["id"] if i else None
        next_id = final[i + 1]["id"] if i + 1 < len(final) else None
        old_prev, old_next = old_neighbors.get(station["id"], (object(), object()))
        for key, prefix, neighbor, old, label in (
            ("previous_link", PREV_PREFIX, final[i - 1] if i else None, old_prev == prev_id, "السابقة"),
            ("next_hook", NEXT_PREFIX, final[i + 1] if i + 1 < len(final) else None, old_next == next_id, "التالية"),
        ):
            text = station.get(key)
            editorial = text is not None and not text.startswith(prefix)
            if editorial and old:
                continue
            if editorial and not old:
                report.invalidated.append((station["id"], key, text))
            station.pop(key, None)
            if neighbor is not None and cfg.bridges == "mechanical":
                station[key] = f"{prefix}«{neighbor['title']}»."
        # ترتيب المفاتيح كما في الملف: previous_link ثم next_hook بعد onRoute
        ordered = {}
        for k in (
            "id", "order", "title", "epoch_id", "covenant", "timeLabel", "year_label", "age_label", "compass_basis",
            "place", "onRoute", "previous_link", "next_hook", "hook", "shura_question", "sceneDescription",
            "challenge", "propheticDecision", "dilemma_options", "evidence", "chapters", "review",
        ):
            if k in station:
                ordered[k] = station[k]
        station.clear()
        station.update(ordered)


# ---------------------------------------------------------------------------
# التقرير
@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    anchors: list[tuple[str, str, int, int]] = field(default_factory=list)
    hijra: tuple[str, int, int] | None = None
    skipped: list[tuple[Unit, str]] = field(default_factory=list)
    years: int = 0
    grouped: int = 0
    split: int = 0
    default_places: int = 0
    invalidated: list[tuple[str, str, str]] = field(default_factory=list)
    overlaps: list[tuple[str, str]] = field(default_factory=list)
    verse: list[tuple[str, str, int]] = field(default_factory=list)
    verse_units: list[str] = field(default_factory=list)

    def render(self, units: list[Unit], stations: list[dict], book_format: str) -> str:
        lines = ["# تقرير استيعاب سيرة ابن هشام", ""]
        total = sum(u.chars for u in units)
        lines.append(f"- صيغة الملف: {book_format}؛ الوحدات الكبرى: {len(units)}؛ حروفها: {total:,}")
        lines.append("")
        lines.append("## مراسي الأطوار")
        for epoch_id, title, vol, page in self.anchors:
            lines.append(f"- {epoch_id}: «{title}» (ج{vol} ص{page})")
        if self.hijra:
            lines.append(f"- الهجرة: «{self.hijra[0]}» (ج{self.hijra[1]} ص{self.hijra[2]})")
        lines.append("")
        lines.append("## المحطات المولّدة")
        gen = [s for s in stations if s["id"].startswith(GENERATED_PREFIX)]
        chars = sum(len(p["quote"]) for s in gen for c in s["chapters"] for p in c["passages"])
        lines.append(f"- العدد: {len(gen)}؛ حروف مقاطعها: {chars:,}")
        for epoch_id, number, title in epochs.EPOCHS:
            mine = [s for s in gen if s["epoch_id"] == epoch_id]
            cur = [s for s in stations if s["epoch_id"] == epoch_id and not s["id"].startswith(GENERATED_PREFIX)]
            lines.append(f"- الطور {ar(number)} «{title}»: {len(mine)} مولّدة + {len(cur)} محررة")
        lines.append(f"- محطات جُمعت من أقسام متجاورة: {self.grouped}؛ محطات قُسمت أجزاءً: {self.split}")
        lines.append(f"- سنوات اشتُقت من العناوين: {self.years}؛ مواضع افتراضية بحسب العهد: {self.default_places}")
        lines.append("")
        lines.append("## الوحدات المتخطاة")
        by_reason: dict[str, list[Unit]] = {}
        for unit, reason in self.skipped:
            by_reason.setdefault(reason, []).append(unit)
        for reason, items in by_reason.items():
            lines.append(f"- {reason}: {len(items)} وحدة، {sum(u.chars for u in items):,} حرفاً")
            for unit in items[:40]:
                lines.append(f"  - «{unit.title}» (ج{unit.vol} ص{unit.page}، {unit.chars:,} حرفاً)")
            if len(items) > 40:
                lines.append(f"  - … و{len(items) - 40} غيرها")
        if self.verse:
            lines += ["", "## أقسام الشعر المستبعدة (بكثافة الأبيات)"]
            lines.append(
                f"- {len(self.verse)} قسماً، {sum(c for _, _, c in self.verse):,} حرفاً؛ منها {len(self.verse_units)} وحدة كاملة لم يبقَ منها نثر"
            )
            for head, title, chars in self.verse[:60]:
                lines.append(f"  - «{title}» (في «{head}»، {chars:,} حرفاً)")
            if len(self.verse) > 60:
                lines.append(f"  - … و{len(self.verse) - 60} غيرها")
        if self.overlaps:
            lines += ["", "## تداخل مع المحطات المحررة"]
            lines += [f"- «{g}» تتضمن نصوصاً من المحررة «{c}»" for g, c in self.overlaps]
        if self.invalidated:
            lines += ["", "## روابط محررة أُبطلت لتغيّر الجار (أعد كتابتها)"]
            lines += [f"- {sid} · {key}: {text}" for sid, key, text in self.invalidated]
        if self.warnings:
            lines += ["", "## تحذيرات"] + [f"- {w}" for w in self.warnings]
        if self.errors:
            lines += ["", "## أخطاء"] + [f"- {e}" for e in self.errors]
        return "\n".join(lines) + "\n"


def mark_overlaps(
    generated: list[tuple[dict, int, int]], curated: list[dict], b: book.Book, cfg: Config, report: Report
) -> None:
    """يسجّل في ملاحظات المحطة المولّدة (والتقرير) أن نصها يشمل مواضع من محطة محررة."""
    spans = []
    for c in curated:
        offsets = [
            at
            for ref in [p for ch in c.get("chapters", []) for p in ch["passages"]] + [e["source"] for e in c.get("evidence", [])]
            if ref["sourceId"] == cfg.source_id
            for at in [b.full_text.find(book.canon(ref.get("quote") or ""))]
            if at >= 0
        ]
        if offsets:
            spans.append((c, offsets))
    for station, low, high in generated:
        for c, offsets in spans:
            if any(low <= o <= high for o in offsets):
                station["review"]["notes"].append(f"يتداخل نصها مع نص المحطة المحررة «{c['title']}» ويزيد عليه.")
                report.overlaps.append((station["title"], c["title"]))


# ---------------------------------------------------------------------------
def ingest(
    dataset: dict,
    b: book.Book,
    cfg: Config,
    gazetteer: Gazetteer,
    report: Report,
) -> tuple[dict, list[Unit]]:
    """يولّد المحطات ويدمجها؛ يعيد (الملف الجديد، وحدات الكتاب)."""
    units = build_units(b, cfg, report)
    assign_epochs(units, cfg, report)
    for unit in units:
        if unit.skip is not None:
            report.skipped.append((unit, unit.skip))
    if report.errors:
        return dataset, units
    drafts = group_units(units, cfg)
    taken = {s["id"] for s in dataset["stations"] if not s["id"].startswith(GENERATED_PREFIX)}
    generated = []
    for draft in drafts:
        paras = draft.paras
        generated.append((make_station(draft, cfg, gazetteer, taken, report), paras[0].offset, paras[-1].offset + len(paras[-1].text)))
    curated = [s for s in dataset["stations"] if not s["id"].startswith(GENERATED_PREFIX)]
    for station in curated:
        at = curated_anchor(station, b, cfg.source_id)
        if at is None:
            report.warnings.append(
                f"المحطة المحررة {station['id']} لا موضع لها في الكتاب المستوعب (طبعة أخرى أو مصدر آخر)؛ رُتّبت بطورها فقط."
            )
        expected = next((u.epoch for u in reversed(units) if at is not None and u.offset <= at), None)
        if at is not None and expected and expected != station["epoch_id"]:
            report.warnings.append(
                f"المحطة المحررة {station['id']} طورها {station['epoch_id']} وموضعها من الكتاب يقع في {expected}؛ بقي طورها كما حُرر."
            )
    merged = merge(dataset, generated, b, cfg, report)
    mark_overlaps(generated, curated, b, cfg, report)
    return merged, units


def check_catalog(source_id: str, catalog_path: str) -> None:
    with open(catalog_path, encoding="utf-8") as handle:
        catalog = json.load(handle)
    if source_id not in {s["id"] for s in catalog["sources"]}:
        raise SystemExit(
            f"المصدر «{source_id}» ليس في {catalog_path}؛ أضف إليه إدخالاً بعنوان الكتاب ومؤلفه وطبعته ومصدر نصه الرقمي"
            " (انظر إدخال sira_ibn_hisham نموذجاً) ثم أعد التشغيل، وإلا رفض التطبيق الملف."
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--book", required=True, help="ملف نص الكتاب (OpenITI أو نص عادي)")
    parser.add_argument("--dataset", default=os.path.join(ROOT, "assets/data/seerah_dataset.json"))
    parser.add_argument("--config", default=os.path.join(HERE, "ingest_config.json"))
    parser.add_argument("--places", default=os.path.join(HERE, "places.json"))
    parser.add_argument("--catalog", default=os.path.join(ROOT, "assets/data/catalogs/sources.json"))
    parser.add_argument("--source-id", help="معرّف المصدر في فهرس المصادر (الافتراضي من الإعدادات)")
    parser.add_argument("--dry-run", action="store_true", help="لا يكتب الملف")
    parser.add_argument("--report", help="مسار يُكتب فيه التقرير المفصل")
    parser.add_argument("--force", action="store_true", help="يكتب الملف رغم مشكلات التدقيق (لا يُنصح)")
    args = parser.parse_args()

    cfg = Config.load(args.config)
    if args.source_id:
        cfg.source_id = args.source_id
    gazetteer = Gazetteer.load(args.places)
    check_catalog(cfg.source_id, args.catalog)
    b = book.read(args.book)
    print(f"قُرئ الكتاب: {b.format}، {len(b.sections)} قسماً، {len(b.full_text):,} حرفاً")
    for warning in b.warnings:
        print("تحذير:", warning, file=sys.stderr)
    with open(args.dataset, encoding="utf-8") as handle:
        dataset = json.load(handle)

    report = Report()
    report.warnings.extend(b.warnings)
    merged, units = ingest(dataset, b, cfg, gazetteer, report)

    issues: list[str] = list(report.errors)
    if not report.errors:
        issues += checks.structure_issues(merged)
        generated_only = {**merged, "stations": [s for s in merged["stations"] if s["id"].startswith(GENERATED_PREFIX)]}
        issues += checks.quote_issues(generated_only, {cfg.source_id: b}, None, only_sources={cfg.source_id})
    text = report.render(units, merged["stations"], b.format)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as handle:
            handle.write(text)
        print("كُتب التقرير", args.report)
    gen = sum(1 for s in merged["stations"] if s["id"].startswith(GENERATED_PREFIX))
    print(f"المحطات المولّدة: {gen}؛ المحررة: {len(merged['stations']) - gen}؛ الوحدات المتخطاة: {len(report.skipped)}")
    for issue in issues[:50]:
        print("FAIL", issue)
    if len(issues) > 50:
        print(f"… و{len(issues) - 50} مشكلة أخرى")
    if issues and not args.force:
        print("لم يُكتب الملف بسبب المشكلات أعلاه.", file=sys.stderr)
        return 1
    if args.dry_run:
        print("--dry-run: لم يُكتب الملف.")
        return 0
    with open(args.dataset, "w", encoding="utf-8") as handle:
        json.dump(merged, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("كُتب", args.dataset)
    return 0


if __name__ == "__main__":
    sys.exit(main())
