import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Retain cleanup of files saved by app versions with automatic name checking.
class ListStore {
  ListStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/lists');

  Future<void> clearAll() async {
    final directory = await _directory();
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File) await entry.delete();
    }
  }
}
