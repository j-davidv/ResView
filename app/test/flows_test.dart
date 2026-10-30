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
import 'package:app/ui/check_name.dart';

class UnavailableListStore extends TestListStore {
  @override
  Future<CheckedList> prepare(
    ResultVersion version, {
    required CancelToken cancellation,
    ValueChanged<double>? onProgress,
  }) async => throw const ListFailure('TEST ONLY download unavailable');
}

class TestListStore extends ListStore {
  @override
  Future<void> cleanupTemporary() async {}
  @override
  Future<List<SavedList>> listSaved() async => [];
}

class TestRepository implements ExamRepository {
  TestRepository(this.state, {this.freshness = SourceFreshness.stale});
  final PublicationState state;
  final SourceFreshness freshness;
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
  Future<List<Publication>> loadPublications(ExamSelection selection) async =>
      [];
  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async =>
      ResultVersion(
        selection: selection,
        state: state,
        freshness: freshness,
        documentVersion: 'test-v1',
        lastSuccessfulCheckUtc: DateTime.utc(2026, 10, 14),
        publicationUrl: Uri.parse('https://www.prc.gov.ph/test-only'),
      );
}

class RecoveryRepository extends TestRepository {
  RecoveryRepository() : super(PublicationState.checkingAvailable);
  PublicationState resultState = PublicationState.checkingAvailable;
  bool offline = false;
  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async {
    if (offline) throw const ServiceUnavailable();
    return ResultVersion(
      selection: selection,
      state: resultState,
      freshness: SourceFreshness.fresh,
      documentVersion: 'test-v1',
      namesBytes: 100,
    );
  }
}

class RecoveryListStore extends TestListStore {
  final revoked = <String>[];
  @override
  Future<List<SavedList>> listSaved() async => [
    const SavedList(
      ResultVersion(
        selection: ExamSelection('test-only', 'test-sitting', 'general'),
        state: PublicationState.checkingAvailable,
        documentVersion: 'test-v1',
      ),
      100,
      false,
    ),
  ];
  @override
  Future<void> markSuperseded(
    String oldVersionId,
    String currentVersionId,
  ) async {
    revoked.add(oldVersionId);
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'same-version revocation blocks saved reuse and resets active checking',
    (tester) async {
      await PrivateStore().saveSelection(
        const ExamSelection('test-only', 'test-sitting', 'general'),
      );
      final repository = RecoveryRepository();
      final lists = RecoveryListStore();
      await tester.pumpWidget(
        ExamApp(repository: repository, listStore: lists),
      );
      await tester.pumpAndSettle();
      final refresh = tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed!;
      await tester.tap(find.text('Check name').last);
      await tester.pumpAndSettle();
      final oldKey = tester
          .widget<CheckNameScreen>(find.byType(CheckNameScreen))
          .key;
      repository.resultState = PublicationState.checkingUnavailable;
      refresh();
      await tester.pumpAndSettle();
      expect(lists.revoked, ['test-only/test-sitting/general/test-v1']);
      expect(
        tester.widget<CheckNameScreen>(find.byType(CheckNameScreen)).key,
        isNot(oldKey),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Check name'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Automatic name checking unavailable.'), findsOneWidget);
    },
  );
  testWidgets(
    'metadata outage retains last-good checking with a stale warning',
    (tester) async {
      await PrivateStore().saveSelection(
        const ExamSelection('test-only', 'test-sitting', 'general'),
      );
      final repository = RecoveryRepository();
      final lists = RecoveryListStore();
      await tester.pumpWidget(
        ExamApp(repository: repository, listStore: lists),
      );
      await tester.pumpAndSettle();
      repository.offline = true;
      await tester.tap(find.byTooltip('Refresh available metadata'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Results').last);
      await tester.pumpAndSettle();
      expect(find.text('Source information may be outdated'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Check name'), findsOneWidget);
      expect(lists.revoked, isEmpty);
    },
  );
  testWidgets('checking failure is brought into view at double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CheckNameScreen(
                version: const ResultVersion(
                  selection: ExamSelection('test', 'test', 'general'),
                  state: PublicationState.checkingAvailable,
                  documentVersion: 'test',
                  freshness: SourceFreshness.fresh,
                  namesBytes: 100,
                ),
                store: PrivateStore(),
                lists: UnavailableListStore(),
                hasSelection: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'TEST ONLY Peña');
    await tester.enterText(find.byType(TextFormField).at(1), 'TEST ONLY Given');
    final check = find.widgetWithText(FilledButton, 'Check name');
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(
      find.text('TEST ONLY download unavailable').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('unsaved draft survives tabs without disk retention', (
    tester,
  ) async {
    await tester.pumpWidget(ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check name').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'TEST ONLY Peña');
    await tester.tap(find.text('Results').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check name').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'TEST ONLY Peña',
    );
    expect(await const FlutterSecureStorage().read(key: 'name'), isNull);
  });
  testWidgets('missing selection leads with recovery before name fields', (
    tester,
  ) async {
    await tester.pumpWidget(ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check name').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose an exam to check a name'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Choose an exam to check a name')).dy,
      lessThan(tester.getTopLeft(find.byType(TextFormField).first).dy),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Choose exam'));
    await tester.pumpAndSettle();
    expect(find.text('Exam selection'), findsOneWidget);
  });
  for (final state in PublicationState.values) {
    testWidgets(
      'publication ${state.name} remains distinct from stale freshness',
      (tester) async {
        final result = await TestRepository(state).loadResultVersion(
          const ExamSelection('test-only', 'test-sitting', 'general'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ResultsScreen(version: result, onCheck: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(publicationLabel(state)), findsOneWidget);
        expect(find.text('Source information may be outdated'), findsOneWidget);
        expect(find.textContaining('UTC+08:00'), findsWidgets);
        expect(
          tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Open PRC publication'),
          ).onPressed,
          isNotNull,
        );
        if (state == PublicationState.checkingAvailable) {
          expect(find.text('Check name'), findsOneWidget);
        } else {
          expect(find.widgetWithText(FilledButton, 'Check name'), findsNothing);
        }
      },
    );
  }
  testWidgets(
    'selection keeps overseas identity and browsing does not request a name',
    (tester) async {
      await tester.pumpWidget(
        ExamApp(
          repository: TestRepository(PublicationState.validationPending),
          listStore: TestListStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('TEST ONLY — Long'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose sitting'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Overseas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View updates'));
      await tester.pumpAndSettle();
      expect(
        find.text('No announcements found for this selection'),
        findsOneWidget,
      );
      expect(find.textContaining('Overseas'), findsWidgets);
      await tester.tap(find.text('Check name').last);
      await tester.pumpAndSettle();
      expect(find.text('Surname'), findsOneWidget);
      expect(find.text('Save when I check'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
    },
  );
  testWidgets(
    'settings privacy controls pass touch target and label guidelines',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const ExamApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
  testWidgets(
    'retry after server deletion failure does not claim a local refresh completed it',
    (tester) async {
      await tester.pumpWidget(ExamApp(listStore: TestListStore()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      final deletion = find.text('Delete server-side push preferences');
      await tester.ensureVisible(deletion);
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      final retry = find.widgetWithText(OutlinedButton, 'Retry').last;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Device data refreshed.'), findsNothing);
      expect(
        find.text(
          'Server deletion pending. Alerts may continue until confirmed.',
        ),
        findsWidgets,
      );
    },
  );
}
