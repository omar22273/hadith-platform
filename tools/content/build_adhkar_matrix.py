#!/usr/bin/env python3
"""يبني ملفات الأذكار الستة في assets/data/adhkar/ بالاقتطاع الحرفي من المدونة المثبّتة.

الخط الأحمر: لا يوجد في هذا المشروع لفظ نبوي مكتوب باليد. المواصفات في
adhkar_matrix_specs.py تحدد فقط: أي حديث، ومن أي كلمة مفتاحية إلى أي كلمة مفتاحية.
أما النص نفسه فيقتطعه adhkar_corpus.cut من الإصدار الرقمي، ويُثبت أنه تتابع كلمات حرفي،
وأن نص الذكر وفضله جزء حرفي من شاهد أو أكثر، وأن العدد (إن زاد على واحد) منصوص في الشاهد.
ما رتبته دون الصحيح والحسن عند الألباني في الإصدار نفسه يُرفض.

الاستعمال:
    python3 tools/content/build_adhkar_matrix.py <hadith-api checkout> [--preview] [--out assets/data/adhkar]
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import adhkar_corpus as ac  # noqa: E402
import adhkar_matrix_specs as specs  # noqa: E402
import adhkar_sources  # noqa: E402
import difflib  # noqa: E402

TASHKEEL = re.compile("[ً-ْ]")
FORBIDDEN = re.compile("[‏‎\"«»{}]")
ALBANI = "Al-Albani"
MUSLIM_NOTE = "ترقيم صحيح مسلم بترقيم محمد فؤاد عبد الباقي."


class BuildError(Exception):
    pass


def locator_of(ref):
    return ref.split(".")[0]


EXTRA = adhkar_sources.ExtraSources()


def by_ref(corpus, ed, ref):
    """الحديث برقمه العربي (arabicnumber) في الإصدار، ويجب أن يكون وحيداً.

    المفاتيح الإضافية q/o/h تقرأ من المصادر المثبّتة في tools/content/sources."""
    if EXTRA.is_extra(ed):
        try:
            return EXTRA.entry(ed, ref)
        except KeyError as error:
            raise BuildError(str(error))
    found = [
        h for h in corpus.entries(ed)
        if (str(h.get("arabicnumber")) == ref) or (h.get("arabicnumber") is None and str(h["hadithnumber"]) == ref)
    ]
    if len(found) != 1:
        raise BuildError(f"{ed}:{ref}: expected exactly one entry, got {len(found)}")
    return found[0]


def albani_grade(corpus, ed, ref):
    """درجة الألباني لهذا الحديث نفسه في الإصدار، أو None إن لم تكن له درجة في مدخله."""
    entry = by_ref(corpus, ed, ref)
    grades = dict((g.get("name"), g.get("grade")) for g in entry.get("grades", []))
    return grades.get(ALBANI)


GRADE_LABELS = {"Sahih": "صحيح", "Hasan": "حسن", "Hasan Sahih": "حسن صحيح", "Sahih Isnaad": "صحيح الإسناد"}
BOOK_NAMES = {"b": "صحيح البخاري", "m": "صحيح مسلم"}

# أسماء المحققين كما ترد في الإصدار ونطقها العربي. تُكتب هنا أسماء أعلام لا ألفاظ حديث.
GRADER_AR = {
    "Al-Albani": "الألباني",
    "Zubair Ali Zai": "الزبير علي زئي",
    "Shuaib Al Arnaut": "شعيب الأرناؤوط",
    "Muhammad Muhyi Al-Din Abdul Hamid": "محمد محيي الدين عبد الحميد",
    "Bashar Awad Maarouf": "بشار عواد معروف",
    "Ahmad Muhammad Shakir": "أحمد محمد شاكر",
    "Muhammad Fouad Abd al-Baqi": "محمد فؤاد عبد الباقي",
    "Abu Ghuddah": "أبو غدة",
}
# أوصاف الدرجات كما ترد في الإصدار؛ ما لا يرد هنا لا يُترجم ولا يُعرض (فلا تخمين).
GRADE_AR = {
    "Sahih": "صحيح",
    "Hasan": "حسن",
    "Hasan Sahih": "حسن صحيح",
    "Daif": "ضعيف",
    "Very Daif": "ضعيف جداً",
    "Mawdu": "موضوع",
    "Munkar": "منكر",
    "Shadh": "شاذ",
    "Isnaad Hasan": "إسناده حسن",
    "Isnaad Sahih": "إسناده صحيح",
    "Hasan Isnaad": "حسن الإسناد",
    "Sahih Isnaad": "صحيح الإسناد",
    "Daif Isnaad": "ضعيف الإسناد",
    "Sanad Daif": "إسناده ضعيف",
    "Sahih Lighairihi": "صحيح لغيره",
    "Hasan Lighairihi": "حسن لغيره",
    "Sahih Muquf": "صحيح موقوف",
    "Sahih - Agreed Upon": "صحيح متفق عليه",
    "Sahih Muslim": "في صحيح مسلم",
    "Sahih Bukhari": "في صحيح البخاري",
}
NOT_FROM_SIX = "لم يرد في الكتب الستة المثبّتة؛ النص من إدخال مالك المشروع (ومرجعه حصن المسلم) وتخريجه بانتظار المراجعة العلمية."


def grade_lines(corpus, sources, evidences):
    """سطر درجة لكل حديث متمايز من الكتب الستة، منقولاً من أحكام الإصدار نفسه."""
    lines = []
    seen = set()
    for ev in evidences:
        ed, ref = ev["ed"], ev["ref"]
        key = (ed, ref)
        if key in seen:
            continue
        seen.add(key)
        if ed == "q":
            lines.append("نص قرآني مشكول أدخله مالك المشروع بنصه الحرفي.")
            continue
        if ed == "o":
            lines.append(NOT_FROM_SIX)
            continue
        if ed == "h":
            continue
        title = sources[ac.EDITIONS[ed][1]]["title"]
        place = f"{title} رقم {locator_of(ref)}"
        if ed in BOOK_NAMES:
            lines.append(f"{place}: مروي في {BOOK_NAMES[ed]}.")
            continue
        entry = by_ref(corpus, ed, ref)
        parts = []
        for grader in entry.get("grades", []):
            name = GRADER_AR.get(grader.get("name"))
            grade = GRADE_AR.get(grader.get("grade"))
            if name and grade:
                parts.append((0 if grader.get("name") == ALBANI else 1, f"{name}: {grade}"))
        if not parts:
            verdict = ev.get("verdict")
            if verdict:
                lines.append(f"{place}: حكم صاحب الكتاب في الإصدار: «{ac.clean_noise(verdict)}».")
            else:
                lines.append(f"{place}: لا درجة مسجلة له في الإصدار.")
            continue
        parts.sort(key=lambda p: p[0])
        lines.append(f"{place}: " + "؛ ".join(p[1] for p in parts) + ".")
    return lines


def check_grade(corpus, spec_ev, item_id, weak_ok=False):
    """يرفض الشاهد من غير الصحيحين ما لم تكن درجته صحيحة أو حسنة عند الألباني في الإصدار.

    إن خلا مدخل الحديث من درجة (رواية فرعية في الإصدار) قُبل بحكم صاحب الكتاب إذا ورد في نص
    الإصدار نفسه حرفياً وطابق [verdict] في المواصفة. وما طلب المالك ذكره صراحةً وهو ضعيف عند
    الألباني يُقبل بـ weak_ok مع تسجيل درجته؛ ويُرجَع بصفة (الوصف، هل هو ضعيف).
    """
    ed, ref = spec_ev["ed"], spec_ev["ref"]
    if EXTRA.is_extra(ed):
        return "نص من مصدر أدخله المالك أو أرفقه", False
    if ed in BOOK_NAMES:
        return "مروي في " + BOOK_NAMES[ed], False
    grade = albani_grade(corpus, ed, ref)
    if grade in GRADE_LABELS:
        return "درجته عند الألباني في الإصدار: " + GRADE_LABELS[grade], False
    verdict = spec_ev.get("verdict")
    if grade is None and verdict:
        entry = by_ref(corpus, ed, ref)
        if not ac.contains_plain(entry["text"], verdict):
            raise BuildError(f"{item_id}: verdict {verdict!r} not found in {ed}:{ref}")
        return "حكم صاحب الكتاب في نص الإصدار: «" + ac.clean_noise(verdict) + "»", False
    if weak_ok and grade in GRADE_AR:
        return "درجته عند الألباني في الإصدار: " + GRADE_AR[grade], True
    raise BuildError(f"{item_id}: {ed}:{ref} grade by {ALBANI} is {grade!r}; only Sahih/Hasan are allowed")


def drop_waw(text):
    """يحذف واو العطف الأولى (مع حركتها) من أول المقطع؛ يبقى المقطع جزءاً حرفياً من الشاهد."""
    if not text.startswith("و"):
        raise BuildError(f"drop_waw: {text[:12]!r} does not start with a waw")
    rest = text[1:]
    while rest and "ً" <= rest[0] <= "ْ":
        rest = rest[1:]
    return rest


def build_quote(corpus, ev, item_id):
    entry = by_ref(corpus, ev["ed"], ev["ref"])
    try:
        quote, start, end = ac.cut(
            entry["text"], ev["first"], ev.get("last"), occurrence=ev.get("occ", 0), last_occurrence=ev.get("lo", 0)
        )
    except ac.CutError as error:
        raise BuildError(f"{item_id}: evidence {ev['ed']}:{ev['ref']}: {error}")
    following = " ".join(ac.tokens(entry["text"])[end + 1:end + 9])
    return quote, following


def build_piece(quotes, piece, item_id, what):
    quote = quotes[piece["ev"]]
    try:
        text, _, _ = ac.cut(quote, piece["first"], piece.get("last"), occurrence=piece.get("occ", 0), last_occurrence=piece.get("lo", 0))
    except ac.CutError as error:
        raise BuildError(f"{item_id}: {what}: {error}")
    if piece.get("waw"):
        text = drop_waw(text)
    if text not in quote:
        raise BuildError(f"{item_id}: {what} is not a verbatim part of its quote")
    if FORBIDDEN.search(text):
        raise BuildError(f"{item_id}: {what} carries stray direction or quote marks")
    return text


def build_item(corpus, order, spec, preview):
    item_id = spec["id"]
    quotes = []
    grades = []
    followings = []
    for ev in spec["ev"]:
        quote, following = build_quote(corpus, ev, item_id)
        if FORBIDDEN.search(quote):
            raise BuildError(f"{item_id}: quote carries stray direction or quote marks")
        quotes.append(quote)
        followings.append(following)
        grades.append(check_grade(corpus, ev, item_id))
    text = build_piece(quotes, spec["text"], item_id, "text")
    if not TASHKEEL.search(text) or len(text) < 6:
        raise BuildError(f"{item_id}: text must be vocalized and not trivial")
    virtue = None
    if spec.get("virtue"):
        virtue = build_piece(quotes, spec["virtue"], item_id, "virtue")
        if not TASHKEEL.search(virtue):
            raise BuildError(f"{item_id}: virtue must be vocalized")
    count = spec["count"]
    proof = spec.get("proof")
    notes = []
    if count > 1:
        if not proof:
            raise BuildError(f"{item_id}: count {count} needs a proof phrase from the quotes")
        if not any(ac.contains_plain(q, proof) for q in quotes):
            raise BuildError(f"{item_id}: proof phrase {proof!r} not found in any quote")
        notes.append(f"العدد ({count}) منصوص في الشاهد بعبارة «{proof}».")
    else:
        if proof:
            if not any(ac.contains_plain(q, proof) for q in quotes):
                raise BuildError(f"{item_id}: proof phrase {proof!r} not found in any quote")
            notes.append(f"المرة الواحدة منصوص عليها في الشاهد بعبارة «{proof}».")
        else:
            notes.append("لم يُنص في الشاهد على عدد؛ يُقرأ الذكر مرة واحدة.")
    seen = set()
    for ev, grade in zip(spec["ev"], grades):
        key = (ev["ed"], ev["ref"])
        if key in seen:
            continue
        seen.add(key)
        notes.append(f"{ac.EDITIONS[ev['ed']][1]} رقم {locator_of(ev['ref'])}: {grade}.")
    if any(ev["ed"] == "m" for ev in spec["ev"]):
        notes.append(MUSLIM_NOTE)
    notes.extend(spec.get("notes", ()))
    notes.append(
        "النص والإحالة منقولان حرفياً بالاقتطاع الآلي من إصدار fawazahmed0/hadith-api المعتمد في فهرس المصادر "
        f"(الإيداع {ac.COMMIT[:7]}) دون كتابة أي لفظ منه من الذاكرة (انظر tools/content/build_adhkar_matrix.py)؛ "
        "أُزيلت منه علامات الاتجاه وعلامات الاقتباس وأقواس الآيات فقط."
    )
    notes.append("الضبط كما في الإصدار الرقمي دون تعديل؛ يراجعه مصحح قبل النشر.")
    evidence = [
        {"sourceId": ac.EDITIONS[ev["ed"]][1], "locator": locator_of(ev["ref"]), "quote": quote}
        for ev, quote in zip(spec["ev"], quotes)
    ]
    result = {
        "id": item_id,
        "order": order,
        "title": spec["title"],
        "text": text,
        "count": count,
    }
    if virtue:
        result["virtue"] = virtue
    result["evidence"] = evidence
    result["review"] = {"status": "pending_scholarly_review", "reviewer": None, "reviewedAt": None, "notes": notes}
    if preview:
        print(f"--- {item_id}  x{count}  [{'; '.join(grades)}]")
        print("  text   :", text)
        if virtue:
            print("  virtue :", virtue)
        for ev, quote, following in zip(spec["ev"], quotes, followings):
            print(f"  quote  : {ev['ed']}:{ev['ref']} ({len(quote.split())} words) ... بعده: {following}")
    return result


def build_file(corpus, file_id, definition, preview, failures):
    items = []
    for order, spec in enumerate(definition["items"], start=1):
        try:
            items.append(build_item(corpus, order, spec, preview))
        except (BuildError, ac.CutError) as error:
            failures.append(f"{file_id}: {error}")
    return {"schemaVersion": "2.0.0", "id": file_id, "title": definition["title"], "items": items}


def known_sources(path):
    with open(path, encoding="utf-8") as fh:
        catalog = json.load(fh)
    return {s["id"]: s for s in catalog["sources"]}


def check_sources(catalog, sources):
    """كل مصدر شاهد معروف في فهرس المصادر، وإيداع الإصدار الرقمي فيه هو المثبّت هنا."""
    for item in catalog["items"]:
        for evidence in item["evidence"]:
            source = sources.get(evidence["sourceId"])
            if source is None:
                raise BuildError(f"{item['id']}: unknown sourceId {evidence['sourceId']}")
            if source["digital"]["commit"] != ac.COMMIT:
                raise BuildError(f"{item['id']}: source {evidence['sourceId']} is not pinned to commit {ac.COMMIT[:7]}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--only")
    parser.add_argument("--out", default="assets/data/adhkar")
    parser.add_argument("--sources", default="assets/data/catalogs/sources.json")
    args = parser.parse_args()
    corpus = ac.Corpus(args.root)
    ids = set()
    built = {}
    failures = []
    sources = known_sources(args.sources)
    for file_id, definition in specs.FILES.items():
        if args.only and args.only != file_id:
            continue
        if args.preview:
            print(f"=========== {file_id}")
        catalog = build_file(corpus, file_id, definition, args.preview, failures)
        check_sources(catalog, sources)
        for item in catalog["items"]:
            if item["id"] in ids:
                raise BuildError(f"duplicate item id {item['id']}")
            ids.add(item["id"])
        built[file_id] = catalog
    if failures:
        raise BuildError("\n".join(failures))
    if args.preview:
        return
    os.makedirs(args.out, exist_ok=True)
    for file_id, catalog in built.items():
        path = os.path.join(args.out, f"{file_id}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(catalog, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print("wrote", path, len(catalog["items"]), "items")


if __name__ == "__main__":
    try:
        main()
    except (BuildError, ac.CutError) as error:
        print("BUILD FAILED:", error, file=sys.stderr)
        sys.exit(1)
