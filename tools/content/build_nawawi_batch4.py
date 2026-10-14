#!/usr/bin/env python3
"""يبني ملفات الأحاديث ٤٣–٥٠ (تتمة الخمسين الرجبية) ويحدّث فهرس المنهج إلى خمسين محطة.

الخط الأحمر المعرفي: لا يُكتب متن حديث ولا إسناد ولا بيان من الذاكرة.
- المتن النبوي لكل حديث يرسله مالك المشروع مشكولاً، ولا يُقبل إلا إذا طابق هيكلُه الحرفي
  (دون الحركات) نصَّ الحديث في الطبعة المثبّتة (fawazahmed0/hadith-api) في كل موضع مذكور
  في verify؛ فإن لم يطابق (كالحديث ٤٩) اعتُمد نص الطبعة المثبّتة نفسه مقتطعاً حرفياً، وسُجّل ذلك.
- مقدمة الراوي («عن ابن عباس قال قال رسول الله ﷺ») تُقتطع حرفياً من نص الطبعة المثبّتة المتصل
  بالمتن مباشرة، وتُحذف منها علامات التنصيص وحرف التطويل فقط.
- غريب الألفاظ والشرح الميسر من «التحفة الربانية» نصاً، وبعد حذف ما يخص لفظاً غير وارد في المتن.
- لا أسانيد: طبقة طالب العلم تبقى «سند الرواية يتاح في التحديث القادم».
- كل اقتباس في السياق والموقف والأثر يُتحقق آلياً أنه نص حرفي في موضعه (آلة build_nawawi_batch2).

الاستعمال:
  python3 tools/content/build_nawawi_batch4.py --editions DIR --jami FILE [--root .] [--only 43,44]
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_nawawi_batch2 as b2  # noqa: E402
import nawawi_batch4  # noqa: E402
from nawawi_text import BIDI, plain  # noqa: E402

squash = b2.squash
canon = b2.canon

FIRST, LAST = 43, 50
BuildError = b2.BuildError
COLLECTION_ID = "tatimmat_al_khamsin"
COLLECTION_TITLE = "تتمة الخمسين الرجبية"
BOOK_NAMES = {
    "b": "صحيح البخاري", "m": "صحيح مسلم", "t": "سنن الترمذي",
    "i": "سنن ابن ماجه", "n": "سنن النسائي",
}
BASE_NOTE = (
    "المتن النبوي لهذا الحديث مرسل من مالك المشروع بتشكيله، وقد قوبل هيكله الحرفي (دون الحركات) بنص الحديث "
    "في الطبعة المثبّتة للمواضع المذكورة في takhrij؛ ومقدمة الراوي مقتطعة حرفياً من الطبعة المثبّتة نفسها لا من الذاكرة. "
    "وتُراجع الحركات على طبعة محققة."
)


# ----------------------------------------------------------------------------
# القص الحرفي من الطبعة المثبّتة
# ----------------------------------------------------------------------------
def indexed_words(text):
    """(كلمات النص المقسّم بالمسافات، [(موضع الكلمة في القائمة، الصورة المعيارية)])."""
    tokens = text.split()
    words = []
    for position, token in enumerate(tokens):
        for word in plain(token).split():
            words.append((position, word))
    return tokens, words


def find_sequence(words, sequence, start=0, stop=None):
    plains = [word for _, word in words]
    end = (len(plains) if stop is None else stop) - len(sequence) + 1
    for index in range(start, end):
        if plains[index:index + len(sequence)] == sequence:
            return index
    return None


def sequence_of(phrase):
    return [plain(word) for word in phrase.split() if plain(word)]


def clean_cut(text):
    """يحذف علامات التنصيص والتطويل المنفردة من المقتطع؛ ولا يمسّ حرفاً ولا حركة."""
    text = text.replace('"', " ").replace("«", " ").replace("»", " ").replace("ـ", " ")
    text = re.sub(r"\s+([:.،؛])", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def replace_tokens(text, old, new):
    """يستبدل أول تتابع كلمات يطابق old بصورته المعيارية (دون التشكيل) بـ new؛ يوقف البناء إن لم يوجد."""
    tokens = text.split()
    target = sequence_of(old)
    plains = [plain(token) for token in tokens]
    for index in range(len(tokens) - len(target) + 1):
        if plains[index:index + len(target)] == target:
            return " ".join(tokens[:index] + [new] + tokens[index + len(target):])
    raise BuildError(f"مقطع التعديل غير موجود في المقدمة: «{old}»")


def cut_from(texts, lead_start, matn):
    """يعيد (المقدمة، مقتطع المتن، نص المصدر) من أول نص يحوي المتن ومقدمته المتصلة به.

    matn: ("supplied", نص) أو ("source", أول المتن، آخره).
    """
    start_words = sequence_of(lead_start)
    for text in texts:
        tokens, words = indexed_words(text)
        if matn[0] == "supplied":
            matn_words = sequence_of(matn[1])
            first = find_sequence(words, matn_words)
            last = None if first is None else first + len(matn_words) - 1
        else:
            first = find_sequence(words, sequence_of(matn[1]))
            end_words = sequence_of(matn[2])
            tail = None if first is None else find_sequence(words, end_words, first)
            last = None if tail is None else tail + len(end_words) - 1
        if first is None or last is None:
            continue
        lead_at = None
        for index in range(first - len(start_words), -1, -1):
            if [word for _, word in words[index:index + len(start_words)]] == start_words:
                lead_at = index
                break
        if lead_at is None:
            continue
        lead = tokens[words[lead_at][0]:words[first][0]]
        body = tokens[words[first][0]:words[last][0] + 1]
        return clean_cut(" ".join(lead)), clean_cut(" ".join(body)), text
    raise BuildError(f"لا نص يجمع المقدمة «{lead_start}» والمتن معاً")


def contains_matn(texts, matn_words):
    for text in texts:
        _, words = indexed_words(text)
        if find_sequence(words, matn_words) is not None:
            return True
    return False


# ----------------------------------------------------------------------------
# تجهيز بيانات حديث واحد للآلة المشتركة
# ----------------------------------------------------------------------------
def verify_fix_source(corpus, spec):
    """يثبت أن النص الجديد للتعديل ورد حرفياً بحركاته في موضعه المثبّت؛ ويعيد وصف الموضع."""
    kind, locator, quote = spec
    if kind == "a":
        text = squash(BIDI.sub("", corpus.nawawi[int(locator)]))
        if squash(quote) not in text:
            raise BuildError(f"ضبط غير حرفي في الأربعين ({locator}): {quote}")
        return f"الأربعين النووية (الحديث {locator})"
    corpus.verify_exact(kind, locator, quote)
    return f"{BOOK_NAMES.get(kind, kind)} ({locator})"


def prepare(number, spec, corpus):
    data = dict(spec)
    kind, locator, lead_start = spec["lead"]
    texts = corpus.parts(kind, locator)
    if not texts:
        raise BuildError(f"الحديث {number}: لا نص في {kind} {locator}")
    matn = spec["matn"]
    lead, body, _ = cut_from(texts, lead_start, matn)
    source_span = f"{lead} {body}".strip()
    notes_extra = []
    moved_lead, moved_body = b2.lam_alif(lead), b2.lam_alif(body)
    if moved_lead != lead or moved_body != body:
        lead, body = moved_lead, moved_body
        notes_extra.append(
            "نقل الفتحة من بعد الألف إلى اللام في «لاَ» وما شاكلها («الإِسْلاَمِ») لتوافق ضبط سائر المتن؛ تغيير موضع علامة لا حرف ولا حركة.")
    prophet = matn[1] if matn[0] == "supplied" else body
    matn_words = sequence_of(prophet)
    source_name = f"{BOOK_NAMES.get(kind, 'التحفة الربانية')} ({locator})"
    if matn[0] == "supplied":
        for check_kind, check_locator in spec["verify"]:
            if not contains_matn(corpus.parts(check_kind, str(check_locator)), matn_words):
                raise BuildError(
                    f"الحديث {number}: المتن المرسل لا يطابق نص {check_kind} {check_locator} في الطبعة المثبّتة")
        places = "، ".join(f"{BOOK_NAMES[k]} ({loc})" for k, loc in spec["verify"])
        notes_extra.append(
            f"المتن النبوي مرسل من مالك المشروع بتشكيله، وطابق هيكله الحرفي (دون الحركات) نص الطبعة المثبّتة في: {places}.")
    else:
        notes_extra.append(
            f"المتن النبوي مقتطع حرفياً من {source_name} في الطبعة المثبّتة؛ لأن اللفظ المرسل لا يوافق أي موضع مثبّت حرفياً (انظر ملاحظات المراجعة).")
    notes_extra.append(
        f"مقدمة الراوي مقتطعة حرفياً من {source_name} بعد حذف علامات التنصيص وحرف التطويل (ـ) وتوحيد الصلاة على النبي إلى ﷺ.")
    for old, new, note, proof in spec.get("lead_fix", []):
        lead = replace_tokens(lead, old, new)
        if proof is not None:
            verify_fix_source(corpus, proof)
            if canon(proof[2]) and canon(new) not in canon(proof[2]):
                raise BuildError(f"الحديث {number}: إثبات التعديل لا يوافق النص الجديد «{new}»")
        notes_extra.append(note)
    for check_kind, check_locator in spec.get("loose", []):
        if not corpus.parts(check_kind, str(check_locator)):
            raise BuildError(f"الحديث {number}: موضع التخريج غير موجود {check_kind} {check_locator}")
    data.update(
        raw=f"{lead} {prophet}".strip(),
        statement=None,
        collection={"id": COLLECTION_ID, "title": COLLECTION_TITLE, "numberInCollection": number},
        matn_source=corpus.ref((kind, locator, source_span)),
        extra_normalizations=notes_extra,
        base_notes=[BASE_NOTE],
    )
    return data


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--editions", required=True)
    parser.add_argument("--jami", required=True)
    parser.add_argument("--root", default=".")
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    root = Path(args.root)
    corpus = b2.Corpus(args.editions, args.jami)
    catalog = nawawi_batch4.HADITHS
    wanted = [int(n) for n in args.only.split(",") if n] or list(range(FIRST, LAST + 1))
    full = not args.only
    if full and sorted(catalog) != list(range(FIRST, LAST + 1)):
        raise BuildError(f"الأحاديث المعرّفة: {sorted(catalog)}")
    out_dir = root / "assets/data/hadith/nawawi40"
    sources = json.loads((root / "assets/data/catalogs/sources.json").read_text(encoding="utf-8"))
    known = {entry["id"] for entry in sources["sources"]}
    items = []
    for number in wanted:
        if number not in catalog:
            continue
        hadith = b2.build_hadith(number, prepare(number, catalog[number], corpus), corpus)
        text = json.dumps(hadith, ensure_ascii=False)
        for source_id in set(re.findall(r'"sourceId": "([a-z0-9_]+)"', text)):
            if source_id not in known:
                raise BuildError(f"الحديث {number}: مصدر غير معرّف في الفهرس: {source_id}")
        path = out_dir / f"{hadith['id']}.json"
        b2.write_json(path, hadith)
        items.append({
            "hadithId": hadith["id"],
            "number": number,
            "title": hadith["title"],
            "assetPath": f"assets/data/hadith/nawawi40/{hadith['id']}.json",
        })
        print(f"OK  {path.name}  chunks={len(hadith['practice']['chunks'])} gharib={len(hadith['matn']['gharib'])}"
              f" edits={len(hadith['provenance']['vocalizationEdits'])}")
    if full:
        curriculum_path = root / "assets/data/curriculum/nawawi40_curriculum.json"
        curriculum = json.loads(curriculum_path.read_text(encoding="utf-8"))
        kept = [item for item in curriculum["items"] if item["number"] < FIRST]
        curriculum["items"] = kept + items
        curriculum["plannedCount"] = LAST
        b2.write_json(curriculum_path, curriculum)
        print(f"OK  {curriculum_path}  items={len(curriculum['items'])} plannedCount={curriculum['plannedCount']}")


if __name__ == "__main__":
    try:
        main()
    except BuildError as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
