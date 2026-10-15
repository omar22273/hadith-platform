"""مصادر الأذكار غير الكتب الستة: الآيات التي أدخلها المالك، وعباراته المشكولة، وملف حصن المسلم.

تقدّم هذه الوحدة واجهة تشبه واجهة المدونة (entries وentry) كي يقصّ المُنشئ منها بالآلية نفسها
التي يقصّ بها من الكتب الستة؛ وكل نص يخرج منها منقول حرفياً من ملف مثبّت في tools/content/sources.

مفاتيح الإصدارات الإضافية:
    q  الآيات المشكولة التي أدخلها المالك (quran_owner_text)
    o  عبارات الأذكار المشكولة التي أدخلها المالك في بند الاستكمال (owner_adhkar_v290)
    h  ملف حصن المسلم بعد التنظيف (hisn_al_muslim)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import hisn_book  # noqa: E402

EXTRA_EDITIONS = {
    "q": "quran_owner_text",
    "o": "owner_adhkar_v290",
    "h": "hisn_al_muslim",
}

SOURCES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sources")


class ExtraSources:
    def __init__(self, sources_dir=SOURCES_DIR):
        self.dir = sources_dir
        self._entries = {}
        self._labels = {}
        self._hisn = None

    def is_extra(self, ed):
        return ed in EXTRA_EDITIONS

    def hisn(self):
        if self._hisn is None:
            self._hisn = hisn_book.load(os.path.join(self.dir, "hisn_al_muslim.txt"))
        return self._hisn

    def _load(self, ed):
        if ed in self._entries:
            return
        entries = []
        labels = {}
        if ed == "q":
            with open(os.path.join(self.dir, "quran_owner_text.json"), encoding="utf-8") as fh:
                data = json.load(fh)
            for passage in data["passages"]:
                entries.append({"hadithnumber": passage["id"], "arabicnumber": passage["id"], "text": passage["text"], "grades": []})
                labels[passage["id"]] = passage["label"]
        elif ed == "o":
            with open(os.path.join(self.dir, "owner_adhkar_v290.json"), encoding="utf-8") as fh:
                data = json.load(fh)
            for span in data["spans"]:
                key = span["key"]
                entries.append({"hadithnumber": key, "arabicnumber": key, "text": span["text"], "grades": [], "count_note": span["count_note"]})
                labels[key] = f"طلب المالك v2.9.0، السطر {span['line']}"
        elif ed == "h":
            for entry in self.hisn().entries:
                key = f"{entry.chapter}.{entry.number}"
                entries.append({"hadithnumber": key, "arabicnumber": key, "text": entry.text, "grades": [], "count": entry.count})
                labels[key] = f"الباب {entry.chapter}، الذكر {entry.number}"
        else:
            raise KeyError(ed)
        self._entries[ed] = entries
        self._labels[ed] = labels

    def entries(self, ed):
        self._load(ed)
        return self._entries[ed]

    def entry(self, ed, ref):
        found = [e for e in self.entries(ed) if e["arabicnumber"] == str(ref)]
        if len(found) != 1:
            raise KeyError(f"{ed}:{ref}: expected exactly one entry, got {len(found)}")
        return found[0]

    def locator(self, ed, ref):
        self._load(ed)
        return self._labels[ed][str(ref)]
