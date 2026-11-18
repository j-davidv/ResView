import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/main.dart';
import 'package:app/data/exam_repository.dart';
import 'package:app/domain/models.dart';
import 'package:app/ui/results.dart';
import 'package:app/ui/shared.dart';
import 'package:app/storage/list_store.dart';
import 'package:app/storage/private_store.dart';

class TestListStore extends ListStore {
  bool cleared = false;
  @override
  Future<void> clearAll() async {
    cleared = true;
  }
}

class TestRepository implements ExamRepository {
  TestRepository(this.state, {this.freshness = SourceFreshness.stale});
  final PublicationState state;
  final SourceFreshness freshness;
  bool metadataUnavailable = false;
  @override
  Future<List<Exam>> loadCatalog() async => [
    const Exam('test-only', 'TEST ONLY — Long accented examination title Ñ'),
  ];
  @override
  Future<List<Sitting>> loadSittings(String id) async => [
    Sitting(
      id: 'test-sitting',
      examId: id,
      start: DateTime.utc(2026, 10, 14),
      end: DateTime.utc(2026, 10, 15),
      type: 'overseas',
      location: 'TEST ONLY location',
      categories: {'general': 'General'},
    ),
  ];
  @override
  Future<List<Publication>> loadPublications(ExamSelection selection) async => [
    Publication(
      id: 'test-only',
      title: 'TEST ONLY official result',
      url: Uri.parse('https://www.prc.gov.ph/article/test-only'),
      publishedAtUtc: DateTime.utc(2026, 10, 16),
      documents: {
        Uri.parse('https://drive.google.com/file/d/TESTONLY123/view'):
            'successful-examinee list',
      },
    ),
  ];
  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async {
    if (metadataUnavailable) throw const ServiceUnavailable();
    return ResultVersion(
      selection: selection,
      state: state,
      freshness: freshness,
      documentVersion: 'test-v1',
      lastSuccessfulCheckUtc: DateTime.utc(2026, 10, 14),
      publicationUrl: Uri.parse('https://www.prc.gov.ph/article/test-only'),
      reason: 'This document format has not passed validation.',
    );
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'}));
  const selection = ExamSelection('test-only', 'test-sitting', 'general');

  for (final state in PublicationState.values) {
    testWidgets(
      'publication status and sources survive legacy state ${state.name}',
      (tester) async {
        final version = ResultVersion(
          selection: selection,
          state: state,
          documentVersion: 'test-v1',
          freshness: SourceFreshness.stale,
          publicationUrl: Uri.parse('https://www.prc.gov.ph/article/test-only'),
          reason: 'This document format has not passed validation.',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ResultsScreen(version: version),
              ),
            ),
          ),
        );
        expect(find.text(publicationLabel(state)), findsOneWidget);
        expect(find.text('Source information may be outdated'), findsOneWidget);
        expect(find.text('Open PRC publication'), findsOneWidget);
        expect(find.textContaining('Document version'), findsNothing);
        expect(find.textContaining('validation'), findsNothing);
        expect(find.text('Check name'), findsNothing);
      },
    );
  }

  testWidgets(
    'upgrade clears legacy checker data and preserves the selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'name', value: '{"surname":"TEST ONLY"}');
      await PrivateStore().saveSelection(selection);
      final lists = TestListStore();
      await tester.pumpWidget(
        ExamApp(
          repository: TestRepository(PublicationState.checkingUnavailable),
          listStore: lists,
        ),
      );
      await tester.pumpAndSettle();
      expect(lists.cleared, isTrue);
      expect(await storage.read(key: 'name'), isNull);
      expect(await PrivateStore().readSelection(), selection);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text('Check name'), findsNothing);
      await tester.tap(find.text('Results').last);
      await tester.pumpAndSettle();
      expect(find.text('Results released'), findsOneWidget);
      expect(find.text('Open successful-examinee list'), findsOneWidget);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Saved name'), findsNothing);
      expect(find.text('Offline lists'), findsNothing);
      expect(find.text('Push alerts'), findsOneWidget);
      expect(find.text('Email updates'), findsOneWidget);
    },
  );

  testWidgets('announcement links survive a result metadata outage', (
    tester,
  ) async {
    await PrivateStore().saveSelection(selection);
    final repository = TestRepository(PublicationState.checkingUnavailable)
      ..metadataUnavailable = true;
    await tester.pumpWidget(
      ExamApp(repository: repository, listStore: TestListStore()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Results').last);
    await tester.pumpAndSettle();
    expect(find.text('Open successful-examinee list'), findsOneWidget);
    expect(find.text('Results released'), findsOneWidget);
  });

  testWidgets('selection retains overseas sitting and loads official links', (
    tester,
  ) async {
    await tester.pumpWidget(
      ExamApp(
        repository: TestRepository(PublicationState.validationPending),
        listStore: TestListStore(),
      ),
    );
    await tester.pumpAndSettle();
    final choose = find.widgetWithText(OutlinedButton, 'Choose exam');
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('TEST ONLY — Long'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose sitting'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Overseas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View updates'));
    await tester.tap(find.text('View updates'));
    await tester.pumpAndSettle();
    expect(find.text('TEST ONLY official result'), findsOneWidget);
    expect(find.textContaining('Overseas'), findsWidgets);
    expect(find.text('Open successful-examinee list'), findsOneWidget);
  });

  testWidgets(
    'settings keeps consent, email, and privacy controls accessible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      await tester.ensureVisible(find.text('Email updates'));
      await tester.tap(find.text('Email updates'));
      await tester.pumpAndSettle();
      expect(find.text('Email signup unavailable'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Privacy and data'));
      await tester.tap(find.text('Privacy and data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Delete server-side push preferences'),
      );
      await tester.tap(find.text('Delete server-side push preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      final retry = find.widgetWithText(OutlinedButton, 'Retry').last;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Server deletion pending. Alerts may continue until confirmed.',
        ),
        findsWidgets,
      );
    },
  );
}
