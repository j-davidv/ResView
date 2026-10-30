import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

void main() {
  testWidgets(
    'unconfigured runtime offers browsing and settings without fictional content',
    (tester) async {
      await tester.pumpWidget(const ExamApp());
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
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ExamApp(),
        ),
      );
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
    await tester.pumpWidget(const ExamApp());
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
