// اختبارات ملف السنن المهجورة assets/data/sunan/sunan_mahjoorah.json: بطاقات مرجعية مقتطعة حرفياً من شواهدها
// (الخط الأحمر: لا لفظ نبوي من الذاكرة). كل نص وفضل جزء حرفي من شاهد، وكل شاهد له موضعه ومصدره المعروف،
// ولكل باب من أبواب شريط التصفية بطاقات، ولا عدّ ولا مسارات هنا، وفاحص السلامة يرفض أي عبث بالملف.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/asset_json_source.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/features/adhkar/data/models/adhkar.dart';
import 'package:hadith_platform/features/adhkar/domain/adhkar_category.dart';
import 'package:hadith_platform/features/sunan/data/asset_sunan_repository.dart';
import 'package:hadith_platform/features/sunan/data/models/sunan.dart';
import 'package:hadith_platform/features/sunan/domain/sunan_info.dart';
import 'package:hadith_platform/features/sunan/domain/sunan_integrity.dart';
import 'package:hadith_platform/features/sunan/domain/sunan_repository.dart';

import '../../support/adhkar_support.dart';
import '../../support/app_harness.dart';

/// الحركات العربية (التشكيل).
final RegExp _tashkeel = RegExp('[ً-ْ]');

/// علامات الاتجاه وعلامات الاقتباس وأقواس الآيات التي أُزيلت من النصوص المنقولة.
final RegExp _strayMarks = RegExp('[‏‎"«»{}]');

/// النص بلا حركات، لمقارنة الألفاظ دون التعويل على ترتيب علامات التشكيل.
String _plain(String value) => value.replaceAll(_tashkeel, '');

/// الكتب الستة المثبتة.
const Set<String> _sixBooks = <String>{
  'sahih_bukhari',
  'sahih_muslim',
  'sunan_tirmidhi',
  'sunan_ibn_majah',
  'sunan_nasai',
  'sunan_abu_dawud',
};

/// عدد بطاقات كل باب كما بُني من المواصفات.
const Map<SunnahBab, int> _perBab = <SunnahBab, int>{
  SunnahBab.purityPrayer: 14,
  SunnahBab.foodDrink: 10,
  SunnahBab.homeGoingOut: 7,
  SunnahBab.sleepClothing: 8,
  SunnahBab.gatheringsManners: 8,
};

/// سنن نص عليها المالك في طلبه، كل منها بطاقة مستقلة.
const List<String> _owner = <String>[
  'rakatan_ba_da_al_wudu',
  'as_siwak_inda_kulli_salah',
  'as_siwak_inda_al_qiyam_min_al_layl',
  'as_siwak_inda_dukhul_al_bayt',
  'an_nazar_ila_as_sama_inda_al_khuruj',
  'laq_al_asabi',
  'at_tanaffus_thalathan_fi_ash_shurb',
  'ash_shurb_jalisan',
  'nafd_al_firash',
  'al_wudu_qabl_an_nawm_wal_idtija_ala_ash_shiqq_al_ayman',
  'wad_al_yad_al_yumna_tahta_al_khadd',
  'at_tayammun',
  'al_intial_bil_yamin_wal_khal_bish_shimal',
  'al_akl_mimma_yalik',
  'imatat_al_adha_an_al_luqma',
  'takhmir_al_ina_wa_ikaa_as_siqa',
  'ighlaq_al_bab_wa_dhikr_allah',
  'kaff_as_sibyan_inda_al_ghurub',
  'rakatan_inda_al_qudum_min_as_safar',
  'salat_ad_duha',
  'al_witr_qabl_an_nawm',
  'at_tabassum_fi_wajh_al_akh',
  'hamd_al_atis_wa_tashmituh',
  'kaffarat_al_majlis',
  'al_bad_bis_salam',
  'al_musafaha',
  'iyadat_al_marid',
  'al_julus_fi_al_musalla_ba_da_al_fajr',
  'al_itikaf_fi_al_ashr_al_awakhir',
  'dua_al_istiftah',
];

/// حزمة أصول من القرص يُستبدل فيها ملف السنن بنص معدَّل.
class _TamperedBundle extends DiskBundle {
  _TamperedBundle(this._replacement);

  final String _replacement;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == SunanInfo.assetPath) {
      return _replacement;
    }
    return super.loadString(key, cache: cache);
  }
}

/// نسخة معدّلة من ملف السنن الخام.
JsonMap _edited(JsonMap raw, void Function(List<JsonMap> items) edit) {
  final JsonMap copy = jsonDecode(jsonEncode(raw)) as JsonMap;
  edit((copy['items'] as List<dynamic>).cast<JsonMap>());
  return copy;
}

void main() {
  final SourceCatalog sources = SourceCatalog.fromJson(loadJson('assets/data/catalogs/sources.json'));
  final JsonMap raw = loadJson(SunanInfo.assetPath);
  final SunanCatalog catalog = SunanCatalog.fromJson(raw);
  final List<SunnahItem> items = catalog.itemsInOrder;

  group('the sunan data file', () {
    test('it has the sunan id and title, at least thirty cards, ordered 1..n with no gaps', () {
      expect(catalog.id, SunanInfo.id);
      expect(catalog.title, SunanInfo.title);
      expect(catalog.schemaVersion, '2.0.0');
      expect(items.length, greaterThanOrEqualTo(30), reason: 'the owner asked for at least thirty documented sunan');
      expect(items, hasLength(47));
      expect(items.map((SunnahItem i) => i.order).toList(), List<int>.generate(items.length, (int i) => i + 1));
    });

    test('it round-trips and passes the integrity checks against the source catalog', () {
      expect(catalog.toJson(), equals(raw));
      expect(checkSunanCatalog(catalog, sources: sources), isEmpty);
    });

    test('the cards are grouped by bab in the order of the filter bar, with the pinned number in each', () {
      for (final SunnahBab bab in SunnahBab.values) {
        expect(catalog.inBab(bab), hasLength(_perBab[bab]!), reason: bab.wire);
      }
      expect(_perBab.values.reduce((int a, int b) => a + b), items.length);
      // الترتيب العام يتبع أبواب الشريط: كل باب متصل بجاره.
      final List<SunnahBab> sequence = items.map((SunnahItem i) => i.bab).toList();
      final List<SunnahBab> collapsed = <SunnahBab>[
        for (int i = 0; i < sequence.length; i++)
          if (i == 0 || sequence[i] != sequence[i - 1]) sequence[i],
      ];
      expect(collapsed, SunnahBab.values);
    });

    test('the filter bar labels are the exact ones the owner chose', () {
      expect(SunanInfo.allLabel, 'الكل');
      expect(
        SunnahBab.values.map((SunnahBab b) => b.label).toList(),
        <String>['الطهارة والصلاة', 'الطعام والشراب', 'المنزل والخروج', 'النوم واللباس', 'المجالس والآداب'],
      );
    });

    test('filterSunan keeps the file order, returns everything for null, and one bab for a bab', () {
      expect(filterSunan(items, null), items);
      for (final SunnahBab bab in SunnahBab.values) {
        final List<SunnahItem> shown = filterSunan(items, bab);
        expect(shown, hasLength(_perBab[bab]!), reason: bab.wire);
        expect(shown.every((SunnahItem i) => i.bab == bab), isTrue, reason: bab.wire);
        expect(shown.map((SunnahItem i) => i.order).toList(), orderedEquals(shown.map((SunnahItem i) => i.order).toList()..sort()));
      }
    });

    test('every sunnah the owner named is its own card', () {
      final Set<String> ids = items.map((SunnahItem i) => i.id).toSet();
      for (final String id in _owner) {
        expect(ids, contains(id));
      }
    });

    test('item ids are unique and never repeat an adhkar id, so nothing is listed twice across the app', () {
      final List<String> ids = items.map((SunnahItem i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final Set<String> adhkarIds = <String>{
        for (final AdhkarCategory c in AdhkarCategories.all)
          for (final DhikrItem d in loadCategory(c).items) d.id,
      };
      expect(ids.toSet().intersection(adhkarIds), isEmpty);
    });

    test('every title is filled; every text is vocalized and a verbatim part of one of its evidence quotes', () {
      for (final SunnahItem item in items) {
        expect(item.title.trim(), isNotEmpty, reason: item.id);
        expect(item.text.trim(), isNotEmpty, reason: item.id);
        expect(_tashkeel.hasMatch(item.text), isTrue, reason: 'vocalized: ${item.id}');
        expect(_strayMarks.hasMatch(item.text), isFalse, reason: 'clean: ${item.id}');
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(item.text)), isTrue, reason: item.id);
      }
    });

    test('every stated virtue is vocalized and a verbatim part of one of its quotes', () {
      int withVirtue = 0;
      for (final SunnahItem item in items) {
        final String? virtue = item.virtue;
        if (virtue == null) {
          continue;
        }
        withVirtue++;
        expect(_tashkeel.hasMatch(virtue), isTrue, reason: 'vocalized: ${item.id}');
        expect(_strayMarks.hasMatch(virtue), isFalse, reason: 'clean: ${item.id}');
        expect(item.evidence.any((SourceRef r) => (r.quote ?? '').contains(virtue)), isTrue, reason: item.id);
      }
      expect(withVirtue, greaterThan(3), reason: 'the stated virtues of the sunan are kept, not dropped');
    });

    test('every evidence carries a vocalized quote, a numeric hadith number and a source of the six books', () {
      for (final SunnahItem item in items) {
        expect(item.evidence, isNotEmpty, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          expect(reference.quote?.trim(), isNotEmpty, reason: item.id);
          expect(_tashkeel.hasMatch(reference.quote!), isTrue, reason: 'vocalized quote: ${item.id}');
          expect(_strayMarks.hasMatch(reference.quote!), isFalse, reason: 'clean quote: ${item.id}');
          expect(sources.byId(reference.sourceId), isNotNull, reason: '${item.id}: ${reference.sourceId}');
          expect(_sixBooks, contains(reference.sourceId), reason: item.id);
          expect(int.tryParse(reference.locator ?? ''), isNotNull, reason: 'numeric hadith number: ${item.id}');
        }
      }
    });

    test('every card records the grade of each hadith it cites, and none rests on a narration al-Albani weakened', () {
      for (final SunnahItem item in items) {
        final String grading = item.grading ?? '';
        expect(grading.trim(), isNotEmpty, reason: item.id);
        for (final SourceRef reference in item.evidence) {
          expect(grading, contains('رقم ${reference.locator}'), reason: '${item.id}: ${reference.locator}');
        }
        expect(grading, isNot(matches(RegExp('الألباني: (ضعيف|موضوع|منكر)'))), reason: item.id);
        expect(item.caution, isNull, reason: 'a card without a weak narration has no caution: ${item.id}');
      }
    });

    test('a card is a reference, not a counter: no count and no tracks in the file', () {
      for (final JsonMap item in (raw['items'] as List<dynamic>).cast<JsonMap>()) {
        expect(item.containsKey('count'), isFalse, reason: item['id'] as String);
        expect(item.containsKey('tracks'), isFalse, reason: item['id'] as String);
        expect(item.containsKey('bab'), isTrue, reason: item['id'] as String);
      }
    });

    test('every card awaits scholarly review in the data, and no internal phrase leaks into display fields', () {
      for (final SunnahItem item in items) {
        expect(item.review.status, ReviewStatus.pendingScholarlyReview, reason: item.id);
        for (final String shown in <String>[item.title, item.text, item.virtue ?? '']) {
          expect(shown, isNot(contains('المراجعة')), reason: item.id);
          expect(shown, isNot(contains('pending')), reason: item.id);
          expect(shown, isNot(contains('[?]')), reason: item.id);
          expect(shown, isNot(contains('TODO')), reason: item.id);
        }
      }
    });

    test('a number is never put in a hadith that does not state it: the bed-shaking card claims no count', () {
      final SunnahItem nafd = items.singleWhere((SunnahItem i) => i.id == 'nafd_al_firash');
      expect(_plain(nafd.text), isNot(contains('ثلاث')));
      expect(nafd.evidence.any((SourceRef r) => _plain(r.quote ?? '').contains('ثلاث')), isFalse);
      // وما نُصّ على ثلاثه في الحديث نفسه يبقى كما ورد.
      final SunnahItem breath = items.singleWhere((SunnahItem i) => i.id == 'at_tanaffus_thalathan_fi_ash_shurb');
      expect(_plain(breath.text), contains('ثلاثا'));
    });

    test('the file has the owner-chosen cards from the supplication-bearing hadiths, quoted whole', () {
      final SunnahItem sky = items.singleWhere((SunnahItem i) => i.id == 'an_nazar_ila_as_sama_inda_al_khuruj');
      expect(_plain(sky.text), contains('رفع طرفه إلى السماء'));
      expect(_plain(sky.text), contains('أعوذ بك أن أضل أو أضل'));
      final SunnahItem majlis = items.singleWhere((SunnahItem i) => i.id == 'kaffarat_al_majlis');
      expect(_plain(majlis.text), contains('سبحانك اللهم وبحمدك'));
      expect(_plain(majlis.virtue!), contains('غفر له'));
    });
  });

  group('the integrity check refuses tampering', () {
    test('a text with a word added is not a verbatim part of any quote', () {
      final SunanCatalog bad = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) => list[0]['text'] = '${list[0]['text']} وَزِيَادَةٌ'),
      );
      expect(checkSunanCatalog(bad, sources: sources), contains(startsWith('items[0].text:')));
    });

    test('a bab with no card is refused, so the filter bar never opens an empty bab', () {
      final SunanCatalog bad = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) => list.removeWhere((JsonMap i) => i['bab'] == 'gatherings_manners')),
      );
      final List<String> issues = checkSunanCatalog(bad, sources: sources);
      expect(issues.any((String m) => m.contains('gatherings_manners')), isTrue);
    });

    test('a narration graded weak by al-Albani without a caution is refused, and a caution without a grading too', () {
      final SunanCatalog weak = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) => list[1]['grading'] = 'جامع الترمذي رقم ٥٥: الألباني: ضعيف.'),
      );
      expect(checkSunanCatalog(weak, sources: sources).any((String m) => m.startsWith('items[1].caution:')), isTrue);
      final SunanCatalog orphan = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) {
          list[2].remove('grading');
          list[2]['caution'] = 'تنبيه: كلام.';
        }),
      );
      expect(checkSunanCatalog(orphan, sources: sources).any((String m) => m.startsWith('items[2].caution:')), isTrue);
    });

    test('an unknown source, a blank quote, a duplicated id and a duplicated order are refused', () {
      final SunanCatalog unknown = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) => ((list[0]['evidence'] as List<dynamic>)[0] as JsonMap)['sourceId'] = 'nowhere'),
      );
      expect(checkSunanCatalog(unknown, sources: sources).any((String m) => m.contains('Unknown sourceId')), isTrue);
      final SunanCatalog blank = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) => ((list[0]['evidence'] as List<dynamic>)[0] as JsonMap)['quote'] = ' '),
      );
      expect(checkSunanCatalog(blank, sources: sources).any((String m) => m.contains('verbatim quote')), isTrue);
      final SunanCatalog twin = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) {
          list[1]['id'] = list[0]['id'];
          list[1]['order'] = list[0]['order'];
        }),
      );
      final List<String> issues = checkSunanCatalog(twin, sources: sources);
      expect(issues.any((String m) => m.contains('Duplicate sunnah id')), isTrue);
      expect(issues.any((String m) => m.contains('Duplicate order')), isTrue);
    });

    test('a virtue that is not in any quote is refused', () {
      final SunanCatalog bad = SunanCatalog.fromJson(
        _edited(raw, (List<JsonMap> list) => list[0]['virtue'] = 'فَضْلٌ مُخْتَلَقٌ'),
      );
      expect(checkSunanCatalog(bad, sources: sources).any((String m) => m.startsWith('items[0].virtue:')), isTrue);
    });
  });

  group('the repository', () {
    test('loads the real file', () async {
      final SunanCatalog loaded = await AssetSunanRepository(AssetJsonSource(DiskBundle())).load();
      expect(loaded.items, hasLength(47));
    });

    test('refuses a tampered file with the integrity exception and shows nothing', () async {
      final JsonMap bad = _edited(raw, (List<JsonMap> list) => list[0]['text'] = 'نَصٌّ لَيْسَ فِي الشَّاهِدِ');
      final AssetSunanRepository repository = AssetSunanRepository(
        AssetJsonSource(_TamperedBundle(jsonEncode(bad))),
      );
      await expectLater(repository.load(), throwsA(isA<SunanIntegrityException>()));
    });

    test('refuses a file whose id is not the sunan id', () async {
      final JsonMap bad = jsonDecode(jsonEncode(raw)) as JsonMap;
      bad['id'] = 'adhkar_sleep';
      final AssetSunanRepository repository = AssetSunanRepository(
        AssetJsonSource(_TamperedBundle(jsonEncode(bad))),
      );
      await expectLater(repository.load(), throwsA(isA<SunanIntegrityException>()));
    });
  });
}
