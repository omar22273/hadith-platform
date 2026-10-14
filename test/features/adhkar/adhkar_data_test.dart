// اختبارات مصفوفة بيانات الأذكار: ستة ملفات في assets/data/adhkar/ مشكولة ومقتطعة
// حرفياً من شواهدها (الخط الأحمر: لا لفظ نبوي من الذاكرة). كل ذكر وفضله جزء حرفي من
// شاهد، والعدد الأكثر من واحد منصوص في الشاهد، وكل مصدر معروف في فهرس المصادر.

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

/// عدد أذكار كل ملف كما بُني من المواصفات.
const Map<String, int> _expectedCounts = <String, int>{
  'adhkar_morning_evening': 13,
  'adhkar_sleep': 13,
  'adhkar_after_prayer': 9,
  'adhkar_home_masjid': 6,
  'sunan_mahjoorah': 13,
  'adhkar_daily_life': 19,
};

void main() {
  final SourceCatalog sources = SourceCatalog.fromJson(loadJson('assets/data/catalogs/sources.json'));
  final Map<AdhkarCategory, JsonMap> raws = <AdhkarCategory, JsonMap>{
    for (final AdhkarCategory category in AdhkarCategories.all) category: loadJson(category.assetPath),
  };
  final Map<AdhkarCategory, AdhkarCatalog> catalogs = <AdhkarCategory, AdhkarCatalog>{
    for (final MapEntry<AdhkarCategory, JsonMap> entry in raws.entries) entry.key: AdhkarCatalog.fromJson(entry.value),
  };
  final List<DhikrItem> allItems = <DhikrItem>[for (final AdhkarCatalog c in catalogs.values) ...c.items];

  group('the six data files', () {
    test('the hub knows exactly six categories, each with its own file whose id is its file stem', () {
      expect(AdhkarCategories.all, hasLength(6));
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

    test('the folder holds those six files and nothing else (the old two-item seed is gone)', () {
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
      expect(allItems, hasLength(73));
    });

    test('the requested content is present: sunan, supplications and the hub subjects', () {
      final Set<String> ids = allItems.map((DhikrItem i) => i.id).toSet();
      const List<String> requested = <String>[
        // السنن المهجورة المطلوبة: ركعتا الوضوء، لعق الأصابع، الابتداء باليمين.
        'rakatan_ba_da_al_wudu',
        'laq_al_asabi',
        'at_tayammun',
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
        expect(checkAdhkarCatalog(entry.value, sources: sources), isEmpty, reason: entry.key.id);
        expect(entry.value.schemaVersion, '2.0.0');
      }
    });

    test('item ids are unique across all six files, so no dhikr is listed twice', () {
      final List<String> ids = allItems.map((DhikrItem i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every dhikr text is a vocalized, verbatim part of one of its evidence quotes', () {
      for (final DhikrItem item in allItems) {
        expect(item.text.trim(), isNotEmpty, reason: item.id);
        expect(_tashkeel.hasMatch(item.text), isTrue, reason: 'vocalized: ${item.id}');
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(item.text)), isTrue, reason: item.id);
        expect(_strayMarks.hasMatch(item.text), isFalse, reason: 'clean: ${item.id}');
        expect(item.title.trim(), isNotEmpty, reason: item.id);
      }
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
      expect(withVirtue, greaterThan(10), reason: 'the stated virtues of the adhkar are kept, not dropped');
    });

    test('every evidence carries a vocalized quote, a numeric locator, and a source known to the catalog', () {
      for (final DhikrItem item in allItems) {
        expect(item.evidence, isNotEmpty, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          expect(reference.quote?.trim(), isNotEmpty, reason: item.id);
          expect(_tashkeel.hasMatch(reference.quote!), isTrue, reason: 'vocalized quote: ${item.id}');
          expect(_strayMarks.hasMatch(reference.quote!), isFalse, reason: 'clean quote: ${item.id}');
          expect(reference.locator?.trim(), isNotEmpty, reason: item.id);
          expect(int.tryParse(reference.locator!), isNotNull, reason: 'numeric locator: ${item.id}');
          expect(sources.byId(reference.sourceId), isNotNull, reason: '${item.id}: ${reference.sourceId}');
        }
      }
      expect(sources.byId('sunan_abu_dawud'), isNotNull, reason: 'Abu Dawud was added for the sunan and duas');
    });

    test('a count above one is stated in the evidence and recorded in the review notes', () {
      int counted = 0;
      for (final DhikrItem item in allItems) {
        expect(item.count, greaterThanOrEqualTo(1), reason: item.id);
        if (item.count > 1) {
          counted++;
          expect(item.review.notes.any((String n) => n.contains('العدد (${item.count}) منصوص في الشاهد')), isTrue,
              reason: item.id);
        }
      }
      expect(counted, greaterThan(5));
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

    test('a weak narration cannot slip in: every evidence outside the two Sahihs records a Sahih or Hasan grade', () {
      for (final DhikrItem item in allItems) {
        for (final SourceRef reference in item.evidence) {
          if (reference.sourceId == 'sahih_bukhari' || reference.sourceId == 'sahih_muslim') {
            continue;
          }
          final String key = '${reference.sourceId} رقم ${reference.locator}:';
          final List<String> notes = item.review.notes.where((String n) => n.contains(key)).toList();
          expect(notes, isNotEmpty, reason: '${item.id}: $key');
          for (final String note in notes) {
            expect(note.contains('صحيح') || note.contains('حسن'), isTrue, reason: '${item.id}: $note');
            expect(note, isNot(contains('ضعيف')), reason: '${item.id}: $note');
            expect(note, isNot(contains('منكر')), reason: '${item.id}: $note');
          }
        }
      }
    });
  });

  group('the integrity checks reject tampering', () {
    final AdhkarCatalog catalog = catalogs[AdhkarCategories.morningEvening]!;
    final DhikrItem first = catalog.items.first;

    AdhkarCatalog withItems(List<DhikrItem> items) => AdhkarCatalog(
          schemaVersion: catalog.schemaVersion,
          id: catalog.id,
          title: catalog.title,
          items: items,
        );

    DhikrItem editedWith(Map<String, dynamic> changes) {
      return DhikrItem.fromJson(<String, dynamic>{...first.toJson(), ...changes});
    }

    test('a text that is not in its quotes, a duplicate id, or a bad count is rejected', () {
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(<String, dynamic>{'text': 'نص لا أصل له في الشاهد'})]),
            sources: sources),
        contains(contains('verbatim part')),
      );
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[first, first]), sources: sources), contains(contains('Duplicate')));
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(<String, dynamic>{'count': 0})]), sources: sources),
        contains(contains('count')),
      );
    });

    test('a virtue that is blank or not in the quotes is rejected', () {
      expect(first.virtue, isNotNull);
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(<String, dynamic>{'virtue': 'فضل لا أصل له في الشاهد'})]),
            sources: sources),
        contains(contains('virtue')),
      );
      expect(
        checkAdhkarCatalog(withItems(<DhikrItem>[editedWith(<String, dynamic>{'virtue': '   '})]), sources: sources),
        contains(contains('virtue')),
      );
    });

    test('a source unknown to the catalog is rejected', () {
      final DhikrItem unknown = editedWith(<String, dynamic>{
        'evidence': <Map<String, dynamic>>[
          <String, dynamic>{...first.evidence.first.toJson(), 'sourceId': 'no_such_source'},
        ],
      });
      expect(checkAdhkarCatalog(withItems(<DhikrItem>[unknown]), sources: sources), contains(contains('Unknown sourceId')));
    });

    test('the JSON schema covers the adhkar catalog', () {
      final JsonMap schema = loadJson('assets/data/schema/hadith_platform.schema.json');
      final JsonMap defs = asJsonMap(schema['\$defs'], 'defs');
      expect(defs.containsKey('AdhkarCatalog'), isTrue);
      expect(defs.containsKey('DhikrItem'), isTrue);
    });
  });
}
