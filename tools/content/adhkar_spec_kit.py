"""أدوات كتابة مواصفات الأذكار: مواصفة تحدد الحديث وحدود القصّ، لا نصاً.

E(...)  شاهد: الإصدار (b/m/t/d/i/n للكتب الستة، وq/o/h للمصادر الإضافية) ورقم الحديث، ثم الكلمة المفتاحية
        الأولى والأخيرة (بلا تشكيل). وللمصادر الإضافية يجوز ترك الكلمات فيؤخذ النص كاملاً.
T(...)  مقطع داخل شاهد: رقم الشاهد في القائمة ثم الكلمتان المفتاحيتان.
W(ev)   النص كاملاً من الشاهد رقم [ev] (للآيات وعبارات المالك).
D(...)  اشتقاق بإبدال كلمة واحدة بكلمة منقولة بتشكيلها من شاهد آخر للذكر (انظر build_adhkar_matrix.apply_derivation).
item(...) ذكر واحد: المعرّف والعنوان والعدد وشواهده ونصه وفضله ومساراته.
          وإن أُعطي [bab] فهو سنة مهجورة (ملف السنن): بطاقة بلا عدد ولا مسار، تُصفّى بباب في الشريط العلوي.
"""

# أبواب السنن المهجورة كما في SunnahBab (المخطط) وبالترتيب الذي يُعرض به الشريط.
PURITY_PRAYER = "purity_prayer"
FOOD_DRINK = "food_drink"
HOME_GOING_OUT = "home_going_out"
SLEEP_CLOTHING = "sleep_clothing"
GATHERINGS_MANNERS = "gatherings_manners"
BABS = [PURITY_PRAYER, FOOD_DRINK, HOME_GOING_OUT, SLEEP_CLOTHING, GATHERINGS_MANNERS]

MORNING = ["morning"]
EVENING = ["evening"]
MORNING_EVENING = ["morning", "evening"]
SLEEP = ["sleep"]
WAKE = ["wake"]
HOME = ["home"]
MASJID = ["masjid"]


def E(ed, ref, first=None, last=None, occ=0, lo=0, verdict=None):
    """شاهد من الإصدار [ed] برقم [ref]؛ يُقتطع من أول [first] إلى [last] (شاملتين)."""
    return {"ed": ed, "ref": str(ref), "first": first, "last": last, "occ": occ, "lo": lo, "verdict": verdict}


def T(ev, first=None, last=None, occ=0, lo=0, waw=False, whole=False):
    """مقطع من نص الشاهد رقم [ev] في قائمة شواهد الذكر."""
    return {"ev": ev, "first": first, "last": last, "occ": occ, "lo": lo, "waw": waw, "whole": whole}


def W(ev=0):
    """نص الشاهد رقم [ev] كاملاً."""
    return T(ev, whole=True)


def D(base, donor, from_word, to_word, proof):
    """اشتقاق: نص الشاهد [base] مع إبدال [from_word] بـ[to_word] المأخوذة بتشكيلها من الشاهد [donor]."""
    return {"base": base, "donor": donor, "from": from_word, "to": to_word, "proof": proof}


def item(
    item_id,
    title,
    evs,
    text,
    count=1,
    proof=None,
    virtue=None,
    notes=(),
    tracks=None,
    weak_ok=False,
    derive=None,
    hisn=None,
    count_from=None,
    bab=None,
):
    """ذكر: [count] عدده المسنون، و[proof] عبارة العدد كما في الشاهد (واجبة إن زاد العدد على واحد
    إلا إذا كان [count_from]='hisn' فيُتحقق من العدد في حصن المسلم المقابل [hisn])."""
    return {
        "id": item_id,
        "title": title,
        "ev": list(evs),
        "text": text,
        "count": count,
        "proof": proof,
        "virtue": virtue,
        "notes": list(notes),
        "tracks": list(tracks) if tracks else None,
        "weak_ok": weak_ok,
        "derive": derive,
        "hisn": hisn,
        "count_from": count_from,
        "bab": bab,
    }
