import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/data/firestore_repository.dart';

import 'flows_test.dart' show TestListStore;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'}));

  testWidgets('Settings opens from the header and Back restores the tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(NavigationDestination, 'Settings'),
      findsNothing,
    );
    final settings = find.byTooltip('Settings');
    expect(settings, findsOneWidget);
    expect(tester.getCenter(settings).dx, greaterThan(300));
    expect(tester.getCenter(settings).dy, lessThan(160));
    await tester.tap(find.text('Bookmarks').last);
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('About us'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-use actions save completion and choose opens the picker', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    for (final action in ['Choose my exam', 'Skip introduction']) {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        ExamApp(
          repository: FirestoreExamRepository(null),
          listStore: TestListStore(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('How ResView works'), findsOneWidget);
      expect(await storage.read(key: 'introSeen'), isNull);
      final button = find.text(action);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(await storage.read(key: 'introSeen'), 'true');
      expect(find.text('How ResView works'), findsNothing);
      if (action == 'Choose my exam') {
        expect(find.text('Exam selection'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Choose exam'), findsOneWidget);
      expect(find.text('Updates'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Results'), findsWidgets);
      await tester.tap(find.text('Bookmarks').last);
      await tester.pumpAndSettle();
      expect(find.text('Nothing saved yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pumpWidget(ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();
    expect(find.text('How ResView works'), findsNothing);
    expect(find.text('Choose exam'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('Results'), findsWidgets);
  });

  testWidgets(
    'unconfigured runtime offers browsing and settings without fictional content',
    (tester) async {
      await tester.pumpWidget(
        ExamApp(
          repository: FirestoreExamRepository(null),
          listStore: TestListStore(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Results released'), findsNothing);
      expect(find.text('Not released'), findsNothing);
      await tester.tap(find.text('Choose exam'));
      await tester.pumpAndSettle();
      expect(find.text('Exam catalog unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Sign up'), findsNothing);
      expect(find.textContaining('Demo data'), findsNothing);
      await tester.tap(find.text('Bookmarks').last);
      await tester.pumpAndSettle();
      expect(find.text('Nothing saved yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('About us'), findsOneWidget);
    },
  );
  testWidgets(
    'navigation and settings reflow at double text in a narrow window',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Delete local data'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large-text landscape keeps all destinations usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();
    for (final title in ['Updates', 'Bookmarks', 'Settings', 'Results']) {
      final tab = title == 'Settings'
          ? find.byTooltip('Settings')
          : find.text(title).last;
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (title == 'Settings') {
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Choose exam'), findsOneWidget);
  });
}
