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
    "SeerahStationModel": """
  /// شواهد مشهد واحد بترتيبها في الملف.
  List<SeerahEvidence> evidenceFor(SeerahScene scene) {
    return List<SeerahEvidence>.unmodifiable(
      evidence.where((SeerahEvidence item) => item.scene == scene),
    );
  }
""",
}
