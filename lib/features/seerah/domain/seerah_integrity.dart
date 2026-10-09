// فحص سلامة محطات السيرة قبل عرضها: معرّفات وترتيب فريدان، ونصوص مشاهد
// غير فارغة، وشاهد منقول بنصه لكل مشهد من المشاهد الثلاثة، ومصادر معروفة.

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/models/source_ref.dart';
import '../data/models/seerah_station.dart';

/// يعيد قائمة المشكلات؛ الفارغة تعني أن الملف سليم.
List<String> checkSeerahDataset(SeerahDataset dataset, {SourceCatalog? sources}) {
  final List<String> issues = <String>[];
  final Set<String> ids = <String>{};
  final Set<int> orders = <int>{};
  for (int index = 0; index < dataset.stations.length; index++) {
    final SeerahStationModel station = dataset.stations[index];
    final String path = 'stations[$index]';
    if (!ids.add(station.id)) {
      issues.add('$path: Duplicate station id "${station.id}".');
    }
    if (!orders.add(station.order)) {
      issues.add('$path: Duplicate order ${station.order}.');
    }
    final Map<String, String> texts = <String, String>{
      'title': station.title,
      'sceneDescription': station.sceneDescription,
      'challenge': station.challenge,
      'propheticDecision': station.propheticDecision,
    };
    texts.forEach((String field, String value) {
      if (value.trim().isEmpty) {
        issues.add('$path.$field: must not be blank.');
      }
    });
    for (final SeerahScene scene in SeerahScene.values) {
      if (station.evidenceFor(scene).isEmpty) {
        issues.add('$path: No evidence for scene "${scene.wire}".');
      }
    }
    for (int e = 0; e < station.evidence.length; e++) {
      final SourceRef source = station.evidence[e].source;
      final String quote = source.quote ?? '';
      if (quote.trim().isEmpty) {
        issues.add('$path.evidence[$e]: Evidence must carry its verbatim quote.');
      }
      final SourceCatalog? catalog = sources;
      if (catalog != null && catalog.byId(source.sourceId) == null) {
        issues.add('$path.evidence[$e]: Unknown sourceId "${source.sourceId}".');
      }
    }
  }
  return issues;
}
