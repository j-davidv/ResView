import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

const maxDownloadBytes = 20 * 1024 * 1024;
const maxSavedBytes = 50 * 1024 * 1024;

class ListFailure implements Exception {
  const ListFailure(this.message);
  final String message;
}

class CancelToken {
  bool cancelled = false;
  VoidCallback? onCancel;
  void cancel() {
    cancelled = true;
    onCancel?.call();
  }

  void check() {
    if (cancelled) throw const ListFailure('Checking cancelled.');
  }
}

enum SaveResult { saved, needsDeletion }

String _versionId(ExamSelection selection, String version) =>
    '${selection.examId}/${selection.sittingId}/${selection.categoryId}/$version';

class SavedList {
  const SavedList(
    this.version,
    this.bytes,
    this.outdated, {
    this.contextDescription,
  });
  final ResultVersion version;
  final int bytes;
  final bool outdated;
  final String? contextDescription;
  String get id => _versionId(version.selection, version.documentVersion);
}

class CheckedList {
  CheckedList(this.document, this.file, this.version, this.alreadySaved);
  final NamesDocument document;
  File file;
  final ResultVersion version;
  bool alreadySaved;
  String? contextDescription;
  Future<void> dispose() async {
    if (!alreadySaved && await file.exists()) await file.delete();
  }
}

NamesDocument _decode(Map<String, dynamic> args) => NamesDocument.fromJson(
  jsonDecode(args['text'] as String) as Map<String, dynamic>,
  expectedSelection: ExamSelection.fromJson(
    args['selection'] as Map<String, dynamic>,
  ),
  expectedVersion: args['version'] as String,
);

class ListStore {
  ListStore({
    Future<Directory> Function()? directory,
    Future<int> Function(String)? freeBytes,
  }) : _directory = directory ?? _defaultDirectory,
       _freeBytes = freeBytes ?? _defaultFreeBytes;
  final Future<Directory> Function() _directory;
  final Future<int> Function(String) _freeBytes;
  final _knownVersions = <ExamSelection, ResultVersion>{};
  final _revoked = <String>{};
  bool _busy = false;
  bool _knownOutdated(ExamSelection selection, String version) {
    final current = _knownVersions[selection];
    return _revoked.contains(_versionId(selection, version)) ||
        (current != null &&
            (current.documentVersion != version ||
                current.state != PublicationState.checkingAvailable));
  }

  Future<void> observeVersion(ResultVersion version) async {
    _knownVersions[version.selection] = version;
    for (final saved in await listSaved()) {
      if (saved.version.selection == version.selection &&
          _knownOutdated(
            saved.version.selection,
            saved.version.documentVersion,
          )) {
        await markSuperseded(saved.id, version.documentVersion);
      }
    }
  }

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/lists')
          .create(recursive: true);
  static Future<int> _defaultFreeBytes(String path) async =>
      await const MethodChannel('org.resview/private')
          .invokeMethod<int>('availableBytes', path) ??
      0;
  String _key(ResultVersion v) => sha256
      .convert(
        utf8.encode(jsonEncode(v.selection.toJson()) + v.documentVersion),
      )
      .toString();
  Future<void> cleanupTemporary() async {
    if (_busy) return;
    await _removeTemporary();
  }

  Future<void> _removeTemporary() async {
    final dir = await _directory();
    await for (final file in dir.list()) {
      if (file is File &&
          (file.path.endsWith('.part') || file.path.endsWith('.temp.json'))) {
        await file.delete();
      }
    }
  }

  Future<CheckedList> prepare(
    ResultVersion version, {
    required CancelToken cancellation,
    ValueChanged<double>? onProgress,
  }) async {
    if (_busy) {
      throw const ListFailure('Another list operation is in progress.');
    }
    if (version.state != PublicationState.checkingAvailable ||
        version.namesBytes == null ||
        version.namesBytes! <= 0 ||
        version.namesBytes! > maxDownloadBytes ||
        version.namesSha256 == null ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(version.namesSha256!)) {
      throw const ListFailure(
        'Automatic name checking unavailable. The download metadata is not usable.',
      );
    }
    _busy = true;
    File? partial;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    cancellation.onCancel = () => client.close(force: true);
    try {
      await _removeTemporary();
      cancellation.check();
      final dir = await _directory();
      final saved = File('${dir.path}/${_key(version)}.saved.json');
      if (_knownOutdated(version.selection, version.documentVersion) ||
          await File('${saved.path}.outdated').exists()) {
        throw const ListFailure(
          'This saved version is outdated. Use the latest publication.',
        );
      }
      File file;
      if (await saved.exists()) {
        file = saved;
      } else {
        if (version.namesUrl == null) {
          throw const ListFailure('The validated download is unavailable.');
        }
        publicUrl(version.namesUrl.toString());
        if (await _freeBytes(dir.path) < version.namesBytes! + 1024 * 1024) {
          throw const ListFailure(
            'Not enough device storage. Free space and try again.',
          );
        }
        partial = File('${dir.path}/${_key(version)}.part');
        final request = await client
            .getUrl(version.namesUrl!)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200) {
          throw const ListFailure(
            'The validated download is unavailable. Try again later.',
          );
        }
        var count = 0;
        final sink = partial.openWrite();
        try {
          await for (final bytes in response.timeout(
            const Duration(seconds: 30),
          )) {
            cancellation.check();
            count += bytes.length;
            if (count > maxDownloadBytes || count > version.namesBytes!) {
              throw const ListFailure('Download exceeded the permitted size.');
            }
            sink.add(bytes);
            onProgress?.call(count / version.namesBytes!);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (count != version.namesBytes) {
          throw const ListFailure('The list download is incomplete.');
        }
        cancellation.check();
        file = partial;
      }
      if (await file.length() != version.namesBytes ||
          (await sha256.bind(file.openRead()).first).toString().toLowerCase() !=
              version.namesSha256!.toLowerCase()) {
        throw const ListFailure('The list integrity check failed.');
      }
      final text = await file.readAsString(encoding: utf8);
      final document = await compute(_decode, {
        'text': text,
        'selection': version.selection.toJson(),
        'version': version.documentVersion,
      });
      cancellation.check();
      if (file != saved) {
        file = await file.rename('${dir.path}/${_key(version)}.temp.json');
      }
      partial = null;
      return CheckedList(document, file, version, file.path == saved.path);
    } on ListFailure {
      rethrow;
    } on FileSystemException {
      throw const ListFailure(
        'Could not store the list. Check available device storage.',
      );
    } catch (_) {
      cancellation.check();
      throw const ListFailure(
        'Automatic name checking unavailable. The download or validation failed.',
      );
    } finally {
      client.close(force: true);
      cancellation.onCancel = null;
      _busy = false;
      if (partial != null && await partial.exists()) await partial.delete();
    }
  }

  Future<SaveResult> saveOffline(CheckedList list) async {
    if (list.alreadySaved) return SaveResult.saved;
    final saved = await listSaved();
    final size = await list.file.length();
    if (saved.fold<int>(0, (sum, item) => sum + item.bytes) + size >
        maxSavedBytes) {
      return SaveResult.needsDeletion;
    }
    final dir = await _directory();
    final target = '${dir.path}/${_key(list.version)}.saved.json';
    final v = list.version;
    final metadata = {
      'selection': v.selection.toJson(),
      'version': v.documentVersion,
      'bytes': size,
      'sha256': v.namesSha256,
      'contextDescription': list.contextDescription,
      'publicationUrl': v.publicationUrl?.toString(),
      'documentUrl': v.documentUrl?.toString(),
      'lastSuccessfulCheckUtc': v.lastSuccessfulCheckUtc
          ?.toUtc()
          .toIso8601String(),
    };
    final metaPartial = File('$target.meta.part');
    await metaPartial.writeAsString(jsonEncode(metadata), flush: true);
    await metaPartial.rename('$target.meta');
    list.file = await list.file.rename(target);
    list.alreadySaved = true;
    return SaveResult.saved;
  }

  Future<List<SavedList>> listSaved() async {
    final dir = await _directory();
    final result = <SavedList>[];
    await for (final file in dir.list()) {
      if (file is! File || !file.path.endsWith('.saved.json')) continue;
      try {
        final j = jsonDecode(
          await File('${file.path}.meta').readAsString(),
        ) as Map<String, dynamic>;
        final selection = ExamSelection.fromJson(
          j['selection'] as Map<String, dynamic>,
        );
        final outdated =
            _knownOutdated(selection, j['version'] as String) ||
            await File('${file.path}.outdated').exists();
        result.add(
          SavedList(
            ResultVersion(
              selection: selection,
              state: outdated
                  ? PublicationState.superseded
                  : PublicationState.checkingAvailable,
              documentVersion: j['version'] as String,
              namesBytes: await file.length(),
              namesSha256: j['sha256'] as String,
              publicationUrl: j['publicationUrl'] == null
                  ? null
                  : publicUrl(j['publicationUrl'] as String),
              documentUrl: j['documentUrl'] == null
                  ? null
                  : publicUrl(j['documentUrl'] as String),
              lastSuccessfulCheckUtc: j['lastSuccessfulCheckUtc'] == null
                  ? null
                  : DateTime.parse(j['lastSuccessfulCheckUtc'] as String),
            ),
            await file.length(),
            outdated,
            contextDescription: j['contextDescription'] as String?,
          ),
        );
      } catch (_) {
        throw const ListFailure(
          'A saved list could not be read. Your saved files have not been deleted.',
        );
      }
    }
    return result;
  }

  Future<void> deleteSaved(String versionId) async {
    final matches = (await listSaved())
        .where((s) => s.id == versionId)
        .toList();
    final dir = await _directory();
    for (final match in matches) {
      final path = '${dir.path}/${_key(match.version)}.saved.json';
      for (final suffix in ['', '.meta', '.outdated']) {
        final f = File('$path$suffix');
        if (await f.exists()) await f.delete();
      }
    }
  }

  Future<void> markSuperseded(
    String oldVersionId,
    String currentVersionId,
  ) async {
    _revoked.add(oldVersionId);
    final dir = await _directory();
    for (final s in await listSaved()) {
      if (s.id == oldVersionId) {
        await File('${dir.path}/${_key(s.version)}.saved.json.outdated')
            .writeAsString(currentVersionId);
      }
    }
  }

  Future<void> clearAll() async {
    if (_busy) {
      throw const ListFailure(
        'Cancel the active download before deleting local data.',
      );
    }
    final dir = await _directory();
    await for (final f in dir.list()) {
      if (f is File) await f.delete();
    }
  }
}
