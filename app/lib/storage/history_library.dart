import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/history.dart';
import 'private_store.dart';

const _maxHistorySize = 50;

class HistoryLibrary extends ChangeNotifier {
  HistoryLibrary(this._store);

  final PrivateStore _store;
  List<HistoryEntry> _items = const [];
  Future<void> _writes = Future<void>.value();
  bool loading = true;
  bool loaded = false;
  String? error;

  List<HistoryEntry> get items => List.unmodifiable(_items);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _items = await _store.readHistory();
      _sort();
      loaded = true;
    } catch (_) {
      error = 'Viewing history could not be loaded. Try again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Records a source view. If the same [sourceId] already exists the entry is
  /// updated with a fresh timestamp and moved to the top. Trims to the most
  /// recent [_maxHistorySize] entries.
  Future<void> record(HistoryEntry entry) {
    if (!loaded) {
      // Silently swallow — do not block source navigation.
      return Future.value();
    }
    return _mutate(() async {
      final now = DateTime.now().toUtc();
      final updated = entry.withViewedAt(now);
      final next = [..._items];
      next.removeWhere((e) => e.sourceId == entry.sourceId);
      next.insert(0, updated);
      if (next.length > _maxHistorySize) {
        next.removeRange(_maxHistorySize, next.length);
      }
      await _store.saveHistory(next);
      _items = next;
    });
  }

  Future<void> remove(String sourceId) {
    if (!loaded) {
      return Future.error(StateError('History is still loading.'));
    }
    return _mutate(() async {
      final next = _items.where((e) => e.sourceId != sourceId).toList();
      if (next.length == _items.length) return;
      await _store.saveHistory(next);
      _items = next;
    });
  }

  Future<void> clearAll() {
    if (!loaded) {
      return Future.error(StateError('History is still loading.'));
    }
    return _mutate(() async {
      await _store.clearHistory();
      _items = [];
    });
  }

  Future<void> _mutate(Future<void> Function() change) {
    final completer = Completer<void>();
    _writes = _writes.then((_) async {
      try {
        await change();
        error = null;
        notifyListeners();
        completer.complete();
      } catch (exception, stackTrace) {
        error = 'Viewing history could not be updated. Try again.';
        notifyListeners();
        completer.completeError(exception, stackTrace);
      }
    });
    return completer.future;
  }

  void _sort() {
    _items.sort((a, b) => b.viewedAtUtc.compareTo(a.viewedAtUtc));
  }
}
