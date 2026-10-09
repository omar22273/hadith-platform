// اختبارات واحة الاستذكار وكاميرا الخريطة: متى تستحق الواحة، وأن الخلط ثابت
// ومختلف عن الترتيب الصحيح، وتقييم المحاولة، وحصر مصفوفة الكاميرا في الحدود.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/domain/seerah_checkpoint.dart';
import 'package:hadith_platform/features/seerah/presentation/widgets/seerah_map_view.dart';

void main() {
  final SeerahDataset dataset = SeerahDataset.fromJson(
    asJsonMap(jsonDecode(File('assets/data/seerah_dataset.json').readAsStringSync()), 'seerah'),
  );
  final List<SeerahStationModel> stations = dataset.chronological;

  test('a checkpoint is due after every fifth station except the last', () {
    expect(SeerahCheckpoint.isDueAfter(3, 12), isFalse);
    expect(SeerahCheckpoint.isDueAfter(4, 12), isTrue);
    expect(SeerahCheckpoint.isDueAfter(9, 12), isTrue);
    expect(SeerahCheckpoint.isDueAfter(11, 12), isFalse);
    expect(SeerahCheckpoint.isDueAfter(4, 5), isFalse);
  });

  test('the checkpoint holds the last five stations in file order, shuffled differently', () {
    final SeerahCheckpoint? checkpoint = SeerahCheckpoint.after(stations, 4);
    expect(checkpoint, isNotNull);
    expect(checkpoint!.stations.map((SeerahStationModel s) => s.id), stations.take(5).map((SeerahStationModel s) => s.id));
    expect(checkpoint.shuffled.length, 5);
    expect(
      checkpoint.shuffled.map((SeerahStationModel s) => s.id).toSet(),
      checkpoint.stations.map((SeerahStationModel s) => s.id).toSet(),
    );
    expect(checkpoint.isSolved(checkpoint.shuffled), isFalse);
    expect(SeerahCheckpoint.after(stations, 3), isNull);
  });

  test('the shuffle is stable for the same group', () {
    final List<String> first =
        SeerahCheckpoint.after(stations, 9)!.shuffled.map((SeerahStationModel s) => s.id).toList();
    final List<String> second =
        SeerahCheckpoint.after(stations, 9)!.shuffled.map((SeerahStationModel s) => s.id).toList();
    expect(first, second);
  });

  test('evaluate marks the right positions and isSolved needs all of them', () {
    final SeerahCheckpoint checkpoint = SeerahCheckpoint.after(stations, 4)!;
    final List<SeerahStationModel> swapped = List<SeerahStationModel>.of(checkpoint.stations);
    final SeerahStationModel first = swapped[0];
    swapped[0] = swapped[1];
    swapped[1] = first;
    expect(checkpoint.evaluate(swapped), <bool>[false, false, true, true, true]);
    expect(checkpoint.isSolved(swapped), isFalse);
    expect(checkpoint.isSolved(checkpoint.stations), isTrue);
  });

  test('the camera matrix centers a point and stays inside the canvas', () {
    const Size size = Size(400, 300);
    final Matrix4 centered = seerahCameraMatrix(at: const Offset(200, 150), size: size, scale: 2);
    expect(centered.getMaxScaleOnAxis(), closeTo(2, 1e-9));
    // نقطة الوسط تبقى في الوسط.
    final Offset mapped = MatrixUtils.transformPoint(centered, const Offset(200, 150));
    expect(mapped.dx, closeTo(200, 1e-9));
    expect(mapped.dy, closeTo(150, 1e-9));
    // نقطة عند الزاوية لا تُخرج اللوحة من الإطار.
    final Matrix4 corner = seerahCameraMatrix(at: Offset.zero, size: size, scale: 3);
    expect(MatrixUtils.transformPoint(corner, Offset.zero), Offset.zero);
    final Matrix4 far = seerahCameraMatrix(at: const Offset(400, 300), size: size, scale: 3);
    final Offset bottomRight = MatrixUtils.transformPoint(far, const Offset(400, 300));
    expect(bottomRight.dx, closeTo(400, 1e-9));
    expect(bottomRight.dy, closeTo(300, 1e-9));
  });
}
