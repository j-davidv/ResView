import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

import 'flows_test.dart' show TestListStore;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'}));

  testWidgets('first-use actions save completion and choose opens the picker', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    for (final action in ['Choose my exam', 'Skip introduction']) {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
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
      expect(find.text('Exam catalog unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pumpWidget(ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();
    expect(find.text('How ResView works'), findsNothing);
    expect(find.text('Exam catalog unavailable'), findsOneWidget);
  });

  testWidgets(
    'unconfigured runtime offers browsing and settings without fictional content',
    (tester) async {
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await tester.pumpAndSettle();
      expect(find.text('Choose your exam'), findsOneWidget);
      expect(find.text('Exam catalog unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Sign up'), findsNothing);
      expect(find.textContaining('Demo data'), findsNothing);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Privacy and data'), findsOneWidget);
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
      await tester.tap(find.text('Settings').last);
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
  testWidgets('large-text landscape keeps navigation and name inputs usable', (
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
    await tester.tap(find.text('Check name').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextFormField).first,
      'TEST ONLY PEÑA DELA CRUZ VERY LONG COMPOUND SURNAME',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
