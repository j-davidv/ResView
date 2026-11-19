import 'dart:convert';

import 'package:app/data/exam_repository.dart';
import 'package:app/domain/bookmark.dart';
import 'package:app/domain/history.dart';
import 'package:app/domain/models.dart';
import 'package:app/storage/bookmark_library.dart';
import 'package:app/storage/history_library.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/design.dart';
import 'package:app/ui/history.dart';
import 'package:app/ui/results.dart';
import 'package:app/ui/shared.dart';
import 'package:app/ui/updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _selection = ExamSelection('exam-test', 'sitting-test', 'general');
final _announcementUrl =
    Uri.parse('https://www.prc.gov.ph/article/notice-test');
final _resultUrl = Uri.parse('https://www.prc.gov.ph/article/result-test');

HistoryEntry _historyEntry({
  required HistoryKind kind,
  required String sourceId,
  required String title,
  required Uri url,
  DateTime? viewedAtUtc,
}) =>
    HistoryEntry(
      sourceId: sourceId,
      kind: kind,
      examId: 'exam-test',
      examName: 'TEST ONLY Licensure Examination',
      title: title,
      url: url,
      publishedAtUtc: DateTime.utc(2026, 11, 10),
      viewedAtUtc: viewedAtUtc ?? DateTime.utc(2026, 11, 19, 8, 30),
      sittingLabel: kind == HistoryKind.result ? 'Domestic · 10/11/2026' : null,
    );

AdvisoryFeed _feed() => AdvisoryFeed.fromJson({
      'coverageStartUtc': '2026-10-31T16:00:00Z',
      'coverageEndUtc': '2026-11-30T16:00:00Z',
      'lastSuccessfulCheckUtc': DateTime.now().toUtc().toIso8601String(),
      'freshness': 'fresh',
      'notices': [
        {
          'kind': 'announcement',
          'title': 'TEST ONLY PRC announcement',
          'publicationUrl': _announcementUrl.toString(),
          'publishedAtUtc': '2026-11-10T00:00:00Z',
        },
      ],
    });

class _Repository implements ExamRepository {
  @override
  Future<List<Exam>> loadCatalog() async => [];

  @override
  Future<List<Sitting>> loadSittings(String examId) async => [];

  @override
  Future<List<Publication>> loadPublications(ExamSelection selection) async =>
      [];

  @override
  Future<AdvisoryFeed?> loadAdvisories(String examId) async => _feed();

  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'history persists, deduplicates on read, and tolerates malformed entries',
    () async {
      final announcement = _historyEntry(
        kind: HistoryKind.announcement,
        sourceId: _announcementUrl.toString(),
        title: 'TEST ONLY announcement',
        url: _announcementUrl,
      );
      final encoded = jsonEncode([
        announcement.toJson(),
        {'kind': 'invalid'},
        announcement.toJson(),
      ]);
      FlutterSecureStorage.setMockInitialValues({'history': encoded});

      final storage = PrivateStore();
      final firstRead = await storage.readHistory();
      expect(firstRead, hasLength(1));

      final result = _historyEntry(
        kind: HistoryKind.result,
        sourceId: 'publication-id',
        title: 'TEST ONLY result publication',
        url: _resultUrl,
      );
      await storage.saveHistory([...firstRead, result, result]);
      final reopened = PrivateStore();
      final persisted = await reopened.readHistory();

      expect(persisted.map((e) => e.sourceId).toSet(), {
        announcement.sourceId,
        result.sourceId,
      });

      await reopened.clearHistory();
      expect(await reopened.readHistory(), isEmpty);
    },
  );

  test(
    'malformed history storage remains intact and reports a load error',
    () async {
      FlutterSecureStorage.setMockInitialValues({'history': '[broken'});
      final storage = const FlutterSecureStorage();
      final library = HistoryLibrary(PrivateStore());

      await library.load();

      expect(library.error, contains('could not be loaded'));
      expect(await storage.read(key: 'history'), '[broken');
      library.dispose();
    },
  );

  test(
    'reopening an existing source moves it to the top and updates timestamp',
    () async {
      final library = HistoryLibrary(PrivateStore());
      await library.load();

      final first = _historyEntry(
        kind: HistoryKind.announcement,
        sourceId: 'source-1',
        title: 'First Source',
        url: _announcementUrl,
        viewedAtUtc: DateTime.utc(2026, 11, 1),
      );
      final second = _historyEntry(
        kind: HistoryKind.result,
        sourceId: 'source-2',
        title: 'Second Source',
        url: _resultUrl,
        viewedAtUtc: DateTime.utc(2026, 11, 2),
      );

      await library.record(first);
      await library.record(second);

      expect(library.items.first.sourceId, 'source-2');

      // Reopen first source
      await library.record(first);

      expect(library.items, hasLength(2));
      expect(library.items.first.sourceId, 'source-1');
      expect(
        library.items.first.viewedAtUtc.isAfter(DateTime.utc(2026, 11, 2)),
        isTrue,
      );

      library.dispose();
    },
  );

  test('history enforces 50-item limit and drops the oldest', () async {
    final library = HistoryLibrary(PrivateStore());
    await library.load();

    for (var i = 0; i < 55; i++) {
      await library.record(
        _historyEntry(
          kind: HistoryKind.announcement,
          sourceId: 'source-$i',
          title: 'Source $i',
          url: _announcementUrl,
        ),
      );
    }

    expect(library.items, hasLength(50));
    expect(library.items.first.sourceId, 'source-54');
    expect(library.items.last.sourceId, 'source-5');
    expect(library.items.any((e) => e.sourceId == 'source-0'), isFalse);

    library.dispose();
  });

  testWidgets(
    'opening an announcement from updates records it in viewing history',
    (tester) async {
      final history = HistoryLibrary(PrivateStore());
      await history.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UpdatesScreen(
                repository: _Repository(),
                selection: _selection,
                examId: _selection.examId,
                examTitle: 'TEST ONLY Licensure Examination',
                historyLibrary: history,
                revision: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEST ONLY PRC announcement'), findsOneWidget);
      expect(find.text('Open PRC notice'), findsOneWidget);

      await tester.tap(find.text('Open PRC notice'));
      await tester.pumpAndSettle();

      expect(history.items, hasLength(1));
      expect(history.items.single.kind, HistoryKind.announcement);
      expect(history.items.single.title, 'TEST ONLY PRC announcement');

      history.dispose();
    },
  );

  testWidgets(
    'opening a result publication records it in viewing history',
    (tester) async {
      final history = HistoryLibrary(PrivateStore());
      await history.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResultsScreen(
                version: null,
                publications: [
                  Publication(
                    id: 'pub-test-id',
                    title: 'TEST ONLY official publication',
                    url: _resultUrl,
                    publishedAtUtc: DateTime.utc(2026, 11, 10),
                  ),
                ],
                historyLibrary: history,
                examId: _selection.examId,
                examName: 'TEST ONLY Licensure Examination',
                sittingLabel: 'Domestic · 10/11/2026',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PRC announcement'), findsOneWidget);

      await tester.tap(find.text('PRC announcement'));
      await tester.pumpAndSettle();

      expect(history.items, hasLength(1));
      expect(history.items.single.kind, HistoryKind.result);
      expect(history.items.single.sourceId, 'pub-test-id');

      history.dispose();
    },
  );

  testWidgets(
    'history screen displays items, filters by type, and supports individual removal',
    (tester) async {
      final library = HistoryLibrary(PrivateStore());
      await library.load();

      await library.record(
        _historyEntry(
          kind: HistoryKind.announcement,
          sourceId: 'ann-1',
          title: 'TEST ONLY Announcement Item',
          url: _announcementUrl,
        ),
      );
      await library.record(
        _historyEntry(
          kind: HistoryKind.result,
          sourceId: 'res-1',
          title: 'TEST ONLY Result Item',
          url: _resultUrl,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryScreen(library: library),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEST ONLY Announcement Item'), findsOneWidget);
      expect(find.text('TEST ONLY Result Item'), findsOneWidget);

      // Filter to Announcements
      await tester.tap(find.widgetWithText(ChoiceChip, 'Announcements'));
      await tester.pumpAndSettle();
      expect(find.text('TEST ONLY Announcement Item'), findsOneWidget);
      expect(find.text('TEST ONLY Result Item'), findsNothing);

      // Remove the announcement
      await tester.tap(find.byTooltip('Remove from history'));
      await tester.pumpAndSettle();
      expect(find.text('No announcements viewed'), findsOneWidget);

      // Filter to Results
      await tester.tap(find.widgetWithText(ChoiceChip, 'Results'));
      await tester.pumpAndSettle();
      expect(find.text('TEST ONLY Result Item'), findsOneWidget);

      // Remove the result
      await tester.tap(find.byTooltip('Remove from history'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing viewed yet'), findsOneWidget);

      library.dispose();
    },
  );

  testWidgets(
    'clearing all history requires confirmation and leaves bookmarks intact',
    (tester) async {
      final store = PrivateStore();
      final history = HistoryLibrary(store);
      final bookmarks = BookmarkLibrary(store);
      await history.load();
      await bookmarks.load();

      await history.record(
        _historyEntry(
          kind: HistoryKind.announcement,
          sourceId: 'ann-1',
          title: 'History item',
          url: _announcementUrl,
        ),
      );

      final bookmark = BookmarkItem(
        id: 'bm-1',
        kind: BookmarkKind.announcement,
        examId: 'exam-test',
        examName: 'Exam Test',
        title: 'Bookmark item',
        url: _announcementUrl,
        savedAtUtc: DateTime.now().toUtc(),
      );
      await bookmarks.toggle(bookmark);

      expect(history.items, hasLength(1));
      expect(bookmarks.items, hasLength(1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryScreen(library: history),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear viewing history'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear viewing history'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Clear viewing history?'), findsOneWidget);
      expect(
        find.textContaining('Your bookmarks will not be affected.'),
        findsOneWidget,
      );

      // Cancel first
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(history.items, hasLength(1));

      // Clear now
      await tester.tap(find.byTooltip('Clear viewing history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();

      expect(history.items, isEmpty);
      expect(find.text('Nothing viewed yet'), findsOneWidget);

      // Bookmarks must remain intact
      expect(bookmarks.items, hasLength(1));
      expect(bookmarks.items.single.id, 'bm-1');

      history.dispose();
      bookmarks.dispose();
    },
  );

  testWidgets(
    'removing a bookmark does not affect history',
    (tester) async {
      final store = PrivateStore();
      final history = HistoryLibrary(store);
      final bookmarks = BookmarkLibrary(store);
      await history.load();
      await bookmarks.load();

      await history.record(
        _historyEntry(
          kind: HistoryKind.announcement,
          sourceId: 'shared-id',
          title: 'Shared source',
          url: _announcementUrl,
        ),
      );

      final bookmark = BookmarkItem(
        id: 'shared-id',
        kind: BookmarkKind.announcement,
        examId: 'exam-test',
        examName: 'Exam Test',
        title: 'Shared source',
        url: _announcementUrl,
        savedAtUtc: DateTime.now().toUtc(),
      );
      await bookmarks.toggle(bookmark);

      expect(history.items, hasLength(1));
      expect(bookmarks.items, hasLength(1));

      // Remove bookmark
      await bookmarks.remove(bookmark.key);
      expect(bookmarks.items, isEmpty);

      // History remains intact
      expect(history.items, hasLength(1));
      expect(history.items.single.sourceId, 'shared-id');

      history.dispose();
      bookmarks.dispose();
    },
  );

  testWidgets(
    'history screen reflows with large text in both light and dark themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final library = HistoryLibrary(PrivateStore());
      await library.load();
      await library.record(
        _historyEntry(
          kind: HistoryKind.result,
          sourceId: 'pub-long',
          title: 'TEST ONLY very long official result publication title Ñ',
          url: _resultUrl,
        ),
      );

      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: HistoryScreen(library: library),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      library.dispose();
    },
  );
}
