import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/storage/list_store.dart';
import 'package:app/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'oversized downloads rejected and cleanup preserves explicitly saved files',
    () async {
      final dir = await Directory.systemTemp.createTemp('prc-storage-test');
      addTearDown(() => dir.delete(recursive: true));
      final store = ListStore(
        directory: () async => dir,
        freeBytes: (_) async => 100 * 1024 * 1024,
      );
      await File('${dir.path}/abandoned.part').writeAsString('partial');
      await File('${dir.path}/chosen.saved.json').writeAsString('{}');
      await store.cleanupTemporary();
      expect(await File('${dir.path}/abandoned.part').exists(), isFalse);
      expect(await File('${dir.path}/chosen.saved.json').exists(), isTrue);
      final version = ResultVersion(
        selection: const ExamSelection('test', 'sitting', 'general'),
        state: PublicationState.checkingAvailable,
        documentVersion: 'test-v1',
        namesBytes: 20 * 1024 * 1024 + 1,
      );
      await expectLater(
        store.prepare(version, cancellation: CancelToken()),
        throwsA(isA<ListFailure>()),
      );
    },
  );
  test('cancel token interrupts rather than publishing a result', () {
    final token = CancelToken()..cancel();
    expect(() => token.check(), throwsA(isA<ListFailure>()));
  });
  test('a second prepare cannot pass the lock while initial cleanup awaits storage', () async {
    final dir = await Directory.systemTemp.createTemp('prc-lock-test');
    addTearDown(() => dir.delete(recursive: true));
    final gate = Completer<Directory>();
    final store = ListStore(directory: () => gate.future);
    final version = ResultVersion(
      selection: const ExamSelection('test', 'sitting', 'general'),
      state: PublicationState.checkingAvailable,
      documentVersion: 'test-v1',
      namesBytes: 1,
      namesSha256: 'a' * 64,
    );
    final token = CancelToken();
    final first = store.prepare(version, cancellation: token);
    final firstCheck = expectLater(first, throwsA(isA<ListFailure>()));
    try {
      await expectLater(
        store
            .prepare(version, cancellation: CancelToken())
            .timeout(const Duration(milliseconds: 50)),
        throwsA(
          isA<ListFailure>().having(
            (e) => e.message,
            'busy message',
            contains('Another'),
          ),
        ),
      );
    } finally {
      token.cancel();
      gate.complete(dir);
      await firstCheck;
    }
  });
}
