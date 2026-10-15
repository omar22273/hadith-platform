// اختبارات فهرس البحث في السيرة: يجد بالعنوان والموضع والطور والبوصلة والتمهيد
// والمشاهد، وبكلمة من نص الرواية الحرفي، دون اعتبار للتشكيل ولا للترتيب.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/domain/seerah_search.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final SeerahDataset dataset = SeerahDataset.fromJson(_load('assets/data/seerah_dataset.json'));
  final SeerahSearchIndex index = SeerahSearchIndex.build(dataset);

  List<String> ids(String query) => index.search(query).map((SeerahStationModel s) => s.id).toList();

  test('an empty query returns every station in chronological order', () {
    expect(ids(''), dataset.chronological.map((SeerahStationModel s) => s.id).toList());
    expect(ids('   '), hasLength(dataset.stations.length));
  });

  test('finds by the station title, ignoring vowel marks', () {
    expect(ids('المولد في عام الفيل'), contains('birth_year_of_elephant'));
    expect(ids('حِلْفُ الفُضُولِ'), contains('hilf_al_fudul'));
  });

  test('finds by the place and by the epoch title', () {
    expect(ids('غار حراء'), contains('hira_first_revelation'));
    expect(ids('الدعوة السرية'), containsAll(<String>['hira_first_revelation', 'dar_al_arqam']));
  });

  test('finds by a word that exists only in the verbatim chapters', () {
    final SeerahStationModel badr = dataset.stationById('badr_hubab_counsel')!;
    final String quote = badr.chapters.expand((SeerahChapter c) => c.passages).map((p) => p.quote!).join(' ');
    final String sample = quote.split(RegExp(r'\s+')).firstWhere((String w) => w.length >= 6);
    expect(ids(sample), contains('badr_hubab_counsel'));
  });

  test('all the words must be present, in any order', () {
    expect(ids('مكة الفيل'), contains('birth_year_of_elephant'));
    expect(ids('الفيل مكة'), contains('birth_year_of_elephant'));
    expect(ids('الفيل كلمةلاوجودلها'), isEmpty);
  });

  test('a word that nothing contains finds nothing', () {
    expect(ids('zzzzzz'), isEmpty);
  });
}
