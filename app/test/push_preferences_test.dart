import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/alerts/push_preferences.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/domain/models.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('registration errors identify the required server setup without leaking provider details', () {
    final authError = explainPushFailure(
      FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'TEST-ONLY-PRIVATE-TOKEN',
      ),
      'sign-in',
    );
    expect(authError.message, contains('Anonymous sign-in'));
    expect(authError.message, contains('sign-in/operation-not-allowed'));
    expect(authError.message, isNot(contains('TEST-ONLY-PRIVATE-TOKEN')));
    final rulesError = explainPushFailure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'TEST-ONLY-PRIVATE-TOKEN',
      ),
      'save-preferences',
    );
    expect(rulesError.message, contains('updated notification rules'));
    expect(rulesError.message, isNot(contains('TEST-ONLY-PRIVATE-TOKEN')));
    final timeout = explainPushFailure(
      TimeoutException('TEST-ONLY-PRIVATE-TOKEN'),
      'save-preferences',
    );
    expect(timeout.message, contains('may still receive alerts'));
    expect(timeout.message, isNot(contains('TEST-ONLY-PRIVATE-TOKEN')));
  });
  test('unconfigured consent cannot claim enabled and deletion retains retry intent', () async {
    final store = PrivateStore();
    final push = PushPreferences(store: store);
    await expectLater(
      push.enable(const ExamSelection('test', 'sitting', 'general')),
      throwsA(isA<PushFailure>()),
    );
    expect(push.enabled, isFalse);
    await expectLater(
      push.deleteServerPreferences(),
      throwsA(isA<PushFailure>()),
    );
    expect(await store.pendingPushDeletion(), isTrue);
    final restarted = PushPreferences(store: store);
    await restarted.restore();
    expect(restarted.status, contains('Turning alerts off'));
  });
}
