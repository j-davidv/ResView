import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../storage/private_store.dart';
import 'exam_alert.dart';

class AlertInbox extends ChangeNotifier {
  AlertInbox(this.store);
  final PrivateStore store;
  List<ExamAlert> _items = [];
  Map<String, dynamic> _baselines = {};
  Future<void> _pending = Future.value();
  Future<void>? _loading;
  bool _disposed = false;
  List<ExamAlert> forSelection(ExamSelection selection) =>
      List.unmodifiable(_items.where((alert) => alert.selection == selection));
  int unread(ExamSelection? selection) => selection == null
      ? 0
      : forSelection(selection).where((alert) => !alert.read).length;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    Map<String, dynamic> data;
    try {
      data = await store.readAlertState();
    } on FormatException {
      data = {};
    }
    _baselines = data['baselines'] is Map
        ? Map<String, dynamic>.from(data['baselines'] as Map)
        : {};
    _items = [];
    for (final item in data['items'] is List ? data['items'] as List : []) {
      try {
        _items.add(ExamAlert.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {
        /* Preserve valid alerts if one stored item is malformed. */
      }
    }
    _notify();
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _pending.then((_) async {
      await load();
      await action();
    });
    _pending = next.catchError((Object _) {});
    return next;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(
    List<ExamAlert> items,
    Map<String, dynamic> baselines,
  ) async {
    final sorted = [...items]..sort((a, b) => b.posted.compareTo(a.posted));
    final bounded = sorted.take(100).toList();
    await store.saveAlertState({
      'items': bounded.map((a) => a.toJson()).toList(),
      'baselines': baselines,
    });
    _items = bounded;
    _baselines = baselines;
    _notify();
  }

  Future<void> observe({
    required ExamSelection selection,
    required Sitting sitting,
    required List<Publication> publications,
    AdvisoryFeed? feed,
    DateTime? now,
  }) => _serialize(() async {
    final time = (now ?? DateTime.now()).toUtc();
    final scope = jsonEncode(selection.toJson());
    final previous = _baselines[scope] as Map?;
    final known = Set<String>.from(previous?['seen'] as List? ?? []);
    final baseline = previous == null
        ? time
        : DateTime.parse(previous['since'] as String);
    final localDay = baseline.add(const Duration(hours: 8));
    final cutoff = DateTime.utc(
      localDay.year,
      localDay.month,
      localDay.day,
    ).subtract(const Duration(hours: 8));
    final candidates = <String, ExamAlert>{};
    final noticeIds = <String>{};
    bool feedReady = previous?['feedReady'] == true;
    void add(AlertKind kind, String title, Uri url, DateTime posted) {
      final official = officialAlertUrl(url.toString());
      final id = official.toString();
      candidates[id] = ExamAlert(
        id: id,
        kind: kind,
        title: title,
        url: official,
        selection: selection,
        posted: posted,
      );
    }

    if (feed != null &&
        !feed.stale &&
        feed.lastCheck != null &&
        !feed.lastCheck!.isAfter(time) &&
        time.difference(feed.lastCheck!) <= AdvisoryFeed.maxAge) {
      feedReady = true;
      for (final item in feed.notices) {
        noticeIds.add(officialAlertUrl(item.url.toString()).toString());
        add(
          isScheduleNotice(item.title)
              ? AlertKind.scheduleChange
              : AlertKind.announcement,
          item.title,
          item.url,
          item.posted,
        );
      }
    }
    for (final publication in publications) {
      add(
        AlertKind.result,
        publication.title,
        publication.url,
        publication.publishedAtUtc,
      );
    }
    final schedule = jsonEncode({
      'start': sitting.start.toUtc().toIso8601String(),
      'end': sitting.end.toUtc().toIso8601String(),
      'location': sitting.location,
      'target': sitting.targetReleaseDate?.toUtc().toIso8601String(),
    });
    if (previous != null &&
        previous['schedule'] != schedule &&
        sitting.catalogUrl != null) {
      String day(DateTime? value) =>
          value?.toUtc().toIso8601String().substring(0, 10) ?? '';
      final id =
          'schedule:${[day(sitting.start), day(sitting.end), sitting.location, day(sitting.targetReleaseDate)].join('|')}';
      candidates[id] = ExamAlert(
        id: id,
        kind: AlertKind.scheduleChange,
        title: 'The official schedule for your selected exam has changed.',
        url: officialAlertUrl(sitting.catalogUrl.toString()),
        selection: selection,
        posted: time,
      );
    }
    final items = [..._items];
    for (final alert in candidates.values) {
      if (previous != null &&
          (previous['feedReady'] == true ||
              !noticeIds.contains(alert.id) ||
              alert.kind == AlertKind.result) &&
          !known.contains(alert.id) &&
          !alert.posted.isBefore(cutoff) &&
          !alert.posted.isAfter(time) &&
          time.difference(alert.posted) <= const Duration(days: 7) &&
          !items.any(
            (saved) => saved.selection == selection && saved.id == alert.id,
          )) {
        items.add(alert);
      }
    }
    known.addAll(candidates.keys);
    // Keep bounded baselines for recently followed sittings. Restoring a scope
    // removed by this bound establishes a new baseline rather than old alerts.
    final baselines = {..._baselines}..remove(scope);
    baselines[scope] = {
      'since': baseline.toIso8601String(),
      'seen': known.toList().reversed.take(1000).toList().reversed.toList(),
      'schedule': schedule,
      'feedReady': feedReady,
    };
    while (baselines.length > 20) {
      baselines.remove(baselines.keys.first);
    }
    await _save(items, baselines);
  });

  Future<void> receive(ExamAlert alert) => _serialize(() async {
    // Push ids and feed ids use the same canonical official source to prevent
    // a foreground push and a refresh from creating two inbox entries.
    final source = alert.url.toString();
    if (_items.any(
      (item) =>
          item.selection == alert.selection &&
          (item.id == alert.id ||
              (item.url.toString() == source &&
                  item.kind != AlertKind.scheduleChange &&
                  alert.kind != AlertKind.scheduleChange)),
    )) {
      return;
    }
    await _save([..._items, alert], _baselines);
  });
  Future<void> markRead(ExamSelection selection, {String? id}) => _serialize(
    () => _save([
      for (final item in _items)
        if (item.selection == selection && (id == null || item.id == id))
          item.asRead()
        else
          item,
    ], _baselines),
  );
  Future<void> clear() => _serialize(() => _save([], {}));
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
