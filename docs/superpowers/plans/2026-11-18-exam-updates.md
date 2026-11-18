# Exam Updates Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or superpowers:subagent-driven-development to implement approved tasks. Track progress with the checkboxes below.

**Goal:** Give users one place to read results now, then introduce exam-specific advisories when an official source is verified.

**Architecture:** Release 1 consolidates existing Flutter screens using the existing result reads. Release 2 adds a worker-owned advisory feed with independent coverage status and a separate client read.

**Tech stack:** Flutter, Dart, Material 3, Python, Cloud Firestore, Firebase Emulator Suite.

**Spec:** [Give Results and Updates distinct jobs](../specs/2026-11-18-exam-updates-design.md)

## Global constraints

Keep exact exam, sitting and category boundaries, existing PRC source protections, anonymous browsing, 48 dp controls, 200% text support and the zero-spend budget. Keep release detection and notification delivery independent of advisory ingestion. Work from the current source viewer and picker behavior, including in-progress workspace changes. Use synthetic metadata in tests.

## Review focus

| Regression | Where to prove it |
|---|---|
| A corrected or combined release loses a list or borrows another article's list | Task 1 |
| A returning user loses their selection or a failed refresh implies “Not released” | Task 2 |
| A regional notice or ambiguous exam name matches the wrong sitting | Tasks 3–4 |
| An outage, duplicate or corrected notice produces a misleading card | Tasks 4–5 |
| Reading Updates changes Results, including on a previously installed client | Tasks 4–5 |

## Release 1 · Consolidate results

### Task 1 · Keep every official result source accessible

Files: `app/lib/ui/results.dart`, `app/lib/ui/shared.dart`, `app/test/publication_links_test.dart`.

- [ ] In the publication-link suite, add “Results groups each article with its own lists”. Supply two distinct publications and a version whose article uses the PRC host or index.php alias of the older item. Expect one status, the current article's title/date and labels with its links, and only the other title/date and links under **Other result publications**. Inspect each button's URI. Also test a missing version, an unmatched version URL, no version URL, and an article without lists.
- [ ] From `app/`, run `flutter test test/publication_links_test.dart`. Confirm the new test fails because only one article is displayed.
- [ ] Keep the `ResultsScreen(version:, publications:)` interface. Reuse the article identity comparison from `SourceLinks` for grouping and document matching. When the version identifies an article, show it first. If its URL is unknown to the feed, show its known sources first and retain all feed articles separately. With no version or no identifiable current article, show the newest feed article first and keep any version-only document separately labeled. Never attach that document to an unrelated article. Render every other distinct article in repository order with its own links. Reuse `OfficialSourceLinks`, `sourceTime` and the existing viewer.
- [ ] Move the multi-list and missing-list assertions currently tied to Updates onto Results. Rerun the suite and check the link counts, targets, canonical aliases and existing document fallback. Commit this behavior independently.

### Task 2 · Land on Results and retire the duplicate destination

Files: `app/lib/main.dart`, `app/lib/ui/{shell,exam_selection,launch,updates}.dart`, `app/test/{shell,flows,exam_selection,visual,publication_links}_test.dart`, `app/integration_test/app_test.dart`, affected `app/test/goldens/`, `PRODUCT.md`, `DESIGN.md`, `README.md`.

- [ ] Add a saved-selection case with a retired sitting and a similar active replacement. Assert the Results picker action appears and no replacement's results load until the user chooses it.

- [ ] Update navigation and flow tests first. Assert Results is selected after Skip and after restoring a saved selection. Exercise Choose my exam, Back, select, change, refresh, failed restore/retry and local-data deletion through Settings. With no selection, expect one accessible picker action in the results context. Assert no Updates destination on phone or rail. Keep the narrow landscape and large-text cases. In the integration test verify the result directly after selection.
- [ ] From `app/`, run `flutter test test/shell_test.dart test/flows_test.dart test/exam_selection_test.dart`. Expect navigation or copy failures against the three-tab implementation.
- [ ] Set Results to index 0 and Settings to index 1 across the shell and app. Audit every destination check, including the existing index-3 subtitle branch, local errors, exam context and refresh visibility. Resolve the picker entry point on Results so the context card and status panel do not both offer “Choose exam”. Preserve chooser access on compact layouts and restoration/loading feedback.
- [ ] Change the first selection CTA to **View results**. Update the welcome instructions to point to Results and the official lists. Remove the retired Updates widget and its imports after the source-link tests move. Retain distinct email/push preference labels. Update the three active product documents to describe the two destinations.
- [ ] Update visual tests to capture the Results landing state, Settings, onboarding and large text in both themes. Retire only the obsolete Updates baselines. Run `flutter test --update-goldens test/visual_test.dart`, inspect changed images, then run `flutter analyze` and `flutter test`. On an Android device run `flutter test integration_test/app_test.dart` and `flutter test integration_test/source_viewer_test.dart`. Expected: both navigation layouts work, existing source-viewer behavior passes, and a failed fetch cannot display an unsupported release claim. Commit release 1. It can ship here.

## Release 2 · Add verified advisories

### Task 3 · Qualify a schedule-change source

Files: `docs/source-access.md` for evidence, `worker/config.json` and `worker/source.py` for permitted routes and parsing once verified, new `worker/tests/test_advisories.py`.

- [ ] Inspect official PRC material through the existing source policy. Record the index and article URLs, posting-date format, how pagination ends, scope of coverage, and one real postponement or rescheduling notice with evidence for its sitting and region. Record a similar result article as an exclusion. An annual schedule alone cannot establish when a change was announced. If a bounded source cannot be verified within the budget, close the investigation with that finding and keep release 1.
- [ ] Translate observed markup into minimal synthetic fixtures. Test a dated change, postponement without a new date, wrong region, similarly named exam, scoped category, ordinary result release, PRC URL aliases and a partial index. Run `python -m unittest worker.tests.test_advisories -v` from the root and confirm the missing behavior.
- [ ] Implement parsing for the observed source. Produce an official title, source URL, PRC posting date normalized to UTC, category `scheduleChange`, and exact validated selection associations. Send ambiguous mappings for private review. Reuse `SourcePolicy` and `publication_identity_url`. Limit any route expansion to verified paths. Rerun the fixtures and commit the parser and evidence.

### Task 4 · Publish independently readable advisory data

Files: `worker/{main,providers}.py`, `worker/tests/test_advisories.py`, `firebase/firestore.rules`, `firebase/tests/firestore.test.mjs`.

- [ ] Record the verified time window in each snapshot as `coverageStartUtc` and `coverageEndUtc`. Test an unresolved notice potentially affecting a covered selection. Mark the affected scope incomplete so it cannot emit a checked-empty state.

- [ ] Use a bounded pilot snapshot per covered selection at `advisoryFeeds/{examId}/sittings/{sittingId}/categories/{categoryId}`. Each document carries `lastSuccessfulCheckUtc`, `freshness` and an ordered `notices` array. Each notice carries `kind`, `title`, `publicationUrl` and `publishedAtUtc`. Exact document reads work through both existing Firestore clients without an index. A successful scan of a covered selection can write an empty array. An absent feed means unknown coverage.
- [ ] Add worker tests for identical rescans, a corrected notice moving between selections, failed/incomplete scans, and a notice-only sitting. Assert one card per canonical article per selection, preservation of prior cards on failure, and zero advisory writes to `publications`, `resultVersions` or result health. In rules tests assert anonymous exact reads succeed and all client writes fail. Run both suites before implementation and confirm the new assertions fail.
- [ ] Run the pilot scan independently of result success/failure. Rebuild snapshots only after a complete scan of the documented window. Deduplicate canonical articles, retain actual official URLs and sort by posting date descending with canonical URL as tie-breaker. Commit the bounded set of affected selection snapshots atomically, including withdrawals; defer publication and mark stale if size/write limits would be exceeded. On an incomplete scan retain last-good data and record stale status for the covered scope. Keep private review records outside the public feed.
- [ ] From root run `python -m unittest discover -s worker/tests -v` and the demo-project emulator command in `firebase/README.md`. Require passing worker and rules suites. Record expected worker traffic, writes and app reads at the chosen cadence before enabling the pilot. Commit the backend separately.

### Task 5 · Restore Updates for verified schedule changes

Files: `app/lib/domain/models.dart`, `app/lib/data/{exam_repository,firestore_repository}.dart`, `app/lib/main.dart`, `app/lib/ui/{updates,shell,launch}.dart`, repository fakes under `app/test/` and `app/integration_test/`, plus the navigation, flow and visual tests from Task 2.

- [ ] Include the verified date range in the checked-empty widget assertion and render it from the coverage fields in Task 4.

- [ ] Add tests for a populated, checked-empty, stale, unsupported and failed feed. Assert a notice-only sitting shows its notice in Updates and never “Results released” in Results. Switch selections during a delayed read and ensure the old card cannot appear. An advisory read error must leave Results usable.
- [ ] Define `Future<AdvisoryFeed?> loadAdvisories(ExamSelection selection)`. Use the Task 4 document path via the existing SDK/REST exact-read helper. Validate source URLs and dates. Null means uncovered; read exceptions mean unavailable. Keep stale cards visibly labeled with the last successful check, and treat a missed scan as stale using the pilot cadence and its documented freshness window.
- [ ] Add Updates between Results and Settings, keeping Results first. Load advisories when Updates opens or refreshes, keyed to the exact selection. Show the official title, posting date, category and **Open PRC notice** using the existing source action. Provide distinct empty, unavailable/retry and stale states. Never pass advisory records to `ResultsScreen.publications`. Bring onboarding, current product docs and goldens into line with the verified coverage.
- [ ] Run the release 1 Flutter checks and the new advisory tests. On a device check one real matched notice and verify its source opens. Confirm an uncovered sitting and a failed check cannot report a verified empty feed. Release the three-tab client only after the pilot data is readable and coverage and cost checks pass. If the source subsequently fails, display dated stale data or the unavailable state. Commit the client separately.
