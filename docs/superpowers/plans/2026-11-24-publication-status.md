# Schedule-aware Publication Status Implementation Plan

> Execute inline with superpowers:executing-plans. User authorized implementation of the proposed behavior.

**Goal:** Replace ambiguous publication status with schedule-aware, source-backed information.

**Architecture:** Extend existing sitting documents with optional targetReleaseDate and officialTargetReleaseDate. Read monitor/status independently of result versions. Derive status in the existing Results widget and retain successful snapshots across refresh failures.

**Tech Stack:** Python unittest, Flutter/Dart and existing Firestore reader.

**Spec:** ../specs/2026-11-24-publication-status-design.md

## Constraints and review focus

- Philippine calendar days, optional backwards-compatible metadata, no new dependencies.
- Releases override dates; no synthetic publication records or automatic release on target dates.
- Ambiguous or past-before-exam targets must not discard sittings.
- Refresh updates schedule corrections and never invents source-check timestamps.
- Preserve source links and previous empty or released snapshots on partial failure.
- Existing green Material UI, large text, both themes, no new visual assets.

## Tasks

- [x] Add failing worker tests for target dates, missing/ambiguous values and corrections; implement optional target parsing in worker/source.py. Run worker suite.
- [x] Add failing Flutter status and refresh tests; extend Sitting, ExamRepository and FirestoreExamRepository, including oral sitting support and monitor/status reads. Update repository test doubles.
- [x] Implement Results status precedence and provenance in app/lib/ui/results.dart; update main.dart to refresh schedules and retain successful snapshots. Verify widget tests and relevant integration expectations.
- [x] Run full worker and Flutter suites, analyzer and Android build. Inspect changed screenshots at enlarged text and both themes, review diff and record limitations.

## Execution record

- Started from clean main checkout. Work stays in the shared workspace as authorized; no push or deployment is implied.
- Worker tests: 94 passed. The new target ingestion assertions failed before implementation.
- Cached official schedule replay: 159 sittings, 114 accepted targets, five target warnings. September 20 Professional Teachers imports November 27 with its source URL and original target text.
- Independent review found three issues, all reproduced before fixes: target-only reviews prevented sitting retirement, malformed/overflow target dates broke decoding, and a duplicate health read could hide verified versions. Corresponding provider/repository regressions now pass.
- Final Flutter suite: 92 passed, eight existing visual failures. All four new/updated status screenshot checks pass. Analyzer reports no issues. Debug Android APK build succeeds; toolchain prints existing Kotlin/SDK compatibility warnings.
- Original HEAD was extracted into ignored `.development/publication-status-baseline/` and reproduced ten visual-test failures before this feature. Two failure-state references changed here were updated to focus on Results; eight unrelated failures remain in `visual_test.dart`: Updates-disabled flow at 412 dp/1x and 900 dp/2x, and pilot notice at 412 dp/2x and 900 dp/2x, each in both themes. Their baseline errors include screenshot mismatches and missing navigation elements. No unrelated reference images were regenerated.
- Visual inspection: awaiting state in light/dark and failure state at 2x text fit without clipping. Existing functional tests exercise retry, partial publication/version reads and correction refreshes; no physical-device test was performed.
- Separate concurrent changes to navigation icons in design.dart, shell.dart and campaign-outline.svg were preserved.
- Logs, original-revision comparison and generated failure images are retained under ignored `.development/`.
- Subsequently authorized live deployment: worker commit 5de749b is published; 94 hosted/local worker checks pass. Two hosted scans timed out at PRC. The same revision completed a workstation production refresh with zero failures at 10:46 UTC+08:00 on November 24. Anonymous reads verify 159 active sittings, 114 source-matched targets, 127 publication associations and fresh health. Teachers derives Awaiting results with November 27 as its target. The phone already has app 1.0.2 build 4; it disconnected before the final live refresh. See docs/worker-deployment-review.md for evidence and remaining hosted-connectivity limits.
