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
  final Map<String, HistoryEntry> _pendingViews = {};

  List<HistoryEntry> get items => List.unmodifiable(_items);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    final completer = Completer<void>();
    _writes = _writes.then((_) async {
      try {
        var merged = await _store.readHistory();
        // Views that arrive during the initial read are held in memory. Persist
        // them on top of the loaded data before enabling normal mutations.
        while (true) {
          final pending = Map<String, HistoryEntry>.from(_pendingViews);
          for (final entry in pending.values) {
            merged = _upsert(merged, entry);
          }
          if (pending.isEmpty) break;
          await _store.saveHistory(merged);
          for (final entry in pending.entries) {
            if (identical(_pendingViews[entry.key], entry.value)) {
              _pendingViews.remove(entry.key);
            }
          }
        }
        _items = merged;
        _sort();
        loaded = true;
        error = null;
        completer.complete();
      } catch (_) {
        error = 'Viewing history could not be loaded. Try again.';
        completer.complete();
      } finally {
        loading = false;
        notifyListeners();
      }
    });
    await completer.future;
  }

  /// Records a source view. If the same [sourceId] already exists the entry is
  /// updated with a fresh timestamp and moved to the top. Trims to the most
  /// recent [_maxHistorySize] entries.
  Future<void> record(HistoryEntry entry) {
    final viewed = entry.withViewedAt(DateTime.now().toUtc());
    if (!loaded) {
      // Queue in memory while loading so a successful source open never waits
      // for storage and cannot be lost when the initial read completes.
      // Keep map iteration in last-opened order, including when an existing
      // pending source is reopened before the initial read completes.
      _pendingViews.remove(entry.sourceId);
      _pendingViews[entry.sourceId] = viewed;
      return Future.value();
    }
    return _mutate(() async {
      final next = _upsert(_items, viewed);
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

  Future<void> clearAll() => _mutate(() async {
    await _store.clearHistory();
    _pendingViews.clear();
    _items = [];
    loaded = true;
  });

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

  List<HistoryEntry> _upsert(List<HistoryEntry> items, HistoryEntry entry) {
    final next = [...items]..removeWhere((e) => e.sourceId == entry.sourceId);
    next.insert(0, entry);
    if (next.length > _maxHistorySize) {
      next.removeRange(_maxHistorySize, next.length);
    }
    return next;
  }

  void _sort() {
    _items.sort((a, b) => b.viewedAtUtc.compareTo(a.viewedAtUtc));
  }
}
