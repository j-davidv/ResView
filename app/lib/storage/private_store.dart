import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  Future<NameInput?> readName() async {
    final value = await _storage.read(key: 'name');
    return value == null
        ? null
        : NameInput.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> saveName(NameInput name) =>
      _storage.write(key: 'name', value: jsonEncode(name.toJson()));
  Future<void> deleteName() => _storage.delete(key: 'name');
  Future<ExamSelection?> readSelection() async {
    final value = await _storage.read(key: 'selection');
    return value == null
        ? null
        : ExamSelection.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> saveSelection(ExamSelection selection) =>
      _storage.write(key: 'selection', value: jsonEncode(selection.toJson()));
  Future<void> clearLocalValues() async {
    await deleteName();
    await _storage.delete(key: 'selection');
  }

  // Preserve the deletion intent and Firebase identity until server acknowledgement.
  Future<void> setPendingPushDeletion(bool pending) =>
      _storage.write(key: 'pushDeletion', value: pending.toString());
  Future<bool> pendingPushDeletion() async =>
      await _storage.read(key: 'pushDeletion') == 'true';
}
