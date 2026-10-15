"""مطابقة أذكار «حصن المسلم» على المدونة المثبّتة (الكتب الستة).

الغاية: حيث يرد الحديث في الكتب الستة يُؤخذ التشكيل منها وحدها، ويُكشف ما يختلف فيه لفظ
الملف عن لفظ الكتاب. لا تكتب هذه الوحدة لفظاً؛ تقارن كلمات مجرّدة وتعيد مواضع في المدونة.
"""
import collections
import difflib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import adhkar_corpus as ac  # noqa: E402

EDITION_KEYS = "bmtind"


class Index:
    """فهرس الكلمات المجرّدة لكل حديث في الإصدارات الستة."""

    def __init__(self, corpus):
        self.corpus = corpus
        self.docs = []  # (ed, entry, cores)
        self.postings = collections.defaultdict(set)
        for ed in EDITION_KEYS:
            for entry, cores in zip(corpus.entries(ed), corpus._cores(ed)):
                doc_id = len(self.docs)
                self.docs.append((ed, entry, cores))
                for token in set(cores):
                    self.postings[token].add(doc_id)

    def candidates(self, tokens, min_share=0.6, limit=2000):
        wanted = set(tokens)
        counts = collections.Counter()
        for token in wanted:
            posting = self.postings.get(token)
            if posting and len(posting) < limit:
                counts.update(posting)
        need = max(2, int(len(wanted) * min_share))
        return [doc for doc, c in counts.items() if c >= need]


def align(index, tokens, min_cover=0.75, top=6):
    """أفضل المواضع التي يغطي فيها حديثٌ ما كلمات [tokens] بتتابعها.

    يعيد قائمة (تغطية، إصدار، رقم، arabicnumber، بداية، نهاية شاملة، كلمات ناقصة، كلمات زائدة)."""
    results = []
    n = len(tokens)
    if n == 0:
        return results
    for doc_id in index.candidates(tokens):
        ed, entry, cores = index.docs[doc_id]
        matcher = difflib.SequenceMatcher(None, tokens, cores, autojunk=False)
        blocks = [b for b in matcher.get_matching_blocks() if b.size > 0]
        if not blocks:
            continue
        # أطول كتلة متصلة، ثم الكتل القريبة منها فقط (نافذة بطول النص)
        anchor = max(blocks, key=lambda b: b.size)
        lo = anchor.b - anchor.a - 3
        hi = lo + n + 6
        near = [b for b in blocks if lo <= b.b - b.a <= hi and lo <= b.b <= hi + n]
        matched = sum(b.size for b in near)
        cover = matched / n
        if cover < min_cover:
            continue
        start = min(b.b for b in near)
        end = max(b.b + b.size - 1 for b in near)
        window = cores[start:end + 1]
        missing = [t for t in tokens if t not in window]
        extra = [t for t in window if t not in tokens]
        results.append((cover, ed, entry["hadithnumber"], entry.get("arabicnumber"), start, end, missing, extra))
    results.sort(key=lambda r: (-r[0], len(r[7])))
    return results[:top]


def span_text(corpus, ed, number, arabicnumber, start, end):
    """النص المشكول للمقطع [start, end] بكلمات الإصدار الأصلية (بالمواضع نفسها المحسوبة على الجواهر)."""
    entry = corpus.entry(ed, number, arabicnumber)
    toks = [t for t in ac.tokens(entry["text"]) if ac.core(t)]
    return ac.strip_edges(ac.clean_noise(" ".join(toks[start:end + 1])))


def grades(corpus, ed, number, arabicnumber):
    try:
        return dict(corpus.grades(ed, number, arabicnumber))
    except ac.CutError:
        return {}
