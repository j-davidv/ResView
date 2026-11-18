import 'dart:io';

import 'package:app/main.dart';
import 'package:app/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flows_test.dart' show TestListStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('assets/fonts/Inter-Variable.ttf');
    final loader = FontLoader('Inter')
      ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
    for (final path in [
      'assets/branding/resview-rv-clean.svg',
      for (final glyph in DesignGlyph.values) 'assets/icons/${glyph.asset}.svg',
    ]) {
      await SvgAssetLoader(path).loadBytes(null);
    }
  });

  void configure(
    WidgetTester tester,
    Size size,
    Brightness brightness,
    double scale,
  ) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('approved screen layouts in ${brightness.name}', (
      tester,
    ) async {
      configure(tester, const Size(412, 892), brightness, 1);
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await settle(tester);
      final frame = find.byType(MaterialApp);
      await expectLater(
        frame,
        matchesGoldenFile('goldens/welcome-${brightness.name}.png'),
      );
      final skip = find.text('Skip introduction');
      await tester.ensureVisible(skip);
      await tester.tap(skip);
      await settle(tester);
      await expectLater(
        frame,
        matchesGoldenFile('goldens/updates-${brightness.name}.png'),
      );
      for (final (tab, file) in [
        ('Results', 'results'),
        ('Check name', 'check-name'),
        ('Settings', 'settings'),
      ]) {
        await tester.tap(find.widgetWithText(NavigationDestination, tab));
        await settle(tester);
        await expectLater(
          frame,
          matchesGoldenFile('goldens/$file-${brightness.name}.png'),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('layout wraps at double text in ${brightness.name}', (
      tester,
    ) async {
      configure(tester, const Size(390, 844), brightness, 2);
      FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'});
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await settle(tester);
      final frame = find.byType(MaterialApp);
      await expectLater(
        frame,
        matchesGoldenFile('goldens/unavailable-${brightness.name}-200.png'),
      );
      await tester.tap(find.text('Check name').last);
      await settle(tester);
      await expectLater(
        frame,
        matchesGoldenFile('goldens/check-name-${brightness.name}-200.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
