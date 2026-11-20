import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/bookmark.dart';
import 'private_store.dart';

class BookmarkLibrary extends ChangeNotifier {
  BookmarkLibrary(this._store);

  final PrivateStore _store;
  List<BookmarkItem> _items = const [];
  Future<void> _writes = Future<void>.value();
  bool loading = true;
  bool loaded = false;
  String? error;

  List<BookmarkItem> get items => List.unmodifiable(_items);

  bool contains(BookmarkItem item) =>
      _items.any((saved) => saved.key == item.key);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _items = await _store.readBookmarks();
      _sort();
      loaded = true;
    } catch (_) {
      error = 'Saved bookmarks could not be loaded. Try again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(BookmarkItem item) {
    if (!loaded) {
      return Future.error(StateError('Bookmarks are still loading.'));
    }
    return _mutate(() async {
      final index = _items.indexWhere((saved) => saved.key == item.key);
      final next = [..._items];
      if (index >= 0) {
        next.removeAt(index);
      } else {
        next.add(item);
      }
      await _store.saveBookmarks(next);
      _items = next;
      _sort();
    });
  }

  Future<void> remove(String key) {
    if (!loaded) {
      return Future.error(StateError('Bookmarks are still loading.'));
    }
    return _mutate(() async {
      final next = _items.where((item) => item.key != key).toList();
      if (next.length == _items.length) return;
      await _store.saveBookmarks(next);
      _items = next;
      _sort();
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
        error = 'Bookmark could not be updated. Try again.';
        notifyListeners();
        completer.completeError(exception, stackTrace);
      }
    });
    return completer.future;
  }

  void _sort() {
    _items.sort((a, b) => b.savedAtUtc.compareTo(a.savedAtUtc));
  }
}
