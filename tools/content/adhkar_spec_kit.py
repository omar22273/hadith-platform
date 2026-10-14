"""أدوات كتابة مواصفات الأذكار: مواصفة تحدد الحديث وحدود القصّ، لا نصاً.

E(...)  شاهد: الإصدار (b/m/t/d/i/n) ورقم الحديث العربي، ثم الكلمة المفتاحية الأولى والأخيرة (بلا تشكيل).
T(...)  مقطع داخل شاهد: رقم الشاهد في القائمة ثم الكلمتان المفتاحيتان.
item(...) ذكر واحد: المعرّف والعنوان والعدد وشواهده ونصه وفضله.
"""


def E(ed, ref, first, last=None, occ=0, lo=0, verdict=None):
    """شاهد من الإصدار [ed] برقم [ref]؛ يُقتطع من أول [first] إلى [last] (شاملتين)."""
    return {"ed": ed, "ref": str(ref), "first": first, "last": last, "occ": occ, "lo": lo, "verdict": verdict}


def T(ev, first, last=None, occ=0, lo=0, waw=False):
    """مقطع من نص الشاهد رقم [ev] في قائمة شواهد الذكر."""
    return {"ev": ev, "first": first, "last": last, "occ": occ, "lo": lo, "waw": waw}


def item(item_id, title, evs, text, count=1, proof=None, virtue=None, notes=()):
    """ذكر: [count] عدده المسنون، و[proof] عبارة العدد كما في الشاهد (واجبة إن زاد العدد على واحد)."""
    return {
        "id": item_id,
        "title": title,
        "ev": list(evs),
        "text": text,
        "count": count,
        "proof": proof,
        "virtue": virtue,
        "notes": list(notes),
    }
