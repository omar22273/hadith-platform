// اختبارات لوحة الإدخال: تحقق المدخلات، وحفظ النص كما أُدخل، وتوليد مصفوفة
// JSON صالحة تُقرأ بنماذج المخطط وتعود كما هي.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/admin/data/models/hadith_draft.dart';
import 'package:hadith_platform/features/admin/domain/admin_drafts.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_bundle.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final HadithBundle bundle = HadithBundle(
    hadith: HadithDailyModel.fromJson(_load('assets/data/hadith/nawawi40/nawawi40_001.json')),
    narrators: NarratorCatalog.fromJson(_load('assets/data/catalogs/narrators.json')),
    sources: SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json')),
  );

  group('hadith form', () {
    test('an existing hadith prefills the form with its own texts', () {
      final HadithDraftForm form = HadithDraftForm.fromBundle(bundle);
      expect(form.parsedNumber, 1);
      expect(form.topNarrator, 'عمر بن الخطاب');
      expect(form.matn, startsWith(bundle.hadith.matn.segments.first.text));
      expect(form.gharib.length, bundle.hadith.matn.gharib.length);
      expect(form.benefitLines.length, bundle.hadith.reflection.impacts.length);
      expect(form.validate(), isEmpty);
    });

    test('an unvocalized matn, a missing narrator and a half gharib row are rejected', () {
      const HadithDraftForm form = HadithDraftForm(
        number: 'x',
        matn: 'انما الاعمال بالنيات',
        topNarrator: ' ',
        gharib: <GharibRow>[GharibRow(word: 'النيات', meaning: '')],
        benefits: '',
      );
      expect(form.validate().length, 4);
    });

    test('the exported array is valid JSON that round-trips through the model', () {
      final HadithDraft draft = HadithDraftForm.fromBundle(bundle).toDraft();
      expect(draft.hadithId, 'nawawi40_001');
      expect(draft.matn, HadithDraftForm.fromBundle(bundle).matn.trim());
      final String json = encodeJsonArray(<Map<String, dynamic>>[draft.toJson()]);
      expect(jsonDecode(json), isA<List<dynamic>>());
      expect(verifyHadithDraftArray(json), isTrue);
      expect(verifyHadithDraftArray('{"not": "an array"}'), isFalse);
    });
  });

  group('seerah form', () {
    SeerahDraftForm form({Map<SeerahScene, String>? quotes}) {
      return SeerahDraftForm(
        id: 'test_station',
        title: 'محطة تجريبية',
        epoch: SeerahEpoch.medinan,
        placeIndex: 4,
        timeLabel: '',
        scene: 'مشهد',
        challenge: 'مأزق',
        decision: 'مخرج',
        sourceId: 'sira_ibn_hisham',
        locator: 'ج1 ص1',
        quotes: quotes ?? <SeerahScene, String>{SeerahScene.setting: 'نص منقول'},
      );
    }

    test('requires a valid id and at least one quote', () {
      expect(form().validate(), isEmpty);
      expect(form(quotes: <SeerahScene, String>{}).validate(), isNotEmpty);
      const SeerahDraftForm bad = SeerahDraftForm.blank;
      expect(bad.validate(), isNotEmpty);
    });

    test('missing scenes are reported and noted in the review', () {
      final SeerahDraftForm partial = form();
      expect(partial.missingScenes, <SeerahScene>[SeerahScene.challenge, SeerahScene.decision]);
      final SeerahStationModel station = partial.toStation(order: 13);
      expect(station.order, 13);
      expect(station.timeLabel, isNull);
      expect(station.evidence.single.scene, SeerahScene.setting);
      expect(station.review.notes.length, 2);
      final String json = encodeJsonArray(<Map<String, dynamic>>[station.toJson()]);
      expect(verifySeerahStationArray(json), isTrue);
    });
  });
}
