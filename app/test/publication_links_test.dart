import 'package:app/domain/models.dart';
import 'package:app/ui/design.dart';
import 'package:app/ui/results.dart';
import 'package:app/ui/shared.dart';
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
      expect(find.text('View list of passers'), findsOneWidget);
      expect(find.text('PRC announcement'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'View list of passers'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'PRC announcement'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'multiple unlabeled lists are distinguishable and fit enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
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
      expect(find.text('View list of passers 1'), findsOneWidget);
      expect(find.text('View list of passers 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a missing list keeps the publication and a reviewed version remains a fallback',
    (tester) async {
      await screen(
        tester,
        ResultsScreen(
          publications: [publication(documents: {})],
          version: null,
        ),
      );
      expect(find.text('View list of passers'), findsNothing);
      expect(find.text('PRC announcement'), findsOneWidget);
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
      expect(find.text('View list of passers'), findsOneWidget);
      expect(find.text('PRC announcement'), findsOneWidget);
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
        find.widgetWithText(SourceButton, 'View list of passers'),
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

  testWidgets('Results offers each labeled list and retains the announcement', (
    tester,
  ) async {
    await screen(
      tester,
      ResultsScreen(
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
    expect(find.text('PRC announcement'), findsOneWidget);
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
      expect(find.text('View list of passers'), findsOneWidget);
      expect(find.text('PRC announcement'), findsOneWidget);
      expect(find.text('Results released'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Check name'), findsNothing);
      expect(
        tester
            .widget<SourceButton>(
              find.widgetWithText(SourceButton, 'View list of passers'),
            )
            .uri,
        list,
      );
    },
  );

  final newer = Publication(
    id: 'newer',
    title: 'TEST ONLY correction',
    url: Uri.parse('https://www.prc.gov.ph/article/test-only-correction'),
    publishedAtUtc: DateTime.utc(2026, 2),
    documents: {secondary: 'Secondary list'},
  );
  final alias = Uri.parse(
    'https://prc.gov.ph/index.php/article/test-only-results',
  );
  ResultVersion result(Uri? url, {Uri? document}) => ResultVersion(
    selection: selection,
    state: PublicationState.checkingAvailable,
    documentVersion: 'v1',
    publicationUrl: url,
    documentUrl: document,
  );

  List<Uri> targets(WidgetTester tester) => tester
      .widgetList<SourceButton>(find.byType(SourceButton))
      .map((button) => button.uri)
      .toList();

  testWidgets('Results groups each article with its own lists', (tester) async {
    await screen(
      tester,
      ResultsScreen(
        version: result(alias),
        publications: [
          newer,
          publication(),
          publication(url: alias),
        ],
      ),
    );
    expect(find.text('Results released'), findsOneWidget);
    expect(find.text('TEST ONLY publication'), findsOneWidget);
    expect(find.textContaining(sourceTime(DateTime.utc(2026))), findsOneWidget);
    expect(
      find.textContaining(sourceTime(newer.publishedAtUtc)),
      findsOneWidget,
    );
    final divider = tester
        .getTopLeft(find.text('Other result publications'))
        .dy;
    expect(
      tester.getTopLeft(find.text('TEST ONLY publication')).dy,
      lessThan(divider),
    );
    expect(
      tester.getTopLeft(find.text('View list of passers')).dy,
      lessThan(divider),
    );
    expect(tester.getTopLeft(find.text(newer.title)).dy, greaterThan(divider));
    expect(
      tester.getTopLeft(find.text('Open Secondary list')).dy,
      greaterThan(divider),
    );
    expect(targets(tester), [list, alias, secondary, newer.url]);
  });

  testWidgets('PRC aliases keep distinct labeled lists on a single article', (
    tester,
  ) async {
    await screen(
      tester,
      ResultsScreen(
        version: null,
        publications: [
          publication(documents: {list: 'Elementary'}),
          publication(url: alias, documents: {secondary: 'Secondary'}),
        ],
      ),
    );
    expect(find.text('TEST ONLY publication'), findsOneWidget);
    expect(find.text('Open Elementary'), findsOneWidget);
    expect(find.text('Open Secondary'), findsOneWidget);
    expect(find.text('Other result publications'), findsNothing);
    expect(targets(tester), [list, secondary, article]);
  });

  testWidgets('missing version features newest and retains earlier sources', (
    tester,
  ) async {
    await screen(
      tester,
      ResultsScreen(version: null, publications: [newer, publication()]),
    );
    expect(find.text('Other result publications'), findsOneWidget);
    expect(targets(tester), [secondary, newer.url, list, article]);
  });

  testWidgets(
    'version outside history keeps its official link and the history',
    (tester) async {
      await screen(
        tester,
        ResultsScreen(
          version: result(article, document: list),
          publications: [newer],
        ),
      );
      expect(find.text('Other result publications'), findsOneWidget);
      expect(targets(tester), [list, article, secondary, newer.url]);
    },
  );

  testWidgets(
    'a version-only document is labeled separately from the featured article',
    (tester) async {
      await screen(
        tester,
        ResultsScreen(
          version: result(null, document: list),
          publications: [newer],
        ),
      );
      expect(find.text(newer.title), findsOneWidget);
      expect(find.text('Other result publications'), findsNothing);
      expect(find.text('Additional official list'), findsOneWidget);
      expect(targets(tester), [secondary, newer.url, list]);
    },
  );
}
