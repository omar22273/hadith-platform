#!/usr/bin/env python3
"""يبني ملفات الأذكار (assets/data/adhkar/) وملف السنن المهجورة (assets/data/sunan/) بالاقتطاع الحرفي من المدونة المثبّتة.

الخط الأحمر: لا يوجد في هذا المشروع لفظ نبوي مكتوب باليد. المواصفات في
adhkar_matrix_specs.py تحدد فقط: أي حديث، ومن أي كلمة مفتاحية إلى أي كلمة مفتاحية.
أما النص نفسه فيقتطعه adhkar_corpus.cut من الإصدار الرقمي، ويُثبت أنه تتابع كلمات حرفي،
وأن نص الذكر وفضله جزء حرفي من شاهد أو أكثر، وأن العدد (إن زاد على واحد) منصوص في الشاهد.
ما رتبته دون الصحيح والحسن عند الألباني في الإصدار نفسه يُرفض، إلا ما نصّ عليه المالك وأُعلنت درجته
(weak_ok) فيُقبل مع تنبيه ظاهر ودرجة مفصّلة في نافذة المعلومات.

مصادر إضافية بمفاتيح q/o/h (انظر adhkar_sources.py): آيات المالك، وعباراته المشكولة، وملف حصن المسلم.
الأذكار التي ليست في الكتب الستة وتشكيلها من نص المالك وحده توسَم بأنها بانتظار المراجعة العلمية.

الاستعمال:
    python3 tools/content/build_adhkar_matrix.py <hadith-api checkout> [--preview] [--out assets/data/adhkar]
                                                [--report docs/adhkar_hisn_crosscheck.md]
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


def source_id_of(ed):
    return adhkar_sources.EXTRA_EDITIONS[ed] if ed in adhkar_sources.EXTRA_EDITIONS else ac.EDITIONS[ed][1]


def locator_for(ed, ref):
    """الموضع المكتوب في الشاهد: رقم الحديث للكتب الستة، وتسمية الموضع للمصادر الإضافية."""
    return EXTRA.locator(ed, ref) if ed in adhkar_sources.EXTRA_EDITIONS else locator_of(ref)


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


GRADE_LABELS = {
    "Sahih": "صحيح",
    "Hasan": "حسن",
    "Hasan Sahih": "حسن صحيح",
    "Sahih Isnaad": "صحيح الإسناد",
    "Hasan Isnaad": "حسن الإسناد",
}
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
    if ev["first"] is None:
        # نص كامل من مصدر إضافي (آية، عبارة المالك، ذكر في حصن المسلم).
        if not EXTRA.is_extra(ev["ed"]):
            raise BuildError(f"{item_id}: whole-text evidence is only for the q/o/h sources")
        if "..." in entry["text"] or "…" in entry["text"]:
            raise BuildError(f"{item_id}: {ev['ed']}:{ev['ref']} is abridged by the owner and cannot be used whole")
        return ac.clean_noise(entry["text"]), ""
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
    if piece.get("whole"):
        return quote
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


def surface_of(quote, plain_word):
    """الصورة المشكولة لكلمة مجرّدة كما وردت في نص الشاهد (أول ورود)."""
    wanted = ac.core(plain_word)
    for token in quote.split():
        if ac.core(token) == wanted:
            return ac.strip_edges(token)
    return None


def apply_derivation(text, quotes, derive, item_id):
    """إبدال كلمة واحدة في نص مقتطع حرفياً بكلمة أخرى منقولة بتشكيلها من شاهد آخر للذكر.

    الإبدال يكون بدلالة الشاهد نفسه: العبارة [proof] يجب أن ترد في نص الشاهد الأساسي (كأن يقول: ومن
    قال مثل ذلك حين يمسي). لا تُكتب الكلمة البديلة هنا، بل تؤخذ من الشاهد المسمّى."""
    base = quotes[derive["base"]]
    donor = quotes[derive["donor"]]
    if not ac.contains_plain(base, derive["proof"]):
        raise BuildError(f"{item_id}: derivation proof {derive['proof']!r} not found in its base quote")
    new_surface = surface_of(donor, derive["to"])
    if new_surface is None:
        raise BuildError(f"{item_id}: replacement word {derive['to']!r} not found in the donor quote")
    old_core = ac.core(derive["from"])
    words = text.split()
    hits = [i for i, w in enumerate(words) if ac.core(w) == old_core]
    if len(hits) != 1:
        raise BuildError(f"{item_id}: expected one {derive['from']!r} in the text, got {len(hits)}")
    old_surface = words[hits[0]]
    words[hits[0]] = new_surface
    proof_surface = None
    tokens = base.split()
    wanted = [ac.core(w) for w in derive["proof"].split()]
    for i in range(len(tokens)):
        if [ac.core(t) for t in tokens[i:i + len(wanted)]] == wanted:
            proof_surface = ac.strip_edges(" ".join(tokens[i:i + len(wanted)]))
            break
    note = (
        f"الشاهد نفسه ينص على أن المسائي كالصباحي: «{proof_surface}»؛ فأُبدلت «{ac.strip_edges(old_surface)}» "
        f"بـ«{new_surface}» المنقولة بتشكيلها من الشاهد الآخر للذكر، ولم يُغيَّر في النص غير هذه الكلمة."
    )
    return " ".join(words), {"fromWord": old_core, "toWord": ac.core(derive["to"]), "note": note}


def hisn_compare(book, ref, text):
    """مقارنة نص الذكر المعتمد بذكر حصن المسلم المقابل: نسبة التطابق والفروق على مستوى الكلمات المجرّدة."""
    chapter, number = (int(part) for part in ref.split("."))
    entry = book.entry(chapter, number)
    mine = [c for c in (ac.core(t) for t in text.split()) if c and c != "*"]
    theirs = [c for c in entry.tokens if c != "*"]
    matcher = difflib.SequenceMatcher(None, mine, theirs, autojunk=False)
    diffs = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != "equal":
            diffs.append((" ".join(mine[i1:i2]), " ".join(theirs[j1:j2])))
    return {
        "ref": ref,
        "chapter": entry.chapter_title,
        "ratio": round(matcher.ratio(), 3),
        "diffs": diffs,
        "hisn_count": entry.count,
        "hisn_count_words": entry.count_words,
    }


def caution_for(evidence_specs, weak_grades):
    """تنبيه البطاقة: يُحسب من الدرجة المسجلة لا من يد المحرر."""
    if weak_grades:
        return (
            f"تنبيه: درجة هذا الحديث عند الألباني في الإصدار المعتمد «{weak_grades[0]}»؛ "
            "أُدرج الذكر لأن طلب المالك وحصن المسلم أوردَاه، فراجع الدرجة المفصّلة في ⓘ قبل الاعتماد عليه."
        )
    if all(ev["ed"] in ("o", "h") for ev in evidence_specs) and any(ev["ed"] == "o" for ev in evidence_specs):
        return (
            "تنبيه: لم يُوجد هذا الذكر في الكتب الستة المثبّتة؛ نصه المشكول من إدخال المالك ومرجعه حصن المسلم، "
            "وتخريجه بانتظار المراجعة العلمية."
        )
    return None


NOTE_QUOTE = re.compile("«([^»]+)»")


def check_note_quotes(notes, quotes, item_id):
    """كل عبارة بين «» في ملاحظات المواصفة يجب أن تكون جزءاً من أحد الشواهد؛ فلا يُكتب لفظ في ملاحظة من الذاكرة."""
    for note in notes:
        for phrase in NOTE_QUOTE.findall(note):
            if not any(ac.contains_plain(quote, phrase) for quote in quotes):
                raise BuildError(f"{item_id}: the note quotes {phrase!r}, which is not inside any of its evidence quotes")


def build_item(corpus, sources, hisn, order, spec, preview, report):
    item_id = spec["id"]
    quotes = []
    labels = []
    followings = []
    weak_grades = []
    used_weak = False
    for ev in spec["ev"]:
        quote, following = build_quote(corpus, ev, item_id)
        if FORBIDDEN.search(quote):
            raise BuildError(f"{item_id}: quote carries stray direction or quote marks")
        quotes.append(quote)
        followings.append(following)
        label, weak = check_grade(corpus, ev, item_id, spec.get("weak_ok", False))
        labels.append(label)
        if weak:
            used_weak = True
            weak_grades.append(GRADE_AR[albani_grade(corpus, ev["ed"], ev["ref"])])
    if spec.get("weak_ok") and not used_weak:
        raise BuildError(f"{item_id}: weak_ok is set but every witness is already Sahih/Hasan")
    text = build_piece(quotes, spec["text"], item_id, "text")
    derivation = None
    if spec.get("derive"):
        text, derivation = apply_derivation(text, quotes, spec["derive"], item_id)
    if not TASHKEEL.search(text) or len(text) < 6:
        raise BuildError(f"{item_id}: text must be vocalized and not trivial")
    virtue = None
    if spec.get("virtue"):
        virtue = build_piece(quotes, spec["virtue"], item_id, "virtue")
        if not TASHKEEL.search(virtue):
            raise BuildError(f"{item_id}: virtue must be vocalized")
    bab = spec.get("bab")
    count = spec["count"]
    proof = spec.get("proof")
    notes = []
    hisn_ref = spec.get("hisn")
    hisn_info = hisn_compare(hisn, hisn_ref, text) if hisn_ref else None
    if bab:
        # سنة مهجورة: بطاقة مرجعية بلا عدّ؛ فلا يُدَّعى عدد ولا يُدوَّن في الملاحظات.
        if count != 1 or proof or hisn_ref or spec.get("tracks") or spec.get("count_from"):
            raise BuildError(f"{item_id}: a sunnah card carries no count, proof, hisn or tracks")
    elif count > 1:
        if proof:
            if not any(ac.contains_plain(q, proof) for q in quotes):
                raise BuildError(f"{item_id}: proof phrase {proof!r} not found in any quote")
            notes.append(f"العدد ({count}) منصوص في الشاهد بعبارة «{proof}».")
        elif spec.get("count_from") == "hisn":
            if hisn_info is None or hisn_info["hisn_count"] != count:
                raise BuildError(f"{item_id}: count {count} is not what Hisn states ({hisn_info and hisn_info['hisn_count']})")
            notes.append(
                f"العدد ({count}) ليس منصوصاً في الشاهد؛ أُخذ من طلب المالك ومن حصن المسلم "
                f"({locator_for('h', hisn_ref)}: «{' / '.join(hisn_info['hisn_count_words'])}»)."
            )
        else:
            raise BuildError(f"{item_id}: count {count} needs a proof phrase from the quotes (or count_from='hisn')")
    else:
        if proof:
            if not any(ac.contains_plain(q, proof) for q in quotes):
                raise BuildError(f"{item_id}: proof phrase {proof!r} not found in any quote")
            notes.append(f"المرة الواحدة منصوص عليها في الشاهد بعبارة «{proof}».")
        else:
            notes.append("لم يُنص في الشاهد على عدد؛ يُقرأ الذكر مرة واحدة.")
    seen = set()
    for ev, label in zip(spec["ev"], labels):
        key = (ev["ed"], ev["ref"])
        if key in seen or EXTRA.is_extra(ev["ed"]):
            continue
        seen.add(key)
        notes.append(f"{source_id_of(ev['ed'])} رقم {locator_of(ev['ref'])}: {label}.")
    if any(ev["ed"] == "m" for ev in spec["ev"]):
        notes.append(MUSLIM_NOTE)
    check_note_quotes(spec.get("notes", ()), quotes, item_id)
    notes.extend(spec.get("notes", ()))
    if derivation:
        notes.append(derivation["note"])
    if any(not EXTRA.is_extra(ev["ed"]) for ev in spec["ev"]):
        notes.append(
            "النص والإحالة منقولان حرفياً بالاقتطاع الآلي من إصدار fawazahmed0/hadith-api المعتمد في فهرس المصادر "
            f"(الإيداع {ac.COMMIT[:7]}) دون كتابة أي لفظ منه من الذاكرة (انظر tools/content/build_adhkar_matrix.py)؛ "
            "أُزيلت منه علامات الاتجاه وعلامات الاقتباس وأقواس الآيات فقط."
        )
    if any(ev["ed"] in ("q", "o") for ev in spec["ev"]):
        notes.append(
            "النص المشكول منقول حرفياً بالاستخراج الآلي من طلب مالك المشروع v2.9.0 "
            "(tools/content/extract_owner_texts.py) دون أن يمر على يد المحرر."
        )
    notes.append("الضبط كما في الإصدار الرقمي دون تعديل؛ يراجعه مصحح قبل النشر.")
    evidence = [
        {"sourceId": source_id_of(ev["ed"]), "locator": locator_for(ev["ed"], ev["ref"]), "quote": quote}
        for ev, quote in zip(spec["ev"], quotes)
    ]
    grading_lines = grade_lines(corpus, sources, spec["ev"])
    result = {
        "id": item_id,
        "order": order,
        "title": spec["title"],
    }
    if bab:
        result["bab"] = bab
    result["text"] = text
    if not bab:
        result["count"] = count
    if virtue:
        result["virtue"] = virtue
    if spec.get("tracks"):
        result["tracks"] = list(spec["tracks"])
    result["evidence"] = evidence
    if grading_lines:
        result["grading"] = "\n".join(grading_lines)
    caution = caution_for(spec["ev"], weak_grades)
    if caution:
        result["caution"] = caution
    if derivation:
        result["derivation"] = derivation
    result["review"] = {"status": "pending_scholarly_review", "reviewer": None, "reviewedAt": None, "notes": notes}
    if hisn_info:
        report.append({"item": item_id, "title": spec["title"], "count": count, **hisn_info})
    if preview:
        print(f"--- {item_id}  {'bab=' + bab if bab else 'x' + str(count)}  tracks={spec.get('tracks')}  [{'; '.join(labels)}]")
        print("  text   :", text)
        if virtue:
            print("  virtue :", virtue)
        if caution:
            print("  caution:", caution)
        if hisn_info:
            print(f"  hisn   : {hisn_ref} ratio={hisn_info['ratio']} diffs={hisn_info['diffs']}")
        for ev, quote, following in zip(spec["ev"], quotes, followings):
            print(f"  quote  : {ev['ed']}:{ev['ref']} ({len(quote.split())} words) ... بعده: {following}")
    return result


def check_tracks(file_id, definition, items):
    """تبديل الفئة: كل ذكر له مساراته من مسارات الملف، ولكل مسار ذكر واحد على الأقل."""
    declared = definition.get("tracks")
    if not declared:
        for item in items:
            if item.get("tracks"):
                raise BuildError(f"{file_id}:{item['id']}: has tracks but the file declares none")
        return
    used = set()
    for item in items:
        own = item.get("tracks")
        if not own:
            raise BuildError(f"{file_id}:{item['id']}: needs tracks (file has {declared})")
        for track in own:
            if track not in declared:
                raise BuildError(f"{file_id}:{item['id']}: unknown track {track!r}")
            used.add(track)
    for track in declared:
        if track not in used:
            raise BuildError(f"{file_id}: track {track!r} has no items")


def check_babs(file_id, definition, items):
    """ملف السنن: لكل بطاقة بابها، ولكل باب من أبواب الشريط بطاقة واحدة على الأقل؛ وملفات الأذكار لا أبواب فيها."""
    import adhkar_spec_kit as kit
    if definition.get("kind") != "sunan":
        for item in items:
            if "bab" in item:
                raise BuildError(f"{file_id}:{item['id']}: only the sunan file carries babs")
        return
    used = set()
    for item in items:
        bab = item.get("bab")
        if bab not in kit.BABS:
            raise BuildError(f"{file_id}:{item['id']}: unknown or missing bab {bab!r}")
        used.add(bab)
    for bab in kit.BABS:
        if bab not in used:
            raise BuildError(f"{file_id}: bab {bab!r} has no items")
    if len(items) < 30:
        raise BuildError(f"{file_id}: expected at least 30 documented sunan, got {len(items)}")


def build_file(corpus, sources, hisn, file_id, definition, preview, failures, report):
    items = []
    for order, spec in enumerate(definition["items"], start=1):
        try:
            items.append(build_item(corpus, sources, hisn, order, spec, preview, report))
        except (BuildError, ac.CutError, KeyError) as error:
            failures.append(f"{file_id}:{spec['id']}: {error}")
    try:
        check_tracks(file_id, definition, items)
    except BuildError as error:
        failures.append(str(error))
    check_babs(file_id, definition, items)
    return {"schemaVersion": "2.0.0", "id": file_id, "title": definition["title"], "items": items}


def known_sources(path):
    with open(path, encoding="utf-8") as fh:
        catalog = json.load(fh)
    return {s["id"]: s for s in catalog["sources"]}


def check_sources(catalog, sources):
    """كل مصدر شاهد معروف في فهرس المصادر، وإيداع الإصدار الرقمي للكتب الستة هو المثبّت هنا."""
    extra_ids = set(adhkar_sources.EXTRA_EDITIONS.values())
    for item in catalog["items"]:
        for evidence in item["evidence"]:
            source = sources.get(evidence["sourceId"])
            if source is None:
                raise BuildError(f"{item['id']}: unknown sourceId {evidence['sourceId']}")
            if evidence["sourceId"] in extra_ids:
                continue
            if source["digital"]["commit"] != ac.COMMIT:
                raise BuildError(f"{item['id']}: source {evidence['sourceId']} is not pinned to commit {ac.COMMIT[:7]}")


def write_report(path, report, fixes_applied):
    """تقرير مطابقة حصن المسلم: لكل ذكر معتمد مقابله في الحصن ونسبة التطابق والفروق، وقائمة الإصلاحات المسمّاة."""
    lines = [
        "# تقرير مطابقة «حصن المسلم» على المدونة المثبتة (v2.9.0)",
        "",
        "يُولَّد آلياً بواسطة `tools/content/build_adhkar_matrix.py --report` ولا يُحرَّر باليد.",
        "",
        "الأذكار المعروضة في التطبيق تُقتطع حرفياً من الكتب الستة المثبتة (فيُضمن تشكيلها)، ويُقارَن كل ذكر بمقابله في ملف الحصن",
        "بعد تنظيفه وتطبيق الإصلاحات المسمّاة (`hisn_fixes.py`). الفروق أدناه على مستوى الكلمات المجرّدة من التشكيل:",
        "العمود الأول لفظ التطبيق، والثاني لفظ ملف الحصن؛ الفرق الفارغ يعني زيادة أو نقصاناً.",
        "",
        "| الذكر | موضعه في الحصن | التطابق | العدد (التطبيق/الحصن) | الفروق (التطبيق ⇠ الحصن) |",
        "|---|---|---|---|---|",
    ]
    for row in sorted(report, key=lambda r: r["ref"]):
        diffs = "؛ ".join(f"«{a or '∅'}» ⇠ «{b or '∅'}»" for a, b in row["diffs"]) or "—"
        counts = f"{row['count']} / {row['hisn_count'] if row['hisn_count'] is not None else '—'}"
        lines.append(f"| {row['title']} | الباب {row['chapter']}، {row['ref']} | {int(row['ratio'] * 100)}٪ | {counts} | {diffs} |")
    lines += ["", "## الإصلاحات المسمّاة المطبَّقة على ملف الحصن", ""]
    for name, hits in sorted(fixes_applied.items()):
        lines.append(f"- `{name}` ×{hits}")
    lines.append("")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--only")
    parser.add_argument("--out", default="assets/data/adhkar")
    parser.add_argument("--sunan-out", default="assets/data/sunan")
    parser.add_argument("--sources", default="assets/data/catalogs/sources.json")
    parser.add_argument("--report")
    args = parser.parse_args()
    corpus = ac.Corpus(args.root)
    hisn = EXTRA.hisn()
    ids = set()
    built = {}
    failures = []
    report = []
    sources = known_sources(args.sources)
    for file_id, definition in specs.FILES.items():
        if args.only and args.only != file_id:
            continue
        if args.preview:
            print(f"=========== {file_id}")
        catalog = build_file(corpus, sources, hisn, file_id, definition, args.preview, failures, report)
        try:
            check_sources(catalog, sources)
        except BuildError as error:
            failures.append(str(error))
        for item in catalog["items"]:
            if item["id"] in ids:
                failures.append(f"duplicate item id {item['id']}")
            ids.add(item["id"])
        built[file_id] = catalog
    if failures:
        raise BuildError("\n".join(failures))
    if args.report:
        write_report(args.report, report, hisn.applied)
        print("wrote", args.report, len(report), "rows")
    if args.preview:
        return
    for file_id, catalog in built.items():
        directory = args.sunan_out if specs.FILES[file_id].get("kind") == "sunan" else args.out
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, f"{file_id}.json")
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
