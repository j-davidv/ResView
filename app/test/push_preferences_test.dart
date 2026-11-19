import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/alerts/push_preferences.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
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
