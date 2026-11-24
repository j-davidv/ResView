import 'package:app/ui/results.dart';
import 'package:app/domain/models.dart';
import 'package:app/ui/shared.dart';
import 'package:app/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Sitting teacherSitting({DateTime? target}) => Sitting(
  id: 'teachers-2026-09-20',
  examId: 'teachers',
  start: DateTime.utc(2026, 9, 20),
  end: DateTime.utc(2026, 9, 20),
  type: 'domestic',
  location: '',
  categories: {'elementary': 'Elementary'},
  targetReleaseDate: target,
  catalogUrl: Uri.parse('https://www.prc.gov.ph/2026-schedule-examination'),
);

Future<void> showStatus(WidgetTester tester, ResultsScreen screen) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: screen)),
      ),
    );

void main() {
  testWidgets(
    'empty successful results do not imply a publication service failure',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ResultsScreen(version: null))),
      );
      expect(
        find.text('No verified result announcement found'),
        findsOneWidget,
      );
      expect(find.text('Publication status unavailable'), findsNothing);
      expect(find.text('Results released'), findsNothing);
    },
  );

  testWidgets(
    'Teachers awaits the published target through its Philippine calendar day',
    (tester) async {
      for (final now in [
        DateTime.utc(2026, 11, 24),
        DateTime.utc(2026, 11, 27, 15, 59),
      ]) {
        await showStatus(
          tester,
          ResultsScreen(
            version: null,
            sitting: teacherSitting(target: DateTime.utc(2026, 11, 27)),
            now: now,
          ),
        );
        expect(find.text('Awaiting results'), findsOneWidget);
        expect(
          find.textContaining('PRC target release: 27/11/2026'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Actual release may change.'),
          findsOneWidget,
        );
        final source = tester.widget<SourceButton>(
          find.widgetWithText(SourceButton, 'PRC exam schedule'),
        );
        expect(
          source.uri.toString(),
          'https://www.prc.gov.ph/2026-schedule-examination',
        );
        expect(find.text('Results released'), findsNothing);
      }
      await showStatus(
        tester,
        ResultsScreen(
          version: null,
          sitting: teacherSitting(target: DateTime.utc(2026, 11, 27)),
          now: DateTime.utc(2026, 11, 27, 16),
        ),
      );
      expect(
        find.text('No verified result announcement found'),
        findsOneWidget,
      );
      expect(find.textContaining('target date has passed'), findsOneWidget);
      expect(find.text('Results released'), findsNothing);
    },
  );

  testWidgets('exam start and end use inclusive Philippine calendar days', (
    tester,
  ) async {
    final sitting = Sitting(
      id: 'test',
      examId: 'test',
      start: DateTime.utc(2026, 11, 25),
      end: DateTime.utc(2026, 11, 27),
      type: 'oral',
      location: 'Davao',
      categories: {'all': 'All'},
    );
    for (final test in [
      (DateTime.utc(2026, 11, 24, 15, 59), 'Upcoming exam'),
      (DateTime.utc(2026, 11, 24, 16), 'Exam in progress'),
      (DateTime.utc(2026, 11, 27, 15, 59), 'Exam in progress'),
      (DateTime.utc(2026, 11, 27, 16), 'No verified result announcement found'),
    ]) {
      await showStatus(
        tester,
        ResultsScreen(version: null, sitting: sitting, now: test.$1),
      );
      expect(find.text(test.$2), findsOneWidget);
      expect(find.text('Results released'), findsNothing);
    }
  });

  testWidgets(
    'missing target and stale monitor remain explicit without inventing a check',
    (tester) async {
      final checked = DateTime.utc(2026, 11, 23, 16, 33);
      await showStatus(
        tester,
        ResultsScreen(
          version: null,
          sitting: teacherSitting(),
          now: DateTime.utc(2026, 11, 24),
          monitorStatus: ResultMonitorStatus(
            freshness: 'fresh',
            lastSuccessfulCheckUtc: checked,
          ),
        ),
      );
      expect(find.textContaining('PRC target release:'), findsNothing);
      expect(
        find.text(
          'Last successful PRC results check: 24/11/2026 00:33 UTC+08:00',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('may be outdated'), findsOneWidget);
      await showStatus(
        tester,
        ResultsScreen(
          version: null,
          sitting: teacherSitting(),
          now: DateTime.utc(2026, 11, 24),
          monitorStatus: ResultMonitorStatus(
            freshness: 'fresh',
            lastSuccessfulCheckUtc: DateTime.utc(2026, 11, 23, 23, 30),
          ),
        ),
      );
      expect(find.textContaining('may be outdated'), findsNothing);
    },
  );

  testWidgets(
    'known publication overrides dates, loading and a failed refresh',
    (tester) async {
      await showStatus(
        tester,
        ResultsScreen(
          version: null,
          loading: true,
          failed: true,
          sitting: teacherSitting(target: DateTime.utc(2026, 11, 27)),
          now: DateTime.utc(2026, 9, 1),
          publications: [
            Publication(
              id: 'release',
              title: 'Official release',
              url: Uri.parse('https://www.prc.gov.ph/article/test-release'),
              publishedAtUtc: DateTime.utc(2026, 11, 26),
            ),
          ],
        ),
      );
      expect(find.text('Results released'), findsOneWidget);
      expect(find.text('PRC announcement'), findsOneWidget);
      expect(find.text('Upcoming exam'), findsNothing);
    },
  );

  testWidgets(
    'initial failure offers retry without claiming a missing release',
    (tester) async {
      var retried = false;
      await showStatus(
        tester,
        ResultsScreen(
          version: null,
          failed: true,
          sitting: teacherSitting(),
          onRetry: () {
            retried = true;
          },
        ),
      );
      expect(find.text("Couldn't refresh"), findsOneWidget);
      expect(find.text('No verified result announcement found'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'awaiting results fits narrow screens at double text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ResultsScreen(
                  version: null,
                  sitting: teacherSitting(target: DateTime.utc(2026, 11, 27)),
                  now: DateTime.utc(2026, 11, 24),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Awaiting results'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
