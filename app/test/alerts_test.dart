import 'dart:convert';

import 'package:app/alerts/alert_inbox.dart';
import 'package:app/alerts/exam_alert.dart';
import 'package:app/domain/models.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/alerts.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flows_test.dart' show TestRepository, TestListStore;

class AlertTestRepository extends TestRepository {
  AlertTestRepository() : super(PublicationState.notReleased);
  List<Publication> publications = [];
  @override
  Future<List<Publication>> loadPublications(ExamSelection selection) async =>
      publications;
}

const selection = ExamSelection('test-exam', 'test-sitting', 'general');
final now = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
Sitting sitting({String location = 'TEST ONLY'}) => Sitting(
  id: 'test-sitting',
  examId: 'test-exam',
  start: now,
  end: now,
  type: 'domestic',
  location: location,
  categories: {'general': 'General'},
  catalogUrl: Uri.parse('https://www.prc.gov.ph/2026-schedule-examination'),
);
Publication result(String id) => Publication(
  id: id,
  title: 'TEST ONLY result $id',
  url: Uri.parse('https://www.prc.gov.ph/article/$id'),
  publishedAtUtc: now,
);
AdvisoryFeed feed(String title, String id) => AdvisoryFeed.fromJson({
  'coverageStartUtc': DateTime.utc(2026).toIso8601String(),
  'coverageEndUtc': now.add(const Duration(seconds: 1)).toIso8601String(),
  'lastSuccessfulCheckUtc': now.toIso8601String(),
  'freshness': 'fresh',
  'notices': [
    {
      'kind': 'announcement',
      'title': title,
      'publicationUrl': 'https://www.prc.gov.ph/article/$id',
      'publishedAtUtc': now.toIso8601String(),
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'baseline avoids old alerts; all three new event types survive restart',
    () async {
      final store = PrivateStore();
      final inbox = AlertInbox(store);
      await inbox.observe(
        selection: selection,
        sitting: sitting(),
        publications: [result('old')],
        feed: feed('TEST ONLY old announcement', 'old-notice'),
        now: now,
      );
      expect(inbox.unread(selection), 0);
      await inbox.observe(
        selection: selection,
        sitting: sitting(location: 'TEST ONLY new center'),
        publications: [result('old'), result('new')],
        feed: feed('TEST ONLY official announcement', 'notice'),
        now: now,
      );
      expect(
        inbox.forSelection(selection).map((item) => item.kind).toSet(),
        AlertKind.values.toSet(),
      );
      final restored = AlertInbox(store);
      await restored.load();
      expect(restored.unread(selection), 3);
      await restored.markRead(selection);
      expect(restored.unread(selection), 0);
    },
  );
  test('refresh and push deduplicate the same source and ignore other selections in the view', () async {
    final inbox = AlertInbox(PrivateStore());
    await inbox.observe(
      selection: selection,
      sitting: sitting(),
      publications: [],
      now: now,
    );
    final alert = ExamAlert.fromJson({
      'sourceId': 'https://www.prc.gov.ph/article/new',
      'kind': 'result',
      'title': 'TEST ONLY result',
      'url': 'https://prc.gov.ph/index.php/article/new',
      ...selection.toJson(),
      'publishedAtUtc': now.toIso8601String(),
    });
    await inbox.receive(alert);
    await inbox.observe(
      selection: selection,
      sitting: sitting(),
      publications: [result('new')],
      now: now,
    );
    expect(inbox.unread(selection), 1);
    expect(
      inbox.unread(
        const ExamSelection('other-exam', 'other-sitting', 'general'),
      ),
      0,
    );
    await inbox.clear();
    expect(inbox.unread(selection), 0);
    final restored = AlertInbox(inbox.store);
    await restored.load();
    expect(restored.unread(selection), 0);
  });
  test(
    'same-day midnight publication is new even after a later baseline',
    () async {
      final inbox = AlertInbox(PrivateStore());
      await inbox.observe(
        selection: selection,
        sitting: sitting(),
        publications: [],
        now: now,
      );
      final local = now.add(const Duration(hours: 8));
      final midnight = DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).subtract(const Duration(hours: 8));
      await inbox.observe(
        selection: selection,
        sitting: sitting(),
        publications: [
          Publication(
            id: 'same-day',
            title: 'TEST ONLY same-day result',
            url: Uri.parse('https://www.prc.gov.ph/article/same-day'),
            publishedAtUtc: midnight,
          ),
        ],
        now: now,
      );
      expect(inbox.unread(selection), 1);
    },
  );
  test('untrusted payloads cannot open a source', () {
    expect(
      () => ExamAlert.fromJson({
        'alertId': 'test',
        'kind': 'result',
        'title': 'TEST ONLY',
        'url': 'https://example.com/phishing',
        ...selection.toJson(),
        'publishedAtUtc': now.toIso8601String(),
      }),
      throwsFormatException,
    );
  });
  testWidgets('refresh shows an unread alert and the bell opens its inbox', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'introSeen': 'true',
      'selection': jsonEncode(
        const ExamSelection('test-only', 'test-sitting', 'general').toJson(),
      ),
    });
    final repository = AlertTestRepository();
    await tester.pumpWidget(
      ExamApp(repository: repository, listStore: TestListStore()),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Alerts'), findsOneWidget);
    repository.publications = [result('new-result')];
    await tester.tap(find.byTooltip('Refresh available metadata'));
    await tester.pumpAndSettle();
    expect(find.text('New exam alerts'), findsOneWidget);
    await tester.tap(find.byTooltip('Alerts (1 unread)'));
    await tester.pumpAndSettle();
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('TEST ONLY result new-result'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Alerts'), findsOneWidget);
    expect(find.text('New exam alerts'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('alerts remain readable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final inbox = AlertInbox(PrivateStore());
    await inbox.receive(
      ExamAlert(
        id: 'test',
        kind: AlertKind.announcement,
        title: 'TEST ONLY a long official announcement for your selected examination',
        url: Uri.parse('https://www.prc.gov.ph/article/test'),
        selection: selection,
        posted: now,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AlertsScreen(inbox: inbox, selection: selection, onOpen: (_) {}),
      ),
    );
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.textContaining('TEST ONLY a long'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
