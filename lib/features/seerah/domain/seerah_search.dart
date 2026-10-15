// فهرس البحث في محطات السيرة: يُبنى مرة واحدة من الملف، فيُطبَّع نص كل محطة
// مرة واحدة ثم يبحث كل حرف يكتبه المستخدم بلا إعادة تطبيع.
//
// يشمل البحثُ عنوانَ المحطة وموضعها وطورها وبوصلتها وتمهيدها ومشاهدها وعناوين
// فصولها ونصوص مقاطعها الحرفية؛ فكلمة من متن ابن هشام تدل على المحطة التي وردت فيها.

import '../../../core/content/models/source_ref.dart';
import '../../../core/text/arabic_search.dart';
import '../data/models/seerah_station.dart';

/// فهرس البحث.
class SeerahSearchIndex {
  /// يبني الفهرس من ملف المحطات.
  factory SeerahSearchIndex.build(SeerahDataset dataset) {
    final Map<String, String> haystacks = <String, String>{};
    for (final SeerahStationModel station in dataset.chronological) {
      final StringBuffer text = StringBuffer()
        ..write(station.title)
        ..write(' ')
        ..write(station.place.name)
        ..write(' ')
        ..write(dataset.epochOf(station)?.title ?? '')
        ..write(' ')
        ..write(station.timeLabel ?? '')
        ..write(' ')
        ..write(station.yearLabel ?? '')
        ..write(' ')
        ..write(station.ageLabel ?? '')
        ..write(' ')
        ..write(station.hook ?? '')
        ..write(' ')
        ..write(station.shuraQuestion ?? '')
        ..write(' ')
        ..write(station.sceneDescription ?? '')
        ..write(' ')
        ..write(station.challenge ?? '')
        ..write(' ')
        ..write(station.propheticDecision ?? '');
      for (final SeerahChapter chapter in station.chapters) {
        text
          ..write(' ')
          ..write(chapter.title);
        for (final SourceRef passage in chapter.passages) {
          text
            ..write(' ')
            ..write(passage.quote ?? '');
        }
      }
      haystacks[station.id] = ArabicSearch.normalize(text.toString());
    }
    return SeerahSearchIndex._(dataset.chronological, haystacks);
  }

  const SeerahSearchIndex._(this._stations, this._haystacks);

  final List<SeerahStationModel> _stations;
  final Map<String, String> _haystacks;

  /// المحطات التي تحوي كل كلمات [query] بلا اعتبار للترتيب، بترتيبها الزمني؛
  /// الاستعلام الفارغ يعيدها كلها.
  List<SeerahStationModel> search(String query) {
    final String needle = ArabicSearch.normalize(query);
    if (needle.isEmpty) {
      return _stations;
    }
    final List<String> words = needle.split(' ');
    return List<SeerahStationModel>.unmodifiable(
      _stations.where((SeerahStationModel station) {
        final String hay = _haystacks[station.id] ?? '';
        return words.every(hay.contains);
      }),
    );
  }
}
