import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    var dir = File(Platform.resolvedExecutable).parent;
    File? font;
    while (dir.parent.path != dir.path) {
      final candidate = File('${dir.path}/material_fonts/Roboto-Regular.ttf');
      if (await candidate.exists()) {
        font = candidate;
        break;
      }
      dir = dir.parent;
    }
    if (font == null) {
      throw StateError(
        'Flutter SDK Roboto font is required for visual verification.',
      );
    }
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('${font.parent.path}/materialicons-regular.otf')
                .readAsBytes(),
          ),
        ),
      );
    await iconLoader.load();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'render normal unavailable interface ${dark ? 'dark' : 'light'} at double text',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(const ExamApp());
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/unavailable-${dark ? 'dark' : 'light'}-200.png',
          ),
        );
        await tester.tap(find.text('Check name').last);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/check-name-${dark ? 'dark' : 'light'}-200.png',
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
