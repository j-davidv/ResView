import 'package:app/data/firestore_repository.dart';
import 'package:app/domain/models.dart';
import 'package:app/main.dart' show ExamApp;
import 'package:app/storage/private_store.dart';
import 'package:app/ui/shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reviewed pilot snapshot opens its PRC notice on Android', (
    tester,
  ) async {
    final firebase = await Firebase.initializeApp(
      options: const FirebaseOptions(
        projectId: 'demo-resview-advisories',
        apiKey: 'demo-only',
        appId: '1:123:android:demo',
        messagingSenderId: '123',
      ),
    );
    final db = FirebaseFirestore.instanceFor(app: firebase);
    db.useFirestoreEmulator('10.0.2.2', 8185);
    final repo = FirestoreExamRepository(db);
    final store = PrivateStore();
    final saved = await store.readSelection();
    final seen = await store.readIntroSeen();
    addTearDown(() async {
      if (saved != null) {
        await store.saveSelection(saved);
      } else {
        await store.clearLocalValues();
      }
      if (!seen) await store.resetIntroSeen();
    });
    await store.markIntroSeen();

    Future<void> waitFor(Finder finder) async {
      final deadline = DateTime.now().add(const Duration(seconds: 35));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(finder, findsWidgets);
    }

    Future<void> show(ExamSelection selection, String expected) async {
      await store.saveSelection(selection);
      await tester.pumpWidget(
        ExamApp(
          key: ValueKey(selection),
          repository: repo,
          advisoryPilot: true,
        ),
      );
      await waitFor(find.text('Publication status unavailable'));
      expect(find.text('Results released'), findsNothing);
      expect(find.byTooltip('Settings'), findsWidgets);
      await tester.tap(find.text('Updates').last);
      await waitFor(find.text(expected));
    }

    await show(
      const ExamSelection(
        'master-plumbers',
        'master-plumbers-2026-07-11',
        'all',
      ),
      'View all updates',
    );
    await show(
      const ExamSelection(
        'master-plumbers',
        'master-plumbers-2026-02-19',
        'all',
      ),
      'View all updates',
    );
    await show(
      const ExamSelection(
        'landscape-architects',
        'landscape-architects-2026-07-14',
        'all',
      ),
      'View all updates',
    );
    final latest = tester
        .widget<SourceButton>(find.byType(SourceButton).first)
        .uri;
    final history = await repo.loadAdvisories('landscape-architects');
    expect(history!.notices.first.url, latest);
    expect(
      history.notices.any(
        (item) =>
            item.url.path ==
            '/article/rescheduling-landscape-architects-licensure-examination',
      ),
      isTrue,
    );
    await tester.ensureVisible(find.text('View all updates'));
    await tester.tap(find.text('View all updates'));
    await waitFor(find.text('All updates'));
    await tester.pumpAndSettle();
    final link = find.byType(SourceButton).first;
    expect(tester.widget<SourceButton>(link).uri, latest);
    final openLatest = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is SourceButton && widget.uri == latest,
      ),
      matching: find.text('Open PRC notice'),
    );
    for (
      var step = 0;
      step < 12 && openLatest.hitTestable().evaluate().isEmpty;
      step++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
    }
    await tester.tap(openLatest.hitTestable());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AndroidView), findsOneWidget);
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (find.byType(LinearProgressIndicator).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('could not be loaded'), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('RESVIEW_LOCAL_ADVISORY_TEST'));
}
