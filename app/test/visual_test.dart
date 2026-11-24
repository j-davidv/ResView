import 'dart:io';

import 'package:app/main.dart';
import 'package:app/domain/models.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/design.dart';
import 'package:app/ui/results.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'advisories_test.dart' show AdvisoryRepository, selection, snapshot;
import 'flows_test.dart' show TestListStore, TestRepository;

class _VisualTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _VisualTestBinding();
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  for (final brightness in Brightness.values) {
    testWidgets('Teachers awaiting result target in ${brightness.name}', (
      tester,
    ) async {
      configure(tester, const Size(390, 844), brightness, 1);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ResultsScreen(
                version: null,
                now: DateTime.utc(2026, 11, 24),
                monitorStatus: ResultMonitorStatus(
                  freshness: 'fresh',
                  lastSuccessfulCheckUtc: DateTime.utc(2026, 11, 23, 23, 30),
                ),
                sitting: Sitting(
                  id: 'teachers-2026-09-20',
                  examId: 'teachers',
                  start: DateTime.utc(2026, 9, 20),
                  end: DateTime.utc(2026, 9, 20),
                  type: 'domestic',
                  location: '',
                  categories: {'elementary': 'Elementary'},
                  targetReleaseDate: DateTime.utc(2026, 11, 27),
                  catalogUrl: Uri.parse(
                    'https://www.prc.gov.ph/2026-schedule-examination',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Awaiting results'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/awaiting-${brightness.name}.png'),
      );
      expect(tester.takeException(), isNull);
    });

    for (final size in [const Size(412, 892), const Size(900, 1000)]) {
      for (final scale in [1.0, 2.0]) {
        final phone = size.width < 600;
        testWidgets(
          'Updates disabled exam flow at ${size.width} dp, ${brightness.name}, ${scale}x',
          (tester) async {
            configure(tester, size, brightness, scale);
            FlutterSecureStorage.setMockInitialValues({});
            final repository = TestRepository(
              PublicationState.checkingAvailable,
            );
            await tester.pumpWidget(
              ExamApp(
                repository: repository,
                listStore: TestListStore(),
                advisoryPilot: false,
              ),
            );
            await settle(tester);
            Future<void> capture(String name) => expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/$name-${brightness.name}.png'),
            );
            if (phone && scale == 1) await capture('welcome');
            await tap(tester, find.text('Skip introduction'));
            expect(find.text('Updates'), findsNothing);
            expect(
              find.byType(NavigationRail),
              phone ? findsNothing : findsOneWidget,
            );
            expect(find.text('Choose exam'), findsOneWidget);
            if (phone && scale == 1) await capture('results');
            await tap(tester, find.text('Choose exam'));
            await tap(tester, find.text('Choose exam'));
            await tap(tester, find.textContaining('Long accented'));
            await tap(tester, find.text('Choose sitting'));
            await tap(tester, find.textContaining('Overseas'));
            await tap(tester, find.text('View results'));
            expect(find.text('Results released'), findsOneWidget);
            expect(find.text('PRC announcement'), findsOneWidget);
            expect(find.text('TEST ONLY official result'), findsOneWidget);
            if ((phone && scale == 1) || (!phone && scale == 2)) {
              await capture(phone ? 'publication' : 'publication-tablet-200');
            }
            await tap(tester, find.text('Change'));
            await tester.pageBack();
            await settle(tester);
            expect(
              await PrivateStore().readSelection(),
              const ExamSelection('test-only', 'test-sitting', 'general'),
            );
            await tap(tester, find.byTooltip('Settings'));
            expect(find.byTooltip('Refresh available metadata'), findsNothing);
            if (phone && scale == 1) await capture('settings');
            await tap(tester, find.text('Change'));
            expect(find.text('Apply selection'), findsOneWidget);
            await tester.pageBack();
            await settle(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final size in [const Size(412, 892), const Size(900, 1000)]) {
      testWidgets(
        'pilot notice at ${size.width} dp in ${brightness.name} at double text',
        (tester) async {
          configure(tester, size, brightness, 2);
          FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'});
          await PrivateStore().saveSelection(selection);
          final repo = AdvisoryRepository()
            ..read = (_) async => AdvisoryFeed.fromJson(
              snapshot(stale: true, checked: DateTime.utc(2026, 7, 31, 12, 30)),
            );
          await tester.pumpWidget(
            ExamApp(
              repository: repo,
              listStore: TestListStore(),
              advisoryPilot: true,
            ),
          );
          await settle(tester);
          await tap(tester, find.text('Updates').last);
          await tester.ensureVisible(find.text('Open PRC notice'));
          await settle(tester);
          expect(find.text('TEST ONLY postponement'), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/pilot-${size.width < 600 ? 'phone' : 'tablet'}-${brightness.name}-200.png',
            ),
          );
          await tap(tester, find.text('View all updates'));
          expect(find.text('All updates'), findsOneWidget);
          expect(find.text('Open PRC notice'), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/history-${size.width < 600 ? 'phone' : 'tablet'}-${brightness.name}-200.png',
            ),
          );
          await tester.pageBack();
          await settle(tester);
          await tap(tester, find.byTooltip('Settings'));
          await tap(tester, find.text('Results').last);
          expect(
            find.text('No verified result announcement found'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('unavailable result at double text in ${brightness.name}', (
      tester,
    ) async {
      configure(tester, const Size(390, 844), brightness, 2);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ResultsScreen(version: null, failed: true, onRetry: () {}),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text("Couldn't refresh"), findsOneWidget);
      await tester.ensureVisible(find.text('Retry'));
      await settle(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/unavailable-${brightness.name}-200.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
