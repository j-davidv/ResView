import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/storage/bookmark_library.dart';
import 'package:app/storage/history_library.dart';
import 'package:app/domain/bookmark.dart';
import 'package:app/domain/history.dart';
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

  test('local deletion clears library queues and their in-memory collections', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = PrivateStore();
    final bookmarks = BookmarkLibrary(store);
    final history = HistoryLibrary(store);
    await Future.wait([bookmarks.load(), history.load()]);
    const url = 'https://www.prc.gov.ph/article/test';
    await bookmarks.toggle(
      BookmarkItem(
        id: url,
        kind: BookmarkKind.announcement,
        examId: 'exam-test',
        examName: 'Test exam',
        title: 'Test announcement',
        url: Uri.parse(url),
        savedAtUtc: DateTime.now().toUtc(),
      ),
    );
    await history.record(
      HistoryEntry(
        sourceId: url,
        kind: HistoryKind.announcement,
        examId: 'exam-test',
        examName: 'Test exam',
        title: 'Test announcement',
        url: Uri.parse(url),
        viewedAtUtc: DateTime.now().toUtc(),
      ),
    );

    await store.clearLocalValues(
      clearBookmarks: bookmarks.clearAll,
      clearHistory: history.clearAll,
    );

    expect(bookmarks.items, isEmpty);
    expect(history.items, isEmpty);
    expect(await store.readBookmarks(), isEmpty);
    expect(await store.readHistory(), isEmpty);
    bookmarks.dispose();
    history.dispose();
  });
}
