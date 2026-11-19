import 'dart:async';

import 'package:app/domain/models.dart';
import 'package:app/main.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/shared.dart';
import 'package:app/ui/updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flows_test.dart' show TestRepository, TestListStore;

const selection = ExamSelection('test-only', 'test-sitting', 'general');
const other = ExamSelection('other-exam', 'test-sitting', 'special');
final source = Uri.parse('https://www.prc.gov.ph/article/test-only-change');
Map<String, dynamic> snapshot({
  bool empty = false,
  bool stale = false,
  DateTime? checked,
}) => {
  'coverageStartUtc': '2026-06-30T16:00:00Z',
  'coverageEndUtc': '2026-07-31T16:00:00Z',
  'lastSuccessfulCheckUtc': (checked ?? DateTime.now())
      .toUtc()
      .toIso8601String(),
  'freshness': stale ? 'stale' : 'fresh',
  'notices': [
    if (!empty)
      {
        'kind': 'announcement',
        'title': 'TEST ONLY postponement',
        'publicationUrl': source.toString(),
        'publishedAtUtc': '2026-07-14T16:00:00Z',
      },
  ],
};

class AdvisoryRepository extends TestRepository {
  AdvisoryRepository() : super(PublicationState.notReleased) {
    emptyHistory = true;
  }
  final reads = <String>[];
  Future<AdvisoryFeed?> Function(String) read = (_) async => null;
  @override
  Future<AdvisoryFeed?> loadAdvisories(String examId) {
    reads.add(examId);
    return read(examId);
  }
}

void main() {
  testWidgets('notice-only sitting has separate Updates and Results reads', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'});
    await PrivateStore().saveSelection(selection);
    final repo = AdvisoryRepository()
      ..read = (_) async {
        final data = snapshot();
        (data['notices'] as List).add(<String, String>{
          ...(data['notices'] as List).first as Map<String, String>,
          'title': 'Earlier PRC announcement',
          'publishedAtUtc': '2026-07-01T16:00:00Z',
          'publicationUrl': 'https://prc.gov.ph/article/earlier',
        });
        return AdvisoryFeed.fromJson(data);
      };
    await tester.pumpWidget(
      ExamApp(
        repository: repo,
        listStore: TestListStore(),
        advisoryPilot: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.reads, isEmpty);
    expect(find.text('Not released'), findsOneWidget);
    await tester.tap(find.text('Updates').last);
    await tester.pumpAndSettle();
    expect(repo.reads, [selection.examId]);
    expect(find.text('TEST ONLY postponement'), findsOneWidget);
    expect(find.text('Latest update'), findsOneWidget);
    expect(
      tester
          .widget<SourceButton>(
            find.widgetWithText(SourceButton, 'Open PRC notice'),
          )
          .uri,
      source,
    );
    await tester.ensureVisible(find.text('View all updates'));
    await tester.tap(find.text('View all updates'));
    await tester.pumpAndSettle();
    expect(find.text('All updates'), findsOneWidget);
    expect(find.text('TEST ONLY postponement'), findsOneWidget);
    expect(find.text('Earlier PRC announcement'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Earlier PRC announcement'), findsNothing);
    expect(find.text('PRC announcement'), findsNothing);
    repo.read = (_) async => throw StateError('offline');
    await tester.tap(find.byTooltip('Refresh available metadata'));
    await tester.pumpAndSettle();
    expect(find.text('Exam updates may be outdated'), findsOneWidget);
    expect(find.textContaining('Last successful check'), findsOneWidget);
    expect(find.text('TEST ONLY postponement'), findsOneWidget);
    await tester.tap(find.text('Results').last);
    await tester.pumpAndSettle();
    expect(find.text('Not released'), findsOneWidget);
    expect(find.text('Results released'), findsNothing);
  });

  testWidgets('only a fresh empty feed declares its checked window', (
    tester,
  ) async {
    final repo = AdvisoryRepository();
    Future<void> show(
      Future<AdvisoryFeed?> Function(String) read,
      int revision,
    ) async {
      repo.read = read;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UpdatesScreen(
                repository: repo,
                selection: selection,
                revision: revision,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const empty = 'No verified updates for this exam';
    await show((_) async => null, 0);
    expect(
      find.text('Update history unavailable for this exam'),
      findsOneWidget,
    );
    await show((_) async => throw StateError('offline'), 1);
    expect(find.text('Exam updates unavailable'), findsOneWidget);
    expect(find.text(empty), findsNothing);
    await show((_) async => AdvisoryFeed.fromJson(snapshot(empty: true)), 2);
    expect(find.text(empty), findsOneWidget);
    expect(find.textContaining('01/07/2026 – 31/07/2026'), findsOneWidget);
    await show((_) async => throw StateError('offline'), 3);
    expect(find.text(empty), findsNothing);
    final retry = Completer<AdvisoryFeed?>();
    repo.read = (_) => retry.future;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text(empty), findsNothing);
    expect(find.text('Exam updates may be outdated'), findsOneWidget);
    retry.complete(AdvisoryFeed.fromJson(snapshot(empty: true)));
    await tester.pumpAndSettle();
    expect(find.text(empty), findsOneWidget);
    await show(
      (_) async => AdvisoryFeed.fromJson(snapshot(empty: true, stale: true)),
      4,
    );
    expect(find.text(empty), findsNothing);
    await show(
      (_) async => AdvisoryFeed.fromJson(
        snapshot(checked: DateTime.now().subtract(const Duration(days: 2))),
      ),
      5,
    );
    expect(find.text('Exam updates may be outdated'), findsOneWidget);
    expect(find.text('Open PRC notice'), findsOneWidget);
  });

  testWidgets('a delayed read cannot cross exam boundaries', (tester) async {
    final pending = Completer<AdvisoryFeed?>();
    final repo = AdvisoryRepository()
      ..read = (key) async => key == selection.examId ? pending.future : null;
    Future<void> show(ExamSelection key) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdatesScreen(repository: repo, selection: key, revision: 0),
        ),
      ),
    );
    await show(selection);
    await show(other);
    await tester.pumpAndSettle();
    pending.complete(AdvisoryFeed.fromJson(snapshot()));
    await tester.pumpAndSettle();
    expect(repo.reads, [selection.examId, other.examId]);
    expect(find.text('TEST ONLY postponement'), findsNothing);
    expect(
      find.text('Update history unavailable for this exam'),
      findsOneWidget,
    );
  });

  test('malformed coverage, dates, kinds and external URLs cannot imply a successful scan', () {
    for (final patch in [
      {'kind': 'result'},
      {'publicationUrl': 'https://other.example/article/test'},
      {'publishedAtUtc': '2026-02-30T00:00:00Z'},
      {'publishedAtUtc': '2026-08-01T00:00:00Z'},
    ]) {
      final data = snapshot();
      (data['notices'] as List).first.addAll(patch);
      expect(() => AdvisoryFeed.fromJson(data), throwsFormatException);
    }
    expect(
      () => AdvisoryFeed.fromJson({
        ...snapshot(empty: true),
        'coverageEndUtc': 'invalid',
      }),
      throwsFormatException,
    );
    expect(
      () => AdvisoryFeed.fromJson({
        ...snapshot(empty: true),
        'lastSuccessfulCheckUtc': null,
      }),
      throwsFormatException,
    );
  });
}
