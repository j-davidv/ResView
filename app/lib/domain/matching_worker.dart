import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../storage/list_store.dart';
import 'models.dart';
import 'matching.dart';

Future<List<NameEntry>> matchOnDevice(
  NamesDocument document,
  NameInput input, {
  required bool possible,
  void Function(void Function())? registerCancellation,
}) async {
  final replies = ReceivePort();
  final completion = Completer<List<NameEntry>>();
  final listener = replies.listen((message) {
    if (completion.isCompleted) return;
    if (message is List && (message.isEmpty || message.first is NameEntry)) {
      completion.complete(message.cast<NameEntry>());
    } else {
      completion.completeError(
        const ListFailure(
          'Automatic name checking unavailable. Name normalization failed.',
        ),
      );
    }
  });
  Isolate? worker;
  try {
    worker = await Isolate.spawn(_matchEntry, {
      'reply': replies.sendPort,
      'document': document,
      'input': input,
      'possible': possible,
      'token': ServicesBinding.rootIsolateToken,
    }, onError: replies.sendPort);
    registerCancellation?.call(() {
      worker?.kill(priority: Isolate.immediate);
      if (!completion.isCompleted) {
        completion.completeError(const ListFailure('Checking cancelled.'));
      }
    });
    return await completion.future;
  } finally {
    worker?.kill(priority: Isolate.immediate);
    await listener.cancel();
    replies.close();
  }
}

Future<void> _matchEntry(Map<String, dynamic> args) async {
  final reply = args['reply'] as SendPort;
  try {
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      args['token'] as RootIsolateToken,
    );
    final document = args['document'] as NamesDocument;
    final input = args['input'] as NameInput;
    final possible = args['possible'] as bool;
    if (possible && !document.componentsReliable) {
      reply.send(<NameEntry>[]);
      return;
    }
    Future<List<String>> normalize(List<String> values) async {
      final normalized = await const MethodChannel('org.resview/private')
          .invokeListMethod<String>('normalizeNfcBatch', values);
      if (normalized == null || normalized.length != values.length) {
        throw const FormatException('Normalization unavailable');
      }
      return normalized.map((s) => normalizeName(s, nfc: (v) => v)).toList();
    }

    final query = await normalize([
      renderQuery(input, document.nameFormat),
      input.surname,
      input.givenNames,
      input.middleName,
      input.suffix,
    ]);
    final normalizedInput = NameInput(query[1], query[2], query[3], query[4]);
    final matched = <NameEntry>[];
    // Bound platform-message memory; keep published entries as the sole full list.
    for (var start = 0; start < document.entries.length; start += 256) {
      final end = start + 256 < document.entries.length
          ? start + 256
          : document.entries.length;
      final batch = document.entries.sublist(start, end);
      final raw = <String>[];
      for (final entry in batch) {
        raw.add(entry.publishedName);
        if (possible) {
          final c = entry.components!;
          raw.addAll([c.surname, c.givenNames, c.middleName, c.suffix]);
        }
      }
      final values = await normalize(raw);
      var cursor = 0;
      final normalizedEntries = <NameEntry>[];
      for (final entry in batch) {
        final name = values[cursor++];
        final components = possible
            ? NameInput(
                values[cursor++],
                values[cursor++],
                values[cursor++],
                values[cursor++],
              )
            : null;
        normalizedEntries.add(
          NameEntry(
            sequence: entry.sequence,
            publishedName: name,
            sectionId: entry.sectionId,
            physicalPage: entry.physicalPage,
            components: components,
          ),
        );
      }
      final normalizedDocument = NamesDocument(
        selection: document.selection,
        documentVersion: document.documentVersion,
        entries: normalizedEntries,
        componentsReliable: possible,
        nameFormat: document.nameFormat,
      );
      final results = possible
          ? findPossible(normalizedDocument, normalizedInput)
          : findExact(normalizedDocument, query[0]);
      final identities = results
          .map((e) => '${e.sectionId}/${e.sequence}')
          .toSet();
      matched.addAll(
        batch.where((e) => identities.contains('${e.sectionId}/${e.sequence}')),
      );
    }
    reply.send(matched);
  } catch (_) {
    reply.send(null);
  }
}
