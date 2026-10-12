// اختبارات طبقة الرواية المفصلة في السيرة: حقل detailed_narrative اختياري لا
// يكسر الملفات القائمة ولا يغيّر تحويلها ذهاباً وإياباً، وشاشة «الرواية الكاملة
// وتفاصيل الحدث» تعرضه فقرات بخط تراثي يتبع حجم الخط في الإعدادات، وتعود إلى
// المشاهد الموثقة حين يغيب.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/core/preferences/reading_preferences.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/domain/seerah_integrity.dart';
import 'package:hadith_platform/features/seerah/presentation/seerah_narrative_screen.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

const String _first = 'الفقرة الأولى من الرواية.';
const String _second = 'الفقرة الثانية من الرواية.';

/// محطة من الملف الحقيقي مضافاً إليها رواية تجريبية للاختبار فقط.
SeerahStationModel _withNarrative(SeerahStationModel base, String narrative) {
  return SeerahStationModel.fromJson(<String, dynamic>{
    ...base.toJson(),
    'detailed_narrative': narrative,
  });
}

void main() {
  final JsonMap raw = _load('assets/data/seerah_dataset.json');
  final SeerahDataset dataset = SeerahDataset.fromJson(raw);
  final SourceCatalog sources = SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json'));
  final SeerahStationModel base = dataset.chronological.first;

  group('the optional detailed_narrative field', () {
    test('existing files carry none, stay valid and round-trip unchanged', () {
      for (final SeerahStationModel station in dataset.stations) {
        expect(station.detailedNarrative, isNull, reason: station.id);
        expect(station.hasDetailedNarrative, isFalse);
        expect(station.narrativeParagraphs, isEmpty);
        expect(station.toJson().containsKey('detailed_narrative'), isFalse);
      }
      expect(dataset.toJson(), equals(raw));
      expect(checkSeerahDataset(dataset, sources: sources), isEmpty);
    });

    test('a narrative is read, split into paragraphs and written back under the same key', () {
      final SeerahStationModel station = _withNarrative(base, '$_first\n\n$_second\n   \n\nالثالثة.');
      expect(station.hasDetailedNarrative, isTrue);
      expect(station.narrativeParagraphs, <String>[_first, _second, 'الثالثة.']);
      expect(station.toJson()['detailed_narrative'], '$_first\n\n$_second\n   \n\nالثالثة.');
      expect(SeerahStationModel.fromJson(station.toJson()), station);
      expect(station, isNot(base), reason: 'equality takes the narrative into account');
    });

    test('a blank narrative shows nothing and is flagged by the integrity check', () {
      final SeerahStationModel blank = _withNarrative(base, '  \n ');
      expect(blank.hasDetailedNarrative, isFalse);
      final SeerahDataset tampered = SeerahDataset(
        schemaVersion: dataset.schemaVersion,
        id: dataset.id,
        title: dataset.title,
        stations: <SeerahStationModel>[blank],
      );
      expect(checkSeerahDataset(tampered, sources: sources), contains(contains('detailed_narrative')));
    });

    test('the JSON schema allows the key but never requires it', () {
      final JsonMap schema = _load('assets/data/schema/hadith_platform.schema.json');
      final JsonMap station = asJsonMap(asJsonMap(schema['\$defs'], 'defs')['SeerahStationModel'], 'station');
      final JsonMap properties = asJsonMap(station['properties'], 'properties');
      expect(properties.containsKey('detailed_narrative'), isTrue);
      expect(station['required'] as List<dynamic>, isNot(contains('detailed_narrative')));
      expect(station['additionalProperties'], isFalse);
    });
  });

  group('the full-narrative screen', () {
    Future<ProviderContainer> openScreen(
      WidgetTester tester, {
      required SeerahStationModel station,
      Map<String, String>? stored,
      Size size = const Size(412, 1800),
    }) async {
      final ProviderContainer container = await pumpApp(tester, size: size, stored: stored);
      final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (BuildContext _) => SeerahNarrativeScreen(station: station)),
      );
      await settle(tester);
      return container;
    }

    double fontSizeOf(WidgetTester tester, String text) {
      final SelectableText widget = tester.widget<SelectableText>(
        find.byWidgetPredicate((Widget w) => w is SelectableText && w.data == text),
      );
      return widget.style!.fontSize!;
    }

    testWidgets('shows the paragraphs in a heritage font tied to the settings font size', (WidgetTester tester) async {
      final ProviderContainer container = await openScreen(
        tester,
        station: _withNarrative(base, '$_first\n\n$_second'),
        stored: <String, String>{
          StorageKeys.readingPreferences: jsonEncode(<String, Object>{
            'matnFontSize': 38,
            'textScale': 1,
            'matnFont': 'amiri',
          }),
        },
      );

      expect(find.byKey(const ValueKey<String>('narrative-body')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('narrative-pending-note')), findsNothing);
      expect(find.text(_first), findsOneWidget);
      expect(find.text(_second), findsOneWidget);
      for (final SeerahScene scene in SeerahScene.values) {
        expect(find.byKey(ValueKey<String>('narrative-scene-${scene.wire}')), findsOneWidget);
      }

      // خط أميري التراثي، وحجمه 21 مضروباً في معامل الإعدادات (38 ÷ 27).
      final SelectableText paragraph = tester.widget<SelectableText>(find.widgetWithText(SelectableText, _first));
      expect(paragraph.style!.fontFamily, 'Amiri');
      expect(fontSizeOf(tester, _first), closeTo(21 * 38 / 27, 0.01));

      // تغيير الحجم من الإعدادات (المتحكم نفسه) ينعكس فوراً على الرواية.
      container.read(readingPreferencesProvider.notifier).setMatnFontSize(22);
      await settle(tester);
      expect(fontSizeOf(tester, _first), closeTo(21 * 22 / 27, 0.01));
      expect(fontSizeOf(tester, _second), closeTo(21 * 22 / 27, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the slider on the screen moves the same preference the settings use, and saves it', (WidgetTester tester) async {
      final ProviderContainer container = await openScreen(
        tester,
        station: _withNarrative(base, _first),
        stored: <String, String>{
          StorageKeys.readingPreferences: jsonEncode(<String, Object>{
            'matnFontSize': 30,
            'textScale': 1,
            'matnFont': 'amiri',
          }),
        },
      );
      expect(container.read(readingPreferencesProvider).matnFontSize, 30);

      await tester.drag(find.byKey(const ValueKey<String>('narrative-font-slider')), const Offset(120, 0));
      await settle(tester);

      final double size = container.read(readingPreferencesProvider).matnFontSize;
      expect(size, isNot(30));
      expect(fontSizeOf(tester, _first), closeTo(21 * size / 27, 0.01));
      final String saved = container.read(keyValueStoreProvider).readString(StorageKeys.readingPreferences)!;
      expect((jsonDecode(saved) as Map<String, dynamic>)['matnFontSize'], size);
    });

    testWidgets('without a narrative the verified scenes stand alone, with a note', (WidgetTester tester) async {
      await openScreen(tester, station: base);

      expect(find.byKey(const ValueKey<String>('narrative-pending-note')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('narrative-body')), findsNothing);
      expect(find.text(base.sceneDescription), findsOneWidget);
      expect(find.text(base.challenge), findsOneWidget);
      expect(find.text(base.propheticDecision), findsOneWidget);
      expect(find.text('بانتظار المراجعة العلمية'), findsOneWidget);
    });

    testWidgets('a long narrative scrolls smoothly down to the last scene on a small phone', (WidgetTester tester) async {
      final String longNarrative = List<String>.generate(30, (int i) => 'فقرة طويلة رقم $i من الرواية.').join('\n\n');
      await openScreen(
        tester,
        size: const Size(360, 640),
        station: _withNarrative(base, longNarrative),
      );

      final Finder scrollable = find.descendant(
        of: find.byKey(const ValueKey<String>('narrative-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('narrative-scene-decision')),
        400,
        scrollable: scrollable,
      );
      expect(find.byKey(const ValueKey<String>('narrative-scene-decision')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
