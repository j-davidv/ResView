import 'dart:convert';
import 'dart:io';

import 'package:app/data/firestore_repository.dart';
import 'package:app/domain/matching_worker.dart';
import 'package:app/domain/models.dart';
import 'package:app/main.dart' as app;
import 'package:app/storage/list_store.dart';
import 'package:app/storage/private_store.dart';
import 'package:app/ui/check_name.dart';
import 'package:app/ui/shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// Redirect only this test's Dart downloads; production still requires HTTPS.
class _DownloadClient implements HttpClient {
  _DownloadClient(this.client, this.requests, this.destination);
  final HttpClient client;
  final List<Uri> requests;
  final Uri? destination;
  @override
  set connectionTimeout(Duration? value) => client.connectionTimeout = value;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) {
    requests.add(uri);
    return client.getUrl(destination ?? uri);
  }

  @override
  void close({bool force = false}) => client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnmodifiedHttp extends HttpOverrides {}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}

const _selection = ExamSelection('test-only', 'test-only', 'all');

ResultVersion _version({
  required int bytes,
  String? hash,
  String id = 'test',
}) => ResultVersion(
  selection: _selection,
  state: PublicationState.checkingAvailable,
  documentVersion: id,
  namesUrl: Uri.parse('https://example.org/test-only.json'),
  namesBytes: bytes,
  namesSha256: hash ?? 'a' * 64,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android accents, suffixes and reviewed candidates', (
    tester,
  ) async {
    const input = NameInput('PEÑA', 'ANA MARIE', 'SANTOS', 'JR.');
    const doc = NamesDocument(
      selection: _selection,
      documentVersion: 'test-only',
      componentsReliable: true,
      entries: [
        NameEntry(
          sequence: 1,
          publishedName: 'PEÑA, ANA MARIE SANTOS JR.',
          sectionId: 'all',
          physicalPage: 2,
          components: input,
        ),
      ],
    );
    Future<int> count(NameInput name, {bool possible = false}) async =>
        (await matchOnDevice(doc, name, possible: possible)).length;
    expect(
      await count(const NameInput('PEN\u0303A', 'ana marie', 'SANTOS', 'JR.')),
      1,
    );
    expect(
      await count(const NameInput('PENA', 'ANA MARIE', 'SANTOS', 'JR.')),
      0,
    );
    expect(await count(const NameInput('PEÑA', 'ANA MARIE', 'SANTOS', '')), 0);
    expect(
      await count(const NameInput('PEÑA', 'ANA MARIE', '', ''), possible: true),
      1,
    );
    expect(
      await count(const NameInput('PEÑA', 'ANA', '', ''), possible: true),
      0,
    );
    expect(await count(input, possible: true), 0);
  });

  testWidgets(
    'Android interrupted downloads, cancellation and storage limits',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final dir = await Directory('${support.path}/task7-storage').create();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Uri>[];
      var mode = 'interrupted';
      server.listen((request) async {
        request.response.bufferOutput = false;
        request.response.add(utf8.encode('partial'));
        await request.response.flush();
        if (mode == 'cancel') {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        await request.response.close();
      });
      final store = ListStore(directory: () async => dir);
      final version = _version(bytes: 100);
      Future<void> noFiles() async =>
          expect(await dir.list().toList(), isEmpty);
      try {
        await HttpOverrides.runZoned(
          () async {
            await expectLater(
              store.prepare(version, cancellation: CancelToken()),
              throwsA(
                isA<ListFailure>().having(
                  (e) => e.message,
                  'message',
                  contains('incomplete'),
                ),
              ),
            );
            await noFiles();
            mode = 'cancel';
            final token = CancelToken();
            await expectLater(
              store.prepare(
                version,
                cancellation: token,
                onProgress: (_) => token.cancel(),
              ),
              throwsA(
                isA<ListFailure>().having(
                  (e) => e.message,
                  'message',
                  contains('cancelled'),
                ),
              ),
            );
            await noFiles();
            final before = requests.length;
            final lowStorage = ListStore(
              directory: () async => dir,
              freeBytes: (_) async => 0,
            );
            await expectLater(
              lowStorage.prepare(version, cancellation: CancelToken()),
              throwsA(
                isA<ListFailure>().having(
                  (e) => e.message,
                  'message',
                  contains('Not enough'),
                ),
              ),
            );
            final cancelled = CancelToken()..cancel();
            await expectLater(
              store.prepare(version, cancellation: cancelled),
              throwsA(isA<ListFailure>()),
            );
            await expectLater(
              store.prepare(
                _version(bytes: maxDownloadBytes + 1),
                cancellation: CancelToken(),
              ),
              throwsA(isA<ListFailure>()),
            );
            expect(requests.length, before);
            expect(maxDownloadBytes, 20 * 1024 * 1024);
            expect(maxSavedBytes, 50 * 1024 * 1024);
            await File('${dir.path}/abandoned.part').writeAsString('partial');
            await File('${dir.path}/abandoned.temp.json').writeAsString('{}');
            await store.cleanupTemporary();
            await noFiles();
          },
          createHttpClient: (context) => _DownloadClient(
            _UnmodifiedHttp().createHttpClient(context),
            requests,
            Uri.parse('http://127.0.0.1:${server.port}/test-only'),
          ),
        );

        Future<CheckedList> sizedList(String id, int bytes) async {
          final file = File('${dir.path}/$id.temp.json');
          final handle = await file.open(mode: FileMode.write);
          await handle.truncate(bytes);
          await handle.close();
          return CheckedList(
            const NamesDocument(
              selection: _selection,
              documentVersion: 'test',
              entries: [],
            ),
            file,
            _version(bytes: bytes, id: id),
            false,
          );
        }

        final first = await sizedList('one', 20 * 1024 * 1024);
        final second = await sizedList('two', 20 * 1024 * 1024);
        final third = await sizedList('three', 10 * 1024 * 1024);
        for (final list in [first, second, third]) {
          expect(await store.saveOffline(list), SaveResult.saved);
        }
        final extra = await sizedList('extra', 1);
        expect(await store.saveOffline(extra), SaveResult.needsDeletion);
        expect(
          (await store.listSaved()).fold<int>(0, (n, s) => n + s.bytes),
          maxSavedBytes,
        );
        await store.cleanupTemporary();
        expect((await store.listSaved()).length, 3);
      } finally {
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
  );

  if (const bool.fromEnvironment('TASK7_LIVE')) {
    testWidgets(
      'approved live list on Android, UI provenance and offline reuse',
      (tester) async {
        await app.main();
        await tester.pumpAndSettle();
        final db = FirebaseFirestore.instance;
        final repository = FirestoreExamRepository(db);
        const selection = ExamSelection(
          'ocular-pharmacologists',
          'ocular-pharmacologists-2026-09-28',
          'all',
        );
        final version = (await repository.loadResultVersion(selection))!;
        expect(version.state, PublicationState.checkingAvailable);
        expect(
          version.documentVersion == 'cada461c37f74824fdf77a0c32cb3af1ca07b9b43b121589bd73959e838dfa15',
          isTrue,
        );
        expect(version.namesBytes, 781);
        expect(
          version.namesSha256 == '1474754159a2071d22780645e0200ebb97fc4b96d8bab7467eca9e2a155f90d8',
          isTrue,
        );
        final store = ListStore();
        final private = PrivateStore();
        final originalName = await private.readName();
        final originalSelection = await private.readSelection();
        final support = await getApplicationSupportDirectory();
        final requests = <Uri>[];
        CheckedList? checked;
        String? savedId;
        try {
          checked = await HttpOverrides.runZoned(
            () => store.prepare(version, cancellation: CancelToken()),
            createHttpClient: (context) => _DownloadClient(
              _UnmodifiedHttp().createHttpClient(context),
              requests,
              null,
            ),
          );
          expect(requests.length, 1);
          expect(requests.single == version.namesUrl, isTrue);
          expect(
            sha256.convert(await checked!.file.readAsBytes()).toString() ==
                version.namesSha256,
            isTrue,
          );
          final document = checked.document;
          expect(document.entries.length, 1);
          final row = document.entries.single;
          expect(row.sequence, 1);
          expect(row.physicalPage, 1);
          expect(row.sectionId, 'all');
          expect(document.componentsReliable, isFalse);
          final parts = row.publishedName.split(', ');
          expect(parts.length, 2);
          final input = NameInput(parts.first, parts.last, '', '');
          await private.deleteName();
          await private.saveSelection(selection);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(const app.ExamApp());
          await tester.pumpAndSettle();
          await _waitFor(tester, find.textContaining('Ocular Pharmacologists'));
          await tester.tap(find.text('Check name').last);
          await tester.pumpAndSettle();
          expect(
            tester
                    .widget<CheckNameScreen>(find.byType(CheckNameScreen))
                    .version
                    ?.documentVersion ==
                version.documentVersion,
            isTrue,
          );
          await tester.enterText(
            find.byType(TextFormField).at(0),
            input.surname,
          );
          await tester.enterText(
            find.byType(TextFormField).at(1),
            input.givenNames,
          );
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Check name'),
          );
          await tester.tap(find.widgetWithText(FilledButton, 'Check name'));
          await _waitFor(
            tester,
            find.text("A matching name appears in PRC's published list."),
          );
          await tester.pumpAndSettle();
          expect(
            find.text("A matching name appears in PRC's published list."),
            findsOneWidget,
          );
          expect(
            find.text('Entry 1 · Section all · PDF page 1'),
            findsOneWidget,
          );
          expect(
            find.textContaining('does not mean you failed'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Possible matching is not supported'),
            findsOneWidget,
          );
          final links = tester
              .widgetList<SourceButton>(find.byType(SourceButton))
              .toList();
          expect(links.any((b) => b.uri == version.publicationUrl), isTrue);
          expect(links.any((b) => b.uri == version.documentUrl), isTrue);
          expect(
            find.text('Document version: ${version.documentVersion}'),
            findsNWidgets(2),
          );
          expect(await private.readName(), isNull);
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          final capture = await binding.takeScreenshot('task7-exact');
          await File('${support.path}/task7-exact.png').writeAsBytes(capture);
          binding.reportData?.remove('screenshots');
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'TASK7 ABSENT NAME',
          );
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Check name'),
          );
          await tester.tap(find.widgetWithText(FilledButton, 'Check name'));
          await _waitFor(
            tester,
            find.text(
              'No exact match found. Check your entered name and the official PRC list.',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              'No exact match found. Check your entered name and the official PRC list.',
            ),
            findsOneWidget,
          );
          expect(await private.readName(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await checked.dispose();
          await store.cleanupTemporary();
          final dir = Directory('${support.path}/lists');
          expect(
            (await dir.list().toList()).where(
              (f) => f.path.endsWith('.part') || f.path.endsWith('.temp.json'),
            ),
            isEmpty,
          );

          checked = await store.prepare(version, cancellation: CancelToken());
          checked.contextDescription =
              'Ocular Pharmacologists · 28/09/2026 · All successful examinees';
          final existing = (await store.listSaved())
              .where(
                (s) => s.version.documentVersion == version.documentVersion,
              )
              .toList();
          expect(await store.saveOffline(checked), SaveResult.saved);
          if (existing.isEmpty) {
            savedId = (await store.listSaved())
                .singleWhere(
                  (s) => s.version.documentVersion == version.documentVersion,
                )
                .id;
          }
          await checked.dispose();
          await db.disableNetwork();
          final offlineRequests = <Uri>[];
          final offline = await HttpOverrides.runZoned(
            () async => ListStore().prepare(
              (await store.listSaved())
                  .singleWhere(
                    (s) => s.version.documentVersion == version.documentVersion,
                  )
                  .version,
              cancellation: CancelToken(),
            ),
            createHttpClient: (context) => _DownloadClient(
              _UnmodifiedHttp().createHttpClient(context),
              offlineRequests,
              Uri.parse('http://127.0.0.1:1/blocked'),
            ),
          );
          try {
            expect(offlineRequests, isEmpty);
            expect(
              (await matchOnDevice(
                offline.document,
                input,
                possible: false,
              )).length,
              1,
            );
            expect(
              await matchOnDevice(
                offline.document,
                const NameInput('TASK7 ABSENT NAME', 'TEST ONLY', '', ''),
                possible: false,
              ),
              isEmpty,
            );
            expect(
              await matchOnDevice(offline.document, input, possible: true),
              isEmpty,
            );
            expect(await private.readName(), isNull);
          } finally {
            await offline.dispose();
          }
          await File('${support.path}/task7-evidence.json').writeAsString(
            jsonEncode({
              'verifiedAtUtc': DateTime.now().toUtc().toIso8601String(),
              'documentVersion': version.documentVersion,
              'namesSha256': version.namesSha256,
              'bytes': version.namesBytes,
              'sourcePage': row.physicalPage,
              'sequence': row.sequence,
              'section': row.sectionId,
              'publicDownloadRequests': requests
                  .map((u) => u.toString())
                  .toList(),
              'offlineDownloadRequests': offlineRequests.length,
              'liveUiExactAndAbsent': true,
              'unsavedNameAbsentFromSecureStorage': true,
              'originalNameWasSaved': originalName != null,
              'originalSelection': originalSelection?.toJson(),
            }),
          );
        } finally {
          await db.enableNetwork();
          await tester.pumpWidget(const SizedBox.shrink());
          await checked?.dispose();
          if (savedId != null) await store.deleteSaved(savedId);
          await private.deleteName();
          if (originalName != null) await private.saveName(originalName);
          if (originalSelection != null) {
            await private.saveSelection(originalSelection);
          } else {
            // clearLocalValues also clears the name, so restore it afterwards.
            await private.clearLocalValues();
            if (originalName != null) await private.saveName(originalName);
          }
          await store.cleanupTemporary();
        }
      },
    );
  }
}
