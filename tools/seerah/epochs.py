"""الأطوار التاريخية الكبرى لمنهج السيرة (عشرة أطوار) بعناوينها المعتمدة.

مصدر وحيد تقرأ منه أداتا الترقية والاستيعاب، ويُكتب منه حقل epochs في ملف
assets/data/seerah_dataset.json؛ والتطبيق يقرأ الأطوار من الملف لا من هنا.
"""

EPOCHS = [
    ("epoch_01_omens", 1, "إرهاصات النبوة وعام الفيل"),
    ("epoch_02_youth", 2, "النشأة والشباب قبل البعثة"),
    ("epoch_03_secret_call", 3, "البعثة والدعوة السرية"),
    ("epoch_04_public_call", 4, "الجهر بالدعوة والصبر على الأذى"),
    ("epoch_05_abyssinia_sorrow", 5, "الهجرة إلى الحبشة وعام الحزن"),
    ("epoch_06_aqaba_hijra", 6, "بيعة العقبة والهجرة إلى المدينة"),
    ("epoch_07_state_badr_uhud", 7, "تأسيس الدولة وبدر وأحد"),
    ("epoch_08_khandaq_hudaybiyyah", 8, "الخندق والحديبية وخيبر"),
    ("epoch_09_conquest_tabuk", 9, "فتح مكة وحنين وتبوك"),
    ("epoch_10_farewell_companion", 10, "حجة الوداع والرفيق الأعلى"),
]

EPOCH_IDS = [epoch_id for epoch_id, _, _ in EPOCHS]
NUMBER_OF = {epoch_id: number for epoch_id, number, _ in EPOCHS}


def as_json():
    """الأطوار بصيغة حقل epochs في ملف البيانات."""
    return [{"id": epoch_id, "number": number, "title": title} for epoch_id, number, title in EPOCHS]


def covenant_of(epoch_id: str, after_hijra: bool) -> str:
    """العهد الافتراضي لمحطة بحسب طورها وموضعها من الهجرة: الطوران الأولان قبل البعثة، والمدني بعد الهجرة."""
    if NUMBER_OF[epoch_id] <= 2:
        return "pre_mission"
    return "medinan" if after_hijra or NUMBER_OF[epoch_id] >= 7 else "meccan"
