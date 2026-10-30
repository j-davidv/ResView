import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('name deletion preserves selection and local deletion preserves pending server intent', () async {
    final store = PrivateStore();
    await store.saveName(const NameInput('PEÑA', 'ANA MARIE', 'SANTOS', 'JR'));
    await store.saveSelection(
      const ExamSelection('test', 'sitting', 'general'),
    );
    expect((await store.readName())!.surname, 'PEÑA');
    await store.deleteName();
    expect(await store.readName(), isNull);
    expect((await store.readSelection())!.sittingId, 'sitting');
    await store.setPendingPushDeletion(true);
    await store.clearLocalValues();
    expect(await store.readSelection(), isNull);
    expect(await store.pendingPushDeletion(), isTrue);
  });
}
