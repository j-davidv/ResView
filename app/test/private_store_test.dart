import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy name cleanup preserves selection and deletion preserves push retry intent', () async {
    FlutterSecureStorage.setMockInitialValues({
      'name': '{"surname":"TEST ONLY"}',
    });
    const storage = FlutterSecureStorage();
    final store = PrivateStore();
    await store.saveSelection(
      const ExamSelection('test', 'sitting', 'general'),
    );
    await store.deleteName();
    expect(await storage.read(key: 'name'), isNull);
    expect((await store.readSelection())!.sittingId, 'sitting');
    await store.setPendingPushDeletion(true);
    await store.clearLocalValues();
    expect(await store.readSelection(), isNull);
    expect(await store.pendingPushDeletion(), isTrue);
  });
}
