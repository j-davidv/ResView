import 'package:app/main.dart';
import 'package:app/ui/shared.dart';
import 'package:app/ui/source_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(condition(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const live = bool.fromEnvironment('SOURCE_VIEWER_LIVE');
  const document = String.fromEnvironment('VIEWER_TEST_DOCUMENT');
  const early = String.fromEnvironment('VIEWER_TEST_EARLY_QUERY');
  const late = String.fromEnvironment('VIEWER_TEST_LATE_QUERY');
  const restricted = String.fromEnvironment('VIEWER_TEST_RESTRICTED_DOCUMENT');
  const restrictedQuery = String.fromEnvironment(
    'VIEWER_TEST_RESTRICTED_QUERY',
  );

  testWidgets(
    'native viewer rejects an untrusted origin and offers retry without a false search outcome',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: SourceViewer(
            uri: Uri.parse('https://example.org/untrusted'),
            openExternal: (_) async {},
          ),
        ),
      );
      await waitFor(
        tester,
        () => find
            .textContaining('The official source could not be loaded')
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.text('No text matches. This is not an exam outcome.'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await waitFor(
        tester,
        () => find
            .textContaining('The official source could not be loaded')
            .evaluate()
            .isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  Future<void> open(WidgetTester tester, String url) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: SourceButton('Test official source', Uri.parse(url)),
        ),
      ),
    );
    await tester.tap(find.text('Test official source'));
    await tester.pump();
    await waitFor(tester, () => find.byType(TextField).evaluate().isNotEmpty);
    await waitFor(
      tester,
      () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Find'))
          .onPressed,
      isNull,
    );
  }

  Future<void> search(
    WidgetTester tester,
    String query,
    String expected,
  ) async {
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      query,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Find');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await waitFor(
      tester,
      () =>
          find.text(expected).evaluate().isNotEmpty ||
          find
              .textContaining('Retry or open this source')
              .evaluate()
              .isNotEmpty,
    );
    expect(
      find.text(expected),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .where((text) => text.contains('Retry or open this source'))
          .join(),
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'touch controls search beyond loaded pages, navigate matches and distinguish absence',
    (tester) async {
      expect(document, isNotEmpty);
      expect(early, isNotEmpty);
      expect(late, isNotEmpty);
      await open(tester, document);
      await search(tester, late, '1 of 1 text matches');
      await search(tester, late, '1 of 1 text matches');
      await search(tester, early, '1 of 2 text matches');
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Next'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Next'));
      await waitFor(
        tester,
        () => find.text('2 of 2 text matches').evaluate().isNotEmpty,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Previous'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
      await waitFor(
        tester,
        () => find.text('1 of 2 text matches').evaluate().isNotEmpty,
      );
      await search(
        tester,
        'ZZZNOTAREALPERSONZZZ',
        'No text matches. This is not an exam outcome.',
      );
      await tester.tap(find.byTooltip('Back'));
      await waitFor(
        tester,
        () => find.text('Test official source').evaluate().isNotEmpty,
      );
    },
    skip: !live,
  );

  testWidgets('touch search also works on a download-restricted list', (
    tester,
  ) async {
    await open(tester, restricted);
    await search(tester, restrictedQuery, '1 of 1 text matches');
    await tester.tap(find.byTooltip('Back'));
    await waitFor(
      tester,
      () => find.text('Test official source').evaluate().isNotEmpty,
    );
  }, skip: !live);

  testWidgets('landscape keeps touch search usable', (tester) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    try {
      await tester.pumpAndSettle();
      await open(tester, document);
      await search(tester, late, '1 of 1 text matches');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back'));
      await waitFor(
        tester,
        () => find.text('Test official source').evaluate().isNotEmpty,
      );
    } finally {
      await SystemChrome.setPreferredOrientations([]);
    }
  }, skip: !live);
}
