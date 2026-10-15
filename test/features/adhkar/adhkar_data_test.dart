// اختبارات مصفوفة بيانات الأذكار: خمسة ملفات في assets/data/adhkar/ (والسنن المهجورة ملف مستقل له اختباره في
// test/features/sunan) مشكولة ومقتطعة
// حرفياً من شواهدها (الخط الأحمر: لا لفظ نبوي من الذاكرة). كل ذكر وفضله جزء حرفي من
// شاهد، والعدد الأكثر من واحد منصوص في الشاهد أو في طلب المالك وحصن المسلم، وكل مصدر
// معروف في فهرس المصادر، وكل ذكر ضعّفه الألباني يحمل تنبيهه، ومسارات التبديل متسقة.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_category.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_integrity.dart';

import '../../support/adhkar_support.dart';

/// الحركات العربية (التشكيل).
final RegExp _tashkeel = RegExp('[ً-ْ]');

/// علامات الاتجاه وعلامات الاقتباس وأقواس الآيات التي أُزيلت من النصوص المنقولة.
final RegExp _strayMarks = RegExp('[‏‎"«»{}]');

/// الكتب الستة المثبتة، ومواضع أحاديثها أرقام.
const Set<String> _sixBooks = <String>{
  'sahih_bukhari',
  'sahih_muslim',
  'sunan_tirmidhi',
  'sunan_ibn_majah',
  'sunan_nasai',
  'sunan_abu_dawud',
};

/// المصادر الإضافية: آيات المالك، وعباراته المشكولة، وحصن المسلم.
const Set<String> _extraSources = <String>{'quran_owner_text', 'owner_adhkar_v290', 'hisn_al_muslim'};

/// عدد أذكار كل ملف كما بُني من المواصفات (ملف السنن المهجورة في assets/data/sunan وله اختباره).
const Map<String, int> _expectedCounts = <String, int>{
  'adhkar_morning_evening': 30,
  'adhkar_sleep': 19,
  'adhkar_after_prayer': 12,
  'adhkar_home_masjid': 7,
  'adhkar_daily_life': 19,
};

/// أذكار درجتها عند الألباني في الإصدار المعتمد دون الحسن، أُدرجت لأن المالك طلبها صراحةً؛
/// كلها يجب أن تحمل تنبيهاً. وأي ذكر ضعيف خارج هذه القائمة يُرفض.
const Set<String> _weakButRequested = <String>{
  'allahumma_ma_asbaha_bi_min_nima',
  'allahumma_ma_amsa_bi_min_nima',
  'allahumma_inni_audhu_bika_minal_hamm',
  'radiytu_billahi_rabba',
  'hasbiyallah_la_ilaha_illa_huwa',
  'allahumma_inni_asbahtu_ushhiduka',
  'ya_rabbi_laka_al_hamd',
};

/// أذكار لا أصل لها في الكتب الستة المثبتة: نصها من إدخال المالك ومرجعها حصن المسلم.
const Set<String> _ownerOnly = <String>{
  'ya_hayyu_ya_qayyum_birahmatika_astaghith',
  'allahumma_inni_audhu_bika_an_ushrika',
};

/// أذكار الصباح والمساء التي نص عليها المالك بأسمائها.
const List<String> _ownerMorningEvening = <String>[
  'ayat_al_kursi_sabahan_wa_masaan',
  'surat_al_ikhlas_thalathan',
  'surat_al_falaq_thalathan',
  'surat_an_nas_thalathan',
  'bismillah_la_yadurru',
  'as_alukal_afwa_wal_afiya',
  'allahumma_alim_al_ghayb_wash_shahada',
  'allahumma_afini_fi_badani',
  'sayyid_al_istighfar',
  'ya_hayyu_ya_qayyum_birahmatika_astaghith',
  'allahumma_inni_audhu_bika_minal_hamm',
  'allahumma_inni_audhu_bika_an_ushrika',
  'radiytu_billahi_rabba',
  'hasbiyallah_la_ilaha_illa_huwa',
  'allahumma_inni_asbahtu_ushhiduka',
  'ya_rabbi_laka_al_hamd',
];

/// ذكر طلبه المالك للصباح والمساء، لكن لفظ الحديث نفسه يقيّده بالمساء («حين يمسي»)،
/// فهو في مسار المساء وحده؛ ولا يُنقل إلى الصباح بلا شاهد.
const String _ownerEveningOnly = 'audhu_bikalimat_allah_thalathan';

void main() {
  final SourceCatalog sources = SourceCatalog.fromJson(loadJson('assets/data/catalogs/sources.json'));
  final Map<AdhkarCategory, JsonMap> raws = <AdhkarCategory, JsonMap>{
    for (final AdhkarCategory category in AdhkarCategories.all) category: loadJson(category.assetPath),
  };
  final Map<AdhkarCategory, AdhkarCatalog> catalogs = <AdhkarCategory, AdhkarCatalog>{
    for (final MapEntry<AdhkarCategory, JsonMap> entry in raws.entries) entry.key: AdhkarCatalog.fromJson(entry.value),
  };
  final List<DhikrItem> allItems = <DhikrItem>[for (final AdhkarCatalog c in catalogs.values) ...c.items];

  group('the five adhkar data files', () {
    test('the hub knows exactly five adhkar categories, each with its own file whose id is its file stem', () {
      expect(AdhkarCategories.all, hasLength(5));
      expect(AdhkarCategories.all.map((AdhkarCategory c) => c.id).toSet(), _expectedCounts.keys.toSet());
      for (final AdhkarCategory category in AdhkarCategories.all) {
        expect(File(category.assetPath).existsSync(), isTrue, reason: category.assetPath);
        expect(category.assetPath, endsWith('${category.id}.json'));
        expect(catalogs[category]!.id, category.id);
        expect(catalogs[category]!.title, category.title, reason: 'the file title is the card title');
        expect(AdhkarCategories.byId(category.id), same(category));
      }
      expect(AdhkarCategories.byId('nonexistent'), isNull);
    });

    test('the folder holds those five files and nothing else (the sunan moved to their own folder)', () {
      final List<String> names = Directory('assets/data/adhkar')
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
      expect(names, _expectedCounts.keys.map((String id) => '$id.json').toList()..sort());
    });

    test('each file has the pinned number of adhkar, ordered 1..n with no gaps', () {
      for (final MapEntry<AdhkarCategory, AdhkarCatalog> entry in catalogs.entries) {
        final List<DhikrItem> items = entry.value.itemsInOrder;
        expect(items, hasLength(_expectedCounts[entry.key.id]!), reason: entry.key.id);
        expect(items.map((DhikrItem i) => i.order).toList(), List<int>.generate(items.length, (int i) => i + 1),
            reason: entry.key.id);
      }
      expect(allItems, hasLength(87));
    });

    test('the requested content is present: supplications and the hub subjects', () {
      final Set<String> ids = allItems.map((DhikrItem i) => i.id).toSet();
      const List<String> requested = <String>[
        // الأدعية: الركوب، السفر، الكرب، نزول الغيث.
        'dua_ar_rukub',
        'dua_as_safar',
        'dua_al_karb',
        'dua_nuzul_al_matar',
        // الصباح والمساء وأدبار الصلوات والنوم والمنزل والمسجد.
        'sayyid_al_istighfar',
        'tasbih_thalathan_wa_thalathin',
        'bismika_rabbi_wadatu_janbi',
        'dukhul_al_masjid',
        'dhikr_allah_inda_dukhul_al_bayt',
      ];
      for (final String id in requested) {
        expect(ids, contains(id));
      }
    });

    test('every file round-trips and passes the integrity checks against the source catalog', () {
      for (final MapEntry<AdhkarCategory, AdhkarCatalog> entry in catalogs.entries) {
        expect(entry.value.toJson(), equals(raws[entry.key]), reason: entry.key.id);
        expect(
          checkAdhkarCatalog(
            entry.value,
            sources: sources,
            trackIds: entry.key.tracks.map((AdhkarTrack t) => t.id).toSet(),
          ),
          isEmpty,
          reason: entry.key.id,
        );
        expect(entry.value.schemaVersion, '2.0.0');
      }
    });

    test('item ids are unique across all five files, so no dhikr is listed twice', () {
      final List<String> ids = allItems.map((DhikrItem i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every dhikr text is vocalized and a verbatim part of one of its evidence quotes (but the one derived text)',
        () {
      int derived = 0;
      for (final DhikrItem item in allItems) {
        expect(item.text.trim(), isNotEmpty, reason: item.id);
        expect(_tashkeel.hasMatch(item.text), isTrue, reason: 'vocalized: ${item.id}');
        expect(_strayMarks.hasMatch(item.text), isFalse, reason: 'clean: ${item.id}');
        expect(item.title.trim(), isNotEmpty, reason: item.id);
        if (item.derivation != null) {
          derived++;
          continue;
        }
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(item.text)), isTrue, reason: item.id);
      }
      expect(derived, 1, reason: 'exactly one text is derived, and it is disclosed');
    });

    test('every virtue is vocalized and a verbatim part of one of its quotes', () {
      int withVirtue = 0;
      for (final DhikrItem item in allItems) {
        final String? virtue = item.virtue;
        if (virtue == null) {
          continue;
        }
        withVirtue++;
        expect(virtue.trim(), isNotEmpty, reason: item.id);
        expect(_tashkeel.hasMatch(virtue), isTrue, reason: 'vocalized: ${item.id}');
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(virtue)), isTrue, reason: item.id);
        expect(_strayMarks.hasMatch(virtue), isFalse, reason: 'clean: ${item.id}');
      }
      expect(withVirtue, greaterThan(20), reason: 'the stated virtues of the adhkar are kept, not dropped');
    });

    test('every evidence carries a quote, a locator and a source known to the catalog', () {
      for (final DhikrItem item in allItems) {
        expect(item.evidence, isNotEmpty, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          expect(reference.quote?.trim(), isNotEmpty, reason: item.id);
          expect(_strayMarks.hasMatch(reference.quote!), isFalse, reason: 'clean quote: ${item.id}');
          expect(reference.locator?.trim(), isNotEmpty, reason: item.id);
          expect(sources.byId(reference.sourceId), isNotNull, reason: '${item.id}: ${reference.sourceId}');
          if (_sixBooks.contains(reference.sourceId)) {
            expect(_tashkeel.hasMatch(reference.quote!), isTrue, reason: 'vocalized quote: ${item.id}');
            expect(int.tryParse(reference.locator!), isNotNull, reason: 'numeric hadith number: ${item.id}');
          } else {
            expect(_extraSources, contains(reference.sourceId), reason: item.id);
            expect(int.tryParse(reference.locator!), isNull, reason: 'a descriptive locator: ${item.id}');
          }
          if (reference.sourceId == 'quran_owner_text' || reference.sourceId == 'owner_adhkar_v290') {
            expect(_tashkeel.hasMatch(reference.quote!), isTrue, reason: 'owner text is vocalized: ${item.id}');
          }
        }
      }
      expect(sources.byId('sunan_abu_dawud'), isNotNull, reason: 'Abu Dawud was added for the sunan and duas');
      expect(sources.byId('hisn_al_muslim')!.kind, SourceKind.adhkarCollection);
      expect(sources.byId('quran_owner_text')!.kind, SourceKind.quranText);
      expect(sources.byId('owner_adhkar_v290')!.kind, SourceKind.ownerText);
    });

    test('a count above one is stated in the evidence, or taken from the owner and Hisn, and noted in review',
        () {
      int counted = 0;
      for (final DhikrItem item in allItems) {
        expect(item.count, greaterThanOrEqualTo(1), reason: item.id);
        if (item.count > 1) {
          counted++;
          final bool stated = item.review.notes.any((String n) => n.contains('العدد (${item.count}) منصوص في الشاهد'));
          final bool fromHisn = item.review.notes.any(
            (String n) => n.contains('العدد (${item.count}) ليس منصوصاً في الشاهد؛ أُخذ من طلب المالك ومن حصن المسلم'),
          );
          expect(stated || fromHisn, isTrue, reason: item.id);
        }
      }
      expect(counted, greaterThan(10));
      // العدد الذي لم يُنص عليه في الحديث وحده معلن في الملاحظات: ذكران فقط.
      final Set<String> fromHisnOnly = <String>{
        for (final DhikrItem item in allItems)
          if (item.review.notes.any((String n) => n.contains('ليس منصوصاً في الشاهد؛ أُخذ من طلب المالك'))) item.id,
      };
      expect(fromHisnOnly, <String>{'radiytu_billahi_rabba'});
    });

    test('every dhikr awaits scholarly review in the data, and no internal phrase leaks into display fields', () {
      for (final DhikrItem item in allItems) {
        expect(item.review.status, ReviewStatus.pendingScholarlyReview, reason: item.id);
        for (final String shown in <String>[item.title, item.text, item.virtue ?? '']) {
          expect(shown, isNot(contains('المراجعة')), reason: item.id);
          expect(shown, isNot(contains('pending')), reason: item.id);
          expect(shown, isNot(contains('[?]')), reason: item.id);
          expect(shown, isNot(contains('TODO')), reason: item.id);
        }
      }
    });

    test('every dhikr records the grade of each of its hadiths, taken from the pinned edition', () {
      for (final DhikrItem item in allItems) {
        final String grading = item.grading ?? '';
        expect(grading.trim(), isNotEmpty, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          if (_sixBooks.contains(reference.sourceId)) {
            expect(grading, contains('رقم ${reference.locator}'), reason: '${item.id}: ${reference.locator}');
          }
        }
        expect(grading, isNot(contains('[?]')), reason: item.id);
      }
    });

    test('a weak narration cannot slip in: only the owner-requested ones, each with its caution banner', () {
      final Set<String> weak = <String>{};
      for (final DhikrItem item in allItems) {
        for (final SourceRef reference in item.evidence) {
          if (!_sixBooks.contains(reference.sourceId) || reference.sourceId == 'sahih_bukhari' || reference.sourceId == 'sahih_muslim') {
            continue;
          }
          final String key = '${reference.sourceId} رقم ${reference.locator}:';
          final List<String> notes = item.review.notes.where((String n) => n.contains(key)).toList();
          expect(notes, isNotEmpty, reason: '${item.id}: $key');
          for (final String note in notes) {
            final bool bad = note.contains('ضعيف') || note.contains('منكر') || note.contains('موضوع');
            if (bad) {
              weak.add(item.id);
            } else {
              expect(note.contains('صحيح') || note.contains('حسن'), isTrue, reason: '${item.id}: $note');
            }
          }
        }
      }
      expect(weak, _weakButRequested, reason: 'the set of weak narrations is exactly the disclosed one');

      final Set<String> cautioned = <String>{
        for (final DhikrItem item in allItems)
          if (item.caution != null) item.id,
      };
      expect(cautioned, <String>{..._weakButRequested, ..._ownerOnly});
      for (final DhikrItem item in allItems.where((DhikrItem i) => i.caution != null)) {
        expect(item.caution, startsWith('تنبيه'), reason: item.id);
        expect(item.caution, isNot(contains('[?]')), reason: item.id);
      }
      for (final DhikrItem item in allItems.where((DhikrItem i) => _weakButRequested.contains(i.id))) {
        expect(item.caution, contains('أُدرج الذكر لأن طلب المالك'), reason: item.id);
        expect(item.grading, matches(RegExp('الألباني: (ضعيف|موضوع|منكر)')), reason: item.id);
      }
    });

    test('owner-only texts are ruled out of the six books, kept apart and labelled for review', () {
      for (final String id in _ownerOnly) {
        final DhikrItem item = allItems.singleWhere((DhikrItem i) => i.id == id);
        expect(item.evidence.map((SourceRef r) => r.sourceId), <String>['owner_adhkar_v290', 'hisn_al_muslim'], reason: id);
        expect(item.caution, contains('لم يُوجد هذا الذكر في الكتب الستة المثبّتة'), reason: id);
        expect(item.grading, contains('بانتظار المراجعة العلمية'), reason: id);
      }
    });
  });

  group('the owner request is fulfilled', () {
    final List<DhikrItem> morningEvening = catalogs[AdhkarCategories.morningEvening]!.itemsInOrder;

    test('every dhikr the owner named for the morning and evening is there, in both tracks', () {
      final Set<String> ids = morningEvening.map((DhikrItem i) => i.id).toSet();
      for (final String id in _ownerMorningEvening) {
        expect(ids, contains(id));
        final DhikrItem item = morningEvening.singleWhere((DhikrItem i) => i.id == id);
        expect(item.inTrack('morning'), isTrue, reason: id);
        expect(item.inTrack('evening'), isTrue, reason: id);
      }
    });

    test('the one dhikr whose hadith says "when he reaches the evening" stays in the evening track only', () {
      final DhikrItem item = morningEvening.singleWhere((DhikrItem i) => i.id == _ownerEveningOnly);
      expect(item.inTrack('evening'), isTrue);
      expect(item.inTrack('morning'), isFalse);
      expect(item.count, 3);
      expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains('يُمْسِي')), isTrue,
          reason: 'the evidence itself restricts it to the evening');
    });

    test('the counts the owner gave are the counts in the data', () {
      int countOf(String id) => morningEvening.singleWhere((DhikrItem i) => i.id == id).count;
      expect(countOf('bismillah_la_yadurru'), 3);
      expect(countOf(_ownerEveningOnly), 3);
      expect(countOf('allahumma_afini_fi_badani'), 3);
      expect(countOf('radiytu_billahi_rabba'), 3);
      expect(countOf('hasbiyallah_la_ilaha_illa_huwa'), 7);
      expect(countOf('allahumma_inni_asbahtu_ushhiduka'), 4);
      expect(countOf('surat_al_ikhlas_thalathan'), 3);
      expect(countOf('surat_al_falaq_thalathan'), 3);
      expect(countOf('surat_an_nas_thalathan'), 3);
      expect(countOf('ayat_al_kursi_sabahan_wa_masaan'), 1);
    });

    test('the Quran passages come from the owner text, at the sunnah positions: morning, sleep and after prayer', () {
      List<DhikrItem> quranIn(AdhkarCategory category) =>
          catalogs[category]!.items.where((DhikrItem i) => i.isQuran).toList();
      expect(quranIn(AdhkarCategories.morningEvening).map((DhikrItem i) => i.id), <String>[
        'ayat_al_kursi_sabahan_wa_masaan',
        'surat_al_ikhlas_thalathan',
        'surat_al_falaq_thalathan',
        'surat_an_nas_thalathan',
      ]);
      expect(quranIn(AdhkarCategories.sleep).map((DhikrItem i) => i.id), <String>[
        'ayat_al_kursi_inda_al_nawm',
        'khawatim_al_baqara_inda_al_nawm',
        'surat_al_ikhlas_inda_al_nawm',
        'surat_al_falaq_inda_al_nawm',
        'surat_an_nas_inda_al_nawm',
      ]);
      expect(quranIn(AdhkarCategories.afterPrayer).map((DhikrItem i) => i.id), <String>[
        'ayat_al_kursi_dubur_kulli_salah',
        'surat_al_ikhlas_dubur_salah',
        'surat_al_falaq_dubur_salah',
        'surat_an_nas_dubur_salah',
      ]);
      for (final DhikrItem item in allItems.where((DhikrItem i) => i.isQuran)) {
        expect(item.evidence.first.sourceId, 'quran_owner_text', reason: item.id);
        expect(item.text, item.evidence.first.quote, reason: 'the verse is the owner text whole: ${item.id}');
        expect(item.displayText, startsWith('﴿'), reason: item.id);
        expect(item.displayText, endsWith('﴾'), reason: item.id);
        expect(item.displayText, isNot(contains('*')), reason: item.id);
      }
    });

    test('the home and masjid file splits into the two requested tracks', () {
      final List<DhikrItem> items = catalogs[AdhkarCategories.homeMasjid]!.itemsInOrder;
      expect(items.where((DhikrItem i) => i.inTrack('home')).map((DhikrItem i) => i.id), <String>[
        'dhikr_allah_inda_dukhul_al_bayt',
        'bismillah_tawakkaltu_inda_al_khuruj',
        'allahumma_inni_audhu_bika_an_adilla',
      ]);
      expect(items.where((DhikrItem i) => i.inTrack('masjid')).map((DhikrItem i) => i.id), <String>[
        'allahumma_ijal_fi_qalbi_nuran',
        'dukhul_al_masjid',
        'audhu_billahil_azim_dukhul_al_masjid',
        'khuruj_min_al_masjid',
      ]);
    });

    test('the sleep file splits into sleep and waking, with the sunnah of the three Quls in the sleep track', () {
      final List<DhikrItem> items = catalogs[AdhkarCategories.sleep]!.itemsInOrder;
      expect(items.where((DhikrItem i) => i.inTrack('wake')), hasLength(3));
      expect(items.where((DhikrItem i) => i.inTrack('sleep')), hasLength(16));
      for (final String id in <String>['surat_al_ikhlas_inda_al_nawm', 'surat_al_falaq_inda_al_nawm', 'surat_an_nas_inda_al_nawm']) {
        final DhikrItem item = items.singleWhere((DhikrItem i) => i.id == id);
        expect(item.count, 3, reason: id);
        expect(item.inTrack('sleep'), isTrue, reason: id);
        expect(item.inTrack('wake'), isFalse, reason: id);
      }
    });

    test('the single derived text swaps one word, taken with its vocalization from another evidence', () {
      final List<DhikrItem> derived = allItems.where((DhikrItem i) => i.derivation != null).toList();
      expect(derived.map((DhikrItem i) => i.id), <String>['allahumma_ma_amsa_bi_min_nima']);
      final DhikrItem item = derived.single;
      expect(item.derivation!.fromWord, 'اصبح');
      expect(item.derivation!.toWord, 'امسي');
      expect(item.inTrack('evening'), isTrue);
      expect(item.inTrack('morning'), isFalse);
      expect(item.derivation!.note, contains('وَمَنْ قَالَ مِثْلَ ذَلِكَ حِينَ يُمْسِي'));
      expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains('أَمْسَى')), isTrue,
          reason: 'the swapped word is in an evidence, vocalized');
    });
  });

  group('the track toggle data', () {
    test('only the three toggle files carry tracks, and each carries them on every dhikr', () {
      for (final MapEntry<AdhkarCategory, AdhkarCatalog> entry in catalogs.entries) {
        final Iterable<DhikrItem> tracked = entry.value.items.where((DhikrItem i) => i.tracks != null);
        if (entry.key.hasTracks) {
          expect(tracked, hasLength(entry.value.items.length), reason: entry.key.id);
          final Set<String> allowed = entry.key.tracks.map((AdhkarTrack t) => t.id).toSet();
          expect(allowed, hasLength(2), reason: entry.key.id);
          for (final DhikrItem item in entry.value.items) {
            expect(item.tracks!.toSet().difference(allowed), isEmpty, reason: '${entry.key.id}: ${item.id}');
          }
          for (final AdhkarTrack track in entry.key.tracks) {
            expect(entry.value.items.where((DhikrItem i) => i.inTrack(track.id)), isNotEmpty,
                reason: '${entry.key.id}: ${track.id}');
          }
        } else {
          expect(tracked, isEmpty, reason: entry.key.id);
        }
      }
    });

    test('the morning and evening tracks share the common adhkar and differ in the times of day', () {
      final List<DhikrItem> items = catalogs[AdhkarCategories.morningEvening]!.itemsInOrder;
      final Set<String> morning = items.where((DhikrItem i) => i.inTrack('morning')).map((DhikrItem i) => i.id).toSet();
      final Set<String> evening = items.where((DhikrItem i) => i.inTrack('evening')).map((DhikrItem i) => i.id).toSet();
      expect(morning, hasLength(25));
      expect(evening, hasLength(25));
      expect(morning.intersection(evening), hasLength(20));
      expect(morning.difference(evening), containsAll(<String>['asbahna_wa_asbaha_al_mulk', 'allahumma_bika_asbahna']));
      expect(evening.difference(morning), containsAll(<String>['amsayna_wa_amsal_mulk', 'allahumma_bika_amsayna']));
    });
  });

  group('the integrity checks reject tampering', () {
    final AdhkarCatalog catalog = catalogs[AdhkarCategories.morningEvening]!;
    final DhikrItem first = catalog.items.first;
    final DhikrItem second = catalog.items[1];
    final Set<String> trackIds = <String>{'morning', 'evening'};

    AdhkarCatalog withItems(List<DhikrItem> items) => AdhkarCatalog(
          schemaVersion: catalog.schemaVersion,
          id: catalog.id,
          title: catalog.title,
          items: items,
        );

    DhikrItem editedWith(DhikrItem base, Map<String, dynamic> changes) {
      return DhikrItem.fromJson(<String, dynamic>{...base.toJson(), ...changes});
    }

    test('a text that is not in its quotes, a duplicate id, or a bad count is rejected', () {
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(first, <String, dynamic>{'text': 'نص لا أصل له في الشاهد'})]),
            sources: sources),
        contains(contains('verbatim part')),
      );
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[first, first]), sources: sources), contains(contains('Duplicate')));
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(first, <String, dynamic>{'count': 0})]), sources: sources),
        contains(contains('count')),
      );
    });

    test('a virtue that is blank or not in the quotes is rejected', () {
      expect(second.virtue, isNotNull);
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(second, <String, dynamic>{'virtue': 'فضل لا أصل له في الشاهد'})]),
            sources: sources),
        contains(contains('virtue')),
      );
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(second, <String, dynamic>{'virtue': '   '})]), sources: sources),
        contains(contains('virtue')),
      );
    });

    test('a source unknown to the catalog is rejected', () {
      final DhikrItem unknown = editedWith(first, <String, dynamic>{
        'evidence': <Map<String, dynamic>>[
          <String, dynamic>{...first.evidence.first.toJson(), 'sourceId': 'no_such_source'},
        ],
      });
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[unknown]), sources: sources), contains(contains('Unknown sourceId')));
    });

    test('tracks must be on every dhikr or on none, be known, and not repeat', () {
      final DhikrItem bare = DhikrItem.fromJson(<String, dynamic>{...first.toJson()}..remove('tracks'));
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[bare, second]), sources: sources, trackIds: trackIds),
        contains(contains('tracks must be set on every dhikr or on none')),
      );
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(first, <String, dynamic>{'tracks': <String>['noon']}), second]),
            sources: sources, trackIds: trackIds),
        contains(contains('unknown track')),
      );
      expect(
        checkAdhkarCatalog(
            withItems(<DhikrItem>[editedWith(first, <String, dynamic>{'tracks': <String>['morning', 'morning']}), second]),
            sources: sources,
            trackIds: trackIds),
        contains(contains('without repeats')),
      );
    });

    test('a weak narration without its caution, or a caution without a grade, is rejected', () {
      final DhikrItem weak = allItems.singleWhere((DhikrItem i) => i.id == 'radiytu_billahi_rabba');
      expect(weak.caution, isNotNull);
      final DhikrItem uncautioned = DhikrItem.fromJson(<String, dynamic>{...weak.toJson()}..remove('caution'));
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[uncautioned]), sources: sources),
          contains(contains('must carry its caution banner')));
      final DhikrItem ungraded = DhikrItem.fromJson(<String, dynamic>{...second.toJson()}
        ..remove('grading')
        ..['caution'] = 'تنبيه');
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[ungraded]), sources: sources),
          contains(contains('needs the recorded grading')));
    });

    test('a derivation is accepted only when the swapped word is vocalized from an evidence and the rest is verbatim', () {
      final DhikrItem derived = allItems.singleWhere((DhikrItem i) => i.derivation != null);
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[derived]), sources: sources), isEmpty);

      // لفظ غيّره المحرر خارج الكلمة المبدَّلة.
      final DhikrItem tampered = editedWith(derived, <String, dynamic>{'text': '${derived.text} وَزِيَادَةٌ'});
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[tampered]), sources: sources), contains(contains('derivation')));

      // الكلمة المبدَّلة بتشكيل لم يرد في أي شاهد.
      final DhikrItem reVocalized = editedWith(derived, <String, dynamic>{'text': derived.text.replaceFirst('أَمْسَى', 'أُمْسِيَ')});
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[reVocalized]), sources: sources), contains(contains('derivation')));

      // وبلا اشتقاق معلن لا يُقبل أي نص خارج الشاهد.
      final DhikrItem undisclosed = DhikrItem.fromJson(<String, dynamic>{...derived.toJson()}..remove('derivation'));
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[undisclosed]), sources: sources), contains(contains('verbatim part')));
    });

    test('the JSON schema covers the adhkar catalog and its new fields', () {
      final JsonMap schema = loadJson('assets/data/schema/hadith_platform.schema.json');
      final JsonMap defs = asJsonMap(schema['\$defs'], 'defs');
      expect(defs.containsKey('AdhkarCatalog'), isTrue);
      expect(defs.containsKey('DhikrItem'), isTrue);
      expect(defs.containsKey('TextDerivation'), isTrue);
      final JsonMap props = asJsonMap(asJsonMap(defs['DhikrItem'], 'DhikrItem')['properties'], 'properties');
      for (final String field in <String>['tracks', 'grading', 'caution', 'derivation']) {
        expect(props.containsKey(field), isTrue, reason: field);
      }
    });
  });
}
