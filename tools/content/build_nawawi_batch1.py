#!/usr/bin/env python3
"""يبني ملفات الأحاديث ٣–١٠ من الأربعين النووية ويحدّث فهرس المنهج.

المبدأ (الخط الأحمر المعرفي): لا يُكتب متن حديث ولا بيان من الذاكرة.
- المتن يُقتطع من نص الأربعين الرقمي المثبّت (fawazahmed0/hadith-api، ara-nawawi).
- كل تصحيح ضبط يُسجَّل في provenance بقاعدته وطريقته ومصدره.
- كل اقتباس (غريب، سياق، أثر) يُتحقق آلياً من أنه نص حرفي في موضعه:
  جامع العلوم والحكم (OpenITI Shamela0004268) أو نسخة الصحيحين المثبّتة.
  أي اقتباس غير مطابق يوقف البناء.

الاستعمال:
  python3 tools/content/build_nawawi_batch1.py --editions DIR --jami FILE [--root .]
حيث DIR فيه ara-nawawi.json وara-bukhari.json وara-muslim.json بالإصدارات المثبّتة
في assets/data/catalogs/sources.json، وFILE ملف OpenITI لجامع العلوم والحكم.
"""

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nawawi_text import (  # noqa: E402
    KASRA, base_clean, cores, lint_candidates, plain, split_statement, tokenize,
)
import nawawi_batch1_a  # noqa: E402
import nawawi_batch1_b  # noqa: E402

ID_RE = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*$")
MATN_SOURCE = "arbaun_nawawiyya"
JAMI = "jami_ulum_hikam"
SOURCE_IDS = {"b": "sahih_bukhari", "m": "sahih_muslim"}


class BuildError(Exception):
    pass


def squash(text):
    return re.sub(r"\s+", " ", text).strip()


SHADDA = "\u0651"


def _is_mark(char):
    return "\u064b" <= char <= "\u065f" or char == "\u0670"


def canon_map(text):
    """صورة معيارية يتقدّم فيها الشدّ على غيره من الحركات، مع مواضع الأصل.

    مصدرا الصحيحين يكتبان الشدّة قبل الحركة غالباً، بينما يكتبها غيرهما بعدها؛
    فتُقارَن الصورتان معيارياً ويُحفظ الاقتباس بحروف المصدر نفسه.
    """
    out = []
    spans = []
    index = 0
    while index < len(text):
        if _is_mark(text[index]):
            end = index
            while end < len(text) and _is_mark(text[end]):
                end += 1
            marks = sorted(text[index:end], key=lambda mark: 0 if mark == SHADDA else 1)
            out.extend(marks)
            spans.extend([(index, end)] * len(marks))
            index = end
        else:
            out.append(text[index])
            spans.append((index, index + 1))
            index += 1
    return "".join(out), spans


def canon(text):
    return canon_map(text)[0]


def locate_verbatim(haystack, needle):
    """يعيد المقطع الحرفي من haystack المطابق معيارياً لـ needle، أو None."""
    hay, spans = canon_map(haystack)
    target = canon(needle)
    position = hay.find(target)
    if position < 0:
        return None
    return haystack[spans[position][0]:spans[position + len(target) - 1][1]]


# ----------------------------------------------------------------------------
# المصادر
# ----------------------------------------------------------------------------
class Corpus:
    def __init__(self, editions, jami_file):
        def load(name):
            return json.load(open(Path(editions) / name, encoding="utf-8"))["hadiths"]

        self.nawawi = {h["hadithnumber"]: h["text"] for h in load("ara-nawawi.json")}
        self.bukhari = {str(h["hadithnumber"]): h["text"] for h in load("ara-bukhari.json")}
        self.muslim = {}
        for h in load("ara-muslim.json"):
            self.muslim[str(h.get("arabicnumber", h["hadithnumber"]))] = h["text"]
        self.pages = self._jami_pages(jami_file)

    @staticmethod
    def _jami_pages(path):
        pages = {}
        volume = None
        page = None
        for line in open(path, encoding="utf-8").read().split("\n"):
            marker = re.match(r"# PageV(\d+)P(\d+)", line)
            if marker:
                volume, page = int(marker.group(1)), int(marker.group(2))
                continue
            if page is None or volume != 1:
                continue
            text = re.sub(r"^(~~|# |### \|? ?)", "", line)
            text = re.sub(r"</?span[^>]*>", "", text)
            pages.setdefault(page, []).append(text.strip())
        return {p: squash(" ".join(lines)) for p, lines in pages.items()}

    def verify(self, kind, locator, quote):
        """يتحقق أن الاقتباس نص حرفي في موضعه، ويعيده بحروف المصدر نفسه."""
        needle = squash(quote)
        if kind == "j":
            haystack = self.pages.get(int(locator))
            if haystack is None:
                raise BuildError(f"جامع العلوم: لا صفحة {locator} في الجزء الأول")
            if re.search(r"\bms\d+\b", needle):
                raise BuildError(f"اقتباس يحوي وسم حاشية: {quote}")
        elif kind == "b":
            haystack = squash(self.bukhari.get(str(locator), ""))
        elif kind == "m":
            number = str(locator)
            haystack = squash(" ".join(
                text for key, text in self.muslim.items()
                if key == number or key.startswith(number + ".")))
        else:
            raise BuildError(f"نوع مصدر مجهول: {kind}")
        found = locate_verbatim(haystack, needle)
        if found is None:
            raise BuildError(f"اقتباس غير حرفي ({kind} {locator}): {quote}")
        return found

    def ref(self, spec):
        kind, locator, quote = spec
        found = self.verify(kind, locator, quote)
        if kind == "j":
            return {"sourceId": JAMI, "locator": f"ج1 ص{locator}", "quote": found}
        return {"sourceId": SOURCE_IDS[kind], "locator": str(locator), "quote": found}

    def edit_source(self, spec):
        source_id, number, quote = spec
        kind = "b" if source_id == "sahih_bukhari" else "m"
        found = self.verify(kind, number, quote)
        return {"sourceId": source_id, "locator": str(number), "quote": found}


# ----------------------------------------------------------------------------
# تنظيف المتن
# ----------------------------------------------------------------------------
def normalise(raw, nested_quotes=False):
    """يعيد (المتن المنظّف، العبارة، قائمة التطبيعات المطبّقة).

    nested_quotes: أول علامة تنصيص وآخرها تحيطان بكلام النبي ﷺ، وما بينهما أزواج لآيات.
    """
    applied = []
    text = raw
    if re.search("[‎‏‪-‮⁦-⁩؜]", text):
        applied.append("حذف محارف الاتجاه الخفية (Unicode bidi controls).")
    if "<br>" in text:
        applied.append("حذف وسم <br> الزائد من المصدر الرقمي.")
    text = base_clean(text)
    if "ﷺ" in text:
        applied.append("توحيد صيغة الصلاة على النبي إلى الرمز ﷺ.")
    text, statement = split_statement(text)
    applied.append("نقل عبارة «[رواه …]» إلى takhrij.compilerStatement دون المعقوفين.")
    if "-" in text:
        text, count = re.subn(r"-(\S[^-]*?\S)-", r"(\1)", text)
        if count:
            applied.append("استبدال الشرطتين المحيطتين بجملة معترضة بقوسين؛ لأن الشرطة تلتصق بالكلمة في التقسيم.")
    quotes = [m.start() for m in re.finditer('"', text)]
    if quotes:
        if len(quotes) % 2:
            raise BuildError("علامات تنصيص فردية")
        chars = list(text)
        inner = quotes[1:-1] if nested_quotes else []
        for position in (quotes if not nested_quotes else (quotes[0], quotes[-1])):
            chars[position] = ""
        for order, position in enumerate(inner):
            chars[position] = "«" if order % 2 == 0 else "»"
        text = "".join(chars)
        applied.append("حذف علامتي التنصيص حول كلام النبي ﷺ؛ إذ يحدده حقل voice.")
        if inner:
            applied.append("تحويل علامتي التنصيص حول الآيتين الكريمتين إلى « ».")
    before = text
    text = re.sub(r"\s+([.،؛:؟!])", r"\1", text)
    text = re.sub(r"([؟!])\.", r"\1", text)
    text = squash(text)
    if text != squash(before):
        applied.append("ضبط المسافات قبل علامات الترقيم.")
    return text, statement, applied


# ----------------------------------------------------------------------------
# تقسيم الكلمات
# ----------------------------------------------------------------------------
def find_phrase(token_cores, phrase, start=0):
    words = phrase.split()
    plains = [plain(core) for core in token_cores]
    for index in range(start, len(plains) - len(words) + 1):
        if plains[index:index + len(words)] == words:
            return index
    raise BuildError(f"العبارة غير موجودة: «{phrase}» بعد الكلمة {start}")


def apply_edits(tokens, explicit, corpus, hadith_no):
    """يطبّق تصحيحات الضبط؛ يعيد (الكلمات، سجل التعديلات بالفهرس العام)."""
    tokens = [list(token) for token in tokens]
    log = []
    wanted = {e[0]: e[1:] for e in explicit}
    for index, token in enumerate(tokens):
        core = token[2]
        if index in wanted:
            before, after, rule, source_spec = wanted.pop(index)
            if core != before:
                raise BuildError(f"الحديث {hadith_no}: الكلمة {index} هي «{core}» لا «{before}»")
            if plain(before) != plain(after):
                raise BuildError(f"الحديث {hadith_no}: تعديل يغيّر الحروف: {before} → {after}")
            if canon(after) not in canon(source_spec[2]):
                raise BuildError(f"الحديث {hadith_no}: مصدر التعديل لا يحوي «{after}»")
            log.append((index, before, after, rule, "aligned_source", corpus.edit_source(source_spec)))
            token[2] = after
        if re.search("إ(?!" + KASRA + ")", token[2]):
            fixed = re.sub("إ(?!" + KASRA + ")", "إ" + KASRA, token[2])
            log.append((index, token[2], fixed, "hamza_below_without_kasra", "orthographic_rule", None))
            token[2] = fixed
        token[0] = token[1] + token[2] + token[3]
    if wanted:
        raise BuildError(f"الحديث {hadith_no}: تعديلات لم تُطبَّق: {sorted(wanted)}")
    return [tuple(token) for token in tokens], sorted(log, key=lambda item: item[0])


def build_segments(tokens, spec):
    starts = []
    cursor = 0
    token_cores = [token[2] for token in tokens]
    for order, (voice, phrase) in enumerate(spec):
        index = find_phrase(token_cores, phrase, cursor if order == 0 else cursor + 1)
        if order == 0 and index != 0:
            raise BuildError("المقطع الأول يجب أن يبدأ من أول المتن")
        starts.append(index)
        cursor = index
    starts.append(len(tokens))
    segments = []
    for order, (voice, _) in enumerate(spec):
        part = tokens[starts[order]:starts[order + 1]]
        segments.append({
            "id": f"s{order + 1}",
            "voice": voice,
            "tokens": part,
            "start": starts[order],
        })
    return segments


# ----------------------------------------------------------------------------
# بناء حديث واحد
# ----------------------------------------------------------------------------
COMMON_NOTES = [
    "نص الأربعين في المصدر الرقمي غير منسوب إلى طبعة ورقية بعينها؛ يُقابَل المتن المعروض بطبعة محققة.",
    "الموقف السلوكي والخلاصة والآثار صياغة تحريرية مستندة إلى الشروح المذكورة في حقول المصادر.",
    "طبقة طالب العلم (الأسانيد ومقارنة الروايات) لم تُملأ بعد لهذا الحديث؛ تُضاف مع تراجم رواته في دفعة لاحقة.",
    "التلاوة الصوتية لم تُسجَّل بعد.",
]
ALIGNED_NOTE = (
    "صُحّح ضبط بعض الكلمات بمطابقة صورة الكلمة (رسماً لا سياقاً) في موضع مشكول من الصحيحين المثبّتين، "
    "وهو مسجّل في provenance.vocalizationEdits؛ تُراجع على طبعة محققة."
)


def build_hadith(number, data, corpus):
    raw = corpus.nawawi.get(number)
    if raw is None:
        raise BuildError(f"لا حديث {number} في الأربعين الرقمي")
    body, statement, normalizations = normalise(raw, data.get("nested_quotes", False))
    tokens = tokenize(body)
    tokens, edit_log = apply_edits(tokens, data["edits"], corpus, number)
    remaining = lint_candidates(" ".join(token[0] for token in tokens))
    if remaining:
        raise BuildError(f"الحديث {number}: ضبط معيب متبقٍّ: {remaining}")

    segments = build_segments(tokens, data["segments"])
    by_id = {segment["id"]: segment for segment in segments}

    def seg_cores(segment_id):
        return [token[2] for token in by_id[segment_id]["tokens"]]

    # ----- المتن
    matn_segments = [{
        "id": segment["id"],
        "voice": segment["voice"],
        "text": " ".join(token[0] for token in segment["tokens"]),
    } for segment in segments]
    for segment in matn_segments:
        if cores(segment["text"]) != seg_cores(segment["id"]):
            raise BuildError(f"الحديث {number}: عدم اتساق التقسيم في {segment['id']}")
    joined = " ".join(segment["text"] for segment in matn_segments)
    if plain(joined) != plain(body):
        raise BuildError(f"الحديث {number}: المتن المجزّأ لا يطابق المصدر")

    def anchor(segment_id, phrase):
        token_cores = seg_cores(segment_id)
        index = find_phrase(token_cores, phrase)
        length = len(phrase.split())
        return {
            "segmentId": segment_id,
            "tokenIndex": index,
            "length": length,
            "surface": " ".join(token_cores[index:index + length]),
        }

    gharib = []
    for entry in data["gharib"]:
        if not ID_RE.match(entry["id"]):
            raise BuildError(f"معرّف غريب غير صالح: {entry['id']}")
        gharib.append({
            "id": entry["id"],
            "anchor": anchor(entry["seg"], entry["phrase"]),
            "headword": entry["headword"],
            "meaning": entry["meaning"],
            "sources": [corpus.ref(spec) for spec in entry["sources"]],
        })
    if not 2 <= len(gharib) <= 4:
        raise BuildError(f"الحديث {number}: الغريب يجب أن يكون بين 2 و4")

    takhrij = data["takhrij"]
    matn = {
        "segments": matn_segments,
        "gharib": gharib,
        "audio": {
            "status": "not_recorded", "remoteUrl": None, "reciter": None,
            "durationMs": None, "timings": [],
        },
        "takhrij": {
            "displayLabel": takhrij["label"],
            "references": [{
                "sourceId": source_id,
                "hadithNumber": hadith_number,
                "numberingSystem": "fuad_abdul_baqi",
                "digitalLocator": locator,
            } for source_id, hadith_number, locator in takhrij["refs"]],
            "compilerStatement": {"text": statement, "sourceId": MATN_SOURCE},
            "gradings": [],
        },
    }
    for reference in matn["takhrij"]["references"]:
        kind = "b" if reference["sourceId"] == "sahih_bukhari" else "m"
        pool = corpus.bukhari if kind == "b" else corpus.muslim
        if not any(key == reference["hadithNumber"] or key.startswith(reference["hadithNumber"] + ".") for key in pool):
            raise BuildError(f"الحديث {number}: رقم التخريج غير موجود {reference}")

    # ----- التدريب
    chunk_specs = data["chunks"]
    if not 3 <= len(chunk_specs) <= 4:
        raise BuildError(f"الحديث {number}: المقاطع يجب أن تكون 3 أو 4")
    chunks = []
    for order, (label, segment_id, first, last) in enumerate(chunk_specs):
        token_cores = seg_cores(segment_id)
        start = find_phrase(token_cores, first)
        end_at = find_phrase(token_cores, last, start)
        end = end_at + len(last.split()) - 1
        if end < start:
            raise BuildError(f"الحديث {number}: مقطع معكوس {label}")
        chunks.append({
            "id": f"c{order + 1}", "segmentId": segment_id,
            "startToken": start, "endToken": end, "label": label,
        })
    practice = {
        "chunks": chunks,
        "reconstruction": {"chunkIds": [chunk["id"] for chunk in chunks], "shuffleStrategy": "per_user_per_day"},
        "vanishing": {
            "levels": [
                {"level": 1, "hidePercent": 25},
                {"level": 2, "hidePercent": 50},
                {"level": 3, "hidePercent": 80},
            ],
            "priorityAnchors": [anchor(segment_id, phrase) for segment_id, phrase in data["anchors"]],
        },
    }

    # ----- السياق
    context_data = data["context"]
    context = {
        "narrative": context_data["narrative"],
        "humanMotive": context_data["humanMotive"],
        "place": None,
        "sources": [corpus.ref(spec) for spec in context_data["sources"]],
        "cautions": [{
            "text": text,
            "sources": [corpus.ref(spec) for spec in specs],
        } for text, specs in context_data["cautions"]],
    }

    # ----- أثر الحديث في حياتك
    scenario_data = data["scenario"]
    options = [{
        "id": f"o{order + 1}", "alignment": alignment, "text": text, "feedback": feedback,
    } for order, (alignment, text, feedback) in enumerate(scenario_data["options"])]
    if sum(option["alignment"] == "aligned" for option in options) != 1:
        raise BuildError(f"الحديث {number}: يجب خيار واحد موافق بالضبط")
    reflection = {
        "scenario": {
            "situation": scenario_data["situation"],
            "question": scenario_data["question"],
            "options": options,
            "takeaway": scenario_data["takeaway"],
            "basis": [corpus.ref(spec) for spec in scenario_data["basis"]],
        },
        "impacts": [{
            "text": text,
            "sources": [corpus.ref(spec) for spec in specs],
        } for text, specs in data["impacts"]],
    }

    # ----- سجل المصدر
    def locate(index):
        for segment in segments:
            if segment["start"] <= index < segment["start"] + len(segment["tokens"]):
                return segment["id"], index - segment["start"]
        raise BuildError(f"كلمة خارج المقاطع: {index}")

    edits = []
    for index, before, after, rule, method, source in edit_log:
        segment_id, local = locate(index)
        edits.append({
            "segmentId": segment_id, "tokenIndex": local, "before": before, "after": after,
            "rule": rule, "method": method, "source": source,
        })
    notes = list(COMMON_NOTES[:1])
    notes += data["notes"]
    if any(edit["method"] == "aligned_source" for edit in edits):
        notes.append(ALIGNED_NOTE)
    notes += COMMON_NOTES[1:]

    hadith = {
        "schemaVersion": "2.0.0",
        "id": f"nawawi40_{number:03d}",
        "sequence": number,
        "collection": {"id": "arbaun_nawawiyya", "title": "الأربعون النووية", "numberInCollection": number},
        "title": data["title"],
        "teaser": {"text": data["teaser"]},
        "milestone": data["milestone"],
        "context": context,
        "matn": matn,
        "practice": practice,
        "reflection": reflection,
        "scholar": {"chains": [], "variants": []},
        "provenance": {
            "matnSource": {"sourceId": MATN_SOURCE, "locator": f"الحديث {number}", "quote": None},
            "normalizations": normalizations,
            "vocalizationEdits": edits,
        },
        "review": {"status": "pending_scholarly_review", "reviewer": None, "reviewedAt": None, "notes": notes},
    }
    return hadith


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--editions", required=True)
    parser.add_argument("--jami", required=True)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root)
    corpus = Corpus(args.editions, args.jami)
    catalog = {**nawawi_batch1_a.HADITHS, **nawawi_batch1_b.HADITHS}
    if sorted(catalog) != list(range(3, 11)):
        raise BuildError(f"الأحاديث المعرّفة: {sorted(catalog)}")
    out_dir = root / "assets/data/hadith/nawawi40"
    sources = json.loads((root / "assets/data/catalogs/sources.json").read_text(encoding="utf-8"))
    known = {entry["id"] for entry in sources["sources"]}
    items = []
    for number in range(3, 11):
        hadith = build_hadith(number, catalog[number], corpus)
        text = json.dumps(hadith, ensure_ascii=False)
        for source_id in set(re.findall(r'"sourceId": "([a-z0-9_]+)"', text)):
            if source_id not in known:
                raise BuildError(f"الحديث {number}: مصدر غير معرّف في الفهرس: {source_id}")
        path = out_dir / f"{hadith['id']}.json"
        write_json(path, hadith)
        items.append({
            "hadithId": hadith["id"],
            "number": number,
            "title": hadith["title"],
            "assetPath": f"assets/data/hadith/nawawi40/{hadith['id']}.json",
        })
        print(f"OK  {path}  chunks={len(hadith['practice']['chunks'])} gharib={len(hadith['matn']['gharib'])}"
              f" edits={len(hadith['provenance']['vocalizationEdits'])}")
    curriculum_path = root / "assets/data/curriculum/nawawi40_curriculum.json"
    curriculum = json.loads(curriculum_path.read_text(encoding="utf-8"))
    kept = [item for item in curriculum["items"] if item["number"] < 3]
    curriculum["items"] = kept + items
    write_json(curriculum_path, curriculum)
    print(f"OK  {curriculum_path}  items={len(curriculum['items'])}")


if __name__ == "__main__":
    try:
        main()
    except BuildError as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
