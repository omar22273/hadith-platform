// اختبارات مشاركة الحديث صورةً: التقاط PNG بدقة عالية، وبطاقة الاقتباس بمتنها
// المشكول حرفاً بحرف وبلون الثيم النشط، وتدفق الزر «مشاركة كصورة».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/share/png_capture.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/theme/app_palette.dart';
import 'package:hadith_platform/features/daily_session/presentation/widgets/hadith_quote_card.dart';
import 'package:hadith_platform/features/hadith/application/hadith_providers.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/journey/presentation/widgets/wird_node.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

int _bigEndian(List<int> bytes, int offset) {
  return (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
}

const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

Future<ProviderContainer> _openShareSheet(
  WidgetTester tester,
  FakeShareService share, {
  Map<String, String>? stored,
  Size size = const Size(412, 3000),
}) async {
  final ProviderContainer container = await pumpApp(
    tester,
    size: size,
    shareService: share,
    stored: stored,
  );
  await tester.tap(find.descendant(of: find.byType(WirdNodeView), matching: find.text('الأعمال بالنيات')).first);
  await settle(tester);
  await tester.tap(find.text('بدء وِرد التثبيت اللمسي'));
  await settle(tester);
  await tester.tap(find.byTooltip('مشاركة الحديث'));
  await settle(tester);
  return container;
}

/// يضغط الزر داخل runAsync ليعمل التقاط الصورة على الزمن الحقيقي.
Future<void> _tapShareAsImage(WidgetTester tester, FakeShareService share) async {
  await tester.runAsync(() async {
    tester.widget<FilledButton>(find.byKey(const ValueKey<String>('share-as-image'))).onPressed!();
    for (int i = 0; i < 100 && share.files.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await settle(tester);
}

void main() {
  testWidgets('captureBoundaryPng returns a PNG scaled by the pixel ratio', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(width: 120, height: 60, child: ColoredBox(color: Color(0xFF00AA00))),
          ),
        ),
      ),
    );

    final List<int> png = (await tester.runAsync(() => captureBoundaryPng(key, pixelRatio: 2)))!;
    expect(png.sublist(0, 8), _pngSignature);
    expect(_bigEndian(png, 16), 240);
    expect(_bigEndian(png, 20), 120);
  });

  testWidgets('a very tall capture is scaled down to stay within GPU limits', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(200, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(width: 100, height: 4000, child: ColoredBox(color: Color(0xFF123456))),
          ),
        ),
      ),
    );

    final List<int> png = (await tester.runAsync(() => captureBoundaryPng(key, pixelRatio: 3)))!;
    expect(_bigEndian(png, 20), lessThanOrEqualTo(maxCaptureDimension.round() + 1));
    expect(_bigEndian(png, 20), greaterThan(6000));
  });

  testWidgets('capturing a key that is not on a repaint boundary fails loudly', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: SizedBox(key: key)));
    await expectLater(captureBoundaryPng(key), throwsStateError);
  });

  testWidgets('the share sheet previews the quote card with the vocalized matn verbatim', (WidgetTester tester) async {
    final FakeShareService share = FakeShareService();
    final ProviderContainer container = await _openShareSheet(tester, share);
    final HadithDailyModel hadith = await container.read(hadithProvider('nawawi40_001').future);

    final Finder card = find.byType(HadithQuoteCard);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(hadith.matn.fullText)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining(hadith.matn.takhrij.displayLabel)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(HadithQuoteCard.platformName)), findsOneWidget);
    expect(tester.getSize(card).width, HadithQuoteCard.width);

    // الأزرار الثلاثة: نسخ، ومشاركة كصورة بجانبه، ومشاركة كنص.
    expect(find.text('نسخ'), findsOneWidget);
    expect(find.text('مشاركة كصورة'), findsOneWidget);
    expect(find.text('مشاركة كنص'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a normal phone the whole card and every button fit without scrolling', (WidgetTester tester) async {
    await _openShareSheet(tester, FakeShareService(), size: const Size(412, 915));

    final Rect imageButton = tester.getRect(find.byKey(const ValueKey<String>('share-as-image')));
    final Rect textButton = tester.getRect(find.text('مشاركة كنص'));
    expect(imageButton.bottom, lessThanOrEqualTo(915));
    expect(textButton.bottom, lessThanOrEqualTo(915));
    // المعاينة مصغّرة لتظهر البطاقة كاملة: أعلى من الأزرار وأصغر من المقاس الأصلي.
    final Rect preview = tester.getRect(find.byType(FittedBox).last);
    expect(preview.bottom, lessThanOrEqualTo(imageButton.top));
    expect(preview.width, lessThan(HadithQuoteCard.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sharing as an image sends a high-resolution PNG of the card', (WidgetTester tester) async {
    final FakeShareService share = FakeShareService();
    await _openShareSheet(tester, share);
    final double cardHeight = tester.getSize(find.byType(HadithQuoteCard)).height;

    await _tapShareAsImage(tester, share);

    expect(share.files, hasLength(1));
    final SharedFile file = share.files.single;
    expect(file.fileName, 'nawawi40_001.png');
    expect(file.mimeType, 'image/png');
    expect(file.bytes.sublist(0, 8), _pngSignature);
    expect(_bigEndian(file.bytes, 16), (HadithQuoteCard.width * 3).round(), reason: '1080 px wide');
    expect(_bigEndian(file.bytes, 20), closeTo(cardHeight * 3, 2));
    expect(find.byType(HadithQuoteCard), findsNothing, reason: 'the sheet closes after sharing');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed image share is explained inside the sheet and the text options remain', (WidgetTester tester) async {
    final FakeShareService share = FakeShareService()..failing = true;
    await _openShareSheet(tester, share);

    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byKey(const ValueKey<String>('share-as-image'))).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await settle(tester);

    expect(find.byKey(const ValueKey<String>('share-image-error')), findsOneWidget);
    expect(find.text('مشاركة كنص'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card follows the active theme: ivory linen by day, navy by night', (WidgetTester tester) async {
    BoxDecoration cardBackground() {
      final Finder boxes = find.descendant(of: find.byType(HadithQuoteCard), matching: find.byType(DecoratedBox));
      return tester.widget<DecoratedBox>(boxes.first).decoration as BoxDecoration;
    }

    final FakeShareService dayShare = FakeShareService();
    await _openShareSheet(tester, dayShare, stored: <String, String>{StorageKeys.themeMode: 'parchment'});
    expect((cardBackground().gradient! as LinearGradient).colors.first, AppPalette.light.paper);
    expect(AppPalette.light.paper, const Color(0xFFF8F6F0));
  });

  testWidgets('in the dark theme the card uses the navy palette', (WidgetTester tester) async {
    final FakeShareService share = FakeShareService();
    await _openShareSheet(tester, share, stored: <String, String>{StorageKeys.themeMode: 'dark'});

    final Finder boxes = find.descendant(of: find.byType(HadithQuoteCard), matching: find.byType(DecoratedBox));
    final BoxDecoration decoration = tester.widget<DecoratedBox>(boxes.first).decoration as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors.first, AppPalette.dark.paper);
    expect(AppPalette.dark.paper, const Color(0xFF0F172A));
  });
}
