import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/domain/models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native private storage and filesystem boundaries preserve deletion intent',
    (tester) async {
      final store = PrivateStore();
      final originalSelection = await store.readSelection();
      final originalPending = await store.pendingPushDeletion();
      try {
        await store.saveSelection(
          const ExamSelection('test-only', 'test-sitting', 'all'),
        );
        expect((await store.readSelection())!.examId, 'test-only');
        await store.setPendingPushDeletion(true);
        await store.clearLocalValues();
        expect(await store.readSelection(), isNull);
        expect(await store.pendingPushDeletion(), isTrue);
        final directory = await getApplicationSupportDirectory();
        expect(
          await const MethodChannel('org.resview/private')
              .invokeMethod<int>('availableBytes', directory.path),
          greaterThan(0),
        );
        await expectLater(
          const MethodChannel('org.resview/private')
              .invokeMethod<int>('availableBytes', '/sdcard'),
          throwsA(isA<PlatformException>()),
        );
      } finally {
        await store.setPendingPushDeletion(originalPending);
        if (originalSelection != null) {
          await store.saveSelection(originalSelection);
        }
      }
    },
  );
}
