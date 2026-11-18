import 'package:app/main.dart' as app;
import 'package:app/data/firestore_repository.dart';
import 'package:app/domain/models.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android shows three destinations and legacy states retain source links',
    (tester) async {
      for (final state in PublicationState.values) {
        final version = ResultVersion(
          selection: const ExamSelection('test-only', 'test-sitting', 'all'),
          state: state,
          documentVersion: 'test-only',
          publicationUrl: Uri.parse('https://www.prc.gov.ph/article/test-only'),
          documentUrl: Uri.parse(
            'https://drive.google.com/file/d/TESTONLY123/view',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: app.appTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(child: SourceLinks(version)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open successful-examinee list'), findsOneWidget);
        expect(find.textContaining('Document version'), findsNothing);
      }
    },
  );

  if (const bool.fromEnvironment('RESVIEW_LIVE_TEST')) {
    testWidgets(
      'live catalog, result sources, settings and saved selection on Android',
      (tester) async {
        final store = PrivateStore();
        final originalSelection = await store.readSelection();
        final introSeen = await store.readIntroSeen();
        const selection = ExamSelection(
          'ocular-pharmacologists',
          'ocular-pharmacologists-2026-09-28',
          'all',
        );
        try {
          final repository = FirestoreExamRepository.fromEnvironment();
          expect(
            (await repository.loadCatalog()).any(
              (e) => e.id == selection.examId,
            ),
            isTrue,
          );
          expect(
            (await repository.loadSittings(selection.examId))
                .any((s) => s.id == selection.sittingId),
            isTrue,
          );
          await store.saveSelection(selection);
          await store.markIntroSeen();
          await app.main();
          await waitFor(tester, find.textContaining('Ocular Pharmacologists'));
          await tester.tap(find.text('Results').last);
          await waitFor(tester, find.text('Results released'));
          await tester.pumpAndSettle();
          expect(find.byType(NavigationDestination), findsNWidgets(3));
          expect(find.text('Check name'), findsNothing);
          expect(find.textContaining('Document version'), findsNothing);
          expect(find.text('Open successful-examinee list'), findsOneWidget);
          expect(find.text('Open PRC publication'), findsOneWidget);
          await tester.tap(find.text('Settings').last);
          await tester.pumpAndSettle();
          expect(find.text('Saved name'), findsNothing);
          expect(find.text('Offline lists'), findsNothing);
          expect(find.text('Push alerts'), findsOneWidget);
          await tester.ensureVisible(find.text('Email updates'));
          await tester.tap(find.text('Email updates'));
          await tester.pumpAndSettle();
          expect(find.text('Email signup unavailable'), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(await store.readSelection(), selection);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          if (originalSelection != null) {
            await store.saveSelection(originalSelection);
          } else {
            await store.clearLocalValues();
          }
          if (!introSeen) await store.resetIntroSeen();
        }
      },
    );
  }
}
