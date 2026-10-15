"""إصلاحات مسمّاة لملف «حصن المسلم» المرفق، على غرار tuhfa_fixes.py.

كل إصلاح: اسم، والنص الخاطئ كما هو في الملف (يجب أن يرد مرة واحدة بالضبط في ذكره)،
وبديله، وسبب الإصلاح. يرفض القارئ (hisn_book.load) أي إصلاح لا يُطبَّق مرة واحدة،
فلا يبقى إصلاح يتيم ولا يمرّ تعديل خارج هذه القائمة.
"""


class Fix:
    def __init__(self, name, find, replace, why):
        self.name = name
        self.find = find
        self.replace = replace
        self.why = why


FIXES = {}
