import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'alerts/push_preferences.dart';
import 'data/exam_repository.dart';
import 'data/firestore_repository.dart';
import 'domain/models.dart';
import 'storage/private_store.dart';
import 'storage/list_store.dart';
import 'storage/bookmark_library.dart';
import 'ui/design.dart';
import 'ui/bookmarks.dart';
import 'ui/exam_selection.dart';
import 'ui/launch.dart';
import 'ui/results.dart';
import 'ui/settings.dart';
import 'ui/shared.dart';
import 'ui/shell.dart';
import 'ui/updates.dart';

export 'ui/design.dart' show appTheme;

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

class ExamApp extends StatelessWidget {
  const ExamApp({
    this.repository,
    this.listStore,
    this.advisoryPilot = const bool.fromEnvironment(
      'RESVIEW_EXAM_UPDATES',
      defaultValue: true,
    ),
    super.key,
  });
  final bool advisoryPilot;
  final ExamRepository? repository;
  final ListStore? listStore;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ResView',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: _ExamHome(
      lists: listStore,
      advisoryPilot: advisoryPilot,
      repository: repository ?? FirestoreExamRepository.fromEnvironment(),
    ),
  );
}

class _ExamHome extends StatefulWidget {
  const _ExamHome({
    required this.repository,
    required this.advisoryPilot,
    this.lists,
  });
  final bool advisoryPilot;
  final ExamRepository repository;
  final ListStore? lists;
  @override
  State<_ExamHome> createState() => _ExamHomeState();
}

class _ExamHomeState extends State<_ExamHome> {
  final _store = PrivateStore();
  late final _bookmarks = BookmarkLibrary(_store);
  late final _lists = widget.lists ?? ListStore();
  late final _push = PushPreferences(store: _store);
  int _destination = 0, _generation = 0;
  int _advisoryRevision = 0;
  bool get _inUpdates => widget.advisoryPilot && _destination == 1;
  bool get _inBookmarks => _destination == (widget.advisoryPilot ? 2 : 1);
  bool get _inSettings => _destination == (widget.advisoryPilot ? 3 : 2);
  SelectedExam? _selected;
  ResultVersion? _version;
  List<Publication> _publications = [];
  bool _loading = false, _failed = false;
  String? _localError;
  bool _readingLaunch = true, _showLaunchProgress = false;
  bool _showWelcome = false, _savingIntro = false, _launchReadFailed = false;
  bool _restoringSelection = false, _restoringPush = true;
  ExamSelection? _selectionToRetry;
  String? _introError;
  Timer? _launchProgress;
  @override
  void initState() {
    super.initState();
    _restoreLaunch();
    _restorePush();
    _restoreBookmarks();
  }

  Future<void> _restoreLaunch() async {
    _launchProgress = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _readingLaunch) {
        setState(() => _showLaunchProgress = true);
      }
    });
    try {
      final introSeen = await _store.readIntroSeen();
      final selection = introSeen ? await _store.readSelection() : null;
      await _cleanupLists();
      if (!mounted) return;
      setState(() {
        _showWelcome = !introSeen;
        _launchReadFailed = false;
        _readingLaunch = false;
      });
      if (selection != null) unawaited(_restoreSelection(selection));
    } catch (_) {
      if (mounted) {
        setState(() {
          _launchReadFailed = true;
          _readingLaunch = false;
        });
      }
    } finally {
      _launchProgress?.cancel();
    }
  }

  Future<void> _finishIntro({required bool chooseExam}) async {
    if (_savingIntro) return;
    setState(() {
      _savingIntro = true;
      _introError = null;
    });
    try {
      await _store.markIntroSeen();
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingIntro = false;
          _introError = 'The introduction could not be saved. Try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _savingIntro = false;
      _showWelcome = false;
    });
    final selection = await _readExistingSelection();
    if (!mounted) return;
    // Completing onboarding must also retain the exact selection from an
    // earlier installation of the app.
    if (selection != null) unawaited(_restoreSelection(selection));
    if (chooseExam) await _change();
  }

  Future<ExamSelection?> _readExistingSelection() async {
    try {
      return await _store.readSelection();
    } catch (_) {
      if (mounted) setState(() => _launchReadFailed = true);
      return null;
    }
  }

  Future<void> _retryLaunch() async {
    setState(() {
      _readingLaunch = true;
      _showLaunchProgress = false;
    });
    await _restoreLaunch();
  }

  Future<void> _cleanupLists() async {
    try {
      await _store.deleteName();
      await _lists.clearAll();
    } catch (_) {
      if (mounted) {
        setState(
          () => _localError = 'Data from the retired name checker could not be removed. Retry deleting local data in Settings.',
        );
      }
    }
  }

  Future<void> _restoreBookmarks() => _bookmarks.load();

  Future<void> _restorePush() async {
    try {
      await _push.restore();
    } catch (_) {
      if (mounted) {
        setState(
          () => _localError = 'Saved alert preferences could not be restored.',
        );
      }
    } finally {
      if (mounted) setState(() => _restoringPush = false);
    }
  }

  Future<void> _restoreSelection(ExamSelection selection) async {
    final generation = ++_generation;
    setState(() {
      _restoringSelection = true;
      _selectionToRetry = null;
    });
    try {
      final exams = await widget.repository.loadCatalog();
      final exam = exams.where((e) => e.id == selection.examId).firstOrNull;
      if (exam == null || !mounted || generation != _generation) return;
      final sittings = await widget.repository.loadSittings(selection.examId);
      if (!mounted || generation != _generation) return;
      final sitting = sittings
          .where(
            (s) => s.id == selection.sittingId && s.examId == selection.examId,
          )
          .firstOrNull;
      if (sitting != null &&
          sitting.categories.containsKey(selection.categoryId)) {
        _selected = SelectedExam(exam, sitting, selection.categoryId);
      }
    } catch (_) {
      if (mounted && generation == _generation) _selectionToRetry = selection;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _restoringSelection = false);
        if (_selected != null) unawaited(_refresh());
      }
    }
  }

  @override
  void dispose() {
    _launchProgress?.cancel();
    _push.dispose();
    _bookmarks.dispose();
    super.dispose();
  }

  Future<void> _select(SelectedExam selected) async {
    final generation = ++_generation;
    setState(() {
      if (_selected == null) _destination = 0;
      _selected = selected;
      _version = null;
      _publications = [];
      _restoringSelection = false;
      _selectionToRetry = null;
      _loading = true;
      _failed = false;
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
    if (mounted && generation == _generation) await _refresh();
  }

  Future<void> _refresh() async {
    if (_selected == null) return;
    final generation = ++_generation;
    final selection = _selected!.selection;
    setState(() {
      _loading = true;
      _failed = false;
    });
    bool current() => mounted && generation == _generation;
    try {
      final (publications, version) = await (
        widget.repository.loadPublications(selection).then((items) {
          if (current() && items.isNotEmpty) {
            setState(() => _publications = items);
          }
          return items;
        }),
        widget.repository.loadResultVersion(selection).then((value) {
          if (current() &&
              value != null &&
              value.state != PublicationState.notReleased) {
            setState(() => _version = value);
          }
          return value;
        }),
      ).wait;
      if (current()) {
        _publications = publications;
        _version = version;
      }
    } catch (_) {
      if (current()) _failed = true;
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _change() async {
    final selected = await Navigator.push<SelectedExam>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: const DesignBackButton(),
            toolbarHeight: math.max(
              56,
              MediaQuery.textScalerOf(context).scale(28) + 16,
            ),
            title: const Text('Exam selection'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(screenGutter),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
                  child: ExamSelectionScreen(
                    repository: widget.repository,
                    current: _selected,
                    onSelected: (selected) => Navigator.pop(context, selected),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _select(selected);
  }

  Widget _content() {
    if (_inSettings) {
      return SettingsScreen(
        store: _store,
        lists: _lists,
        push: _push,
        selection: _selected?.selection,
        examTitle: _selected?.exam.title,
        examDetails: _selected?.details,
        restoringPush: _restoringPush,
        onChange: _change,
        onLocalDeleted: () {
          setState(() {
            _selected = null;
            _version = null;
            _publications = [];
            _generation++;
            _restoringSelection = false;
            _selectionToRetry = null;
            _loading = false;
            _failed = false;
            _localError = null;
          });
          unawaited(_bookmarks.load());
        },
      );
    }
    if (_inBookmarks) return BookmarksScreen(library: _bookmarks);
    if (_restoringSelection) {
      return const Notice(
        'Loading official information',
        'Restoring your exam selection.',
        action: LinearProgressIndicator(
          semanticsLabel: 'Restoring your exam selection',
        ),
      );
    }
    if (_selected == null) return const SizedBox.shrink();
    if (_inUpdates) {
      return UpdatesScreen(
        repository: widget.repository,
        selection: _selected!.selection,
        examId: _selected!.exam.id,
        examTitle: _selected!.exam.title,
        bookmarks: _bookmarks,
        revision: _advisoryRevision,
      );
    }
    final hasPrevious = _version != null || _publications.isNotEmpty;
    return ResultsScreen(
      version: _version,
      publications: _publications,
      bookmarks: _bookmarks,
      examId: _selected!.exam.id,
      examName: _selected!.exam.title,
      sittingLabel: _selected!.details,
      loading: _loading && !hasPrevious,
      onRetry: _failed && !hasPrevious ? _refresh : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_readingLaunch) return LaunchScreen(showProgress: _showLaunchProgress);
    if (_showWelcome) {
      return WelcomeScreen(
        advisoryPilot: widget.advisoryPilot,
        onChoose: () => _finishIntro(chooseExam: true),
        onSkip: () => _finishIntro(chooseExam: false),
        busy: _savingIntro,
        error: _introError,
      );
    }
    return ExamShell(
      advisoryPilot: widget.advisoryPilot,
      destination: _destination,
      onNavigate: (index) => setState(() => _destination = index),
      examTitle: _selected?.exam.title,
      examDetails: _selected?.details,
      restoringSelection: _restoringSelection,
      onChoose: _change,
      canRefresh: _selected != null && !_inSettings && !_inBookmarks,
      onRefresh: _inUpdates
          ? () => setState(() => _advisoryRevision++)
          : _inBookmarks || _loading
          ? null
          : _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_launchReadFailed)
            Notice(
              'Device preferences',
              'Saved preferences could not be restored.',
              warning: true,
              action: OutlinedButton(
                onPressed: _retryLaunch,
                child: const Text('Retry'),
              ),
            ),
          if (_selectionToRetry case final selection?)
            Notice(
              'Saved exam selection unavailable',
              'The official catalog could not be reached to restore your saved selection.',
              glyph: DesignGlyph.unreachable,
              action: OutlinedButton(
                onPressed: () => _restoreSelection(selection),
                child: const Text('Retry'),
              ),
            ),
          if (_localError != null && _inSettings)
            Notice('Device preferences', _localError!),
          if (_destination == 0 &&
              _failed &&
              (_version != null || _publications.isNotEmpty))
            const Notice(
              'Refresh unavailable',
              'Showing previously retrieved information.',
              warning: true,
            ),
          if (_destination == 0 &&
              _loading &&
              (_version != null || _publications.isNotEmpty))
            const LinearProgressIndicator(),
          KeyedSubtree(key: ValueKey(_destination), child: _content()),
        ],
      ),
    );
  }
}
