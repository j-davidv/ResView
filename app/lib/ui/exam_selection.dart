import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../data/exam_repository.dart';
import 'shared.dart';

class SelectedExam {
  const SelectedExam(this.exam, this.sitting, this.categoryId);
  final Exam exam;
  final Sitting sitting;
  final String categoryId;
  ExamSelection get selection => ExamSelection(exam.id, sitting.id, categoryId);
  String get description =>
      '${exam.title}\n${sitting.label}${categoryId == 'general' ? '' : '\n${sitting.categories[categoryId] ?? categoryId}'}';
}

class ExamSelectionScreen extends StatefulWidget {
  const ExamSelectionScreen({
    required this.repository,
    required this.onSelected,
    this.current,
    super.key,
  });
  final ExamRepository repository;
  final ValueChanged<SelectedExam> onSelected;
  final SelectedExam? current;
  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionState();
}

class _ExamSelectionState extends State<ExamSelectionScreen> {
  List<Exam> _exams = [];
  List<Sitting> _sittings = [];
  Exam? _exam;
  Sitting? _sitting;
  String? _category;
  DateTimeRange? _range;
  bool _busy = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _exam = widget.current?.exam;
    _sitting = widget.current?.sitting;
    _category = widget.current?.categoryId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final exams = await widget.repository.loadCatalog();
      final sittings = _exam == null
          ? <Sitting>[]
          : await widget.repository.loadSittings(_exam!.id);
      if (mounted) {
        setState(() {
          _exams = exams;
          _sittings = sittings;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _pick<T>(
    String title,
    List<T> values,
    String Function(T) label, {
    bool search = false,
  }) => Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => _ChoicePage<T>(
        title: title,
        values: values,
        label: label,
        search: search,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Heading('Choose your exam'),
      const Text('Browse official announcements. No signup required.'),
      const SizedBox(height: 16),
      if (_busy)
        const LinearProgressIndicator(semanticsLabel: 'Loading exam catalog'),
      if (_failed)
        Notice(
          'Exam catalog unavailable',
          'We could not retrieve the official catalog. Try again when the service is available.',
          action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ),
      if (!_busy && !_failed && _exams.isEmpty)
        Notice(
          'No exams available',
          'The official catalog has not yet been made available.',
          action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ),
      if (!_failed && _exams.isNotEmpty) ...[
        const Heading('Exam'),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  final e = await _pick<Exam>(
                    'Choose exam',
                    _exams,
                    (e) => e.title,
                    search: true,
                  );
                  if (e != null && mounted) {
                    setState(() {
                      _exam = e;
                      _sitting = null;
                      _category = null;
                    });
                    await _load();
                  }
                },
          child: Text(_exam?.title ?? 'Choose exam'),
        ),
        const Heading('Sitting / date range'),
        OutlinedButton(
          onPressed: _exam == null || _busy
              ? null
              : () async {
                  final s = await _pick<Sitting>(
                    'Choose sitting',
                    _sittings
                        .where(
                          (s) =>
                              _range == null ||
                              (!s.end.isBefore(_range!.start) &&
                                  !s.start.isAfter(_range!.end)),
                        )
                        .toList(),
                    (s) => s.label,
                  );
                  if (s != null && mounted) {
                    setState(() {
                      _sitting = s;
                      _category = s.categories.length == 1
                          ? s.categories.keys.single
                          : null;
                    });
                  }
                },
          child: Text(_sitting?.label ?? 'Choose sitting'),
        ),
        TextButton(
          onPressed: _exam == null
              ? null
              : () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: _range,
                  );
                  if (range != null && mounted) setState(() => _range = range);
                },
          child: Text(
            _range == null
                ? 'Filter sitting dates'
                : '${dateLabel(_range!.start)} – ${dateLabel(_range!.end)}',
          ),
        ),
        if (_range != null)
          TextButton(
            onPressed: () => setState(() => _range = null),
            child: const Text('Clear date filter'),
          ),
        if (_sitting != null &&
            !(_sitting!.categories.length == 1 &&
                _sitting!.categories.containsKey('general'))) ...[
          const Heading('Category'),
          OutlinedButton(
            onPressed: () async {
              final c = await _pick<String>(
                'Choose category',
                _sitting!.categories.keys.toList(),
                (c) => _sitting!.categories[c]!,
              );
              if (c != null && mounted) setState(() => _category = c);
            },
            child: Text(_sitting!.categories[_category] ?? 'Choose category'),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed:
              _exam == null || _sitting == null || _category == null || _busy
              ? null
              : () => widget.onSelected(
                  SelectedExam(_exam!, _sitting!, _category!),
                ),
          child: Text(
            widget.current == null ? 'View updates' : 'Apply selection',
          ),
        ),
      ],
    ],
  );
}

class _ChoicePage<T> extends StatefulWidget {
  const _ChoicePage({
    required this.title,
    required this.values,
    required this.label,
    required this.search,
  });
  final String title;
  final List<T> values;
  final String Function(T) label;
  final bool search;
  @override
  State<_ChoicePage<T>> createState() => _ChoiceState<T>();
}

class _ChoiceState<T> extends State<_ChoicePage<T>> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final choices = widget.values
        .where(
          (v) => widget.label(v).toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.search)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search exams',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            if (choices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No choices found. Change the filter or try again later.',
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: choices.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  minVerticalPadding: 16,
                  title: Text(widget.label(choices[index])),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, choices[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
