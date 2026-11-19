import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/bookmark.dart';
import '../domain/history.dart';
import '../domain/models.dart';

class PrivateStore {
  PrivateStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  Future<bool> readIntroSeen() async =>
      await _storage.read(key: 'introSeen') == 'true';
  Future<void> markIntroSeen() =>
      _storage.write(key: 'introSeen', value: 'true');
  Future<void> resetIntroSeen() => _storage.delete(key: 'introSeen');

  Future<void> deleteName() => _storage.delete(key: 'name');
  Future<ExamSelection?> readSelection() async {
    final value = await _storage.read(key: 'selection');
    return value == null
        ? null
        : ExamSelection.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> saveSelection(ExamSelection selection) =>
      _storage.write(key: 'selection', value: jsonEncode(selection.toJson()));

  Future<List<BookmarkItem>> readBookmarks() async {
    final value = await _storage.read(key: 'bookmarks');
    if (value == null) return [];

    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      throw const FormatException('Stored bookmarks are malformed.');
    }
    if (decoded is! List) {
      throw const FormatException('Stored bookmarks are malformed.');
    }

    final items = <BookmarkItem>[];
    final seen = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final item = BookmarkItem.fromJson(Map<String, dynamic>.from(entry));
        if (seen.add(item.key)) items.add(item);
      } catch (_) {
        // Ignore malformed entries while preserving the rest of the list.
      }
    }
    return items;
  }

  Future<void> saveBookmarks(List<BookmarkItem> items) => _storage.write(
    key: 'bookmarks',
    value: jsonEncode(items.map((item) => item.toJson()).toList()),
  );

  Future<List<HistoryEntry>> readHistory() async {
    final value = await _storage.read(key: 'history');
    if (value == null) return [];

    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      throw const FormatException('Stored history is malformed.');
    }
    if (decoded is! List) {
      throw const FormatException('Stored history is malformed.');
    }

    final items = <HistoryEntry>[];
    final seen = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final item = HistoryEntry.fromJson(Map<String, dynamic>.from(entry));
        if (seen.add(item.sourceId)) items.add(item);
      } catch (_) {
        // Ignore malformed entries while preserving the rest of the list.
      }
    }
    return items;
  }

  Future<void> saveHistory(List<HistoryEntry> items) => _storage.write(
    key: 'history',
    value: jsonEncode(items.map((item) => item.toJson()).toList()),
  );

  Future<void> clearHistory() => _storage.delete(key: 'history');

  Future<void> clearLocalValues() async {
    await deleteName();
    await _storage.delete(key: 'selection');
    await _storage.delete(key: 'bookmarks');
    await _storage.delete(key: 'history');
  }

  // Preserve the deletion intent and Firebase identity until server acknowledgement.
  Future<void> setPendingPushDeletion(bool pending) =>
      _storage.write(key: 'pushDeletion', value: pending.toString());
  Future<bool> pendingPushDeletion() async =>
      await _storage.read(key: 'pushDeletion') == 'true';
}
