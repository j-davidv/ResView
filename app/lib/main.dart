import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'alerts/push_preferences.dart';
import 'data/exam_repository.dart';
import 'data/firestore_repository.dart';
import 'domain/models.dart';
import 'storage/private_store.dart';
import 'storage/list_store.dart';
import 'ui/check_name.dart';
import 'ui/exam_selection.dart';
import 'ui/results.dart';
import 'ui/settings.dart';
import 'ui/shared.dart';
import 'ui/updates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if (project.isNotEmpty) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
          projectId: project,
        ),
      );
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
    } catch (_) {}
  }
  runApp(const ExamApp());
}

ThemeData appTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff185f59),
    brightness: brightness,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleMedium: base.textTheme.titleMedium!.copyWith(fontSize: 18),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(fontSize: 16),
      bodySmall: base.textTheme.bodySmall!.copyWith(fontSize: 14),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

class ExamApp extends StatelessWidget {
  const ExamApp({this.repository, this.listStore, super.key});
  final ExamRepository? repository;
  final ListStore? listStore;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PRC Exam Updates',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: _ExamHome(
      lists: listStore,
      repository:
          repository ??
          FirestoreExamRepository(
            Firebase.apps.isEmpty ? null : FirebaseFirestore.instance,
          ),
    ),
  );
}

class _ExamHome extends StatefulWidget {
  const _ExamHome({required this.repository, this.lists});
  final ExamRepository repository;
  final ListStore? lists;
  @override
  State<_ExamHome> createState() => _ExamHomeState();
}

class _ExamHomeState extends State<_ExamHome> {
  static const _titles = ['Updates', 'Results', 'Check name', 'Settings'];
  static const _icons = [
    Icons.article_outlined,
    Icons.fact_check_outlined,
    Icons.person_search_outlined,
    Icons.settings_outlined,
  ];
  final _store = PrivateStore();
  late final _lists = widget.lists ?? ListStore();
  late final _push = PushPreferences(store: _store);
  int _destination = 0, _generation = 0;
  SelectedExam? _selected;
  String? _savedDescription;
  NameInput? _nameDraft;
  ResultVersion? _version;
  List<Publication> _publications = [];
  bool _loading = false, _failed = false;
  String? _localError;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      await _lists.cleanupTemporary();
      await _push.restore();
      final selection = await _store.readSelection();
      if (selection == null) return;
      final exams = await widget.repository.loadCatalog();
      final sittings = await widget.repository.loadSittings(selection.examId);
      final exam = exams.where((e) => e.id == selection.examId).firstOrNull;
      final sitting = sittings
          .where((s) => s.id == selection.sittingId)
          .firstOrNull;
      if (exam != null &&
          sitting != null &&
          sitting.categories.containsKey(selection.categoryId) &&
          mounted) {
        setState(
          () => _selected = SelectedExam(exam, sitting, selection.categoryId),
        );
        await _refresh();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _localError = 'Some saved preferences could not be restored. Your data has not been deleted.',
        );
      }
    }
  }

  @override
  void dispose() {
    _push.dispose();
    super.dispose();
  }

  Future<void> _select(SelectedExam selected) async {
    setState(() {
      _selected = selected;
      _savedDescription = null;
      _version = null;
      _publications = [];
    });
    try {
      await _store.saveSelection(selected.selection);
    } catch (_) {
      if (mounted) {
        feedback(
          context,
          'Selection could not be saved. It remains available for this session.',
        );
      }
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_selected == null) return;
    final generation = ++_generation;
    final selection = _selected!.selection;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final publications = await widget.repository.loadPublications(selection);
      final version = await widget.repository.loadResultVersion(selection);
      if (mounted && generation == _generation) {
        setState(() {
          _publications = publications;
          _version = version;
        });
        if (version != null) {
          try {
            await _lists.observeVersion(version);
          } catch (_) {
            if (mounted) {
              setState(
                () => _localError = 'Saved-list version status could not be updated. Retry before reusing an offline list.',
              );
            }
          }
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          final old = _version;
          if (old != null) {
            _version = ResultVersion(
              selection: old.selection,
              state: old.state,
              documentVersion: old.documentVersion,
              freshness: SourceFreshness.stale,
              lastSuccessfulCheckUtc: old.lastSuccessfulCheckUtc,
              publicationUrl: old.publicationUrl,
              documentUrl: old.documentUrl,
              namesUrl: old.namesUrl,
              namesBytes: old.namesBytes,
              namesSha256: old.namesSha256,
              validatedAtUtc: old.validatedAtUtc,
              reason: old.reason,
            );
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _change() async {
    final selected = await Navigator.push<SelectedExam>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Exam selection')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ExamSelectionScreen(
                repository: widget.repository,
                current: _selected,
                onSelected: (selected) => Navigator.pop(context, selected),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _select(selected);
  }

  Widget _content() {
    if (_destination == 3) {
      return SettingsScreen(
        store: _store,
        lists: _lists,
        push: _push,
        selection: _selected?.selection,
        onChange: _change,
        onEditName: () => setState(() => _destination = 2),
        onNameDeleted: () => _nameDraft = null,
        onLocalDeleted: () => setState(() {
          _nameDraft = null;
          _selected = null;
          _version = null;
          _publications = [];
          _generation++;
        }),
        onUseSaved: (saved) => setState(() {
          _selected = null;
          _savedDescription = saved.contextDescription;
          _version = saved.version;
          _destination = 2;
        }),
      );
    }
    if (_destination == 2) {
      return CheckNameScreen(
        key: ValueKey(
          '${_selected?.selection.hashCode}/${_version?.documentVersion}/${_version?.state}',
        ),
        version: _version,
        publications: _publications,
        store: _store,
        lists: _lists,
        contextDescription: _selected?.description ?? _savedDescription,
        initialDraft: _nameDraft,
        onDraftChanged: (name) => _nameDraft = name,
        hasSelection: _selected != null || _version != null,
        onChooseExam: _change,
        onViewResults: () => setState(() => _destination = 1),
      );
    }
    if (_selected == null) {
      return ExamSelectionScreen(
        repository: widget.repository,
        onSelected: _select,
      );
    }
    if (_loading && _version == null && _publications.isEmpty) {
      return const Notice(
        'Loading official information',
        'Retrieving available publications and validation metadata.',
        action: LinearProgressIndicator(
          semanticsLabel: 'Loading official information',
        ),
      );
    }
    if (_failed && _version == null && _publications.isEmpty) {
      return Notice(
        'Official information unavailable',
        'The service could not be reached. This does not establish whether results have been released.',
        action: OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
      );
    }
    return _destination == 0
        ? UpdatesScreen(publications: _publications, version: _version)
        : ResultsScreen(
            version: _version,
            publications: _publications,
            onCheck: () => setState(() => _destination = 2),
          );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600 && constraints.maxHeight >= 500;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final content = SingleChildScrollView(
        key: ValueKey(_destination),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selected!.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(onPressed: _change, child: const Text('Change')),
                  ],
                ),
              ),
            if (_selected == null && _version != null)
              Notice(
                'Saved offline list',
                '${_savedDescription ?? 'Saved exam context unavailable. Confirm the sitting in the official publication.'}\nThis device cannot know about corrections published while offline.',
                warning: true,
              ),
            if (_localError != null && _destination == 3)
              Notice('Device preferences', _localError!),
            if (_failed && (_version != null || _publications.isNotEmpty))
              const Notice(
                'Refresh unavailable',
                'Showing previously retrieved information.',
                warning: true,
              ),
            if (_loading && _version != null) const LinearProgressIndicator(),
            _content(),
          ],
        ),
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_destination]),
          actions: [
            if (_selected != null && _destination < 2)
              IconButton(
                tooltip: 'Refresh available metadata',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                NavigationRail(
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: _destination,
                  onDestinationSelected: (index) =>
                      setState(() => _destination = index),
                  destinations: [
                    for (var i = 0; i < 4; i++)
                      NavigationRailDestination(
                        icon: Icon(_icons[i]),
                        label: Text(_titles[i]),
                      ),
                  ],
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelMedium!
                        .copyWith(fontSize: 12 * scale / scale.clamp(1, 1.3)),
                  ),
                ),
                child: NavigationBar(
                  height: scale > 1.4 ? 116 : 80,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _destination,
                  onDestinationSelected: (index) =>
                      setState(() => _destination = index),
                  destinations: [
                    for (var i = 0; i < 4; i++)
                      NavigationDestination(
                        icon: Icon(_icons[i]),
                        label: _titles[i],
                      ),
                  ],
                ),
              ),
      );
    },
  );
}
