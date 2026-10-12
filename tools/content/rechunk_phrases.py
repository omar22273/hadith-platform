"""Re-cut the memorization chunks of hadiths 1-10 into whole phrases.

Usage: python3 tools/content/rechunk_phrases.py [<repo root>]

The matn text is never touched. Each phrase is a token range (inclusive) inside
one segment of the hadith file; the labels are editorial sub-headings. The app
orders whole phrases (a tile is a phrase), grouped four at a time at most, so
the phrases are cut at natural stops of the sentence: a complete clause, an
enumerated item, a conditional and its answer.

The script rewrites only `practice.chunks` and `practice.reconstruction.chunkIds`
and checks that the ranges lie inside their segments, do not overlap and are in
reading order. It is deterministic and idempotent.
"""

import json
import os
import sys

# hadith number -> [(segment id, first token, last token, label), ...]
PHRASES = {
    1: [
        ('s2', 0, 2, 'ميزان الأعمال'),
        ('s2', 3, 7, 'حظ كل عامل'),
        ('s2', 8, 13, 'هجرة إلى الله ورسوله'),
        ('s2', 14, 17, 'جزاء هذه الهجرة'),
        ('s2', 18, 25, 'هجرة لدنيا أو امرأة'),
        ('s2', 26, 30, 'جزاء هذه الهجرة'),
    ],
    2: [
        ('s4', 0, 11, 'الإسلام: الشهادتان'),
        ('s4', 12, 13, 'إقامة الصلاة'),
        ('s4', 14, 15, 'إيتاء الزكاة'),
        ('s4', 16, 17, 'صوم رمضان'),
        ('s4', 18, 23, 'حج البيت'),
        ('s10', 0, 7, 'الإيمان: أركانه الخمسة'),
        ('s10', 8, 11, 'الإيمان بالقدر'),
        ('s16', 0, 4, 'الإحسان: المشاهدة'),
        ('s16', 5, 10, 'الإحسان: المراقبة'),
        ('s20', 0, 5, 'علم الساعة'),
        ('s24', 0, 3, 'الأمارة الأولى'),
        ('s24', 4, 13, 'الأمارة الثانية'),
        ('s26', 0, 4, 'سؤال النبي لعمر'),
        ('s28', 0, 4, 'ختام المجلس'),
    ],
    3: [
        ('s2', 0, 3, 'بناء الإسلام'),
        ('s2', 4, 13, 'الشهادتان'),
        ('s2', 14, 15, 'إقام الصلاة'),
        ('s2', 16, 17, 'إيتاء الزكاة'),
        ('s2', 18, 19, 'حج البيت'),
        ('s2', 20, 21, 'صوم رمضان'),
    ],
    4: [
        ('s2', 0, 9, 'الأربعون الأولى: النطفة'),
        ('s2', 10, 14, 'العلقة'),
        ('s2', 15, 19, 'المضغة'),
        ('s2', 20, 26, 'إرسال الملك ونفخ الروح'),
        ('s2', 27, 36, 'الكلمات الأربع'),
        ('s2', 37, 41, 'القسم بالله'),
        ('s2', 42, 54, 'عمل أهل الجنة حتى ذراع'),
        ('s2', 55, 62, 'سبق الكتاب فدخول النار'),
        ('s2', 63, 75, 'عمل أهل النار حتى ذراع'),
        ('s2', 76, 83, 'سبق الكتاب فدخول الجنة'),
    ],
    5: [
        ('s2', 0, 7, 'إحداث ما ليس من الدين'),
        ('s2', 8, 9, 'الحكم: فهو رد'),
        ('s4', 0, 5, 'رواية مسلم: عمل مخالف'),
        ('s4', 6, 7, 'الحكم: فهو رد'),
    ],
    6: [
        ('s2', 0, 2, 'الحلال بيّن'),
        ('s2', 3, 5, 'الحرام بيّن'),
        ('s2', 6, 13, 'المشتبهات بينهما'),
        ('s2', 14, 20, 'من اتقى الشبهات'),
        ('s2', 21, 27, 'من وقع في الشبهات'),
        ('s2', 28, 35, 'مثل الراعي والحمى'),
        ('s2', 36, 40, 'حمى الملوك'),
        ('s2', 41, 45, 'حمى الله محارمه'),
        ('s2', 46, 50, 'مضغة في الجسد'),
        ('s2', 51, 55, 'صلاحها صلاح الجسد'),
        ('s2', 56, 60, 'فسادها فساد الجسد'),
        ('s2', 61, 63, 'هي القلب'),
    ],
    7: [
        ('s2', 0, 1, 'جوهر الدين'),
        ('s3', 0, 1, 'سؤال الصحابة'),
        ('s5', 0, 2, 'لله ولكتابه ولرسوله'),
        ('s5', 3, 5, 'للأئمة والعامة'),
    ],
    8: [
        ('s2', 0, 3, 'الأمر بقتال الناس'),
        ('s2', 4, 14, 'الغاية: الشهادتان'),
        ('s2', 15, 16, 'إقامة الصلاة'),
        ('s2', 17, 18, 'إيتاء الزكاة'),
        ('s2', 19, 25, 'عصمة الدم والمال'),
        ('s2', 26, 28, 'إلا بحق الإسلام'),
        ('s2', 29, 32, 'الحساب على الله'),
    ],
    9: [
        ('s2', 0, 3, 'النهي: الاجتناب'),
        ('s2', 4, 10, 'الأمر: بقدر الاستطاعة'),
        ('s2', 11, 15, 'سبب هلاك الأمم'),
        ('s2', 16, 20, 'كثرة المسائل والاختلاف'),
    ],
    10: [
        ('s2', 0, 6, 'الله طيب لا يقبل إلا طيباً'),
        ('s2', 7, 14, 'أمر المؤمنين كالمرسلين'),
        ('s2', 15, 24, 'آية الرسل'),
        ('s2', 25, 35, 'آية المؤمنين'),
        ('s3', 0, 6, 'الرجل المسافر الأشعث'),
        ('s3', 7, 10, 'يمد يديه إلى السماء'),
        ('s4', 0, 3, 'يا رب يا رب'),
        ('s4', 4, 9, 'حرام المطعم والمشرب والملبس'),
        ('s4', 10, 11, 'غذي بالحرام'),
        ('s4', 12, 14, 'فأنى يستجاب له'),
    ],
}


def rechunk(root: str) -> None:
    for number, phrases in PHRASES.items():
        path = os.path.join(root, 'assets', 'data', 'hadith', 'nawawi40', 'nawawi40_%03d.json' % number)
        with open(path, encoding='utf-8') as handle:
            data = json.load(handle)
        sizes = {segment['id']: len(segment['text'].split()) for segment in data['matn']['segments']}
        order = [segment['id'] for segment in data['matn']['segments']]
        last = (-1, -1)
        chunks = []
        for index, (segment_id, first, final, label) in enumerate(phrases, start=1):
            if segment_id not in sizes:
                raise SystemExit('H%d: unknown segment %s' % (number, segment_id))
            if not 0 <= first <= final < sizes[segment_id]:
                raise SystemExit('H%d %s: bad range %d-%d (segment has %d tokens)' % (number, segment_id, first, final, sizes[segment_id]))
            position = (order.index(segment_id), first)
            if position <= last:
                raise SystemExit('H%d %s %d-%d: phrases overlap or are out of reading order' % (number, segment_id, first, final))
            last = (order.index(segment_id), final)
            chunks.append({'id': 'c%d' % index, 'segmentId': segment_id, 'startToken': first, 'endToken': final, 'label': label})
        data['practice']['chunks'] = chunks
        data['practice']['reconstruction']['chunkIds'] = [chunk['id'] for chunk in chunks]
        with open(path, 'w', encoding='utf-8') as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
        print('H%d: %d phrases' % (number, len(chunks)))


if __name__ == '__main__':
    rechunk(sys.argv[1] if len(sys.argv) > 1 else '.')
