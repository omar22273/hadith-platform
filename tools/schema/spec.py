"""Single source of truth for the data model.

Both the JSON Schema and the Dart immutable models are generated from this
spec so that they can never drift apart.
"""


class F:
    def __init__(self, name, type_, doc, **schema):
        self.name = name
        self.type = type_
        self.doc = doc
        self.schema = schema


class Model:
    def __init__(self, name, file, doc, fields, extra_dart="", extra_imports=()):
        self.name = name
        self.file = file
        self.doc = doc
        self.fields = fields
        self.extra_dart = extra_dart
        self.extra_imports = extra_imports


class Enum:
    def __init__(self, name, file, doc, values):
        self.name = name
        self.file = file
        self.doc = doc
        self.values = values  # list of (dartName, wire, docAr)


ID = dict(pattern=r"^[a-z0-9]+(_[a-z0-9]+)*$")
SEMVER = dict(pattern=r"^\d+\.\d+\.\d+$")

ENUMS = [
    Enum("JourneyAssignmentBasis", "hadith_daily_model.dart", "أساس ربط الحديث بمحطة القافلة.", [
        ("thematic", "thematic", "ربط موضوعي تعليمي، لا يدّعي أن الحديث قيل في ذلك المكان."),
        ("historical", "historical", "ربط تاريخي مُسنَد إلى مصدر."),
    ]),
    Enum("PlaceRelation", "historical_context.dart", "علاقة المكان بالحديث.", [
        ("eventLocation", "event_location", "مكان وقوع الحدث نفسه."),
        ("subjectLocation", "subject_location", "مكان يدور عليه موضوع الحديث."),
        ("transmissionLocation", "transmission_location", "مكان مرتبط برواية الحديث ونقله."),
    ]),
    Enum("SegmentVoice", "matn.dart", "صاحب الكلام في مقطع المتن.", [
        ("narration", "narration", "كلام الراوي وسياق الحكاية."),
        ("prophet", "prophet", "كلام النبي ﷺ."),
        ("interlocutor", "interlocutor", "كلام المحاور أو السائل."),
    ]),
    Enum("AudioStatus", "audio_sync.dart", "حالة التلاوة الصوتية للمتن.", [
        ("notRecorded", "not_recorded", "لم تُسجَّل بعد."),
        ("recorded", "recorded", "مسجلة دون مزامنة كلمات."),
        ("aligned", "aligned", "مسجلة ومتزامنة كلمةً كلمة."),
    ]),
    Enum("NumberingSystem", "takhrij.dart", "نظام ترقيم الأحاديث في المصدر.", [
        ("fuadAbdulBaqi", "fuad_abdul_baqi", "ترقيم محمد فؤاد عبد الباقي."),
        ("sunnahCom", "sunnah_com", "ترقيم موقع sunnah.com."),
        ("other", "other", "ترقيم آخر يوضَّح في digitalLocator."),
    ]),
    Enum("ShuffleStrategy", "practice.dart", "طريقة بعثرة كلمات الترصيع.", [
        ("perUserPerDay", "per_user_per_day", "بذرة ثابتة للمستخدم في اليوم الواحد."),
        ("fixed", "fixed", "ترتيب بعثرة ثابت للجميع."),
    ]),
    Enum("OptionAlignment", "reflection.dart", "درجة موافقة الخيار لمقصد الحديث (بلا توبيخ).", [
        ("aligned", "aligned", "موافق لمقصد الحديث."),
        ("partial", "partial", "فيه خير ويحتاج تكميلاً."),
        ("misaligned", "misaligned", "بعيد عن مقصد الحديث."),
    ]),
    Enum("VariantRelation", "scholar_layer.dart", "علاقة الرواية بالحديث الأصل.", [
        ("sameCompanion", "same_companion", "رواية عن الصحابي نفسه."),
        ("witnessOtherCompanion", "witness_other_companion", "شاهد من حديث صحابي آخر."),
    ]),
    Enum("LintRule", "provenance.dart", "قاعدة الضبط التي كشفت الحاجة إلى التعديل.", [
        ("missingFinalVowel", "missing_final_vowel", "آخر الكلمة بلا حركة."),
        ("sukunBeforeWasl", "sukun_before_wasl", "سكون قبل همزة وصل."),
        ("fathaOnWaslAlif", "fatha_on_wasl_alif", "فتحة على ألف وصل."),
        ("hamzaBelowWithoutKasra", "hamza_below_without_kasra", "همزة تحت الألف بلا كسرة."),
    ]),
    Enum("EditMethod", "provenance.dart", "مصدر التصحيح.", [
        ("alignedSource", "aligned_source", "منقول من الكلمة المقابلة في مصدر مشكول بعد مطابقة الرسم."),
        ("orthographicRule", "orthographic_rule", "قاعدة إملائية حتمية (كسرة الهمزة تحت الألف)."),
    ]),
    Enum("ReviewStatus", "provenance.dart", "حالة المراجعة العلمية.", [
        ("pendingScholarlyReview", "pending_scholarly_review", "بانتظار مراجعة متخصص."),
        ("approved", "approved", "معتمد للنشر."),
        ("changesRequested", "changes_requested", "طُلبت تعديلات."),
    ]),
    Enum("NarratorCategory", "narrator_profile.dart", "صفة العَلَم في الإسناد.", [
        ("prophet", "prophet", "النبي ﷺ."),
        ("companion", "companion", "صحابي."),
        ("narrator", "narrator", "راوٍ."),
        ("compiler", "compiler", "مصنِّف الكتاب."),
    ]),
    Enum("TabaqaQualifier", "narrator_profile.dart", "وصف موقع الراوي داخل طبقته.", [
        ("senior", "senior", "من كبارها."),
        ("junior", "junior", "من صغارها."),
        ("head", "head", "من رؤوسها."),
    ]),
    Enum("DeathYearDerivation", "narrator_profile.dart", "كيف استُخرجت سنة الوفاة من نص الترجمة.", [
        ("explicit", "explicit", "صرّح النص بالمئة أو هو صحابي قبل المئة."),
        ("taqribCenturyRule", "taqrib_century_rule", "قاعدة ابن حجر في مقدمة التقريب: المئة تُعرف من الطبقة."),
    ]),
    Enum("SourceKind", "source_catalog.dart", "نوع المصدر.", [
        ("hadithCollection", "hadith_collection", "كتاب حديث مسند."),
        ("sharh", "sharh", "شرح حديثي."),
        ("gharib", "gharib", "كتاب في غريب الحديث."),
        ("rijal", "rijal", "كتاب في تراجم الرواة."),
        ("history", "history", "كتاب في السيرة والتاريخ والطبقات."),
        ("geography", "geography", "كتاب في البلدان والمواضع."),
    ]),
    Enum("UnlockAnchor", "curriculum_manifest.dart", "متى يُفتح وِرد اليوم التالي.", [
        ("fajr", "fajr", "عند دخول وقت الفجر محلياً."),
    ]),
]

MODELS = [
    # ---------------------------------------------------------------- shared
    Model("SourceRef", "source_ref.dart", "إحالة موثقة إلى مصدر، مع نص الشاهد حرفياً للتحقق.", [
        F("sourceId", "String", "معرّف المصدر في فهرس المصادر.", **ID),
        F("locator", "String?", "موضع الشاهد: الجزء والصفحة أو رقم الحديث."),
        F("quote", "String?", "نص الشاهد كما هو في المصدر، يُستعمل في التدقيق الآلي."),
    ]),
    Model("TokenAnchor", "source_ref.dart", "مرساة تربط بيانات بكلمة أو أكثر من مقطع في المتن.", [
        F("segmentId", "String", "معرّف المقطع.", **ID),
        F("tokenIndex", "int", "رقم أول كلمة داخل المقطع (يبدأ من صفر).", minimum=0),
        F("length", "int", "عدد الكلمات المشمولة.", minimum=1),
        F("surface", "String", "الكلمات كما في المتن دون علامات الترقيم، للتحقق من سلامة المرساة."),
    ]),
    # ---------------------------------------------------------------- root
    Model("HadithDailyModel", "hadith_daily_model.dart",
          "الوِرد اليومي: حديث واحد بمراحله الأربع وطبقة طالب العلم وسجل التوثيق.", [
              F("schemaVersion", "String", "إصدار المخطط.", **SEMVER),
              F("id", "String", "معرّف الحديث، مثل nawawi40_001.", **ID),
              F("sequence", "int", "ترتيب الحديث في المنهج.", minimum=1),
              F("collection", "CollectionRef", "الكتاب الذي ينتمي إليه الحديث في المنهج."),
              F("title", "String", "عنوان وصفي قصير."),
              F("teaser", "Teaser", "لمحة التشويق التي تُعرض في ختام وِرد اليوم السابق."),
              F("journey", "JourneyPlacement", "موضع الحديث في مسار القوافل."),
              F("context", "HistoricalContext", "المرحلة الأولى: سياق الورود والحدث التاريخي."),
              F("matn", "Matn", "المرحلة الثانية: المتن والبيان اللغوي والتخريج."),
              F("practice", "PracticeConfig", "المرحلة الثالثة: التثبيت والحفظ التراكمي."),
              F("reflection", "Reflection", "المرحلة الرابعة: الإسقاط السلوكي."),
              F("scholar", "ScholarLayer", "طبقة طالب العلم: الإسناد ومقارنة الروايات."),
              F("provenance", "Provenance", "سجل مصدر المتن وكل تعديل طرأ عليه."),
              F("review", "ReviewInfo", "حالة المراجعة العلمية قبل النشر."),
          ]),
    Model("CollectionRef", "hadith_daily_model.dart", "الكتاب الذي يُدرَّس منه الحديث.", [
        F("id", "String", "معرّف الكتاب.", **ID),
        F("title", "String", "عنوان الكتاب."),
        F("numberInCollection", "int", "رقم الحديث في الكتاب.", minimum=1),
    ]),
    Model("Teaser", "hadith_daily_model.dart", "بطاقة التشويق للغد.", [
        F("text", "String", "نص اللمحة الغامضة."),
    ]),
    Model("JourneyPlacement", "hadith_daily_model.dart", "موضع الحديث على خريطة الرحلة.", [
        F("stationId", "String", "معرّف المحطة في فهرس الرحلة.", **ID),
        F("stepInStation", "int", "رقم الخطوة داخل المحطة.", minimum=1),
        F("milestone", "String", "عنوان الخطوة على الخريطة."),
        F("assignmentBasis", "E:JourneyAssignmentBasis", "أساس الربط بالمحطة."),
    ]),
    # ---------------------------------------------------------------- stage 1
    Model("HistoricalContext", "historical_context.dart", "بطاقة سياق الورود (70-80 كلمة).", [
        F("narrative", "String", "القصة المركزة بالزمان والمكان والدافع البشري."),
        F("humanMotive", "String", "الدافع البشري في سطر واحد."),
        F("place", "HistoricalPlace?", "المكان المرتبط على الخريطة التاريخية."),
        F("sources", "List<SourceRef>", "مصادر كل معلومة في القصة.", minItems=1),
        F("cautions", "List<ContextCaution>", "تنبيهات على أخبار مشهورة لم تثبت."),
    ]),
    Model("HistoricalPlace", "historical_context.dart", "مكان على الخريطة التاريخية.", [
        F("name", "String", "اسم المكان."),
        F("stationId", "String?", "محطة الرحلة المقابلة إن وجدت."),
        F("relation", "E:PlaceRelation", "علاقة المكان بالحديث."),
        F("latitude", "double", "خط العرض.", minimum=-90, maximum=90),
        F("longitude", "double", "خط الطول.", minimum=-180, maximum=180),
        F("coordinatesApproximate", "bool", "هل الإحداثيات تقريبية."),
    ]),
    Model("ContextCaution", "historical_context.dart", "تنبيه علمي يمنع نسبة ما لم يثبت.", [
        F("text", "String", "نص التنبيه."),
        F("sources", "List<SourceRef>", "مستند التنبيه.", minItems=1),
    ]),
    # ---------------------------------------------------------------- stage 2
    Model("Matn", "matn.dart", "المتن مقسماً إلى مقاطع بحسب المتكلم، مع الغريب والصوت والتخريج.", [
        F("segments", "List<MatnSegment>", "مقاطع المتن بالترتيب.", minItems=1),
        F("gharib", "List<GharibEntry>", "غريب الألفاظ اللمسي."),
        F("audio", "AudioSync", "التلاوة والتتبع الصوتي."),
        F("takhrij", "Takhrij", "التوثيق والتخريج."),
    ]),
    Model("MatnSegment", "matn.dart", "مقطع متصل من المتن لمتكلم واحد.", [
        F("id", "String", "معرّف المقطع داخل الحديث.", **ID),
        F("voice", "E:SegmentVoice", "صاحب الكلام."),
        F("text", "String", "النص المشكول كما هو بعد التطبيع الموثق."),
    ]),
    Model("GharibEntry", "matn.dart", "شرح لفظة غريبة من كتاب معتمد.", [
        F("id", "String", "معرّف الشرح.", **ID),
        F("anchor", "TokenAnchor", "موضع اللفظة في المتن."),
        F("headword", "String", "اللفظة أو أصلها."),
        F("meaning", "String", "البيان المختصر المعروض في البطاقة."),
        F("sources", "List<SourceRef>", "كتب الغريب والشروح المستند إليها.", minItems=1),
    ]),
    Model("AudioSync", "audio_sync.dart", "بيانات التلاوة والتتبع الصوتي التزامني.", [
        F("status", "E:AudioStatus", "حالة التسجيل."),
        F("assetPath", "String?", "مسار الملف الصوتي في الأصول."),
        F("reciter", "String?", "اسم القارئ."),
        F("durationMs", "int?", "مدة التلاوة بالمللي ثانية.", minimum=0),
        F("timings", "List<WordTiming>", "توقيت كل كلمة؛ فارغة حتى تتم المزامنة."),
    ]),
    Model("WordTiming", "audio_sync.dart", "توقيت كلمة واحدة في التلاوة.", [
        F("segmentId", "String", "معرّف المقطع.", **ID),
        F("tokenIndex", "int", "رقم الكلمة داخل المقطع.", minimum=0),
        F("startMs", "int", "بداية الكلمة.", minimum=0),
        F("endMs", "int", "نهاية الكلمة.", minimum=0),
    ]),
    Model("Takhrij", "takhrij.dart", "التوثيق الهادئ في زاوية الشاشة والتخريج الإجمالي.", [
        F("displayLabel", "String", "النص المختصر في الزاوية العلوية."),
        F("references", "List<TakhrijReference>", "مواضع الحديث في الكتب.", minItems=1),
        F("compilerStatement", "CompilerStatement?", "عبارة المصنف في التخريج كما وردت."),
        F("gradings", "List<Grading>", "أحكام منقولة عن الأئمة فقط، ولا يُولَّد فيها حكم."),
    ]),
    Model("TakhrijReference", "takhrij.dart", "موضع الحديث في كتاب مسند.", [
        F("sourceId", "String", "معرّف الكتاب.", **ID),
        F("hadithNumber", "String", "رقم الحديث."),
        F("numberingSystem", "E:NumberingSystem", "نظام الترقيم."),
        F("digitalLocator", "String?", "موضعه في المصدر الرقمي المستخرج منه."),
    ]),
    Model("CompilerStatement", "takhrij.dart", "عبارة المصنف في عزو الحديث.", [
        F("text", "String", "النص كما في المصدر."),
        F("sourceId", "String", "معرّف كتاب المصنف.", **ID),
    ]),
    Model("Grading", "takhrij.dart", "حكم على الحديث منقول بنصه عن إمام.", [
        F("grade", "String", "نص الحكم."),
        F("gradedBy", "String", "صاحب الحكم."),
        F("source", "SourceRef", "موضع الحكم."),
    ]),
    # ---------------------------------------------------------------- stage 3
    Model("PracticeConfig", "practice.dart", "إعدادات الترصيع والتلاشي التدريجي.", [
        F("chunks", "List<PracticeChunk>", "مقاطع الحفظ التراكمي.", minItems=1),
        F("reconstruction", "ReconstructionConfig", "ترصيع المتن."),
        F("vanishing", "VanishingConfig", "التلاشي التدريجي."),
    ]),
    Model("PracticeChunk", "practice.dart", "مقطع حفظ: مدى من كلمات مقطع واحد.", [
        F("id", "String", "معرّف المقطع التدريبي.", **ID),
        F("segmentId", "String", "مقطع المتن.", **ID),
        F("startToken", "int", "أول كلمة.", minimum=0),
        F("endToken", "int", "آخر كلمة (شاملة).", minimum=0),
        F("label", "String", "عنوان المقطع في واجهة التدريب."),
    ]),
    Model("ReconstructionConfig", "practice.dart", "تمرين ترصيع المتن.", [
        F("chunkIds", "List<String>", "المقاطع التي تُبعثر كلماتها بالترتيب.", minItems=1),
        F("shuffleStrategy", "E:ShuffleStrategy", "طريقة البعثرة."),
    ]),
    Model("VanishingConfig", "practice.dart", "تمرين التلاشي التدريجي.", [
        F("levels", "List<VanishingLevel>", "المستويات بنسب إخفاء متصاعدة.", minItems=1),
        F("priorityAnchors", "List<TokenAnchor>", "كلمات مفتاحية تُخفى أولاً."),
    ]),
    Model("VanishingLevel", "practice.dart", "مستوى إخفاء.", [
        F("level", "int", "رقم المستوى.", minimum=1),
        F("hidePercent", "int", "نسبة الكلمات المخفية.", minimum=1, maximum=100),
    ]),
    # ---------------------------------------------------------------- stage 4
    Model("Reflection", "reflection.dart", "الإسقاط السلوكي.", [
        F("scenario", "Scenario", "مأزق الموقف الواقعي."),
        F("impacts", "List<BehavioralImpact>", "الأثر السلوكي في المسار الميسر.", minItems=1),
    ]),
    Model("Scenario", "reflection.dart", "موقف معاصر بخيارات تقيس فهم المقصد.", [
        F("situation", "String", "وصف الموقف."),
        F("question", "String", "السؤال."),
        F("options", "List<ScenarioOption>", "الخيارات.", minItems=2),
        F("takeaway", "String", "الخلاصة بعد الإجابة."),
        F("basis", "List<SourceRef>", "الشروح التي بُني عليها الموقف.", minItems=1),
    ]),
    Model("ScenarioOption", "reflection.dart", "خيار مع تغذية راجعة لطيفة.", [
        F("id", "String", "معرّف الخيار.", **ID),
        F("text", "String", "نص الخيار."),
        F("alignment", "E:OptionAlignment", "درجة الموافقة."),
        F("feedback", "String", "تغذية راجعة بلا توبيخ."),
    ]),
    Model("BehavioralImpact", "reflection.dart", "أثر سلوكي مستند إلى شرح معتمد.", [
        F("text", "String", "نص الأثر."),
        F("sources", "List<SourceRef>", "المستند.", minItems=1),
    ]),
    # ---------------------------------------------------------------- scholar layer
    Model("ScholarLayer", "scholar_layer.dart", "طبقة طالب العلم.", [
        F("chains", "List<SanadChain>", "أسانيد تُدمج في شجرة الإسناد التفاعلية.", minItems=1),
        F("variants", "List<NarrationVariant>", "مصفوفة مقارنة الروايات."),
    ]),
    Model("SanadChain", "scholar_layer.dart", "إسناد واحد كما ورد في كتاب، مرتب من النبي ﷺ إلى المصنف.", [
        F("id", "String", "معرّف الإسناد.", **ID),
        F("source", "ChainSource", "موضع الإسناد."),
        F("isWordingChain", "bool", "هل اللفظ المسوق لهذا الإسناد."),
        F("remark", "String?", "ملاحظة من نص المصدر."),
        F("links", "List<SanadLink>", "حلقات الإسناد من النبي ﷺ إلى المصنف.", minItems=2),
    ]),
    Model("ChainSource", "scholar_layer.dart", "موضع الإسناد.", [
        F("sourceId", "String", "معرّف الكتاب.", **ID),
        F("hadithNumber", "String", "رقم الحديث."),
    ]),
    Model("SanadLink", "scholar_layer.dart", "حلقة في الإسناد.", [
        F("narratorId", "String", "معرّف الراوي في فهرس الرواة.", **ID),
        F("nameAsWritten", "String?", "الاسم كما ورد في الإسناد مشكولاً."),
        F("term", "String?", "صيغة الأداء التي تحمّل بها عمّن قبله."),
        F("remark", "String?", "ملاحظة على هذه الحلقة."),
        F("identificationBasis", "String?", "مستند تعيين الراوي إذا أُبهم اسمه في الإسناد."),
    ]),
    Model("NarrationVariant", "scholar_layer.dart", "رواية تُقارن بالمتن المعروض.", [
        F("id", "String", "معرّف الرواية.", **ID),
        F("sourceId", "String", "الكتاب.", **ID),
        F("hadithNumber", "String", "رقم الحديث."),
        F("relation", "E:VariantRelation", "علاقتها بالحديث."),
        F("companionNarratorId", "String", "الصحابي راوي الحديث.", **ID),
        F("chainIds", "List<String>", "الأسانيد المرتبطة بها في الشجرة."),
        F("fullText", "String", "النص الكامل كما في المصدر."),
        F("matnText", "String", "موضع المتن من النص الكامل، للمقارنة المرئية."),
        F("notes", "List<String>", "فروق موثقة بالنص."),
    ]),
    # ---------------------------------------------------------------- provenance & review
    Model("Provenance", "provenance.dart", "سجل مصدر المتن وكل تطبيع أو ضبط.", [
        F("matnSource", "SourceRef", "مصدر المتن."),
        F("normalizations", "List<String>", "عمليات تطبيع لا تمس الحروف ولا الحركات."),
        F("vocalizationEdits", "List<VocalizationEdit>", "كل تعديل في الضبط بمستنده."),
    ]),
    Model("VocalizationEdit", "provenance.dart", "تعديل ضبط كلمة واحدة.", [
        F("segmentId", "String", "المقطع.", **ID),
        F("tokenIndex", "int", "رقم الكلمة.", minimum=0),
        F("before", "String", "الكلمة في المصدر الرقمي."),
        F("after", "String", "الكلمة بعد التعديل."),
        F("rule", "E:LintRule", "القاعدة التي كشفت الخلل."),
        F("method", "E:EditMethod", "طريقة التصحيح."),
        F("source", "SourceRef?", "المصدر المشكول المنقول منه."),
    ]),
    Model("ReviewInfo", "provenance.dart", "المراجعة العلمية.", [
        F("status", "E:ReviewStatus", "الحالة."),
        F("reviewer", "String?", "المراجع."),
        F("reviewedAt", "String?", "تاريخ المراجعة YYYY-MM-DD.", pattern=r"^\d{4}-\d{2}-\d{2}$"),
        F("notes", "List<String>", "ملاحظات مفتوحة للمراجع."),
    ]),
    # ---------------------------------------------------------------- narrators catalog
    Model("NarratorCatalog", "narrator_profile.dart", "فهرس تراجم الرواة المشترك بين الأحاديث.", [
        F("schemaVersion", "String", "إصدار المخطط.", **SEMVER),
        F("narrators", "List<NarratorProfile>", "التراجم.", minItems=1),
    ]),
    Model("NarratorProfile", "narrator_profile.dart", "بطاقة الراوي بلمسة واحدة.", [
        F("id", "String", "المعرّف.", **ID),
        F("displayName", "String", "الاسم المختصر للعرض."),
        F("category", "E:NarratorCategory", "صفته."),
        F("tabaqa", "Tabaqa?", "الطبقة كما في التقريب."),
        F("gradeText", "String?", "عبارة الجرح والتعديل بنصها من التقريب."),
        F("death", "DeathRecord?", "الوفاة."),
        F("sigla", "String?", "رموز من أخرج له كما في التقريب."),
        F("entry", "RijalEntry?", "نص الترجمة كاملاً بمصدره."),
    ]),
    Model("Tabaqa", "narrator_profile.dart", "طبقة الراوي.", [
        F("number", "int", "رقم الطبقة عند ابن حجر.", minimum=1, maximum=12),
        F("qualifier", "E:TabaqaQualifier?", "كبار أو صغار أو رؤوس."),
        F("text", "String", "العبارة كما في التقريب."),
    ]),
    Model("DeathRecord", "narrator_profile.dart", "وفاة الراوي.", [
        F("text", "String", "عبارة الوفاة كما في التقريب."),
        F("yearHijri", "int?", "السنة الهجرية الكاملة إن أمكن تعيينها.", minimum=1, maximum=1500),
        F("derivation", "E:DeathYearDerivation?", "طريقة تعيين السنة."),
    ]),
    Model("RijalEntry", "narrator_profile.dart", "نص الترجمة بمصدره.", [
        F("sourceId", "String", "كتاب التراجم.", **ID),
        F("locator", "String?", "الموضع."),
        F("text", "String", "نص الترجمة كاملاً."),
    ]),
    # ---------------------------------------------------------------- journey catalog
    Model("JourneyCatalog", "journey_catalog.dart", "فهرس مسار القوافل.", [
        F("schemaVersion", "String", "إصدار المخطط.", **SEMVER),
        F("regions", "List<JourneyRegion>", "المراحل الكبرى.", minItems=1),
        F("stations", "List<JourneyStation>", "المحطات.", minItems=1),
    ]),
    Model("JourneyRegion", "journey_catalog.dart", "مرحلة كبرى من الرحلة.", [
        F("id", "String", "المعرّف.", **ID),
        F("order", "int", "الترتيب.", minimum=1),
        F("name", "String", "الاسم."),
        F("theme", "String", "موضوع أحاديثها."),
    ]),
    Model("JourneyStation", "journey_catalog.dart", "محطة على الخريطة.", [
        F("id", "String", "المعرّف.", **ID),
        F("regionId", "String", "المرحلة.", **ID),
        F("order", "int", "الترتيب داخل الرحلة كلها.", minimum=1),
        F("name", "String", "الاسم."),
        F("description", "String", "وصف قصير."),
        F("latitude", "double", "خط العرض.", minimum=-90, maximum=90),
        F("longitude", "double", "خط الطول.", minimum=-180, maximum=180),
        F("coordinatesApproximate", "bool", "هل الإحداثيات تقريبية."),
        F("event", "StationEvent?", "الحدث التاريخي الموثق للمحطة."),
    ]),
    Model("StationEvent", "journey_catalog.dart", "حدث تاريخي موثق بنصوص مصادره.", [
        F("title", "String", "عنوان الحدث كما يُعرض على الخريطة، مستخلص من نصوص الشواهد."),
        F("sources", "List<SourceRef>", "شواهد الحدث منقولة بنصها مع مواضعها.", minItems=1),
    ]),
    # ---------------------------------------------------------------- wisdom bank
    Model("WisdomCatalog", "wisdom_catalog.dart", "بنك العبارات التراثية الموثقة لشاشة ختام الوِرد.", [
        F("schemaVersion", "String", "إصدار المخطط.", **SEMVER),
        F("entries", "List<WisdomEntry>", "العبارات.", minItems=1),
    ]),
    Model("WisdomEntry", "wisdom_catalog.dart", "عبارة تراثية منقولة بنصها عن قائلها.", [
        F("id", "String", "المعرّف.", **ID),
        F("text", "String", "نص العبارة كما في المصدر."),
        F("speaker", "String", "القائل كما سُمّي في المصدر."),
        F("source", "SourceRef", "موضع العبارة، والشاهد كاملاً بإسنادها إلى قائلها."),
    ]),
    # ---------------------------------------------------------------- sources catalog
    Model("SourceCatalog", "source_catalog.dart", "فهرس المصادر المعتمدة.", [
        F("schemaVersion", "String", "إصدار المخطط.", **SEMVER),
        F("sources", "List<SourceWork>", "المصادر.", minItems=1),
    ]),
    Model("SourceWork", "source_catalog.dart", "كتاب معتمد.", [
        F("id", "String", "المعرّف.", **ID),
        F("title", "String", "العنوان."),
        F("author", "String", "المؤلف."),
        F("authorDeathHijri", "int?", "وفاة المؤلف.", minimum=1, maximum=1500),
        F("kind", "E:SourceKind", "النوع."),
        F("edition", "SourceEdition?", "الطبعة الورقية المقابلة."),
        F("digital", "DigitalOrigin", "المصدر الرقمي الذي استُخرجت منه البيانات."),
    ]),
    Model("SourceEdition", "source_catalog.dart", "الطبعة الورقية.", [
        F("editor", "String?", "المحقق."),
        F("publisher", "String?", "الناشر."),
        F("printing", "String?", "رقم الطبعة وسنتها."),
    ]),
    Model("DigitalOrigin", "source_catalog.dart", "أصل البيانات الرقمي لإعادة الإنتاج.", [
        F("provider", "String", "الجهة."),
        F("repository", "String", "المستودع."),
        F("path", "String", "مسار الملف داخل المستودع."),
        F("commit", "String", "رقم الإيداع.", pattern=r"^[0-9a-f]{7,40}$"),
        F("retrievedAt", "String", "تاريخ الاستخراج.", pattern=r"^\d{4}-\d{2}-\d{2}$"),
    ]),
    # ---------------------------------------------------------------- curriculum
    Model("CurriculumManifest", "curriculum_manifest.dart", "ترتيب الأوراد وسياسة القفل اليومي.", [
        F("schemaVersion", "String", "إصدار المخطط.", **SEMVER),
        F("id", "String", "المعرّف.", **ID),
        F("title", "String", "العنوان."),
        F("dailyCap", "DailyCapPolicy", "قفل الوِرد اليومي."),
        F("items", "List<CurriculumItem>", "الأحاديث بالترتيب.", minItems=1),
    ]),
    Model("DailyCapPolicy", "curriculum_manifest.dart", "سياسة إغلاق الوِرد اليومي.", [
        F("newHadithPerDay", "int", "عدد الأحاديث الجديدة يومياً.", minimum=1),
        F("unlockAt", "E:UnlockAnchor", "وقت فتح الوِرد التالي."),
        F("fallbackLocalTime", "String", "وقت بديل HH:MM إن تعذر حساب الفجر.", pattern=r"^([01]\d|2[0-3]):[0-5]\d$"),
        F("completionMessage", "String", "رسالة الإتمام."),
    ]),
    Model("CurriculumItem", "curriculum_manifest.dart", "عنصر في المنهج.", [
        F("hadithId", "String", "معرّف الحديث.", **ID),
        F("assetPath", "String", "مسار ملف الحديث في الأصول."),
        F("stationId", "String", "محطة الحديث، فهرس سريع يطابق journey.stationId في ملف الحديث.", **ID),
        F("title", "String", "عنوان الحديث، فهرس سريع يطابق title في ملف الحديث."),
    ]),
]

FILE_DOCS = {
    "source_ref.dart": "الإحالات الموثقة ومراسي الكلمات.",
    "hadith_daily_model.dart": "النموذج الجذري للوِرد اليومي.",
    "historical_context.dart": "المرحلة الأولى: سياق الورود.",
    "matn.dart": "المرحلة الثانية: المتن والغريب.",
    "audio_sync.dart": "التتبع الصوتي التزامني.",
    "takhrij.dart": "التوثيق والتخريج.",
    "practice.dart": "المرحلة الثالثة: التثبيت والحفظ.",
    "reflection.dart": "المرحلة الرابعة: الإسقاط السلوكي.",
    "scholar_layer.dart": "طبقة طالب العلم: الإسناد والروايات.",
    "provenance.dart": "سجل التوثيق والمراجعة.",
    "narrator_profile.dart": "فهرس تراجم الرواة.",
    "journey_catalog.dart": "فهرس مسار القوافل.",
    "source_catalog.dart": "فهرس المصادر.",
    "curriculum_manifest.dart": "ترتيب الأوراد وسياسة القفل اليومي.",
    "wisdom_catalog.dart": "بنك العبارات التراثية.",
}
