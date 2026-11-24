import 'dart:convert';

import 'package:app/data/exam_repository.dart';
import 'package:app/domain/bookmark.dart';
import 'package:app/domain/models.dart';
import 'package:app/storage/bookmark_library.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/bookmarks.dart';
import 'package:app/ui/design.dart';
import 'package:app/ui/results.dart';
import 'package:app/ui/shared.dart';
import 'package:app/ui/updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _selection = ExamSelection('exam-test', 'sitting-test', 'general');
final _announcementUrl = Uri.parse(
  'https://www.prc.gov.ph/article/notice-test',
);
final _resultUrl = Uri.parse('https://www.prc.gov.ph/article/result-test');

Finder _filterOption(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem),
);

BookmarkItem _item({
  required BookmarkKind kind,
  required String id,
  required String title,
  required Uri url,
}) => BookmarkItem(
  id: id,
  kind: kind,
  examId: 'exam-test',
  examName: 'TEST ONLY Licensure Examination',
  title: title,
  url: url,
  publishedAtUtc: DateTime.utc(2026, 11, 10),
  savedAtUtc: DateTime.utc(2026, 11, 19),
  sittingLabel: kind == BookmarkKind.result ? 'Domestic · 10/11/2026' : null,
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
  Future<ResultMonitorStatus?> loadResultMonitorStatus() async => null;
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
    'bookmarks persist, deduplicate on read, and tolerate malformed entries',
    () async {
      final announcement = _item(
        kind: BookmarkKind.announcement,
        id: _announcementUrl.toString(),
        title: 'TEST ONLY announcement',
        url: _announcementUrl,
      );
      final encoded = jsonEncode([
        announcement.toJson(),
        {'kind': 'invalid'},
        announcement.toJson(),
      ]);
      FlutterSecureStorage.setMockInitialValues({'bookmarks': encoded});

      final storage = PrivateStore();
      final firstRead = await storage.readBookmarks();
      expect(firstRead, hasLength(1));

      final result = _item(
        kind: BookmarkKind.result,
        id: 'publication-id',
        title: 'TEST ONLY result publication',
        url: _resultUrl,
      );
      await storage.saveBookmarks([...firstRead, result, result]);
      final reopened = PrivateStore();
      final persisted = await reopened.readBookmarks();

      expect(persisted.map((item) => item.key).toSet(), {
        announcement.key,
        result.key,
      });
      await reopened.clearLocalValues();
      expect(await reopened.readBookmarks(), isEmpty);
    },
  );

  test(
    'malformed bookmark storage remains intact and reports a load error',
    () async {
      FlutterSecureStorage.setMockInitialValues({'bookmarks': '[broken'});
      final storage = const FlutterSecureStorage();
      final library = BookmarkLibrary(PrivateStore());

      await library.load();

      expect(library.error, contains('could not be loaded'));
      expect(await storage.read(key: 'bookmarks'), '[broken');
      library.dispose();
    },
  );

  testWidgets('announcement cards expose a bookmark action and toggle it', (
    tester,
  ) async {
    final library = BookmarkLibrary(PrivateStore());
    await library.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpdatesScreen(
              repository: _Repository(),
              selection: _selection,
              examId: _selection.examId,
              examTitle: 'TEST ONLY Licensure Examination',
              bookmarks: library,
              revision: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEST ONLY PRC announcement'), findsOneWidget);
    expect(find.byTooltip('Bookmark announcement'), findsOneWidget);
    final source = tester.widget<SourceButton>(
      find.widgetWithText(SourceButton, 'Open PRC notice'),
    );
    expect(source.uri, _announcementUrl);

    await tester.tap(find.byTooltip('Bookmark announcement'));
    await tester.pumpAndSettle();
    expect(library.items, hasLength(1));
    expect(library.items.single.kind, BookmarkKind.announcement);
    expect(
      find.byTooltip('Remove announcement from bookmarks'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Remove announcement from bookmarks'));
    await tester.pumpAndSettle();
    expect(library.items, isEmpty);
    library.dispose();
  });

  testWidgets('result publications can be bookmarked without outcome claims', (
    tester,
  ) async {
    final library = BookmarkLibrary(PrivateStore());
    await library.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultsScreen(
              version: null,
              publications: [
                Publication(
                  id: 'publication-id',
                  title: 'TEST ONLY official publication',
                  url: _resultUrl,
                  publishedAtUtc: DateTime.utc(2026, 11, 10),
                ),
              ],
              bookmarks: library,
              examId: _selection.examId,
              examName: 'TEST ONLY Licensure Examination',
              sittingLabel: 'Domestic · 10/11/2026',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Results released'), findsOneWidget);
    expect(find.text('Check name'), findsNothing);
    expect(find.byTooltip('Bookmark result publication'), findsOneWidget);
    await tester.tap(find.byTooltip('Bookmark result publication'));
    await tester.pumpAndSettle();
    expect(library.items.single.kind, BookmarkKind.result);
    expect(library.items.single.id, 'publication-id');
    expect(library.items.single.url, _resultUrl);
    library.dispose();
  });

  testWidgets(
    'bookmarks filter by type and removing the last shows empty state',
    (tester) async {
      final library = BookmarkLibrary(PrivateStore());
      await library.load();
      await library.toggle(
        _item(
          kind: BookmarkKind.announcement,
          id: _announcementUrl.toString(),
          title: 'TEST ONLY announcement',
          url: _announcementUrl,
        ),
      );
      await library.toggle(
        _item(
          kind: BookmarkKind.result,
          id: 'publication-id',
          title: 'TEST ONLY result',
          url: _resultUrl,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookmarksScreen(library: library),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEST ONLY announcement'), findsOneWidget);
      expect(find.text('TEST ONLY result'), findsOneWidget);
      final source = tester.widget<SourceButton>(
        find.widgetWithText(SourceButton, 'Open official source').first,
      );
      expect(source.uri, _announcementUrl);

      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.byTooltip('Filter bookmarks'));
      await tester.pumpAndSettle();
      await tester.tap(_filterOption('Announcements'));
      await tester.pumpAndSettle();
      expect(find.text('TEST ONLY announcement'), findsOneWidget);
      expect(find.text('TEST ONLY result'), findsNothing);
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pumpAndSettle();
      expect(find.text('No announcements saved'), findsOneWidget);

      await tester.tap(find.byTooltip('Filter bookmarks'));
      await tester.pumpAndSettle();
      await tester.tap(_filterOption('Results'));
      await tester.pumpAndSettle();
      expect(find.text('TEST ONLY result'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing saved yet'), findsOneWidget);
      library.dispose();
    },
  );

  testWidgets(
    'bookmark filter menu supports selection and dismissal with large text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = BookmarkLibrary(PrivateStore());
      await library.load();
      await library.toggle(
        _item(
          kind: BookmarkKind.result,
          id: 'publication-id',
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
                child: BookmarksScreen(library: library),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.text('Announcements'), findsNothing);
        await tester.tap(find.byTooltip('Filter bookmarks'));
        await tester.pumpAndSettle();
        final all = _filterOption('All');
        final results = _filterOption('Results');
        expect(tester.widget<CheckedPopupMenuItem>(all).checked, isTrue);
        expect(find.text('Announcements'), findsOneWidget);
        await tester.tap(results);
        await tester.pumpAndSettle();
        expect(_filterOption('Results'), findsNothing);
        await tester.tap(find.byTooltip('Filter bookmarks'));
        await tester.pumpAndSettle();
        expect(tester.widget<CheckedPopupMenuItem>(results).checked, isTrue);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Filter bookmarks'));
        await tester.pumpAndSettle();
        expect(tester.widget<CheckedPopupMenuItem>(results).checked, isTrue);
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      library.dispose();
    },
  );
}
