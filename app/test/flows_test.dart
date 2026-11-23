import 'dart:async';

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
  bool catalogUnavailable = false, emptyHistory = false;
  final resultReads = <ExamSelection>[];
  final versionReads = <ExamSelection>[];
  Completer<List<Publication>>? pendingHistory;
  Completer<ResultVersion?>? pendingVersion;
  @override
  Future<AdvisoryFeed?> loadAdvisories(String examId) async => null;
  @override
  Future<List<Exam>> loadCatalog() async {
    if (catalogUnavailable) throw const ServiceUnavailable();
    return [
      const Exam('test-only', 'TEST ONLY — Long accented examination title Ñ'),
    ];
  }

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
  Future<List<Publication>> loadPublications(ExamSelection selection) async {
    resultReads.add(selection);
    if (pendingHistory != null) return pendingHistory!.future;
    if (emptyHistory) return [];
    return [
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
  }

  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async {
    versionReads.add(selection);
    if (pendingVersion != null) return pendingVersion!.future;
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
        expect(find.text('Source freshness'), findsNothing);
        expect(find.text('Source information may be outdated'), findsNothing);
        expect(find.text('PRC announcement'), findsOneWidget);
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
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Check name'), findsNothing);
      expect(find.text('Source freshness'), findsNothing);
      expect(find.text('Stale'), findsNothing);
      expect(find.text('Results released'), findsOneWidget);
      expect(find.text('View list of passers'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
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
    expect(find.text('Refresh unavailable'), findsOneWidget);
    expect(find.text('View list of passers'), findsOneWidget);
    expect(find.text('Results released'), findsOneWidget);
  });

  testWidgets(
    'retired sitting requires choosing the replacement before any result read',
    (tester) async {
      await PrivateStore().saveSelection(
        const ExamSelection('test-only', 'retired-sitting', 'general'),
      );
      final repository = TestRepository(PublicationState.validationPending);
      await tester.pumpWidget(
        ExamApp(repository: repository, listStore: TestListStore()),
      );
      await tester.pumpAndSettle();
      expect(repository.resultReads, isEmpty);
      expect(repository.versionReads, isEmpty);
      expect(find.text('Results released'), findsNothing);
      expect(find.text('Choose exam'), findsOneWidget);
      await tester.tap(find.text('Choose exam'));
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
      await tester.ensureVisible(find.text('View results'));
      await tester.tap(find.text('View results'));
      await tester.pumpAndSettle();
      expect(find.text('TEST ONLY official result'), findsOneWidget);
      expect(find.textContaining('Overseas'), findsWidgets);
      expect(find.text('View list of passers'), findsOneWidget);
      expect(repository.resultReads, [selection]);
      expect(repository.versionReads, [selection]);
      expect(find.text('Results released'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await PrivateStore().readSelection(), selection);
      expect(repository.resultReads, [selection]);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply selection'));
      await tester.tap(find.text('Apply selection'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete local data'));
      await tester.tap(find.text('Delete local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(await PrivateStore().readSelection(), isNull);
      expect(find.text('Choose exam'), findsOneWidget);
      expect(find.text('PRC announcement'), findsNothing);
    },
  );

  testWidgets(
    'failed restore retries the saved selection and preserves history on partial refresh',
    (tester) async {
      await PrivateStore().saveSelection(selection);
      final repository = TestRepository(PublicationState.checkingUnavailable)
        ..catalogUnavailable = true;
      await tester.pumpWidget(
        ExamApp(repository: repository, listStore: TestListStore()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved exam selection unavailable'), findsOneWidget);
      expect(find.text('Not released'), findsNothing);
      repository.catalogUnavailable = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('TEST ONLY official result'), findsOneWidget);
      repository.pendingHistory = Completer();
      repository.metadataUnavailable = true;
      await tester.tap(find.byTooltip('Refresh available metadata'));
      await tester.pump();
      expect(find.text('TEST ONLY official result'), findsOneWidget);
      repository.pendingHistory!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Refresh unavailable'), findsOneWidget);
      expect(find.text('TEST ONLY official result'), findsOneWidget);
      expect(find.text('View list of passers'), findsOneWidget);
      expect(find.text('Not released'), findsNothing);
    },
  );

  testWidgets('confirmed version opens when the publication history fails', (
    tester,
  ) async {
    await PrivateStore().saveSelection(selection);
    final repository = TestRepository(PublicationState.checkingAvailable)
      ..pendingHistory = Completer();
    await tester.pumpWidget(
      ExamApp(repository: repository, listStore: TestListStore()),
    );
    await tester.pump();
    await tester.pump();
    repository.pendingHistory!.completeError(const ServiceUnavailable());
    await tester.pumpAndSettle();
    expect(find.text('Results released'), findsOneWidget);
    expect(find.text('PRC announcement'), findsOneWidget);
    expect(find.text('Refresh unavailable'), findsOneWidget);
  });

  testWidgets('known articles open while result-version metadata is pending', (
    tester,
  ) async {
    await PrivateStore().saveSelection(selection);
    final repository = TestRepository(PublicationState.checkingAvailable)
      ..pendingVersion = Completer();
    await tester.pumpWidget(
      ExamApp(repository: repository, listStore: TestListStore()),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('View list of passers'), findsOneWidget);
    repository.pendingVersion!.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Results released'), findsOneWidget);
  });

  testWidgets(
    'failed initial result read offers retry without claiming release',
    (tester) async {
      await PrivateStore().saveSelection(selection);
      final repository = TestRepository(PublicationState.notReleased)
        ..emptyHistory = true
        ..metadataUnavailable = true;
      await tester.pumpWidget(
        ExamApp(repository: repository, listStore: TestListStore()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Publication status unavailable'), findsOneWidget);
      expect(find.text('Results released'), findsNothing);
      expect(find.text('Not released'), findsNothing);
      repository.metadataUnavailable = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Not released'), findsOneWidget);
    },
  );

  testWidgets(
    'settings keeps email accessible and About us focused on the overview',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      await tester.ensureVisible(find.text('Email updates'));
      await tester.tap(find.text('Email updates'));
      await tester.pumpAndSettle();
      expect(find.text('Email signup unavailable'), findsOneWidget);
      await tester.ensureVisible(find.text('Unsubscribe from email updates'));
      await tester.tap(find.text('Unsubscribe from email updates'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Open an email update from ResView'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('About us'));
      await tester.tap(find.text('About us'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ResView helps you follow'), findsOneWidget);
      expect(
        find.textContaining('ResView saves your exam choice'),
        findsOneWidget,
      );
      expect(find.text('Privacy controls'), findsNothing);
      expect(find.text('Android notification settings'), findsNothing);
      expect(find.text('Delete server-side push preferences'), findsNothing);
    },
  );
}
