"""اختبارات أدوات السيرة: قارئ الكتاب، ومدقق الاقتباسات، وأداة استيعاب ابن هشام.

كلها على كتاب اصطناعي بصيغة OpenITI صغير تُبنى نصوصه هنا، فلا تحتاج مدونة ولا شبكة.
  python3 -m unittest discover -s tools/seerah -p 'test_*.py'
"""
import copy
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

import book
import checks
import corpora
import epochs
import ingest_ibn_hisham as ing

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SOURCE = "sira_ibn_hisham"

# عناوين تطابق مراسي ingest_config.json بعد توحيدها.
ANCHORS = {
    "epoch_01_omens": "أمر الفيل، وقصة النسأة",
    "epoch_02_youth": "وفاة آمنة وحال رسول الله صلى الله عليه وسلم مع جده",
    "epoch_03_secret_call": "مبعث النبي صلى الله عليه وسلم",
    "epoch_04_public_call": "مباداة رسول الله صلى الله عليه وسلم قومه",
    "epoch_05_abyssinia_sorrow": "ذكر الهجرة الأولى إلى أرض الحبشة",
    "epoch_06_aqaba_hijra": "عرض رسول الله صلى الله عليه وسلم نفسه على القبائل",
    "epoch_07_state_badr_uhud": "المؤاخاة بين المهاجرين والأنصار",
    "epoch_08_khandaq_hudaybiyyah": "غزوة الخندق في شوال سنة خمس",
    "epoch_09_conquest_tabuk": "ذكر الأسباب الموجبة المسير إلى مكة",
    "epoch_10_farewell_companion": "حجة الوداع",
}


class Writer:
    """يبني ملف OpenITI صغيراً: عناوين وفقرات وعلامات صفحات متتابعة."""

    def __init__(self):
        self.lines = ["######OpenITI#", "#META#Header#End#"]
        self.page = 1
        self.counter = 0

    def h1(self, title):
        self.lines.append(f"### | {title}")

    def h2(self, title):
        self.lines.append(f"### || ({title})")

    def para(self, text=None, pages=True):
        self.counter += 1
        text = text or f"هذه فقرة تجريبية رقم {self.counter} من الكتاب ذات نص كاف للتجربة."
        marker = f" PageV01P{self.page:03d}" if pages else ""
        self.lines.append(f"# {text}{marker}")
        if pages:
            self.page += 1
        return text

    def paras(self, count):
        return [self.para() for _ in range(count)]

    def verse(self, count):
        """أبيات متتالية بلا علامات صفحات بينها (فعلامة الصفحة تضم الفقرات المعلقة)، وعلامة في آخرها."""
        for i in range(count):
            self.para(f"قال الشاعر بيتاً رقم {i} من القصيدة ... وأتم شطره الثاني بكلام آخر", pages=i == count - 1)

    def text(self):
        return "\n".join(self.lines) + "\n"


def sample_book(extra=None):
    """كتاب لكل طور فيه وحدة، وفيه قوائم وشعر وسرد مختلط وعنوان بسنة وموضع بعينه."""
    w = Writer()
    w.h1("ذكر سرد النسب الزكي")
    w.paras(3)
    for epoch_id, title in ANCHORS.items():
        if epoch_id == "epoch_07_state_badr_uhud":
            w.h1("هجرة الرسول صلى الله عليه وسلم")
            w.paras(4)
            w.h1("أسماء من شهد العقبة")
            w.paras(4)
        w.h1(title)
        w.h2("القسم الأول")
        w.paras(3)
        w.h2("القسم الثاني")
        w.paras(3)
        if epoch_id == "epoch_07_state_badr_uhud":
            w.h1("غزوة بدر الكبرى")
            w.paras(6)
            w.h2("شعر في بدر")
            w.verse(4)
            w.h2("خبر بعد الشعر")
            w.paras(3)
            w.h1("ما قيل من الشعر في يوم أحد")
            w.verse(5)
    if extra:
        extra(w)
    return book.parse(w.text())


def write_config(tmp, **limits):
    with open(os.path.join(HERE, "ingest_config.json"), encoding="utf-8") as handle:
        raw = json.load(handle)
    raw["limits"] = {"min_station_chars": 300, "max_station_chars": 3000, "target_chapter_chars": 500, **limits}
    path = os.path.join(tmp, "config.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(raw, handle, ensure_ascii=False)
    return path


def curated(station_id, order, epoch_id, quote, locator, **extra):
    station = {
        "id": station_id,
        "order": order,
        "title": f"محطة محررة {station_id}",
        "epoch_id": epoch_id,
        "covenant": "medinan",
        "timeLabel": None,
        "place": {"name": "المدينة النبوية", "latitude": 24.4673, "longitude": 39.6114, "coordinatesApproximate": True},
        "onRoute": True,
        "evidence": [],
        "chapters": [{"id": "c1", "title": "فصل", "passages": [{"sourceId": SOURCE, "locator": locator, "quote": quote}]}],
        "review": {"status": "pending_scholarly_review", "reviewer": None, "reviewedAt": None, "notes": ["ملاحظة"]},
    }
    station.update(extra)
    return station


def base_dataset(stations=()):
    return {
        "schemaVersion": 1,
        "id": "seerah",
        "title": "رحلة السيرة",
        "epochs": epochs.as_json(),
        "stations": list(stations),
    }


class TestBook(unittest.TestCase):
    def test_canon_strips_structure_marks_only(self):
        self.assertEqual(book.canon("نص  ms12 [3] </span> آخر"), "نص آخر")
        self.assertEqual(book.canon("  سطر\n\tآخر "), "سطر آخر")

    def test_sections_levels_and_pages(self):
        b = sample_book()
        titles = [(s.level, s.title) for s in b.sections if s.title]
        self.assertIn((1, "أمر الفيل، وقصة النسأة"), titles)
        self.assertIn((2, "(القسم الأول)"), titles)
        self.assertEqual(b.format, "openiti")
        first = next(p for p in b.paragraphs())
        self.assertEqual(first.locator, "ج1 ص1")

    def test_page_marker_closes_the_page_before_it(self):
        raw = "#META#Header#End#\n### | عنوان\n# بداية الجملة ثم PageV01P007\n~~ تتمتها هنا. PageV01P008\n"
        b = book.parse(raw)
        para = b.sections[0].paras[0]
        self.assertEqual((para.vol, para.first_page, para.last_page), (1, 7, 8))
        self.assertEqual(para.text, "بداية الجملة ثم تتمتها هنا.")

    def test_verify_counts_occurrences(self):
        b = sample_book()
        sentence = next(b.paragraphs()).text
        self.assertEqual(b.verify(sentence), 1)
        self.assertEqual(b.verify("عبارة ليست في الكتاب"), 0)

    def test_split_text_never_loses_a_character(self):
        text = " ".join(f"جملة رقم {i}." for i in range(80))
        pieces = book.split_text(text, 200)
        self.assertGreater(len(pieces), 1)
        self.assertEqual(" ".join(pieces), text)
        self.assertTrue(all(len(p) <= 200 for p in pieces))


class TestChecks(unittest.TestCase):
    def setUp(self):
        self.book = sample_book()
        para = next(s for s in self.book.sections if s.paras).paras[0]
        self.quote, self.locator = para.text, para.locator
        self.station = curated("c_one", 1, "epoch_01_omens", self.quote, self.locator, covenant="pre_mission")

    def issues(self, station, **kw):
        return checks.quote_issues(base_dataset([station]), {SOURCE: self.book}, **kw)

    def test_verbatim_quote_with_right_page_passes(self):
        self.assertEqual(self.issues(self.station), [])

    def test_tampered_quote_is_flagged(self):
        bad = copy.deepcopy(self.station)
        bad["chapters"][0]["passages"][0]["quote"] = self.quote.replace("تجريبية", "مبدلة")
        self.assertEqual(len(self.issues(bad)), 1)
        self.assertIn("ليس في", self.issues(bad)[0])

    def test_wrong_page_is_flagged(self):
        bad = copy.deepcopy(self.station)
        bad["chapters"][0]["passages"][0]["locator"] = "ج1 ص99"
        self.assertIn("صفحة", self.issues(bad)[0])

    def test_a_section_heading_is_accepted_as_a_quote(self):
        heading = ANCHORS["epoch_08_khandaq_hudaybiyyah"]
        at = next(i for i, s in enumerate(self.book.sections) if s.title == heading)
        para = next(s for s in self.book.sections[at:] if s.paras).paras[0]
        station = curated("c_h", 1, "epoch_08_khandaq_hudaybiyyah", heading, para.locator)
        self.assertEqual(self.issues(station), [])

    def test_unknown_source_is_flagged_and_only_sources_filters(self):
        other = copy.deepcopy(self.station)
        other["chapters"][0]["passages"][0]["sourceId"] = "tabaqat_ibn_sad"
        self.assertEqual(len(self.issues(other)), 1)
        self.assertEqual(self.issues(other, only_sources={SOURCE}), [])

    def test_books_may_be_keyed_by_short_key_or_source_id(self):
        by_key = checks.quote_issues(base_dataset([self.station]), {"ih": self.book})
        self.assertEqual(by_key, [])

    def test_structure_rules(self):
        a = curated("a", 1, "epoch_01_omens", self.quote, self.locator, previous_link="سابقة لا محل لها")
        b = curated("b", 2, "epoch_01_omens", self.quote, self.locator, hook="تمهيد بلا طبقة معايشة")
        c = curated("a", 3, "epoch_99_unknown", self.quote, self.locator, year_label="سنة بلا أساس")
        found = "\n".join(checks.structure_issues(base_dataset([a, b, c])))
        self.assertIn("previous_link في أول محطة", found)
        self.assertIn("hook بلا طبقة معايشة", found)
        self.assertIn("معرّف مكرر", found)
        self.assertIn("epoch_id مجهول", found)
        self.assertIn("سنة أو عمر بلا compass_basis", found)

    def test_a_clean_dataset_has_no_structure_issues(self):
        self.assertEqual(checks.structure_issues(base_dataset([self.station])), [])


class TestIngest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config_path = write_config(self.tmp.name)
        self.cfg = ing.Config.load(self.config_path)
        self.gazetteer = ing.Gazetteer.load(os.path.join(HERE, "places.json"))
        self.book = sample_book()

    def run_ingest(self, dataset=None, b=None, cfg=None):
        report = ing.Report()
        merged, units = ing.ingest(dataset or base_dataset(), b or self.book, cfg or self.cfg, self.gazetteer, report)
        return merged, units, report

    def generated(self, merged):
        return [s for s in merged["stations"] if s["id"].startswith(ing.GENERATED_PREFIX)]

    def test_every_epoch_gets_stations_in_epoch_order(self):
        merged, _, report = self.run_ingest()
        self.assertEqual(report.errors, [])
        stations = merged["stations"]
        self.assertEqual([s["order"] for s in stations], list(range(1, len(stations) + 1)))
        rank = {e: n for e, n, _ in epochs.EPOCHS}
        ranks = [rank[s["epoch_id"]] for s in stations]
        self.assertEqual(ranks, sorted(ranks))
        self.assertEqual(set(ranks), set(range(1, 11)))

    def test_output_is_structurally_sound_and_every_quote_is_verbatim(self):
        merged, _, _ = self.run_ingest()
        self.assertEqual(checks.structure_issues(merged), [])
        self.assertEqual(checks.quote_issues(merged, {SOURCE: self.book}), [])

    def test_text_before_the_first_anchor_and_name_lists_are_skipped(self):
        _, units, report = self.run_ingest()
        reasons = {u.title: reason for u, reason in report.skipped}
        self.assertEqual(reasons["ذكر سرد النسب الزكي"], "قبل بداية المنهج")
        self.assertEqual(reasons["أسماء من شهد العقبة"], "قوائم أسماء")

    def test_verse_sections_go_but_the_prose_around_them_stays(self):
        merged, _, report = self.run_ingest()
        titles = [t for _, t, _ in report.verse]
        self.assertIn("شعر في بدر", titles)
        self.assertIn("ما قيل من الشعر في يوم أحد", report.verse_units)
        text = " ".join(p["quote"] for s in self.generated(merged) for c in s["chapters"] for p in c["passages"])
        self.assertNotIn("قال الشاعر", text)
        after = next(s for s in self.book.sections if s.title == "(خبر بعد الشعر)")
        self.assertIn(after.paras[0].text, text)

    def test_passages_never_glue_text_across_a_dropped_section(self):
        merged, _, _ = self.run_ingest()
        for station in self.generated(merged):
            for chapter in station["chapters"]:
                for passage in chapter["passages"]:
                    self.assertEqual(self.book.verify(passage["quote"]), 1, passage["quote"][:40])

    def test_contiguous_runs_split_where_a_section_was_dropped(self):
        paras = list(self.book.paragraphs())
        runs = ing.contiguous_runs([paras[0], paras[1], paras[5]])
        self.assertEqual([len(r) for r in runs], [2, 1])

    def test_covenant_follows_the_epoch_and_the_hijra(self):
        merged, units, _ = self.run_ingest()
        by_epoch = {}
        for station in self.generated(merged):
            by_epoch.setdefault(station["epoch_id"], set()).add(station["covenant"])
        self.assertEqual(by_epoch["epoch_01_omens"], {"pre_mission"})
        self.assertEqual(by_epoch["epoch_02_youth"], {"pre_mission"})
        self.assertEqual(by_epoch["epoch_03_secret_call"], {"meccan"})
        self.assertEqual(by_epoch["epoch_06_aqaba_hijra"], {"meccan", "medinan"})
        self.assertEqual(by_epoch["epoch_07_state_badr_uhud"], {"medinan"})
        self.assertEqual(by_epoch["epoch_10_farewell_companion"], {"medinan"})

    def test_a_year_in_a_heading_becomes_the_compass_year_with_the_heading_as_proof(self):
        merged, _, report = self.run_ingest()
        khandaq = next(s for s in self.generated(merged) if s["epoch_id"] == "epoch_08_khandaq_hudaybiyyah")
        self.assertEqual(khandaq["year_label"], "شوال سنة خمس")
        self.assertEqual(khandaq["compass_basis"][0]["quote"], ANCHORS["epoch_08_khandaq_hudaybiyyah"])
        self.assertEqual(report.years, 1)
        others = [s for s in self.generated(merged) if s is not khandaq]
        self.assertTrue(all("year_label" not in s for s in others), "no year is invented without a heading stating it")

    def test_place_comes_from_the_heading_or_else_the_covenant_default(self):
        merged, _, report = self.run_ingest()
        badr = next(s for s in self.generated(merged) if s["title"] == "غزوة بدر الكبرى")
        self.assertEqual(badr["place"]["name"], "بدر")
        elephant = next(s for s in self.generated(merged) if s["epoch_id"] == "epoch_01_omens")
        self.assertEqual(elephant["place"]["name"], "مكة")
        self.assertTrue(all(s["place"]["coordinatesApproximate"] for s in self.generated(merged)))
        self.assertGreater(report.default_places, 0)

    def test_generated_stations_say_they_await_review_and_have_no_experience_layer(self):
        merged, _, _ = self.run_ingest()
        for station in self.generated(merged):
            self.assertEqual(station["review"]["status"], ing.STATUS)
            for key in ("sceneDescription", "challenge", "propheticDecision", "hook", "shura_question"):
                self.assertNotIn(key, station)
            self.assertEqual(station["evidence"], [])
            self.assertTrue(station["chapters"])

    def test_small_neighbours_are_grouped_and_a_huge_unit_is_split(self):
        def extra(w):
            w.h1("وحدة ضخمة جدا")
            for i in range(6):
                w.h2(f"قسم ضخم {i}")
                w.paras(14)

        big = sample_book(extra)
        cfg = ing.Config.load(write_config(self.tmp.name, min_station_chars=900, max_station_chars=2500))
        merged, _, report = self.run_ingest(b=big, cfg=cfg)
        parts = [s for s in self.generated(merged) if s["title"].startswith("وحدة ضخمة جدا (")]
        self.assertGreaterEqual(len(parts), 2)
        self.assertEqual(report.split, 1, "one unit was split, however many parts it gave")
        self.assertGreaterEqual(report.grouped, 1)
        sizes = [sum(len(p["quote"]) for c in s["chapters"] for p in c["passages"]) for s in parts]
        self.assertTrue(all(size <= 2500 * 1.5 for size in sizes), sizes)

    def test_ids_are_unique_stable_and_prefixed(self):
        merged, _, _ = self.run_ingest()
        ids = [s["id"] for s in merged["stations"]]
        self.assertEqual(len(ids), len(set(ids)))
        again, _, _ = self.run_ingest()
        self.assertEqual(ids, [s["id"] for s in again["stations"]])
        self.assertTrue(all(i.startswith(ing.GENERATED_PREFIX) for i in ids))

    def test_running_twice_gives_the_same_file(self):
        first, _, _ = self.run_ingest()
        second, _, _ = self.run_ingest(dataset=copy.deepcopy(first))
        self.assertEqual(json.dumps(first, ensure_ascii=False), json.dumps(second, ensure_ascii=False))

    def test_mechanical_links_quote_neighbouring_headings_and_the_ends_have_none(self):
        merged, _, _ = self.run_ingest()
        stations = merged["stations"]
        self.assertNotIn("previous_link", stations[0])
        self.assertNotIn("next_hook", stations[-1])
        for i in range(1, len(stations)):
            self.assertIn(f"«{stations[i - 1]['title']}»", stations[i]["previous_link"])
            self.assertTrue(stations[i]["previous_link"].startswith(ing.PREV_PREFIX))
        for i in range(len(stations) - 1):
            self.assertIn(f"«{stations[i + 1]['title']}»", stations[i]["next_hook"])

    def test_bridges_none_leaves_the_links_out(self):
        cfg = ing.Config.load(self.config_path)
        cfg.bridges = "none"
        merged, _, _ = self.run_ingest(cfg=cfg)
        self.assertTrue(all("previous_link" not in s and "next_hook" not in s for s in merged["stations"]))

    def _curated_after_first_badr_part(self):
        badr = next(s for s in self.book.sections if s.title == "غزوة بدر الكبرى")
        para = badr.paras[5]
        return curated(
            "badr_curated", 1, "epoch_07_state_badr_uhud", para.text, para.locator,
            previous_link="ربط محرر بما قبلها", next_hook="ربط محرر بما بعدها",
        )

    def test_curated_stations_are_kept_whole_and_placed_by_their_place_in_the_book(self):
        station = self._curated_after_first_badr_part()
        before = json.dumps(station["chapters"], ensure_ascii=False)
        merged, _, _ = self.run_ingest(dataset=base_dataset([station]))
        ids = [s["id"] for s in merged["stations"]]
        at = ids.index("badr_curated")
        kept = merged["stations"][at]
        self.assertEqual(json.dumps(kept["chapters"], ensure_ascii=False), before)
        self.assertEqual(kept["review"]["notes"], ["ملاحظة"])
        epoch7 = [s for s in merged["stations"] if s["epoch_id"] == "epoch_07_state_badr_uhud"]
        self.assertIn("badr_curated", [s["id"] for s in epoch7])
        titles_before = [s["title"] for s in merged["stations"][:at] if s["epoch_id"] == "epoch_07_state_badr_uhud"]
        self.assertTrue(any("المؤاخاة" in t for t in titles_before), "text earlier in the book comes before it")

    def test_an_editorial_link_whose_neighbour_changed_is_invalidated_and_reported(self):
        station = self._curated_after_first_badr_part()
        merged, _, report = self.run_ingest(dataset=base_dataset([station]))
        kept = next(s for s in merged["stations"] if s["id"] == "badr_curated")
        self.assertTrue(kept["previous_link"].startswith(ing.PREV_PREFIX))
        self.assertTrue(kept["next_hook"].startswith(ing.NEXT_PREFIX))
        reported = {(sid, key) for sid, key, _ in report.invalidated}
        self.assertEqual(reported, {("badr_curated", "previous_link"), ("badr_curated", "next_hook")})

    def test_an_editorial_link_whose_neighbour_is_unchanged_survives(self):
        badr = next(s for s in self.book.sections if s.title == "غزوة بدر الكبرى")
        first = curated("first_cur", 1, "epoch_07_state_badr_uhud", badr.paras[1].text, badr.paras[1].locator)
        second = curated("second_cur", 2, "epoch_07_state_badr_uhud", badr.paras[2].text, badr.paras[2].locator)
        first["next_hook"] = "ربط محرر بالتالية"
        second["previous_link"] = "ربط محرر بالسابقة"
        merged, _, report = self.run_ingest(dataset=base_dataset([first, second]))
        by_id = {s["id"]: s for s in merged["stations"]}
        ids = [s["id"] for s in merged["stations"]]
        self.assertEqual(ids.index("second_cur"), ids.index("first_cur") + 1)
        self.assertEqual(by_id["first_cur"]["next_hook"], "ربط محرر بالتالية")
        self.assertEqual(by_id["second_cur"]["previous_link"], "ربط محرر بالسابقة")
        self.assertEqual(report.invalidated, [])
        self.assertTrue(by_id["first_cur"]["previous_link"].startswith(ing.PREV_PREFIX), "an absent link is filled mechanically")

    def test_a_missing_anchor_stops_the_ingestion_untouched(self):
        report = ing.Report()
        w = Writer()
        w.h1(ANCHORS["epoch_01_omens"])
        w.paras(5)
        w.h1(ANCHORS["epoch_02_youth"])
        w.paras(5)
        short = book.parse(w.text())
        dataset = base_dataset()
        merged, _ = ing.ingest(dataset, short, self.cfg, self.gazetteer, report)
        self.assertIs(merged, dataset)
        self.assertTrue(any("epoch_03_secret_call" in e for e in report.errors))

    def test_overlap_with_a_curated_station_is_noted_on_the_generated_one(self):
        station = self._curated_after_first_badr_part()
        merged, _, report = self.run_ingest(dataset=base_dataset([station]))
        self.assertTrue(report.overlaps)
        noted = [s for s in self.generated(merged) if any("يتداخل نصها" in n for n in s["review"]["notes"])]
        self.assertTrue(noted)

    def test_a_curated_station_not_found_in_the_book_is_still_kept_and_warned(self):
        alien = curated("alien", 1, "epoch_03_secret_call", "نص ليس في هذا الكتاب أبداً", "ج9 ص9")
        merged, _, report = self.run_ingest(dataset=base_dataset([alien]))
        self.assertIn("alien", [s["id"] for s in merged["stations"]])
        self.assertTrue(any("alien" in w and "لا موضع لها" in w for w in report.warnings))

    def test_the_report_names_anchors_skips_and_counts(self):
        merged, units, report = self.run_ingest()
        text = report.render(units, merged["stations"], self.book.format)
        for needle in ("مراسي الأطوار", "المحطات المولّدة", "الوحدات المتخطاة", "أقسام الشعر المستبعدة", "قوائم أسماء"):
            self.assertIn(needle, text)

    def test_bad_config_is_refused_with_a_clear_message(self):
        path = os.path.join(self.tmp.name, "bad.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({"epoch_anchors": [{"epoch": "x"}]}, handle)
        with self.assertRaises(SystemExit) as caught:
            ing.Config.load(path)
        self.assertIn("غير صالحة", str(caught.exception))

    def test_a_place_default_missing_from_the_gazetteer_is_refused(self):
        path = os.path.join(self.tmp.name, "places.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({"defaults": {"meccan": "غير موجود"}, "places": []}, handle)
        with self.assertRaises(SystemExit):
            ing.Gazetteer.load(path)

    def test_the_real_config_and_places_are_loadable_and_consistent(self):
        cfg = ing.Config.load(os.path.join(HERE, "ingest_config.json"))
        self.assertEqual([e for e, _ in cfg.anchors], epochs.EPOCH_IDS)
        gazetteer = ing.Gazetteer.load(os.path.join(HERE, "places.json"))
        for covenant in ("pre_mission", "meccan", "medinan"):
            place, derived = gazetteer.place_for("عنوان بلا موضع", covenant)
            self.assertFalse(derived)
            self.assertTrue(-90 <= place["latitude"] <= 90 and -180 <= place["longitude"] <= 180)


class TestIngestCommandLine(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.book_path = os.path.join(self.tmp.name, "book.txt")
        with open(self.book_path, "w", encoding="utf-8") as handle:
            handle.write(self._sample_text())
        self.dataset_path = os.path.join(self.tmp.name, "dataset.json")
        with open(self.dataset_path, "w", encoding="utf-8") as handle:
            json.dump(base_dataset(), handle, ensure_ascii=False)
        self.config_path = write_config(self.tmp.name)

    @staticmethod
    def _sample_text():
        w = Writer()
        w.h1("ذكر سرد النسب الزكي")
        w.paras(3)
        for epoch_id, title in ANCHORS.items():
            if epoch_id == "epoch_07_state_badr_uhud":
                w.h1("هجرة الرسول صلى الله عليه وسلم")
                w.paras(5)
            w.h1(title)
            w.h2("قسم")
            w.paras(8)
        return w.text()

    def run_main(self, *extra):
        argv = [
            "ingest_ibn_hisham.py", "--book", self.book_path, "--dataset", self.dataset_path,
            "--config", self.config_path, "--catalog", os.path.join(ROOT, "assets/data/catalogs/sources.json"),
            *extra,
        ]
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "argv", argv), redirect_stdout(out), redirect_stderr(err):
            code = ing.main()
        return code, out.getvalue(), err.getvalue()

    def dataset(self):
        with open(self.dataset_path, encoding="utf-8") as handle:
            return json.load(handle)

    def test_dry_run_reports_and_writes_nothing(self):
        report = os.path.join(self.tmp.name, "report.md")
        code, out, _ = self.run_main("--dry-run", "--report", report)
        self.assertEqual(code, 0)
        self.assertIn("لم يُكتب", out)
        self.assertEqual(self.dataset()["stations"], [])
        with open(report, encoding="utf-8") as handle:
            self.assertIn("تقرير استيعاب", handle.read())

    def test_a_real_run_writes_a_dataset_that_passes_every_check(self):
        code, _, _ = self.run_main()
        self.assertEqual(code, 0)
        data = self.dataset()
        self.assertGreaterEqual(len(data["stations"]), 10)
        self.assertEqual(checks.structure_issues(data), [])
        self.assertEqual(checks.quote_issues(data, {SOURCE: book.read(self.book_path)}), [])

    def test_a_second_run_changes_nothing(self):
        self.run_main()
        with open(self.dataset_path, "rb") as handle:
            first = handle.read()
        self.run_main()
        with open(self.dataset_path, "rb") as handle:
            self.assertEqual(handle.read(), first)

    def test_a_source_missing_from_the_catalog_is_refused(self):
        with self.assertRaises(SystemExit) as caught:
            self.run_main("--source-id", "كتاب_غير_مفهرس")
        self.assertIn("ليس في", str(caught.exception))

    def test_a_tampered_station_stops_the_write(self):
        original = ing.checks.quote_issues
        with mock.patch.object(ing.checks, "quote_issues", return_value=["محطة مفسدة"]):
            code, out, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("FAIL محطة مفسدة", out)
        self.assertIn("لم يُكتب الملف", err)
        self.assertEqual(self.dataset()["stations"], [])
        self.assertIs(ing.checks.quote_issues, original)


class TestCorpora(unittest.TestCase):
    def test_source_ids_and_known_checksums_agree(self):
        self.assertEqual(set(corpora.SOURCE_IDS), set(corpora.KNOWN_SHA256))

    def test_epochs_are_ten_numbered_in_order(self):
        self.assertEqual([n for _, n, _ in epochs.EPOCHS], list(range(1, 11)))
        self.assertEqual(epochs.covenant_of("epoch_02_youth", False), "pre_mission")
        self.assertEqual(epochs.covenant_of("epoch_06_aqaba_hijra", False), "meccan")
        self.assertEqual(epochs.covenant_of("epoch_06_aqaba_hijra", True), "medinan")
        self.assertEqual(epochs.covenant_of("epoch_08_khandaq_hudaybiyyah", False), "medinan")


if __name__ == "__main__":
    unittest.main()
