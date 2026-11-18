import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/storage/list_store.dart';

void main() {
  test(
    'legacy file cleanup is repeatable and bounded to the old lists folder',
    () async {
      final root = await Directory.systemTemp.createTemp('resview-cleanup-');
      try {
        final lists = await Directory('${root.path}/lists').create();
        await File('${lists.path}/old.saved.json').writeAsString('{}');
        await File('${lists.path}/old.part').writeAsString('partial');
        final unrelated = await File('${root.path}/selection')
            .writeAsString('keep');
        final store = ListStore(directory: () async => lists);
        await store.clearAll();
        await store.clearAll();
        expect(await lists.list().toList(), isEmpty);
        expect(await unrelated.readAsString(), 'keep');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
