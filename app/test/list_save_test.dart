import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:app/storage/list_store.dart';
import 'package:app/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sameVersion in [false, true]) {
    test(
      'known ${sameVersion ? 'revoked' : 'superseded'} list stays blocked after reopening',
      () async {
        final dir = await Directory.systemTemp.createTemp('prc-outdated-test');
        addTearDown(() => dir.delete(recursive: true));
        final store = ListStore(directory: () async => dir);
        const selection = ExamSelection('test', 'sitting', 'general');
        final text = jsonEncode({
          'formatVersion': 1,
          'nameFormat': 'surnameCommaNamesV1',
          'selection': selection.toJson(),
          'documentVersion': 'test-v1',
          'originalSha256': 'a' * 64,
          'publicationUrl': 'https://www.prc.gov.ph/article/test',
          'documentUrl': 'https://www.prc.gov.ph/sites/default/files/test.pdf',
          'validatedAtUtc': '2026-10-15T00:00:00Z',
          'entryCount': 1,
          'componentsReliable': false,
          'entries': [
            {
              'sequence': 1,
              'publishedName': 'TEST, ALPHA',
              'sectionId': 'general',
              'physicalPage': 1,
            },
          ],
        });
        final version = ResultVersion(
          selection: selection,
          state: PublicationState.checkingAvailable,
          documentVersion: 'test-v1',
          namesBytes: utf8.encode(text).length,
          namesSha256: sha256.convert(utf8.encode(text)).toString(),
        );
        final file = await File('${dir.path}/test.temp.json')
            .writeAsString(text);
        await store.saveOffline(
          CheckedList(
            NamesDocument.fromJson(
              jsonDecode(text) as Map<String, dynamic>,
              expectedSelection: selection,
              expectedVersion: 'test-v1',
            ),
            file,
            version,
            false,
          ),
        );
        expect(
          (await store.prepare(
            version,
            cancellation: CancelToken(),
          )).alreadySaved,
          isTrue,
        );
        await store.markSuperseded(
          (await store.listSaved()).single.id,
          sameVersion ? 'test-v1' : 'test-v2',
        );
        final reopened = ListStore(directory: () async => dir);
        expect((await reopened.listSaved()).single.outdated, isTrue);
        expect(
          (await reopened.listSaved()).single.version.state,
          PublicationState.superseded,
        );
        await expectLater(
          reopened.prepare(version, cancellation: CancelToken()),
          throwsA(
            isA<ListFailure>().having(
              (e) => e.message,
              'message',
              contains('outdated'),
            ),
          ),
        );
        expect(await file.exists(), isFalse);
        expect((await reopened.listSaved()).length, 1);
      },
    );
  }
  for (final duringEnumeration in [false, true]) {
    test(
      'failed revocation ${duringEnumeration ? 'enumeration' : 'persistence'} still blocks the known version in this session',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'prc-revocation-failure',
        );
        addTearDown(() => dir.delete(recursive: true));
        var unavailable = false;
        final store = ListStore(
          directory: () async {
            if (unavailable) {
              throw const FileSystemException(
                'TEST ONLY unavailable directory',
              );
            }
            return dir;
          },
        );
        const selection = ExamSelection('test', 'sitting', 'general');
        final version = ResultVersion(
          selection: selection,
          state: PublicationState.checkingAvailable,
          documentVersion: 'test-v1',
          namesBytes: 2,
          namesSha256: sha256.convert(utf8.encode('{}')).toString(),
        );
        final file = await File('${dir.path}/test.temp.json')
            .writeAsString('{}');
        await store.saveOffline(
          CheckedList(
            const NamesDocument(
              selection: selection,
              documentVersion: 'test-v1',
              entries: [],
            ),
            file,
            version,
            false,
          ),
        );
        final id = (await store.listSaved()).single.id;
        unavailable = true;
        await expectLater(
          duringEnumeration
              ? store.observeVersion(
                  ResultVersion(
                    selection: selection,
                    state: PublicationState.checkingUnavailable,
                    documentVersion: 'test-v1',
                  ),
                )
              : store.markSuperseded(id, 'test-v2'),
          throwsA(isA<FileSystemException>()),
        );
        unavailable = false;
        expect((await store.listSaved()).single.outdated, isTrue);
        await expectLater(
          store.prepare(version, cancellation: CancelToken()),
          throwsA(
            isA<ListFailure>().having(
              (e) => e.message,
              'message',
              contains('outdated'),
            ),
          ),
        );
      },
    );
  }
  test('explicit saving reuses one copy and refuses over-budget saving without eviction', () async {
    final dir = await Directory.systemTemp.createTemp('prc-save-test');
    addTearDown(() => dir.delete(recursive: true));
    final store = ListStore(directory: () async => dir);
    const selection = ExamSelection('test', 'sitting', 'general');
    final version = ResultVersion(
      selection: selection,
      state: PublicationState.checkingAvailable,
      documentVersion: 'test-v1',
      namesSha256: 'a' * 64,
    );
    final file = await File('${dir.path}/first.temp.json').writeAsString('{}');
    final list = CheckedList(
      const NamesDocument(
        selection: selection,
        documentVersion: 'test-v1',
        entries: [],
      ),
      file,
      version,
      false,
    );
    list.contextDescription =
        'TEST ONLY exam · Overseas · 14/10/2026 · TEST location';
    expect(await store.saveOffline(list), SaveResult.saved);
    expect(await store.saveOffline(list), SaveResult.saved);
    expect((await store.listSaved()).length, 1);
    expect(
      (await store.listSaved()).single.contextDescription,
      'TEST ONLY exam · Overseas · 14/10/2026 · TEST location',
    );
    final tooLarge = File('${dir.path}/second.temp.json');
    await tooLarge.writeAsBytes([]);
    final handle = await tooLarge.open(mode: FileMode.write);
    await handle.truncate(50 * 1024 * 1024);
    await handle.close();
    final second = CheckedList(
      const NamesDocument(
        selection: selection,
        documentVersion: 'test-v2',
        entries: [],
      ),
      tooLarge,
      ResultVersion(
        selection: selection,
        state: PublicationState.checkingAvailable,
        documentVersion: 'test-v2',
        namesSha256: 'b' * 64,
      ),
      false,
    );
    expect(await store.saveOffline(second), SaveResult.needsDeletion);
    expect((await store.listSaved()).single.version.documentVersion, 'test-v1');
    await store.markSuperseded((await store.listSaved()).single.id, 'test-v2');
    expect((await store.listSaved()).single.outdated, isTrue);
    await store.deleteSaved((await store.listSaved()).single.id);
    expect(await store.listSaved(), isEmpty);
  });
  test('deleting one section never removes another section from the same document version', () async {
    final dir = await Directory.systemTemp.createTemp(
      'prc-section-delete-test',
    );
    addTearDown(() => dir.delete(recursive: true));
    final store = ListStore(directory: () async => dir);
    for (final category in ['elementary', 'secondary']) {
      final selection = ExamSelection('test', 'sitting', category);
      final version = ResultVersion(
        selection: selection,
        state: PublicationState.checkingAvailable,
        documentVersion: 'shared-test-v1',
        namesSha256: 'a' * 64,
      );
      final file = await File('${dir.path}/$category.temp.json')
          .writeAsString('{}');
      await store.saveOffline(
        CheckedList(
          NamesDocument(
            selection: selection,
            documentVersion: 'shared-test-v1',
            entries: [],
          ),
          file,
          version,
          false,
        ),
      );
    }
    final saved = await store.listSaved();
    await store.deleteSaved(saved.first.id);
    final remaining = await store.listSaved();
    expect(remaining.length, 1);
    expect(remaining.single.version.selection, saved.last.version.selection);
  });
}
