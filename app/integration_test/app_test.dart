import 'package:app/main.dart' as app;
import 'package:app/data/firestore_repository.dart';
import 'package:app/domain/models.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../test/flows_test.dart' show TestRepository, TestListStore;

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
  testWidgets('legacy states retain their official source links on Android', (
    tester,
  ) async {
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
      expect(find.text('View list of passers'), findsOneWidget);
      expect(find.textContaining('Document version'), findsNothing);
    }
  });

  if (!const bool.fromEnvironment('RESVIEW_LIVE_TEST')) {
    testWidgets('picking a sitting opens Results on Android', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        app.ExamApp(
          repository: TestRepository(PublicationState.checkingAvailable),
          listStore: TestListStore(),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Choose my exam',
        'Choose exam',
        'TEST ONLY — Long accented examination title Ñ',
        'Choose sitting',
      ]) {
        final control = find.text(label);
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.textContaining('Overseas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View results'));
      await tester.tap(find.text('View results'));
      await tester.pumpAndSettle();
      expect(find.text('Results released'), findsOneWidget);
      expect(find.text('View list of passers'), findsOneWidget);
      expect(find.text('Updates'), findsOneWidget);
    });
  } else {
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
          await waitFor(tester, find.text('Results released'));
          await tester.pumpAndSettle();
          expect(find.text('Updates'), findsOneWidget);
          expect(find.text('Check name'), findsNothing);
          expect(find.textContaining('Document version'), findsNothing);
          expect(find.text('View list of passers'), findsOneWidget);
          expect(find.text('PRC announcement'), findsOneWidget);
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
