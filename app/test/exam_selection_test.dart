import 'package:app/data/exam_repository.dart';
import 'package:app/domain/models.dart';
import 'package:app/ui/exam_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SelectionRepository implements ExamRepository {
  SelectionRepository(this.title, this.categories);
  final String title;
  final List<Map<String, String>> categories;

  @override
  Future<AdvisoryFeed?> loadAdvisories(String examId) async => null;
  @override
  Future<List<Exam>> loadCatalog() async => [Exam('test-exam', title)];

  @override
  Future<List<Sitting>> loadSittings(String examId) async => [
    for (var i = 0; i < categories.length; i++)
      Sitting(
        id: 'sitting-$i',
        examId: examId,
        start: DateTime.utc(2026, 10, i + 1),
        end: DateTime.utc(2026, 10, i + 1),
        type: 'domestic',
        location: '',
        categories: categories[i],
      ),
  ];

  @override
  Future<List<Publication>> loadPublications(ExamSelection selection) async =>
      [];

  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async =>
      null;
}

Future<void> openSelection(
  WidgetTester tester,
  SelectionRepository repository,
  ValueChanged<SelectedExam> onSelected,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExamSelectionScreen(
            repository: repository,
            onSelected: onSelected,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose exam'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(repository.title));
  await tester.pumpAndSettle();
}

void main() {
  for (final category in ['all', 'general', 'custom']) {
    testWidgets(
      'sole $category category is hidden and submitted automatically',
      (tester) async {
        final repository = SelectionRepository('Test exam', [
          {category: 'Only group'},
        ]);
        SelectedExam? selected;
        await openSelection(tester, repository, (value) => selected = value);
        await tester.tap(find.text('Choose sitting'));
        await tester.pumpAndSettle();
        final sitting = (await repository.loadSittings('test-exam')).single;
        await tester.tap(find.text(sitting.label));
        await tester.pumpAndSettle();
        expect(find.text('Category'), findsNothing);
        expect(find.text('Only group'), findsNothing);
        await tester.tap(find.text('View results'));
        expect(
          selected?.selection,
          ExamSelection('test-exam', sitting.id, category),
        );
        expect(selected?.details, sitting.label);
        expect(selected?.description, 'Test exam\n${sitting.label}');
      },
    );
  }

  for (final teachers in [true, false]) {
    testWidgets('multiple categories require a choice (teachers: $teachers)', (
      tester,
    ) async {
      final repository = SelectionRepository(
        teachers ? 'Professional Teachers (SPLE)' : 'Test exam',
        [
          {'elementary': 'Elementary', 'secondary': 'Secondary'},
          {'all': 'All successful examinees'},
        ],
      );
      SelectedExam? selected;
      await openSelection(tester, repository, (value) => selected = value);
      final sittings = await repository.loadSittings('test-exam');
      await tester.tap(find.text('Choose sitting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sittings.first.label));
      await tester.pumpAndSettle();
      final label = teachers ? 'Teaching level' : 'Category';
      final prompt = teachers ? 'Choose teaching level' : 'Choose category';
      expect(find.text(label), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(prompt));
      await tester.pumpAndSettle();
      expect(find.text(prompt), findsOneWidget);
      await tester.tap(find.text('Secondary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View results'));
      expect(selected?.categoryId, 'secondary');
      expect(selected?.details, '${sittings.first.label}\nSecondary');

      await tester.tap(
        find.widgetWithText(OutlinedButton, sittings.first.label),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(sittings.last.label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      await tester.tap(find.text('View results'));
      expect(selected?.categoryId, 'all');
      expect(selected?.details, sittings.last.label);

      await tester.tap(
        find.widgetWithText(OutlinedButton, sittings.last.label),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(sittings.first.label));
      await tester.pumpAndSettle();
      expect(find.text(prompt), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  }
}
