import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/main.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/matching_worker.dart';
import 'package:app/storage/list_store.dart';
import 'package:app/ui/results.dart';
import 'package:app/ui/shared.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'near-limit isolated list leaves the root isolate responsive and cancellation stops matching',
    (tester) async {
      const selection = ExamSelection('test-only', 'test-only', 'general');
      final entries = List.generate(
        38000,
        (i) => NameEntry(
          sequence: i + 1,
          publishedName: 'TEST ONLY, LONG ${'NAME ' * 80}$i',
          sectionId: 'test-only',
          physicalPage: 1,
        ),
      );
      final byteCount = utf8
          .encode(
            jsonEncode(
              entries
                  .map(
                    (e) => {
                      'sequence': e.sequence,
                      'publishedName': e.publishedName,
                      'sectionId': e.sectionId,
                      'physicalPage': e.physicalPage,
                    },
                  )
                  .toList(),
            ),
          )
          .length;
      expect(byteCount, greaterThan(18 * 1024 * 1024));
      expect(byteCount, lessThan(20 * 1024 * 1024));
      final doc = NamesDocument(
        selection: selection,
        documentVersion: 'test-only',
        entries: entries,
      );
      var ticks = 0;
      final ticker = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => ticks++,
      );
      try {
        expect(
          await matchOnDevice(
            doc,
            const NameInput('NO EXACT', 'TEST ONLY', '', ''),
            possible: false,
          ),
          isEmpty,
        );
      } finally {
        ticker.cancel();
      }
      expect(ticks, greaterThan(0));
      await expectLater(
        matchOnDevice(
          doc,
          const NameInput('NO EXACT', 'TEST ONLY', '', ''),
          possible: false,
          registerCancellation: (cancel) => cancel(),
        ),
        throwsA(isA<ListFailure>()),
      );
    },
  );
  testWidgets(
    'all publication states stay separate from stale freshness on Android',
    (tester) async {
      for (final state in PublicationState.values) {
        final version = ResultVersion(
          selection: const ExamSelection('test-only', 'test-only', 'general'),
          state: state,
          documentVersion: 'test-only',
          freshness: SourceFreshness.stale,
          lastSuccessfulCheckUtc: DateTime.utc(2026, 10, 14),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: Scaffold(
              appBar: AppBar(title: const Text('Isolated state test')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ResultsScreen(version: version, onCheck: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(publicationLabel(state)), findsOneWidget);
        expect(find.text('Source information may be outdated'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'native background matching preserves accents and published entries',
    (tester) async {
      final doc = NamesDocument(
        selection: const ExamSelection('test-only', 'test-only', 'general'),
        documentVersion: 'test-only',
        entries: [
          const NameEntry(
            sequence: 1,
            publishedName: 'PEÑA, Ana Marie',
            sectionId: 'test-only',
            physicalPage: 1,
          ),
          const NameEntry(
            sequence: 2,
            publishedName: 'PEÑA, ANA MARIE',
            sectionId: 'test-only',
            physicalPage: 2,
          ),
        ],
      );
      final exact = await matchOnDevice(
        doc,
        const NameInput('PEN\u0303A', 'ANA MARIE', '', ''),
        possible: false,
      );
      expect(exact.length, 2);
      expect(exact.first.publishedName, 'PEÑA, Ana Marie');
      expect(
        await matchOnDevice(
          doc,
          const NameInput('PENA', 'ANA MARIE', '', ''),
          possible: false,
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'normal Android runtime has honest availability and usable long-name form',
    (tester) async {
      await tester.pumpWidget(const ExamApp());
      await tester.pumpAndSettle();
      expect(find.text('Exam catalog unavailable'), findsOneWidget);
      expect(find.textContaining('Demo data'), findsNothing);
      await tester.tap(find.text('Check name').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'TEST ONLY — PEÑA DELA CRUZ COMPOUND SURNAME WITH LONG TEXT',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'TEST ONLY LONG GIVEN NAMES',
      );
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      expect(
        await const MethodChannel('org.resview/private')
            .invokeMethod<String>('normalizeNfc', 'PEN\u0303A'),
        'PEÑA',
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('check-name');
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Privacy and data'), findsOneWidget);
      expect(find.text('Email signup unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
