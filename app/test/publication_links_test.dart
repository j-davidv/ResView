import 'package:app/domain/models.dart';
import 'package:app/ui/results.dart';
import 'package:app/ui/shared.dart';
import 'package:app/ui/updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final article = Uri.parse('https://www.prc.gov.ph/article/test-only-results');
final list = Uri.parse('https://drive.google.com/file/d/TESTONLY123/view');
final secondary = Uri.parse('https://drive.google.com/file/d/TESTONLY456/view');
const selection = ExamSelection('test-only', 'test-only', 'all');

Publication publication({Uri? url, Map<Uri, String>? documents}) => Publication(
  id: 'test-only',
  title: 'TEST ONLY publication',
  url: url ?? article,
  publishedAtUtc: DateTime.utc(2026),
  documents: documents ?? {list: 'successful-examinee list'},
);

Future<void> screen(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'Results retains known source links when result-version metadata is missing',
    (tester) async {
      await screen(
        tester,
        ResultsScreen(version: null, publications: [publication()]),
      );
      expect(find.text('Results released'), findsOneWidget);
      expect(find.text('Open successful-examinee list'), findsOneWidget);
      expect(find.text('Open PRC publication'), findsOneWidget);
    },
  );
  testWidgets(
    'multiple unlabeled lists are distinguishable and fit enlarged text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfficialSourceLinks(
                publicationUrl: article,
                documents: {
                  list: 'successful-examinee list',
                  secondary: 'successful-examinee list',
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Open successful-examinee list 1'), findsOneWidget);
      expect(find.text('Open successful-examinee list 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a missing list keeps the publication and a reviewed version remains a fallback',
    (tester) async {
      await screen(
        tester,
        UpdatesScreen(
          publications: [publication(documents: {})],
          version: null,
        ),
      );
      expect(find.text('Open successful-examinee list'), findsNothing);
      expect(find.text('Open PRC publication'), findsOneWidget);
      await screen(
        tester,
        SourceLinks(
          ResultVersion(
            selection: selection,
            state: PublicationState.checkingAvailable,
            documentVersion: 'test-only',
            publicationUrl: article,
            documentUrl: list,
          ),
        ),
      );
      expect(find.text('Open successful-examinee list'), findsOneWidget);
      expect(find.text('Open PRC publication'), findsOneWidget);
    },
  );

  testWidgets(
    'fresh announcement links replace an older reviewed document link',
    (tester) async {
      await screen(
        tester,
        SourceLinks(
          ResultVersion(
            selection: selection,
            state: PublicationState.checkingAvailable,
            documentVersion: 'test-only',
            publicationUrl: article,
            documentUrl: list,
          ),
          publications: [
            publication(documents: {secondary: 'successful-examinee list'}),
          ],
        ),
      );
      final button = tester.widget<SourceButton>(
        find.widgetWithText(SourceButton, 'Open successful-examinee list'),
      );
      expect(button.uri, secondary);
      expect(find.byType(SourceButton), findsNWidgets(2));
    },
  );

  test('preserves qualified labels, deduplicates and omits unsafe or malformed links', () {
    final result = successfulExamineeLinks({
      'documents': [
        list.toString(),
        secondary.toString(),
        'javascript:alert(1)',
        '/relative.pdf',
        42,
      ],
      'documentCandidates': [
        {
          'url': secondary.toString(),
          'label': 'List of Successful Examinees for Secondary',
        },
        {
          'url': 'https://name:password@example.org/list.pdf',
          'label': 'Invalid URL',
        },
        {'url': 'https://example.org/ignored.pdf', 'label': null},
        null,
      ],
    });
    expect(result, {
      secondary: 'List of Successful Examinees for Secondary',
      list: 'successful-examinee list',
    });
    expect(
      successfulExamineeLinks({
        'documents': false,
        'documentCandidates': 'bad',
      }),
      isEmpty,
    );
  });

  testWidgets('Updates offers each labeled list and retains the announcement', (
    tester,
  ) async {
    await screen(
      tester,
      UpdatesScreen(
        publications: [
          publication(
            documents: {
              list: 'List of Successful Examinees for Elementary',
              secondary: 'List of Successful Examinees for Secondary',
            },
          ),
        ],
        version: null,
      ),
    );
    expect(
      find.text('Open List of Successful Examinees for Elementary'),
      findsOneWidget,
    );
    expect(
      find.text('Open List of Successful Examinees for Secondary'),
      findsOneWidget,
    );
    expect(find.text('Open PRC publication'), findsOneWidget);
  });

  testWidgets(
    'Results offers an official list even when automatic checking is unavailable',
    (tester) async {
      await screen(
        tester,
        ResultsScreen(
          version: ResultVersion(
            selection: selection,
            state: PublicationState.checkingUnavailable,
            documentVersion: 'test-only',
            publicationUrl: Uri.parse(
              'https://prc.gov.ph/index.php/article/test-only-results',
            ),
          ),
          publications: [publication()],
        ),
      );
      expect(find.text('Open successful-examinee list'), findsOneWidget);
      expect(find.text('Open PRC publication'), findsOneWidget);
      expect(find.text('Results released'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Check name'), findsNothing);
      expect(
        tester
            .widget<SourceButton>(
              find.widgetWithText(
                SourceButton,
                'Open successful-examinee list',
              ),
            )
            .uri,
        list,
      );
    },
  );

  testWidgets('Results does not borrow a list from a different announcement', (
    tester,
  ) async {
    await screen(
      tester,
      ResultsScreen(
        version: ResultVersion(
          selection: selection,
          state: PublicationState.checkingUnavailable,
          documentVersion: 'test-only',
          publicationUrl: article,
        ),
        publications: [
          publication(
            url: Uri.parse('https://www.prc.gov.ph/article/different-release'),
          ),
        ],
      ),
    );
    expect(find.text('Open successful-examinee list'), findsNothing);
    expect(find.text('Open PRC publication'), findsOneWidget);
  });
}
