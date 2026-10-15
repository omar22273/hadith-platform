// فحص سلامة محطات السيرة قبل عرضها.
//
// الأطوار: من ثمانية إلى عشرة، بمعرّفات وأرقام فريدة مرتبة، ولكل محطة طور معروف
// لا يسبق طور المحطة التي قبلها في الترتيب الزمني.
//
// المحطات: معرّفات وترتيب فريدان، وطبقة المعايشة والموقف (المشهد والمأزق والقرار)
// تُكتب كلها أو لا تُكتب، وحين تُكتب يلزمها شاهد منقول بنصه لكل مشهد، وتمهيدها
// وسؤال الشورى لا يصحان بدونها. شريط البوصلة: السنة أو العمر يلزمهما شاهد، ولا
// شاهد بلا ما يشهد له. الربط بالسابقة لا يكون في أول محطة، والتمهيد للتالية لا
// يكون في آخر محطة. وللمحطة فصل واحد على الأقل، في كل فصل مقطع منقول بنصه وله
// موضعه. وخيارات المأزق (dilemma_options) إن وُجدت متمايزة وكل منها جزء حرفي من
// شاهد مشهد المأزق.
//
// مصدر كل شاهد ومقطع يجب أن يكون في فهرس المصادر حين يُمرَّر الفهرس.

import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/models/source_ref.dart';
import '../data/models/seerah_station.dart';

/// أقل عدد من الأطوار التاريخية الكبرى.
const int seerahMinEpochs = 8;

/// أكثر عدد من الأطوار التاريخية الكبرى.
const int seerahMaxEpochs = 10;

bool _blank(String? value) => value == null || value.trim().isEmpty;

/// يعيد قائمة المشكلات؛ الفارغة تعني أن الملف سليم.
List<String> checkSeerahDataset(SeerahDataset dataset, {SourceCatalog? sources}) {
  final List<String> issues = <String>[];

  final Map<String, int> epochRank = <String, int>{};
  final Set<int> numbers = <int>{};
  if (dataset.epochs.length < seerahMinEpochs || dataset.epochs.length > seerahMaxEpochs) {
    issues.add(
      'epochs: Expected $seerahMinEpochs to $seerahMaxEpochs epochs, found ${dataset.epochs.length}.',
    );
  }
  int? previousNumber;
  for (int index = 0; index < dataset.epochs.length; index++) {
    final SeerahEpochInfo epoch = dataset.epochs[index];
    final String path = 'epochs[$index]';
    if (epochRank.containsKey(epoch.id)) {
      issues.add('$path: Duplicate epoch id "${epoch.id}".');
    }
    epochRank[epoch.id] = epoch.number;
    if (!numbers.add(epoch.number)) {
      issues.add('$path: Duplicate epoch number ${epoch.number}.');
    }
    if (previousNumber != null && epoch.number <= previousNumber) {
      issues.add('$path: Epoch numbers must ascend.');
    }
    previousNumber = epoch.number;
    if (_blank(epoch.title)) {
      issues.add('$path.title: must not be blank.');
    }
  }

  final CatalogCheck sourceCheck = CatalogCheck(sources, issues);
  final List<SeerahStationModel> chronological = dataset.chronological;
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
    if (_blank(station.title)) {
      issues.add('$path.title: must not be blank.');
    }
    final int position = chronological.indexWhere((SeerahStationModel s) => s.id == station.id);
    if (!epochRank.containsKey(station.epochId)) {
      issues.add('$path.epoch_id: Unknown epoch "${station.epochId}".');
    } else if (position > 0) {
      final int? before = epochRank[chronological[position - 1].epochId];
      if (before != null && epochRank[station.epochId]! < before) {
        issues.add('$path.epoch_id: The epoch precedes the epoch of the previous station.');
      }
    }

    // طبقة المعايشة والموقف: كلها أو لا شيء.
    final Map<String, String?> layer = <String, String?>{
      'sceneDescription': station.sceneDescription,
      'challenge': station.challenge,
      'propheticDecision': station.propheticDecision,
    };
    final int written = layer.values.where((String? value) => value != null).length;
    if (written != 0 && written != layer.length) {
      issues.add('$path: The experience layer is incomplete; write the scene, the dilemma and the decision together or none.');
    }
    layer.forEach((String field, String? value) {
      if (value != null && _blank(value)) {
        issues.add('$path.$field: must not be blank.');
      }
    });
    final bool hasLayer = written == layer.length;
    final Map<String, String?> editorial = <String, String?>{
      'hook': station.hook,
      'shura_question': station.shuraQuestion,
      'previous_link': station.previousLink,
      'next_hook': station.nextHook,
    };
    editorial.forEach((String field, String? value) {
      if (value != null && _blank(value)) {
        issues.add('$path.$field: must not be blank when present.');
      }
    });
    if (!hasLayer && (station.hook != null || station.shuraQuestion != null)) {
      issues.add('$path: hook and shura_question need the experience layer.');
    }
    if (hasLayer) {
      for (final SeerahScene scene in SeerahScene.values) {
        if (station.evidenceFor(scene).isEmpty) {
          issues.add('$path: No evidence for scene "${scene.wire}".');
        }
      }
    } else if (station.evidence.isNotEmpty) {
      issues.add('$path: Scene evidence without an experience layer.');
    }
    for (int e = 0; e < station.evidence.length; e++) {
      sourceCheck.reference(station.evidence[e].source, '$path.evidence[$e]');
    }

    // خيارات المأزق: حرفية من شاهد المأزق.
    final List<String>? options = station.dilemmaOptions;
    if (options != null) {
      final List<String> challengeQuotes = <String>[
        for (final SeerahEvidence item in station.evidenceFor(SeerahScene.challenge)) item.source.quote ?? '',
      ];
      if (options.length < 2 || options.toSet().length != options.length) {
        issues.add('$path.dilemma_options: needs at least two distinct options.');
      }
      for (int o = 0; o < options.length; o++) {
        final String option = options[o].trim();
        if (option.isEmpty || !challengeQuotes.any((String quote) => quote.contains(option))) {
          issues.add(
            '$path.dilemma_options[$o]: The option must be a verbatim part of a challenge-scene quote.',
          );
        }
      }
    }

    // شريط البوصلة.
    final List<SourceRef> basis = station.compassBasis ?? const <SourceRef>[];
    if (station.hasCompassFacts && basis.isEmpty) {
      issues.add('$path: year_label or age_label without compass_basis.');
    }
    if (!station.hasCompassFacts && basis.isNotEmpty) {
      issues.add('$path: compass_basis without year_label or age_label.');
    }
    for (final String? label in <String?>[station.yearLabel, station.ageLabel]) {
      if (label != null && _blank(label)) {
        issues.add('$path: A compass label must not be blank when present.');
      }
    }
    for (int b = 0; b < basis.length; b++) {
      sourceCheck.quoted(basis[b], '$path.compass_basis[$b]');
    }

    // الربط بين المحطات.
    if (position == 0 && station.previousLink != null) {
      issues.add('$path.previous_link: The first station has no previous station.');
    }
    if (position == chronological.length - 1 && station.nextHook != null) {
      issues.add('$path.next_hook: The last station has no next station.');
    }

    // فصول الرواية المطولة.
    if (station.chapters.isEmpty) {
      issues.add('$path.chapters: needs at least one chapter.');
    }
    final Set<String> chapterIds = <String>{};
    for (int c = 0; c < station.chapters.length; c++) {
      final SeerahChapter chapter = station.chapters[c];
      final String chapterPath = '$path.chapters[$c]';
      if (!chapterIds.add(chapter.id)) {
        issues.add('$chapterPath: Duplicate chapter id "${chapter.id}".');
      }
      if (_blank(chapter.title)) {
        issues.add('$chapterPath.title: must not be blank.');
      }
      if (chapter.passages.isEmpty) {
        issues.add('$chapterPath.passages: needs at least one passage.');
      }
      for (int p = 0; p < chapter.passages.length; p++) {
        sourceCheck.quoted(chapter.passages[p], '$chapterPath.passages[$p]', located: true);
      }
    }
  }
  return issues;
}

/// فحص مصدر الإحالة ونصها وموضعها، يضيف مشكلاته إلى القائمة المشتركة.
class CatalogCheck {
  const CatalogCheck(this.catalog, this.issues);

  /// فهرس المصادر؛ null يعطل فحص المعرّفات.
  final SourceCatalog? catalog;

  /// قائمة المشكلات المشتركة.
  final List<String> issues;

  /// شاهد مشهد: نص منقول، ومصدر معروف.
  void reference(SourceRef source, String path) {
    quoted(source, path, located: true);
  }

  /// إحالة بنص منقول، وموضعها إن طُلب [located].
  void quoted(SourceRef source, String path, {bool located = false}) {
    if (_blank(source.quote)) {
      issues.add('$path: Evidence must carry its verbatim quote.');
    }
    if (located && _blank(source.locator)) {
      issues.add('$path: The quote must carry its locator.');
    }
    final SourceCatalog? known = catalog;
    if (known != null && known.byId(source.sourceId) == null) {
      issues.add('$path: Unknown sourceId "${source.sourceId}".');
    }
  }
}
