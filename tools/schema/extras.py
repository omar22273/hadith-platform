"""Hand-written convenience members injected into generated Dart classes."""

EXTRA_IMPORTS = {
    "matn.dart": ("matn_tokenizer.dart",),
}

EXTRAS = {
    "Matn": """
  /// يعيد المقطع بمعرّفه، أو null إن لم يوجد.
  MatnSegment? segmentById(String segmentId) {
    for (final MatnSegment segment in segments) {
      if (segment.id == segmentId) {
        return segment;
      }
    }
    return null;
  }

  /// مقاطع كلام النبي ﷺ فقط، وهي مادة الحفظ والتلاوة.
  List<MatnSegment> get propheticSegments {
    return List<MatnSegment>.unmodifiable(
      segments.where(
        (MatnSegment segment) => segment.voice == SegmentVoice.prophet,
      ),
    );
  }

  /// المتن كاملاً متصلاً للعرض والبحث.
  String get fullText {
    return segments.map((MatnSegment segment) => segment.text).join(' ');
  }
""",
    "MatnSegment": """
  /// كلمات المقطع وفق عقد التقسيم المشترك مع خط معالجة البيانات.
  List<MatnToken> get tokens => MatnTokenizer.tokenize(text);
""",
    "PracticeConfig": """
  /// يعيد مقطع الحفظ بمعرّفه، أو null إن لم يوجد.
  PracticeChunk? chunkById(String chunkId) {
    for (final PracticeChunk chunk in chunks) {
      if (chunk.id == chunkId) {
        return chunk;
      }
    }
    return null;
  }
""",
    "PracticeChunk": """
  /// عدد كلمات المقطع.
  int get tokenCount => endToken - startToken + 1;
""",
    "Scenario": """
  /// الخيار الموافق لمقصد الحديث.
  ScenarioOption? get alignedOption {
    for (final ScenarioOption option in options) {
      if (option.alignment == OptionAlignment.aligned) {
        return option;
      }
    }
    return null;
  }
""",
    "ScholarLayer": """
  /// يعيد الإسناد بمعرّفه، أو null إن لم يوجد.
  SanadChain? chainById(String chainId) {
    for (final SanadChain chain in chains) {
      if (chain.id == chainId) {
        return chain;
      }
    }
    return null;
  }
""",
    "NarratorCatalog": """
  /// يعيد ترجمة الراوي بمعرّفه، أو null إن لم توجد.
  NarratorProfile? byId(String narratorId) {
    for (final NarratorProfile narrator in narrators) {
      if (narrator.id == narratorId) {
        return narrator;
      }
    }
    return null;
  }
""",
    "SourceCatalog": """
  /// يعيد المصدر بمعرّفه، أو null إن لم يوجد.
  SourceWork? byId(String sourceId) {
    for (final SourceWork source in sources) {
      if (source.id == sourceId) {
        return source;
      }
    }
    return null;
  }
""",
    "CurriculumManifest": """
  /// الحديث التالي في المنهج، ومنه تُقرأ بطاقة تشويق الغد.
  CurriculumItem? itemAfter(String hadithId) {
    for (int index = 0; index < items.length - 1; index++) {
      if (items[index].hadithId == hadithId) {
        return items[index + 1];
      }
    }
    return null;
  }

  /// القسم الذي يضم الحديث برقمه، أو null إن لم تُعرَّف أقسام أو لم يقع الرقم في أحدها.
  CurriculumSection? sectionOf(int number) {
    for (final CurriculumSection section in sections ?? const <CurriculumSection>[]) {
      if (number >= section.firstNumber && number <= section.lastNumber) {
        return section;
      }
    }
    return null;
  }
""",
    "SeerahDataset": """
  /// يعيد المحطة بمعرّفها، أو null إن لم توجد.
  SeerahStationModel? stationById(String stationId) {
    for (final SeerahStationModel station in stations) {
      if (station.id == stationId) {
        return station;
      }
    }
    return null;
  }

  /// المحطات مرتبة زمنياً بحقل order.
  List<SeerahStationModel> get chronological {
    final List<SeerahStationModel> result = List<SeerahStationModel>.of(stations)
      ..sort(
        (SeerahStationModel a, SeerahStationModel b) => a.order.compareTo(b.order),
      );
    return List<SeerahStationModel>.unmodifiable(result);
  }
""",
    "DhikrItem": """
  /// هل الذكر نص قرآني أدخله المالك؛ يُعرض بين ﴿ ﴾ وتُحوَّل فواصل الآيات فيه.
  bool get isQuran => evidence.any((SourceRef reference) => reference.sourceId == 'quran_owner_text');

  /// النص كما يُعرض: الآية بين ﴿ ﴾ وفواصل الآيات (*) علامات ۝، وغير الآيات كما هي دون تغيير.
  String get displayText => isQuran ? '﴿${text.replaceAll(' * ', ' ۝ ')}﴾' : text;

  /// هل يظهر الذكر في المسار [trackId]؛ الذكر بلا مسارات يظهر في كل مسار.
  bool inTrack(String trackId) {
    final List<String>? own = tracks;
    return own == null || own.contains(trackId);
  }
""",
    "SunanCatalog": """
  /// السنن مرتبة بحقل order كما تُعرض في الشاشة.
  List<SunnahItem> get itemsInOrder {
    final List<SunnahItem> result = List<SunnahItem>.of(items)
      ..sort((SunnahItem a, SunnahItem b) => a.order.compareTo(b.order));
    return List<SunnahItem>.unmodifiable(result);
  }

  /// سنن باب واحد بترتيب العرض.
  List<SunnahItem> inBab(SunnahBab bab) {
    return List<SunnahItem>.unmodifiable(itemsInOrder.where((SunnahItem item) => item.bab == bab));
  }
""",
    "AdhkarCatalog": """
  /// الأذكار مرتبة بحقل order كما تُعرض في الوِرد.
  List<DhikrItem> get itemsInOrder {
    final List<DhikrItem> result = List<DhikrItem>.of(items)
      ..sort((DhikrItem a, DhikrItem b) => a.order.compareTo(b.order));
    return List<DhikrItem>.unmodifiable(result);
  }
""",
    "SeerahStationModel": """
  /// شواهد مشهد واحد بترتيبها في الملف.
  List<SeerahEvidence> evidenceFor(SeerahScene scene) {
    return List<SeerahEvidence>.unmodifiable(
      evidence.where((SeerahEvidence item) => item.scene == scene),
    );
  }

  /// فقرات الرواية المفصلة (تفصل بينها سطور فارغة)؛ فارغة إن غابت الرواية
  /// أو كانت بياضاً، فيعود العرض إلى نصوص المشاهد الموثقة.
  List<String> get narrativeParagraphs {
    final String? text = detailedNarrative;
    if (text == null) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      text
          .split(RegExp(r'\\n\\s*\\n'))
          .map((String paragraph) => paragraph.trim())
          .where((String paragraph) => paragraph.isNotEmpty),
    );
  }

  /// هل للمحطة رواية مفصلة جاهزة للعرض.
  bool get hasDetailedNarrative => narrativeParagraphs.isNotEmpty;
""",
}
