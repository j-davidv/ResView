# PRC Exam Updates Android App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a zero-spending Android app for real PRC announcements, validated public results, private on-device name checking, offline lists, and consent-based live alerts; test it through Android Studio first, then verify readiness for public deployment.

**Architecture:** Flutter owns the interface, private device storage, and all personal matching. A Python worker validates permitted PRC publications and result documents, publishes compact files to Supabase and metadata to Firestore, and maintains independent push/email queues. The installed app uses live repositories and real provider integrations after access, free-plan configuration, and consent gates pass; missing configuration produces an honest unavailable state. Fixtures and fake providers are confined to isolated automated tests.

**Tech Stack:** Flutter/Dart, flutter_secure_storage, path_provider, Firebase Auth/Firestore/FCM on Spark, Python/pypdf, public-repository GitHub Actions, Supabase Storage Free, and Brevo Free. Python standard-library unittest; Flutter tests; Firestore Rules emulator tests.

**Spec:** [2026-10-14-prc-exam-app-design.md](../specs/2026-10-14-prc-exam-app-design.md).

**Execution status:** Revised on 14 October 2026 to match the Android Studio-first, real-data spec. Prior local-demo completion claims do not establish compliance with this revision. At execution time inspect any existing code and reuse compliant parts; replace runtime fixture repositories, simulated-success paths, and demo-only controls. No implementation, toolchain, live provider, or source-access check has been performed during this revision. Keep all tasks unchecked until their current requirements have evidence.

## Global Constraints

- “Build an Android app with Dart and Flutter that is intended for live deployment.”
- “First run and test it through Android Studio, using an Android emulator and a connected physical Android device for device-dependent checks.”
- “Do not ship or display seeded announcements, fictional result lists, sample subscribers, simulated delivery success, demo banners, or placeholder controls.”
- “Synthetic fixtures and mocked failures are allowed only in automated tests and must never populate the installed app or live databases.”
- “Include all PRC board exams in the exam catalog.”
- “PRC is the sole information source; documents hosted elsewhere are acceptable only when linked directly by an official PRC publication, with the source chain preserved.”
- “Keep the entered name and personal matching results exclusively on-device.”
- “Email addresses, exam subscriptions, and push identifiers may leave the device with explicit user consent.”
- “Do not access individual ratings, application numbers, birthdates, or private PRC accounts.”
- “Do not use Firebase Cloud Functions, Firebase Cloud Storage, billing-enabled Google Cloud services, paid domains, or paid upgrades.”
- “Supabase provides file storage only; Firestore is the application's database.”
- “Repository contents and build logs must exclude email addresses, device tokens, secrets, and subscriber exports.”
- “OCR is excluded from the initial automatic-checking path.”
- “Show a separate **Show possible matches** button, as approved.”
- “cap each compact names-file download at 20 MiB and process one file at a time.”
- “Agreed total budget for explicitly saved offline lists: 50 MiB.”
- “Expire an unsent release email after 48 hours; keep the announcement available in-app.”
- “Clean up stale subscriptions after 90 days without app activity.”
- “Redacted operational-log retention is 7 days and delivery metadata retention is 30 days.”
- “Real messages may be sent only to explicitly authorized test recipients after separate instructions.”
- “no outbound request to PRC is sent without explicit instructions.”
- “Public distribution and paid publishing steps are deferred until after Android Studio acceptance and a distribution-route decision; they are not required for the initial test milestone.”
- “No public deployment, subscriber broadcast, or paid publishing action is authorized merely by approving this spec.”

## Review Focus

These five risks receive explicit regression tests in the owning tasks below:

1. Selection/version changes during a download must cancel the check and prevent a stale outcome from appearing (Tasks 5 and 6).
2. A valid-looking JSON file with a wrong selection, unsupported schema, or mismatched checksum must yield unavailable, never no-match (Tasks 2 and 5).
3. An app killed during download/save must recover without searching partial files or deleting user-selected offline copies (Task 5).
4. Unsubscribe, correction, and exhausted capacity racing with a retry must not send obsolete or ineligible email (Task 10).
5. A source outage after release must preserve release state and last successful check, with freshness marked stale (Tasks 6 and 8).

## Planning Decisions and Boundaries

- Workspace: `E:/USER/Downloads/ResView`. The earlier plan names [j-davidv/ResView](https://github.com/j-davidv/ResView); verify the actual Git remote, branch, files, and repository instructions before implementation rather than treating that reference as current state. This plan and its authoritative spec remain in `E:/USER/Downloads/superpowers/`; if execution needs repository-local copies, copy both together and preserve their relative link.
- Test environment: Windows with Android Studio, its Flutter/Dart plugins, and one Google APIs-enabled Android emulator supporting the selected Flutter/Firebase versions. Open `app/` as the Flutter project in Android Studio and run with its Run/Debug controls. Verify SDK and dependency versions during Task 1 rather than relying on historical version claims. A connected physical Android phone is required for device-dependent acceptance and public-release readiness; missing hardware is an acceptance gap.
- This request authorizes planning only. No application, provider account, deployment, PRC request, or real message is part of this planning turn.
- Adopt the spec's proposed 30-minute interval as `7,37 * * * *` UTC, with manual reruns. Adopt its conservative candidate rule, enabled only for reviewed component mappings.
- Use Material 3 and the existing `docs/design/2026-10-14-prc-ui-ux.md` in the reference project as an optional visual proposal, not an expansion of scope. Four destinations, labeled navigation, 48 dp targets, wrapping names, and enlarged-text support are implementation requirements here. No new image assets are needed.
- The worker and app share the frozen contract. Tasks 1–6 establish tested app behavior; Tasks 7–10 establish worker and real-provider capabilities; Tasks 11–12 complete live integration and Android Studio acceptance; Task 13 verifies release readiness. Earlier unit-test milestones are not accepted substitutes for the live app.
- Complete permitted retrieval, real catalog import, live provider setup, and real integration evidence for Android Studio acceptance. If a gate fails, retain honest unavailable states and record the blocked feature; never replace it with runtime fixtures. The zero-spending requirement remains in force.

## File Map

All paths below are relative to the repository root. Create only files needed by each task.

| Files | Responsibility |
|---|---|
| `app/pubspec.yaml`, generated Android scaffold, `app/lib/main.dart` | Android app entry and development configuration |
| `app/lib/domain/{models,matching}.dart` | Cross-system models, selection/version checks, local normalization and matching |
| `app/lib/data/{exam_repository,firestore_repository}.dart` | Shared public metadata interface and live Firestore repository; no runtime fixture repository |
| `app/lib/storage/{private_store,list_store}.dart` | Private values, bounded downloads, explicit offline lists |
| `app/lib/ui/{exam_selection,updates,results,check_name,settings}.dart` | Four destinations and exam context selection |
| `app/lib/alerts/push_preferences.dart` | Consent, anonymous identity, token lifecycle |
| `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/src/main/res/xml/{backup_rules,data_extraction_rules}.xml`, `app/android/app/src/main/kotlin/org/resview/app/MainActivity.kt` | Backup exclusions and free-space/NFC platform operations |
| `contracts/{names-v1.schema.json,example-names-v1.json,metadata.md}` | Frozen JSON and Firestore interfaces; synthetic example clearly labeled |
| `worker/{models,extract,source,publish,delivery,main}.py` | Worker contracts, format validation, restricted source retrieval, publish ordering, queues, command entry |
| `worker/requirements.txt`, `worker/tests/`, `worker/fixtures/` | Worker dependencies, offline tests, private/reference fixture manifest |
| `firebase/{firestore.rules,firebase.json,firestore.indexes.json,package.json}`, `firebase/tests/` | Owner isolation and emulator configuration/tests |
| `.github/workflows/monitor.yml`, `.gitignore` | Disabled-by-default monitoring and exclusion of private/generated data |
| `docs/{android-studio-runbook,source-access,provider-setup,format-validation,android-studio-acceptance,release-readiness,privacy-policy}.md` | Reproducible setup, permission records, live acceptance evidence, operational recovery, release readiness, and privacy disclosure |
| `app/test/`, `app/integration_test/` | Isolated fixture tests and live Android verification, kept out of runtime assets |
| `app/android/app/build.gradle.kts`, `app/android/key.properties.example` | Release signing configuration and a non-secret configuration template; use the generated Gradle extension if different |

## Shared Contract (freeze in Task 2)

`ExamSelection(examId, sittingId, categoryId)` uses stable string identifiers; use category `general` only when an exam has no categories. A sitting carries ISO dates plus `domestic|special|overseas` and location; a date range never collapses distinct sittings.

`PublicationState` values: `notReleased`, `validationPending`, `checkingAvailable`, `checkingUnavailable`, `superseded`. `SourceFreshness` is independently `fresh|stale|unknown`. Models store `lastSuccessfulCheckUtc` separately; every displayed date includes its timezone.

Names JSON v1 is one UTF-8 object: `formatVersion: 1`, `selection: {examId,sittingId,categoryId}`, `publicationUrl`, `documentUrl`, `documentVersion`, `validatedAtUtc`, `entryCount`, `originalSha256`, `nameFormat`, `componentsReliable`, and `entries`. Each entry has `sequence` (positive integer), `publishedName`, `sectionId`, `physicalPage` (one-based positive integer), and optional `components: {surname,givenNames,middleName,suffix}`. Components are absent unless their boundaries were reviewed; do not split a tail on its last word. `nameFormat` identifies a reviewed rendering rule, initially `surnameCommaNamesV1`. Never include user input or personal outcomes.

Trusted availability metadata adds `namesUrl`, `namesBytes`, `namesSha256`, selection, document version, and validation state; it must agree with the file. Names files represent one selected section, even when the original PDF contains several. A format adapter with ambiguous input-to-published ordering cannot enable structured checking; offer explicit full-published-name input only when exact normalization is reliable, otherwise disable checking.

Firestore paths: public `exams/{examId}`, `sittings/{sittingId}`, `publications/{publicationId}`, `resultVersions/{versionId}`, and `monitor/status`; private `pushPreferences/{uid}`; worker-only `emailQueue/{opaqueId}`, `deliveryAttempts/{opaqueId}`, `workerState/{key}`, and `validationReviews/{id}`. Private push fields are exactly `enabled`, `selection`, `token`, `lastActiveAtUtc`; use server timestamps for activity. No names, outcomes, or email addresses. Result metadata references immutable versions and a current-version pointer. Public reads do not require authentication; client public writes are always denied. No whole-database listeners.

Email queue identity is SHA-256 of opaque provider contact ID, publication ID, version ID, and channel. Queue records store no address: `contactRef`, publication/version, selection, priority, `publishedAtUtc`, `expiresAtUtc`, deterministic `orderKey`, status, attempt count, and next retry time. Queue upserts are idempotent. Push and email attempt records have distinct channel IDs.

Constants: `maxDownloadBytes = 20 * 1024 * 1024`; `maxSavedBytes = 50 * 1024 * 1024`; email account ceiling `300/day`, release expiry `48 hours`, inactive push `90 days`, logs `7 days`, delivery metadata `30 days`. Initial queue cap: `10_000` pending records; when full, preserve a discovery cursor, expose backlog, and retry later without dropping publication metadata. Validate this operational default against the intended initial audience and current free quotas in Task 13.

---

### Task 1: Runnable Android Studio App Shell Without Runtime Fixtures

**Files:** Create or adapt `app/` using Flutter's Android scaffold, `app/lib/main.dart`, `app/test/shell_test.dart`, `.gitignore`, and `docs/android-studio-runbook.md`. Inspect existing code before creating files; remove any fixture repository from runtime imports and assets.

**Interfaces:** Produces `ExamApp` as the single runtime root. Start with the selection shell; Task 6 extends its repository/store/controller wiring. There is no `demoMode`, seeded catalog, or simulated provider fallback. Until live configuration exists, show a service-unavailable state with setup documented for the developer outside the product UI.

- [ ] **Step 1: Establish the runnable environment.** Inspect existing repository instructions/code. Run `flutter doctor -v`, `flutter emulators`, and `flutter devices`; verify Android Studio and its Flutter/Dart plugins. Configure a compatible Google APIs-enabled emulator, then record versions and device IDs. Create the Android scaffold with `flutter create --platforms=android --org org.resview app` only if no app exists. Open `app/` in Android Studio, select the emulator, and verify Run/Debug launches the Flutter app. Record equivalent CLI commands as a secondary route. No web/Windows substitute satisfies Android acceptance.
- [ ] **Step 2: Write a failing shell test.**

```dart
testWidgets('browse without signup or seeded content', (tester) async {
  await tester.pumpWidget(const ExamApp());
  expect(find.text('Choose your exam'), findsOneWidget);
  expect(find.textContaining('Demo data'), findsNothing);
  expect(find.text('Sign up'), findsNothing);
});
```

- [ ] **Step 3: Run** `flutter test test/shell_test.dart` from `app`; expect a missing `ExamApp` or assertion failure. If existing code already passes, record that baseline and test the remaining runtime-fixture removal requirements.
- [ ] **Step 4: Implement the entry and selection shell.** Use Material 3, no signup barrier, no seeded publications, no placeholder success actions, and no demo branding. Exclude `.env`, credentials, signing keys, subscriber exports, runtime lists, worker input PDFs, build output, and local emulator data from Git. Test that missing configuration shows unavailable rather than synthetic content. Add only immediate dependencies and commit lockfiles; inspect current official package instructions during execution before selecting compatible versions.
- [ ] **Step 5: Verify** `flutter test test/shell_test.dart`, `flutter analyze`, and `flutter run -d <recorded-android-device-id>`; expect passing tests, no analysis errors, and an Android selection screen.
- [ ] **Step 6: Commit** the explicit shell files with `chore: prepare Android Studio app shell`.

### Task 2: Freeze Selection, Publication, and Names-File Contracts

**Files:** Create `contracts/names-v1.schema.json`, `contracts/example-names-v1.json`, `contracts/metadata.md`, `app/lib/domain/models.dart`, `app/test/contracts_test.dart`, `worker/models.py`, `worker/tests/test_contracts.py`, `worker/requirements.txt`.

**Interfaces:** Produces Dart `ExamSelection`, `NameInput`, `NameEntry`, `NamesDocument`, `ResultVersion`, `Publication`, and `PublicationState`; `NamesDocument.fromJson(Map<String,dynamic>, {required ExamSelection expectedSelection, required String expectedVersion})`. Python `validate_names_document(data: dict, expected_selection: dict, expected_version: str) -> dict` rejects invalid input with `ValueError`. Define `ResultVersion` fields from shared metadata and `NameInput(surname,givenNames,middleName,suffix)` now.

- [ ] **Step 1: Write cross-language contract failures.** Use the same small synthetic fixture in both languages; test valid parsing and each rejection separately.

```python
def test_contract_rejects_wrong_selection(self):
    with self.assertRaises(ValueError):
        validate_names_document(self.fixture, {**self.selection, 'categoryId': 'secondary'}, 'test-v1')

def test_contract_rejects_unsupported_version(self):
    with self.assertRaises(ValueError):
        validate_names_document({**self.fixture, 'formatVersion': 2}, self.selection, 'test-v1')
```

In Dart assert the same mutations throw `FormatException`. Also assert missing fields, incorrect `entryCount`, duplicate sequence within a section, nonpositive physical page, and mismatched document version are rejected. Published duplicate names with different sequence numbers remain valid.
- [ ] **Step 2: Run** `python -m unittest discover -s worker/tests -p test_contracts.py` and `flutter test test/contracts_test.dart` from `app`; expect failing contract tests.
- [ ] **Step 3: Implement the schema and models.** Use exact shared field names. Reject unsupported formats before matching; separate publication state from matching outcomes. Label the synthetic contract example as test-only in its documentation and keep it out of app assets and live imports. Add `nameFormat` capabilities with `componentsReliable=false` as default.
- [ ] **Step 4: Verify** both commands pass; the example is accepted identically by Python and Dart. Include tests for unknown state values and invalid sitting/category references.
- [ ] **Step 5: Commit** these files with `feat: define result and selection contracts`.

### Task 3: Private Name Storage and Deletion

**Files:** Create `app/lib/storage/private_store.dart`, `app/test/private_store_test.dart`; modify `app/pubspec.yaml`, `app/android/app/src/main/AndroidManifest.xml`, and `app/android/app/src/main/kotlin/org/resview/app/MainActivity.kt`; create `app/android/app/src/main/res/xml/backup_rules.xml` and `app/android/app/src/main/res/xml/data_extraction_rules.xml`.

**Interfaces:** Consumes `NameInput` and `ExamSelection`. Produces `PrivateStore.readName() -> Future<NameInput?>`, `saveName(NameInput) -> Future<void>`, `deleteName() -> Future<void>`, selection read/write, and `clearLocalValues() -> Future<void>`. Storage accepts an injected secure-storage instance for tests.

- [ ] **Step 1: Write failing storage tests.** Assert saving/reading all four fields preserves accents and suffixes; deleting name makes `readName()` null without deleting selection; clearing values removes both. Assert storage exceptions are surfaced without logging their values.
- [ ] **Step 2: Run** `flutter test test/private_store_test.dart`; expect missing implementation failures.
- [ ] **Step 3: Implement with flutter_secure_storage.** Save only when the user elects to retain their name. Keep selection usable with no name. Exclude all private app file/database/preferences domains from cloud backup and device transfer using both applicable Android rule formats; set `allowBackup=false`. No analytics or crash-reporting SDK. Configure a single MethodChannel in `MainActivity.kt` for `normalizeNfc(String) -> String` using Java `Normalizer`, and `availableBytes(String privatePath) -> int` using `StatFs`; reject paths outside app-owned directories. This avoids adding a normalization or disk-space package.
- [ ] **Step 4: Verify** Flutter tests plus Android assertions that `PEN\u0303A` normalizes to `PEÑA`, invalid paths fail, and generated manifest includes the backup exclusions. Verify no saved name appears in app logs. Test key loss/storage failure with a clear edit/re-enter flow.
- [ ] **Step 5: Commit** with `feat: keep saved name private on device`.

### Task 4: Conservative Local Exact and Possible Matching

**Files:** Create `app/lib/domain/matching.dart`, `app/test/matching_test.dart`; extend `app/lib/domain/models.dart` with `MatchOutcome` and per-format rendering capabilities.

**Interfaces:** Consumes Task 2 models and platform NFC from Task 3. Produces `normalizeName(String value, {required String Function(String) nfc}) -> String`, `findExact(NamesDocument document, String publishedQuery) -> List<NameEntry>`, `findPossible(NamesDocument document, NameInput input) -> List<NameEntry>`, and `renderQuery(NameInput input, String nameFormat) -> String`. Run NFC preparation asynchronously before synchronous matching; tests inject independently normalized Unicode fixtures. `findPossible` returns no entries when components are unreliable; UI distinguishes unsupported from an empty candidate list.

- [ ] **Step 1: Write the failing acceptance matrix.**

```dart
expect(normalizeName('  Peña, Ana  Marie ', nfc: nfc), 'PEÑA, ANA MARIE');
expect(normalizeName('PEN\u0303A', nfc: nfc), normalizeName('PEÑA', nfc: nfc));
expect(normalizeName('PEÑA', nfc: nfc), isNot(normalizeName('PENA', nfc: nfc)));
expect(normalizeName('ANA-MARIE', nfc: nfc), isNot(normalizeName('ANA MARIE', nfc: nfc)));
expect(findExact(duplicateDocument, 'PEÑA, ANA').length, 2);
expect(findPossible(unreliableDocument, input), isEmpty);
```

Define synthetic documents in this test with complete component fields where reliable. Assert DELA CRUZ/CRUZ, ANA MARIE/ANA, and JR omission are never exact; same complete surname/given names with different middle/suffix is possible only with reliable components. Wrong selection/version is rejected before any call to these functions. Full published entries and references survive matching.
- [ ] **Step 2: Run** `flutter test test/matching_test.dart`; expect failing tests.
- [ ] **Step 3: Implement normalization and reviewed rendering.** NFC, uppercase, and collapse Unicode whitespace only; no accent removal, punctuation deletion, fuzzy distance, or guessed middle-name boundaries. Prepare normalized entries once, retaining published text; do not build a second complete names-string index. The initial reviewed render rule joins nonempty given/middle/suffix fields after `surname, ` only for formats whose ordering evidence supports it. Unsupported ordering shows official-link fallback.
- [ ] **Step 4: Verify** the full matrix and Android NFC integration pass, including canonical-equivalence behavior through the real channel. Possible matches are computed only after the separate UI request in Task 6.
- [ ] **Step 5: Commit** with `feat: match validated names conservatively`.

### Task 5: Bounded Downloads, Cleanup, and Explicit Offline Lists

**Files:** Create `app/lib/storage/list_store.dart`, `app/test/list_store_test.dart`, `app/integration_test/storage_test.dart`; add path_provider and checksum support to `app/pubspec.yaml`.

**Interfaces:** Consumes `ResultVersion`, contract parser, and `availableBytes` channel. Produces `ListStore.prepare(ResultVersion version, {required CancelToken cancellation}) -> Future<CheckedList>`, `saveOffline(CheckedList) -> Future<SaveResult>`, `listSaved() -> Future<List<SavedList>>`, `deleteSaved(String versionId) -> Future<void>`, `cleanupTemporary() -> Future<void>`, `markSuperseded(String oldVersionId, String currentVersionId) -> Future<void>`, `clearAll() -> Future<void>`. `SaveResult` is `saved|needsDeletion`. `CheckedList` carries document, private path, and whether already saved; its `dispose()` removes only temporary data. `CancelToken.cancel()` interrupts download/parse and suppresses publication of results.

- [ ] **Step 1: Write failing boundary tests using a loopback HTTP server and temporary directories.** Assert known size `20*1024*1024` is permitted, larger/unknown trusted size is refused before download, a lying/missing response length cannot exceed the byte cap, checksum/selection/version mismatch produces unavailable, and partial files are never parsed. Test free-space failure, cancellation, interrupted restart, repeated checks, and single-operation locking.

```dart
expect(await savedBytesAfterReuseSameVersion(), originalSavedBytes);
expect(await attemptSaveOverBudget(50 * 1024 * 1024 + 1), SaveResult.needsDeletion);
expect(await listOriginalSavedVersions(), contains(originalVersionId));
expect(await temporaryFilesAfterCancelledDownload(), isEmpty);
```

These helper scenarios live in `list_store_test.dart`, use injected directories/network/free-space callbacks, and return the shown primitive values.
- [ ] **Step 2: Run** `flutter test test/list_store_test.dart`; expect missing implementation failures.
- [ ] **Step 3: Implement private streamed download.** Disclose trusted byte size before requesting it; incrementally hash and count stream bytes into a `.part` file. Fail above 20 MiB regardless of headers. Require free space for the file and conservative working allowance, catch ENOSPC even after the precheck. Verify byte count/hash before decoding; verify JSON/version/selection before rename. Parse once off the UI thread, cap retained representations, and drop the byte buffer before matching. One file at a time. Every exit cleans temporary files; startup and pre-download cleanup remove abandoned partial/transient files.
- [ ] **Step 4: Implement save/delete recovery.** Saved filenames derive from validated version IDs and remain inside private directories. Save by atomic rename when possible; recover incomplete saves by retaining only validated complete files. Calculate the actual saved-file total, reuse a saved version, never evict chosen files, and return `needsDeletion` above 50 MiB. Refresh/check metadata before online saved reuse; offline reuse displays version/time and unseen-correction limitation. Superseded files stay visibly outdated and cannot silently produce current results.
- [ ] **Step 5: Verify** unit tests and `flutter test integration_test/storage_test.dart -d <device-id>` pass. Kill the app mid-download and mid-save, restart, and assert no searchable partial file, no duplicate saved copy, and no accidental saved-file deletion. Switch selection while downloading and assert old results cannot reach the UI. Record observed memory behavior for the largest available fixture on a constrained emulator; file-byte budgets are not RAM guarantees.
- [ ] **Step 6: Commit** with `feat: bound result files and recover interrupted checks`.

### Task 6: Complete App Flows and Honest Availability States

**Files:** Create the five `app/lib/ui/*.dart` files from the file map, `app/lib/data/exam_repository.dart`, and `app/test/flows_test.dart`; modify the entry and add `app/integration_test/app_test.dart`. Test doubles stay under `app/test/` only.

**Interfaces:** Consumes Tasks 2–5. Extends Task 1 `ExamApp` with injected metadata repository, stores, and alert controller; `ExamRepository.loadCatalog()`, `loadSittings(String examId)`, `loadPublications(ExamSelection)`, `loadResultVersion(ExamSelection)`, each returning typed futures. Task 11 implements the same repository interface. Automated widget tests inject fakes; runtime wiring never chooses them. Browsing never requires a private identity.

- [ ] **Step 1: Write failing widget flows.** Select an exam, a sitting/date range, and category; distinguish domestic/special/overseas. Assert every publication state has its specified action; stale released content remains released. Assert exact messages below and every duplicate entry/reference. Tap **Show possible matches** and verify candidate computation occurs only then. Unsupported components disable candidates with manual-inspection guidance.

```dart
expect(find.text("A matching name appears in PRC's published list."), findsOneWidget);
expect(find.text('No exact match found. Check your entered name and the official PRC list.'), findsOneWidget);
expect(find.text('Possible match — confirm the published details.'), findsOneWidget);
expect(find.text('Automatic name checking unavailable.'), findsOneWidget);
```

Place these assertions in separate named scenarios, not simultaneously. Also test nameless browsing, official publication/document links, known download-size consent, deletion, save-budget prompt, offline version labels, and late completion after context/version change.
- [ ] **Step 2: Run** `flutter test test/flows_test.dart`; expect failed flows.
- [ ] **Step 3: Implement Updates, Results, Check name, and Settings.** Show publication/source freshness separately; no failed-exam inference. Exact first, candidates on demand, complete published names/sequence/section/physical page/source/version. Cancel on Back or context change; clear displayed outcomes on leaving the check flow, deleting the name, or learning of correction. No persistent match history. Settings edits/deletes name, selects exams, manages offline files, handles consent/email links, and separately deletes local data/server push preferences with honest offline retry status.
- [ ] **Step 4: Add the spec's four-paragraph privacy disclosure verbatim in Settings.** Before connected use, compare every sentence with actual traffic and provider settings. Clarify anonymous data leaving the device, independent email unsubscribe, duplicate identities, and backup/storage limits. Test distinct empty/loading/offline/stale/unavailable states and retry/official-link actions; never fabricate results or show developer setup details as product content.
- [ ] **Step 5: Verify** unit/widget tests pass and the Android app launches without runtime fixtures. Manually check TalkBack labels/order, large text at 200%, landscape/keyboard insets, slow/offline connections, and long accented names. Request notification permission only from alerts opt-in; no result claims based on color alone. Live integration acceptance follows Tasks 11–12.
- [ ] **Step 6: Commit** with `feat: complete exam app flows and honest states`.

### Task 7: Offline PDF Validation and Derived File Generation

**Files:** Create `worker/extract.py`, `worker/tests/test_extract.py`, `worker/fixtures/manifest.json`, `docs/format-validation.md`; extend worker requirements with pypdf. Keep original PDFs and extracted real-name files ignored outside public Git.

**Interfaces:** Consumes Task 2 schema. Produces `extract_pdf(path: Path, expected: dict) -> ValidationReport` and `write_names_file(report: ValidationReport, output: Path) -> dict` returning checksum/size metadata only on success. `ValidationReport` carries status, reasons, sections, physical page references, source/version identity, counts, and component capabilities. `expected` comes from reviewed official publication evidence, not guessed totals.

- [ ] **Step 1: Register reference fixtures without changing them.** Locate and verify the reported `validation/archive-{1,2,3}.pdf`, `archive-results.json`, rendered checks, and `validation-report.md`; do not assume they exist in this checkout. Record file checksums/source chain and manually checked rows in a private fixture manifest. If unavailable, record the missing evidence and establish permitted PRC-sourced fixtures through Task 8 instead of fabricating the historical counts. Existing access evidence is not permission to republish. Offline inspection can proceed; publishing is gated on documented permitted reuse.
- [ ] **Step 2: Write failing extraction tests.**

```python
def test_combined_pdf_keeps_sections_separate(self):
    report = extract_pdf(self.archive2, self.reviewed_archive2)
    self.assertEqual([s.entry_count for s in report.sections], [1208, 1141])
    self.assertEqual([s.entries[0].sequence for s in report.sections], [1, 1])
    self.assertEqual(report.sections[1].entries[0].physical_page, 26)
```

Also assert Teachers elementary `21198`, Midwives `1055`, complete numbered sequences, nine independently transcribed rows from the report, original hash, UTF-8 accents, and physical-page references. Mutate local fixtures to exercise omitted rows/pages, wrong heading/sitting/category, topnotchers/room assignments, restricted HTML with HTTP 200, scanned/no-text content, unexpected layout, missing supplied end marker, and count disagreement. Every invalid case disables checking and gives a reason. Printed page “2 of 425” alone must not invalidate the 424-page Teachers PDF.
- [ ] **Step 3: Run** `python -m unittest discover -s worker/tests -p test_extract.py`; expect failures.
- [ ] **Step 4: Implement only reviewed text-PDF adapters.** Read every relevant page/section with pypdf; require all six validation checks from the spec. Register exact heading/sitting/category and rendering rules with evidence. Never use a general regex as proof of correct format or infer components from the last word. These archival adapters default candidate capability off unless separate component evidence establishes boundaries. Unfamiliar formats go to review; exceptions record official source/reason/time/version and cannot approve incompleteness.
- [ ] **Step 5: Verify** all offline tests; deserialize each generated file with Task 2 validator. Compare all rows with the existing independently extracted sequences and manually checked entries. Confirm original/derived versions agree and there is no user query in the output.
- [ ] **Step 6: Commit** code, synthetic failure fixtures, and redacted validation documentation with `feat: validate permitted result formats offline`. Do not commit real-name rows/PDFs without documented reuse and an explicit review of repository exposure.

### Task 8: Restricted Publication Monitoring and Review Queue

**Files:** Create `worker/source.py`, `worker/tests/test_source.py`, `docs/source-access.md`; extend worker models.

**Interfaces:** Produces `SourcePolicy` with approved hosts/routes/access evidence; `fetch_publication(url: str, policy: SourcePolicy) -> Publication`; `discover_documents(publication: Publication) -> list[DocumentLink]`; `scan(sources: list[str], state: dict, now: datetime) -> ScanResult`. Use injectable transport and clock in tests; real transport disabled unless an approved source policy exists.

- [ ] **Step 1: Write failing tests with local HTML/PDF responses.** Assert official title/date/URL/document links/retrieval time/stable version IDs; correction changes version; repeated crawl does not duplicate release. Ambiguous exam relevance enters review, clear general notices remain general. Reject unapproved redirects/hosts, localhost/private/link-local addresses, restricted HTML, and unexpected content. A failed scan preserves prior release and last-success time, changing freshness only. Test 429/5xx retries capped at three attempts with delays 1/4/16 seconds, respecting Retry-After without extending beyond the worker run budget.
- [ ] **Step 2: Run** `python -m unittest discover -s worker/tests -p test_source.py`; expect failures.
- [ ] **Step 3: Implement metadata ingestion and provenance.** Follow only document links from approved official publications; disable automatic redirects and validate each hop/DNS destination before following. Require HTTPS, approved hostnames/routes, bounded response sizes/timeouts, and PDF signature/content checks. Do not guess hidden download URLs or bypass restrictions. Record review reasons and stale health; summaries reproduce attributable PRC facts only.
- [ ] **Step 4: Document the live source gate.** With explicit instructions for PRC requests, identify an official feed or documented permitted retrieval route and authoritative all-exam catalog. Record permission/reuse evidence, robots/provider terms, frequency limits, redirects, format associations, and retrieval dates. Robots alone does not establish permission. Until this gate passes, allow isolated fixture tests only; live ingestion remains blocked and the app reports actual source/checking availability without fixture imports. No email/contacting PRC is authorized by this plan.
- [ ] **Step 5: Verify** mocked tests and offline end-to-end scan produce stable records/review reports. Only after the source gate, execute a bounded authorized live sample and record outcomes; a denied source is a valid fallback result, not a reason to circumvent access.
- [ ] **Step 6: Commit** with `feat: monitor approved publication sources safely`.

### Task 9: Firestore Isolation and Ordered Asset Publication

**Files:** Create Firebase files/tests, `worker/publish.py`, `worker/tests/test_publish.py`, `docs/provider-setup.md`; update `.gitignore`.

**Interfaces:** Produces `FirestoreExamRepository` contract support and `publish_validated(report: ValidationReport, names_path: Path, providers: Providers) -> ResultVersion`. `Providers` is a small injected bundle of storage/database clients, not a new server. Worker alone uses admin credentials; no admin/storage service secret in the app.

- [ ] **Step 1: Write failing emulator rules tests.** Two anonymous users: A can read/write/delete only A's push preferences, B cannot access A; unauthenticated public reads succeed; every client public/worker record write fails. Reject extra fields (`name`, `email`, `outcome`), invalid selection/token/types, spoofed activity timestamps, oversized tokens, and invalid enabled state. Public listing is limited to public collections; all worker records deny client reads.
- [ ] **Step 2: Write failing publish-order tests.** Mock upload failure leaves availability pending/unavailable, never available. Assert completed immutable asset hash/size and version before metadata switches; correction retains original/source audit and supersedes the previous version. Fail on accidental mismatch or reused version with different bytes. Repeating a successful job is idempotent.
- [ ] **Step 3: Run** `npm --prefix firebase test` (package script invokes Firestore emulator tests) and `python -m unittest discover -s worker/tests -p test_publish.py`; expect failures.
- [ ] **Step 4: Implement rules and publication ordering.** Define field allowlists and owner checks. Use SDK admin privileges only from trusted worker; use Firestore transactions for version pointers/queue updates. Upload the full validated asset under an immutable object key before publishing availability; reject wrong versions, leave orphan handling in maintenance, and keep official links readable on failure. Public Supabase bucket contains permitted public results only, no subscriber data. SDK credentials remain local ignored secrets or GitHub encrypted secrets.
- [ ] **Step 5: Verify** emulator tests and worker ordering tests pass. Document free-plan account checks: Spark/no billing, Supabase Free/no upgrades, Brevo Free/hosted form eligibility and approval, provider subdomains, restricted keys, quotas and project suspension behavior. Verify current official provider documentation at execution time; the spec's allowances are planning inputs, not a claim about unchanged future terms. Account creation/deployment are future implementation actions, not performed by this plan.
- [ ] **Step 6: Commit** with `feat: isolate preferences and publish validated versions`.

### Task 10: Real Delivery, Capacity, and Retention

**Files:** Create `worker/delivery.py`, `worker/tests/test_delivery.py`; extend provider setup and runbook.

**Interfaces:** Produces `enqueue_alerts(publication: Publication, contacts: Iterable[ContactRef], store: QueueStore, now: datetime) -> QueueSummary`, `drain_email(store: QueueStore, provider: EmailProvider, now: datetime, policy: DeliveryPolicy) -> DeliverySummary`, `send_push(publication: Publication, preferences: Iterable[dict], provider: PushProvider, policy: DeliveryPolicy) -> DeliverySummary`, and `maintain(store, now: datetime) -> MaintenanceSummary`. `DeliveryPolicy` has `mode: disabled|test|public` and authorized opaque contact/device references for test mode. Disabled is the deployment default; test mode sends only to its explicit allowlist, and public mode requires a separately authorized launch. `DeliverySummary` distinguishes accepted-by-provider, deferred, disabled, rejected, and uncertain; provider acceptance does not prove device/inbox receipt. Interfaces use opaque IDs, not subscriber-address exports. Provider calls resolve addresses transiently; logs never contain addresses/tokens/names.

- [ ] **Step 1: Write failing delivery tests.**

```python
def test_account_capacity_is_shared(self):
    provider = FakeEmailProvider(account_used=299, daily_limit=300)
    summary = drain_email(self.two_confirmed_items, provider, self.now, self.authorized_test_policy)
    self.assertEqual(summary.accepted, 1)
    self.assertEqual(summary.deferred, 1)

def test_disabled_policy_does_not_send_or_claim_success(self):
    summary = drain_email(self.queue, self.provider, self.now, self.disabled_policy)
    self.assertEqual(self.provider.real_send_calls, 0)
    self.assertEqual(summary.accepted, 0)
```

Add tests: confirmed/active only, duplicate enqueue, urgent/release priority then oldest publication then stable opaque tie-breaker, expiry at 48 hours, original date in delayed content, correction before sending, unsubscribe before retry, verification of active status immediately before provider call, quota unavailable means queue, queue-cap/cursor persistence, bounded retries, provider invalid-token removal, and stale push cleanup at 90 days. Test that uncertain send outcomes are recorded, not claimed exactly-once.
- [ ] **Step 2: Run** `python -m unittest discover -s worker/tests -p test_delivery.py`; expect failures.
- [ ] **Step 3: Implement persisted per-channel attempts and email backlog with real Brevo/FCM adapters.** Use transaction/lease to prevent concurrent drains; one worker flow controls account budget. Provider confirmations/other sends consume shared 300/day capacity; if capacity cannot be confirmed, send none. Corrected versions cancel obsolete queued alerts; each drain removes unsubscribed recipients before send, with provider suppression as the final boundary. Bound retries; keep error details redacted. Verify policy immediately before every provider call; reject non-allowlisted test recipients and missing credentials without claiming success. Fake adapters exist only in automated tests. Push payloads/email announce publication with official link, never personal results.
- [ ] **Step 4: Implement retention.** Purge redacted operational logs after 7 days, attempt metadata after 30 days, expired unsent release mail after 48 hours, and inactive push preferences after 90 days without app activity. Invalid push tokens become inactive. Provider email suppression is minimal and provider-owned; verified fresh opt-in can reactivate. Full deletion requires verified provider semantics before promising erasure. No Firestore TTL feature required.
- [ ] **Step 5: Verify** all delivery/retention tests, including unsubscribe/correction arriving between queue lease and retry, disabled-mode non-delivery, and test-allowlist isolation for both channels. After explicit instructions naming test recipients, verify actual FCM receipt and Brevo email confirmation/delivery/unsubscribe, storing redacted evidence. Credentials alone never enable sends; unavailable integration evidence blocks channel acceptance.
- [ ] **Step 6: Commit** with `feat: deliver bounded consent-based publication alerts`.

### Task 11: Connected Catalog, Consent, and Worker Execution

**Files:** Create `app/lib/data/firestore_repository.dart`, `app/lib/alerts/push_preferences.dart`, `app/test/push_preferences_test.dart`, `app/integration_test/privacy_test.dart`, `worker/main.py`, `worker/tests/test_main.py`, `.github/workflows/monitor.yml`; modify Settings and provider/runbook docs.

**Interfaces:** Implements Task 6 `ExamRepository`; `PushPreferences.enable(ExamSelection) -> Future<void>`, `disable() -> Future<void>`, `deleteServerPreferences() -> Future<void>`. `enable` establishes anonymous identity only after opt-in and OS permission; no permission/token means no enabled record. Worker CLI: `python -m worker.main --live-sources --delivery disabled|test|public` and `python -m worker.main --maintenance`. Delivery defaults disabled; test mode consumes a private authorized-recipient allowlist, public mode refuses operation until launch authorization is recorded. No production CLI path imports fixtures or simulates delivery. Unit tests invoke worker functions with isolated fakes.

- [ ] **Step 1: Write failing consent tests.** Browsing does not create a private record; enable after accepted permission writes only allowed fields; denial/auth failure creates no enabled preference. Token rotation updates the owner record; disable/delete detaches sending and retries honestly when offline. App restart and new anonymous UID do not imply recovered local/server data. Email signup launches only the reviewed Brevo-hosted double-opt-in URL after the email consent explanation; never stores an email locally/in Firestore. Unsubscribe opens provider-supported management/help and never claims uninstall cancels mail.
- [ ] **Step 2: Write failing CLI tests.** Missing source approval or configuration refuses live ingestion without fixture fallback. Disabled delivery makes no provider send calls and cannot mark attempts successful. Test delivery refuses a missing allowlist and skips recipients outside it; public delivery refuses missing launch authorization. A real publication with blocked checking still supports an authorized actual publication alert. Maintenance respects all retention limits. Partial failure preserves last-good metadata and emits a redacted health report.
- [ ] **Step 3: Run** Flutter preference tests and `python -m unittest discover -s worker/tests -p test_main.py`; expect failures.
- [ ] **Step 4: Implement connected reads and consent.** Install compatible Firebase Flutter packages per current official instructions; commit non-secret client configuration only after review. Wire `ExamApp` exclusively to `FirestoreExamRepository` at runtime. Query selected publications/results with pagination and exact filters; preserve cached metadata on errors, distinguish true empty responses from outage. Import a PRC-sourced all-exam catalog with provenance and reviewed aliases; reject test fixtures in live imports. No cross-device name synchronization. Copy the public repository interface from Task 6 exactly.
- [ ] **Step 5: Wire scheduled/manual worker execution.** Public code repository, standard runner, cron `7,37 * * * *`, `workflow_dispatch`, read-only repository permissions, concurrency group preventing overlap. Keep live-source scheduling disabled until source/provider gates pass, then enable actual ingestion and verify a scheduled run. Default delivery remains disabled; select test mode only with authorized recipients. Public delivery requires the separate launch gate. Never serialize contacts/FCM tokens into artifacts or logs. Persist cursors/attempts/queue in private Firestore records. Check provider free quotas before upload/send; preserve links and expose degraded health when unavailable. Deploy tested rules and provision the public storage bucket and reviewed hosted email form as part of authorized implementation, recording configuration and rollback steps.
- [ ] **Step 6: Verify** CLI tests, rules emulator checks, live repository integration, and Android network inspection pass. In the isolated privacy integration test, enter a unique test name and assert it and its personal outcome never appear in outbound request payloads, DNS/URLs, logs, or backup files; never seed public data with it. Anonymous identity, selection, token may leave only after consent; Brevo gets email only through its explicit signup flow. With authorized test recipients, verify actual double opt-in/unsubscribe and FCM receipt. Do not satisfy these checks with fakes or simulated sends.
- [ ] **Step 7: Commit** with `feat: connect consent and guarded worker execution`.

### Task 12: Real-Data Android Studio Acceptance and Maintainer Handoff

**Files:** Extend `app/integration_test/app_test.dart`, `docs/android-studio-runbook.md`, `docs/format-validation.md`, `docs/source-access.md`, `docs/provider-setup.md`; create `docs/android-studio-acceptance.md`. Keep injected-state regression scenarios in `app/test/flows_test.dart`.

**Interfaces:** Consumes all preceding contracts. Produces a reproducible real app runnable from Android Studio, redacted live-integration evidence, an explicit supported-format matrix, and maintainer procedures. Release readiness is evaluated separately in Task 13; no admin website is added.

- [ ] **Step 1: Write remaining failing end-to-end scenarios.** Exercise the actual catalog, sitting/category selection, live announcements, validated permitted list download, exact checking, official-link fallback, cancellation, cleanup/restart, offline save/reuse/delete, and privacy controls. Test all five publication states, duplicates, no-exact outcomes, budget exhaustion, and conservative candidate rules in isolated automated tests when current live publications do not provide those cases. If no real format supports reliable components, keep possible matching unavailable with manual-inspection guidance; never seed candidate data into the installed app.
- [ ] **Step 2: Run** `flutter test integration_test/app_test.dart -d <device-id>` from `app` against configured live services; record actual failures before fixing missing wiring. Keep outbound test delivery disabled unless its recipients have been explicitly authorized.
- [ ] **Step 3: Finish integration and write the maintainer runbook.** Include Android Studio Open/Run/Debug instructions for `app/`, emulator and USB-device selection, required non-secret client configuration, developer credential provisioning, actual last successful scan, manual reruns, revoked-credential recovery, quota checks, provider outage/source restrictions, format-review/official-exception records, correction/supersession procedure, orphan asset review, queue expiry and recipient suppression. Explain how to disable a faulty format or channel and detect worker failures. Owner/developer is maintainer; no continuous support claim. Document unresolved live gates prominently.
- [ ] **Step 4: Run final checks once.** `python -m unittest discover -s worker/tests`; `npm --prefix firebase test`; from `app`, `flutter analyze`, `flutter test`, and Android integration tests. Expect all applicable automated checks passing. Open and run the normal app through Android Studio on the emulator and physical device. Record TalkBack, 200% text, notifications denied/allowed, offline/slow network, storage interruption, memory observation, and traffic/backup inspection separately as manual pass/fail. Missing hardware/provider evidence is an explicit acceptance gap, never an inferred pass.
- [ ] **Step 5: Record actual integration evidence.** Record publication/document URLs, exam/version, validation/hash/count, and the real retrieval-to-publish-to-download-to-local-check outcome without recording a tester's personal name or match result. Verify actual push receipt and email double opt-in/delivery/unsubscribe with authorized recipients. Record actual catalog and format coverage independently. Restricted/unsupported results show official links without no-match claims; missing permitted-document or provider evidence blocks the corresponding feature. Isolated test results support regression coverage but never satisfy live acceptance.
- [ ] **Step 6: Commit** redacted acceptance documentation with `docs: record real-data Android Studio acceptance`. Provide the Android Studio run procedure and known limitations. Do not claim public-release readiness until Task 13 passes, and do not publicly distribute the app or broadcast to subscribers during this test milestone.

### Task 13: Signed Release Readiness, Capacity, Privacy, and Recovery

**Files:** Create `docs/release-readiness.md`, `docs/privacy-policy.md`, `app/android/key.properties.example`; modify the generated `app/android/app/build.gradle.kts` (or `.gradle`), `.gitignore`, Settings privacy/contact links, and `docs/android-studio-runbook.md`. Add `app/test/release_configuration_test.dart` for configuration and fixture-exclusion regressions.

**Interfaces:** Consumes Task 12 live-acceptance evidence and all provider/source contracts. Produces a signed Android release build verified on a physical device, a documented signing/deployment/recovery procedure, a privacy policy matching actual data flows, and a pass/fail readiness record. Public distribution route and launch authorization remain separate decisions.

- [ ] **Step 1: Write release configuration checks.** Assert normal runtime wiring cannot choose a fixture repository, no fixture asset is registered in `pubspec.yaml`, and missing live configuration yields unavailable rather than success. Verify an attempted release without the required signing configuration fails explicitly instead of silently using a debug key. Check ignored key/credential paths and inspect build contents for test fixtures, subscriber exports, and worker/provider secrets. These checks must not print secrets.
- [ ] **Step 2: Configure release signing and reproducible builds.** Keep the keystore/passwords outside source control, load them through ignored local configuration, and document secure backup and update-signing continuity. Commit only the non-secret template and generated Gradle changes needed for release signing. Record Flutter/SDK/package versions and the equivalent Android Studio release configuration.
- [ ] **Step 3: Build and verify the release.** From `app`, run `flutter analyze`, `flutter test`, and `flutter build apk --release` with configured signing. Inspect the APK signing certificate using the Android SDK signing tool and confirm it matches the intended release key. Install the signed APK on a physical Android device and exercise launch, catalog, official publications, validated local checks, privacy deletion, offline lists, and authorized push delivery. Test an update over a previous build signed with the same key; saved settings/lists remain usable and superseded lists stay marked outdated. Record failures rather than claiming emulator evidence covers hardware behavior. The APK is a private verification artifact, not authorization for public distribution.
- [ ] **Step 4: Verify capacity and operations.** Recheck current official free-plan limits, record the intended initial audience, and estimate Firestore reads/writes, storage/transfer, scheduled-worker usage, and shared email volume against those limits. Document the capacity ceiling, queue/degraded behavior, and the 300/day email constraint without enabling billing. Verify a real scheduled worker run and manual rerun; exercise safe channel/format disablement, credential rotation, and restoration of public metadata. Never restore deleted private preferences or replay obsolete/unsubscribed alerts. Document and verify rollback to a known-good worker/app release using disposable public test records in an isolated environment where destructive probes are needed.
- [ ] **Step 5: Finalize public-launch prerequisites.** Write the privacy policy and maintainer contact from verified behavior, including provider processing, consent, retention, deletion, independent email unsubscribe, and public PRC names. Implement the Settings policy/contact access and verify its links. Before public launch, publish the policy on a no-cost permitted hosting route and select the app distribution route; record its outstanding requirements. Keep public delivery mode disabled until launch is separately authorized. A pending policy publication or distribution decision remains an explicit launch blocker.
- [ ] **Step 6: Commit** the inspected non-secret configuration and readiness record with `docs: record Android release readiness`. Mark each source/provider/security/hardware/build/privacy/recovery requirement pass, fail, or blocked with evidence. Report ready to deploy only after every applicable requirement passes; otherwise report the specific blockers. No public deployment, subscriber broadcast, repository publication, or paid publishing action is performed as a side effect.

## Execution Gates and Recommended Handoff

Tasks 1–6 establish app behavior with isolated automated tests; Tasks 7–10 implement extraction, approved live ingestion, publication, and real delivery adapters; Tasks 11–12 configure and verify the real app through Android Studio. Task 13 evaluates public-release readiness afterward. Establish Task 8's source/access gate early; if Task 7's reference fixtures are missing, obtain permitted fixtures through that gate before completing extraction tests. Provider terms, source permissions, actual catalog import, real integration evidence, and physical-device checks are required gates. Failed gates do not prevent isolated development but do prevent corresponding live acceptance. Never populate runtime or live services with synthetic fixtures to work around them.

Native execution is recommended because the app and worker share contracts across the tasks and one implementer can preserve them with less repeated context. Before implementation, review this revised plan and choose native or subagent-driven execution. In either method, carry forward the Android Studio-first workflow, proposed polling/candidate defaults, zero-spending constraint, and live-access/provider gates. This revision changes planning documents only; it does not execute provider setup, source retrieval, real delivery, or release distribution.

## Self-Review Record

- Scope coverage: real runtime/no seeded data and Android Studio setup (1/6/11/12), catalog and sitting distinctions (2/6/8/11), no-name browsing (1/6), publication states/freshness (2/6/8), provenance/validation/corrections (7–9), matching examples/messages (4/6), file/backup/privacy limits (3/5/11), consent/isolation/live alerts (9–12), backlog/retention (10), actual scheduled execution and health (8/11/13), accessibility/physical-device acceptance (6/12/13), signing/capacity/privacy policy/recovery/distribution gate (13).
- Type consistency: Task 5's final `saveOffline(CheckedList) -> Future<SaveResult>` is the sole save signature; `normalizeName` receives a synchronous NFC callback after platform preparation. Task 1 creates `ExamApp`, Task 6 extends it, and Task 11 wires the shared repository to Firestore. Task 10 defines `DeliveryPolicy` and Task 11 maps CLI delivery modes to it. Worker record IDs remain opaque.
- Review-focus coverage: all five risks have named owning tests above.
- Revision check: obsolete demo deliverables, fixture/simulation runtime defaults, old spec/workspace links, and historical completion/version claims were replaced. Synthetic data remains only in isolated automated tests. Source/provider gates, Android Studio acceptance, and public-release readiness remain distinct.
- No implementation, build, hardware, source-access, outbound messaging, or live-service checks were performed during this plan revision. All such requirements are future checks, not claimed results.
