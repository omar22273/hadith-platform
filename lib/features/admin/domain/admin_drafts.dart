// نماذج لوحة الإدخال: تحقق مدخلات الحديث ومشهد السيرة، وتحويلها إلى نماذج
// المخطط، وتوليد مصفوفة JSON معيارية مع التحقق منها ذهاباً وإياباً.
//
// الخط الأحمر: اللوحة لا تولّد نصاً؛ تحفظ ما يُدخله المحرر حرفاً بحرف (مع
// قص المسافات في الطرفين فقط)، وتُعلّم كل مسودة «بانتظار المراجعة العلمية».

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../hadith/data/models/models.dart';
import '../../hadith/domain/hadith_bundle.dart';
import '../../seerah/data/models/seerah_station.dart';
import '../data/models/hadith_draft.dart';

/// إصدار المخطط في المسودات المصدّرة.
const String draftSchemaVersion = '2.0.0';

final RegExp _arabicLetter = RegExp('[ء-ي]');
final RegExp _harakah = RegExp('[ً-ْ]');
final RegExp _idPattern = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

/// سطر غريب في النموذج.
@immutable
class GharibRow {
  const GharibRow({required this.word, required this.meaning});

  /// اللفظة.
  final String word;

  /// البيان.
  final String meaning;

  /// هل السطر فارغ كله.
  bool get isBlank => word.trim().isEmpty && meaning.trim().isEmpty;
}

/// مدخلات نموذج الحديث كما كتبها المحرر.
@immutable
class HadithDraftForm {
  const HadithDraftForm({
    required this.number,
    required this.matn,
    required this.topNarrator,
    required this.gharib,
    required this.benefits,
  });

  /// نموذج فارغ.
  static const HadithDraftForm blank = HadithDraftForm(
    number: '',
    matn: '',
    topNarrator: '',
    gharib: <GharibRow>[],
    benefits: '',
  );

  /// يملأ النموذج من حديث موجود للتعديل، بنصوصه كما في ملفه.
  factory HadithDraftForm.fromBundle(HadithBundle bundle) {
    final HadithDailyModel hadith = bundle.hadith;
    String narrator = '';
    for (final SanadChain chain in hadith.scholar.chains) {
      for (final SanadLink link in chain.links) {
        final NarratorProfile? profile = bundle.narrators.byId(link.narratorId);
        if (profile != null && profile.category == NarratorCategory.companion) {
          narrator = profile.displayName;
          break;
        }
      }
      if (narrator.isNotEmpty) {
        break;
      }
    }
    return HadithDraftForm(
      number: '${hadith.collection.numberInCollection}',
      matn: hadith.matn.segments.map((MatnSegment segment) => segment.text).join(' '),
      topNarrator: narrator,
      gharib: <GharibRow>[
        for (final GharibEntry entry in hadith.matn.gharib) GharibRow(word: entry.headword, meaning: entry.meaning),
      ],
      benefits: hadith.reflection.impacts.map((BehavioralImpact impact) => impact.text).join('\n'),
    );
  }

  /// رقم الحديث.
  final String number;

  /// المتن المشكول.
  final String matn;

  /// الراوي الأعلى.
  final String topNarrator;

  /// المفردات وغريب الألفاظ.
  final List<GharibRow> gharib;

  /// الفوائد السلوكية، فائدة في كل سطر.
  final String benefits;

  /// رقم الحديث بعد التحويل، أو null إن لم يكن عدداً موجباً.
  int? get parsedNumber {
    final int? value = int.tryParse(number.trim());
    return value != null && value >= 1 ? value : null;
  }

  /// الفوائد سطراً سطراً.
  List<String> get benefitLines {
    return benefits
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// أخطاء النموذج بالعربية؛ الفارغة تعني الصلاحية.
  List<String> validate() {
    final List<String> errors = <String>[];
    if (parsedNumber == null) {
      errors.add('رقم الحديث عدد صحيح موجب.');
    }
    final String text = matn.trim();
    if (text.isEmpty) {
      errors.add('المتن مطلوب.');
    } else if (!_arabicLetter.hasMatch(text)) {
      errors.add('المتن يُكتب بالعربية.');
    } else if (!_harakah.hasMatch(text)) {
      errors.add('المتن يُدخل مشكولاً كما في المصدر المحقق.');
    }
    if (topNarrator.trim().isEmpty) {
      errors.add('الراوي الأعلى مطلوب.');
    }
    for (int i = 0; i < gharib.length; i++) {
      final GharibRow row = gharib[i];
      if (row.isBlank) {
        continue;
      }
      if (row.word.trim().isEmpty || row.meaning.trim().isEmpty) {
        errors.add('سطر الغريب ${i + 1}: اللفظة وبيانها معاً.');
      }
    }
    return errors;
  }

  /// يحوّل النموذج الصالح إلى مسودة المخطط.
  HadithDraft toDraft() {
    final int value = parsedNumber ?? 1;
    return HadithDraft(
      schemaVersion: draftSchemaVersion,
      hadithId: 'nawawi40_${value.toString().padLeft(3, '0')}',
      number: value,
      matn: matn.trim(),
      topNarrator: topNarrator.trim(),
      gharib: <GharibDraft>[
        for (final GharibRow row in gharib)
          if (!row.isBlank) GharibDraft(word: row.word.trim(), meaning: row.meaning.trim()),
      ],
      behavioralBenefits: benefitLines,
      review: const ReviewInfo(
        status: ReviewStatus.pendingScholarlyReview,
        reviewer: null,
        reviewedAt: null,
        notes: <String>[
          'أُدخلت المسودة من لوحة الإدخال المحلية؛ يُقابَل المتن بطبعة محققة ويُوثَّق الغريب والفوائد من مصادرها قبل الدمج.',
        ],
      ),
    );
  }
}

/// موضع مقترح في نموذج مشهد السيرة، بإحداثيات تقريبية.
@immutable
class SeerahPlacePreset {
  const SeerahPlacePreset(this.name, this.latitude, this.longitude);

  /// الاسم.
  final String name;

  /// خط العرض.
  final double latitude;

  /// خط الطول.
  final double longitude;
}

/// المواضع المقترحة.
const List<SeerahPlacePreset> seerahPlacePresets = <SeerahPlacePreset>[
  SeerahPlacePreset('مكة', 21.4225, 39.8262),
  SeerahPlacePreset('غار حراء', 21.4576, 39.8592),
  SeerahPlacePreset('الطائف', 21.2703, 40.4158),
  SeerahPlacePreset('أرض الحبشة', 14.1211, 38.7238),
  SeerahPlacePreset('المدينة النبوية', 24.4672, 39.6111),
  SeerahPlacePreset('بدر', 23.7333, 38.7667),
  SeerahPlacePreset('جبل أُحُد', 24.5017, 39.6122),
  SeerahPlacePreset('الحديبية', 21.4411, 39.5797),
  SeerahPlacePreset('خيبر', 25.6990, 39.2920),
  SeerahPlacePreset('تبوك', 28.3835, 36.5662),
];

/// مدخلات نموذج مشهد السيرة.
@immutable
class SeerahDraftForm {
  const SeerahDraftForm({
    required this.id,
    required this.title,
    required this.epoch,
    required this.placeIndex,
    required this.timeLabel,
    required this.scene,
    required this.challenge,
    required this.decision,
    required this.sourceId,
    required this.locator,
    required this.quotes,
  });

  /// نموذج فارغ.
  static const SeerahDraftForm blank = SeerahDraftForm(
    id: '',
    title: '',
    epoch: SeerahEpoch.meccan,
    placeIndex: 0,
    timeLabel: '',
    scene: '',
    challenge: '',
    decision: '',
    sourceId: 'sira_ibn_hisham',
    locator: '',
    quotes: <SeerahScene, String>{},
  );

  /// المعرّف اللاتيني للمحطة.
  final String id;

  /// المحطة (عنوان الحدث).
  final String title;

  /// الحقبة.
  final SeerahEpoch epoch;

  /// الموضع من المواضع المقترحة.
  final int placeIndex;

  /// وسم زمني اختياري من الشواهد.
  final String timeLabel;

  /// المشهد.
  final String scene;

  /// المأزق.
  final String challenge;

  /// المخرج النبوي.
  final String decision;

  /// المصدر.
  final String sourceId;

  /// الموضع في المصدر.
  final String locator;

  /// نص الشاهد لكل مشهد.
  final Map<SeerahScene, String> quotes;

  /// أخطاء النموذج.
  List<String> validate() {
    final List<String> errors = <String>[];
    if (!_idPattern.hasMatch(id.trim())) {
      errors.add('المعرّف حروف لاتينية صغيرة وأرقام وشرطة سفلية، مثل hilf_al_fudul.');
    }
    if (title.trim().isEmpty) {
      errors.add('اسم المحطة مطلوب.');
    }
    if (placeIndex < 0 || placeIndex >= seerahPlacePresets.length) {
      errors.add('اختر الموضع.');
    }
    if (scene.trim().isEmpty) {
      errors.add('المشهد مطلوب.');
    }
    if (challenge.trim().isEmpty) {
      errors.add('المأزق مطلوب.');
    }
    if (decision.trim().isEmpty) {
      errors.add('المخرج النبوي مطلوب.');
    }
    if (!_idPattern.hasMatch(sourceId.trim())) {
      errors.add('اختر المصدر.');
    }
    if (quotes.values.every((String quote) => quote.trim().isEmpty)) {
      errors.add('أدخل نص شاهد واحد على الأقل منقولاً من المصدر بنصه.');
    }
    return errors;
  }

  /// المشاهد التي لم يُدخل لها شاهد؛ لا تظهر المحطة في التطبيق حتى تكتمل.
  List<SeerahScene> get missingScenes {
    return <SeerahScene>[
      for (final SeerahScene scene in SeerahScene.values)
        if ((quotes[scene] ?? '').trim().isEmpty) scene,
    ];
  }

  /// يحوّل النموذج الصالح إلى محطة بالمخطط.
  SeerahStationModel toStation({required int order}) {
    final SeerahPlacePreset place = seerahPlacePresets[placeIndex];
    final String trimmedLocator = locator.trim();
    return SeerahStationModel(
      id: id.trim(),
      order: order,
      title: title.trim(),
      epoch: epoch,
      timeLabel: timeLabel.trim().isEmpty ? null : timeLabel.trim(),
      place: SeerahPlace(
        name: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        coordinatesApproximate: true,
      ),
      onRoute: true,
      sceneDescription: scene.trim(),
      challenge: challenge.trim(),
      propheticDecision: decision.trim(),
      evidence: <SeerahEvidence>[
        for (final SeerahScene item in SeerahScene.values)
          if ((quotes[item] ?? '').trim().isNotEmpty)
            SeerahEvidence(
              scene: item,
              source: SourceRef(
                sourceId: sourceId.trim(),
                locator: trimmedLocator.isEmpty ? null : trimmedLocator,
                quote: quotes[item]!.trim(),
              ),
            ),
      ],
      review: ReviewInfo(
        status: ReviewStatus.pendingScholarlyReview,
        reviewer: null,
        reviewedAt: null,
        notes: <String>[
          'أُدخلت المحطة من لوحة الإدخال المحلية؛ يُتحقق من الشواهد في مصادرها قبل الدمج.',
          if (missingScenes.isNotEmpty)
            'ينقصها شاهد لمشهد أو أكثر؛ لا تظهر في التطبيق حتى يكون لكل مشهد شاهده.',
        ],
      ),
    );
  }
}

/// يولد مصفوفة JSON معيارية مقروءة.
String encodeJsonArray(List<Map<String, dynamic>> items) {
  return const JsonEncoder.withIndent('  ').convert(items);
}

/// يتحقق أن النص مصفوفة JSON صالحة تُقرأ عناصرها بنماذج المخطط وتعود كما هي.
bool verifyHadithDraftArray(String json) {
  final Object? decoded = jsonDecode(json);
  if (decoded is! List) {
    return false;
  }
  for (final Object? item in decoded) {
    if (item is! Map<String, dynamic>) {
      return false;
    }
    final HadithDraft draft = HadithDraft.fromJson(item);
    if (jsonEncode(draft.toJson()) != jsonEncode(item)) {
      return false;
    }
  }
  return true;
}

/// يتحقق من مصفوفة محطات السيرة.
bool verifySeerahStationArray(String json) {
  final Object? decoded = jsonDecode(json);
  if (decoded is! List) {
    return false;
  }
  for (final Object? item in decoded) {
    if (item is! Map<String, dynamic>) {
      return false;
    }
    final SeerahStationModel station = SeerahStationModel.fromJson(item);
    if (jsonEncode(station.toJson()) != jsonEncode(item)) {
      return false;
    }
  }
  return true;
}
