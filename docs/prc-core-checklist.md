# PRC core feature checklist

Created: October 29, 2026.

This checklist is based on local code and repository evidence reviewed on that date. Live checks for completed steps are recorded below; unchecked steps are not established by those checks.

The Android UI, local matching, metadata worker, and Firebase integration already exist. A validated list has a demonstrated PRC-to-phone path. October 30 verification adds hosted metadata imports, correction/failure checks and automatic retrieval/revalidation of the approved PDF through the Drive API. The hourly monitor is enabled. Public `worker/config.json` contains no name profiles; the reviewed profile is supplied privately to the worker. Revised originals still require independent review before names checking can use them.

Work in the order below. Check an item only after recording its evidence. Prioritize steps 1–8 to establish browsing and name checking for a validated list with automatic metadata updates. Steps 10–11 complete alerts; step 13 covers public distribution.

## 1. Run Android with real Firebase configuration

Coverage requirement confirmed October 29, 2026: all PRC exams and publications from 2026 onward. A single-exam smoke check does not establish this coverage. Complete missing imports and mappings in steps 2–3, and validated name-list coverage in steps 4–9.

- [x] Use the existing `.development/firebase-client.json` run configuration.
- [x] Confirm a phone loads real exams, sittings, announcements, and official links.
- [x] Verify the intended exam/sitting/category can be selected without signup (Foresters smoke check; complete 2026-onward coverage remains pending).

Reference: [Android runbook](android-studio-runbook.md).

## 2. Restore PRC access from the worker environment

- [x] Recheck the documented HTTPS connection refusal from GitHub Actions.
- [x] Resolve normal connectivity or use an authorized execution environment that can reach PRC.
- [x] Complete a successful manual live import and verify updated Firestore records and scan health.
- [x] Keep scheduled ingestion disabled until the manual run succeeds.

Completed October 29 using the authorized workstation over normal HTTPS. GitHub-hosted access still fails; `PRC_MONITOR_ENABLED=false` remains in place. Discovery now accepts PRC's `/index.php/article/` links. This completes the manual metadata-import requirement, not unattended operation or complete publication mapping.

Reference: [Worker deployment review](worker-deployment-review.md).

## 3. Complete relevant exam and publication mappings

- [x] Review ambiguous aliases, special sittings, oral/practical dates, and unmatched publications in `workerReview`.
- [ ] Verify each result points to the correct exam, sitting, and category.
- [x] Add historical discovery/backfill where needed; follow the official index through the pre-2026 publication boundary.
- [x] Establish schedule rollover beyond the hardcoded 2026 source.

October 29 review/import: 79 announcements now have 95 verified exam/sitting/category mappings and 159 active sittings. Twelve archive pages were inspected, including the pre-2026 boundary. Seven oral/technical-evaluation or qualifying-assessment announcements still lack exact sitting evidence, so task 3 is not complete. The schedule menu now controls annual discovery; 2027 rollover is tested synthetically because no 2027 schedule is linked yet. See [mapping decisions, verification and remaining evidence](prc-mapping-review.md).

October 30 follow-up: 120 mapped records across 84 announcements are now verified live. Three announcements were resolved fully; two more have confirmed regional mappings while retaining their unresolved locations in review. Four distinct issues remain: January Professional Electronics Engineers, February Professional Mechanical Engineers, the Davao portion of the August mechanical release, and the Cebu/Davao portions of the October electronics release. PRC article-route aliases now share one mapping/record identity; 13 duplicate public records were archived privately. All 43 worker tests and live public-query/private-denial checks pass. Task 3 remains partial.

## 4. Obtain one accessible official passing-list document

- [x] Select one exam to prove the complete flow.
- [x] Retrieve an accessible official PRC passing list without bypassing restrictions.
- [x] Preserve the original document and its official source chain privately.

Completed October 30, 2026: selected Ocular Pharmacologists, September 28, 2026 (`ocular-pharmacologists-2026-09-28`, category `all`). The [official PRC announcement](https://www.prc.gov.ph/index.php/article/september-2026-ocular-pharmacologists-special-certification-computer-based-licensure), published October 15, links its List of Successful Examinees to [this Google Drive document](https://drive.google.com/file/d/1KO7U84q5HCMCE2mRsC3rwBlfJDc2A5w3/view?usp=sharing). Its unauthenticated standard download succeeded at 02:19:13 UTC (10:19:13 Asia/Taipei), without viewer extraction or a restriction workaround.

The original PDF is 270,838 bytes, SHA-256 `cada461c37f74824fdf77a0c32cb3af1ca07b9b43b121589bd73959e838dfa15`. It opens without encryption. Visual inspection confirms the exam/date headings, one numbered successful examinee and `NOTHING FOLLOWS`, consistent with the announcement's one passer. The downloaded original has one physical page with the printed label `Page: 2 of 2`; task 5 must account for that distinction without modifying the original or assuming a missing page.

Private evidence is retained under ignored `.development/task4/`: original `1KO7U84q5HCMCE2mRsC3rwBlfJDc2A5w3.pdf`, freshly fetched `announcement.html`, download attempts and redirect chain in `attempts.json`, rendered `passing-list-page-1.png`, file hashes and timestamps in `provenance.json`, and `verify.py`. No examinee name is copied into repository documentation or configuration. Metallurgical Engineers and Naval Architects returned explicit owner/editor-only download restrictions on the same normal route and were left alone. The previously inspected Foresters download restriction is not rechecked here. This completes acquisition only; independent extraction validation and the PDF-to-phone flow remain tasks 5–7.

## 5. Validate the document and enable its extraction profile

- [x] Independently compare every extracted row with another reader.
- [x] Verify names, numbering, physical pages, headings, category, published count, and completion marker.
- [x] Record the document hash, independent row digest, visual samples, and review timestamp.
- [x] Register the approved version in `profiles`, reviewing any real-name exposure before repository publication.
- [x] Add a parser only if the target document requires one. The current extractor supports a single numbered section in a text PDF, not scanned, wrapped-name, or multi-section formats.
- [x] Run original-document mutation tests and confirm invalid or changed documents refuse checking.

Completed October 30, 2026 for the exact task 4 original. MuPDF 1.28.2 independently read the complete list; all one of one rows agree with the visual transcript and production pypdf 6.20.1 extraction, including exact spelling, sequence, category `all` and physical page 1. The official announcement reports one passer out of two examinees. Exam/sitting/release headings and `NOTHING FOLLOWS` were verified visually. The original remains unchanged: its one physical page retains the printed `Page: 2 of 2` label. No new parser is needed. This document contains no accented or suffixed names; it does not establish those cases on a real list.

Review timestamp: `2026-10-30T02:24:58.756235+00:00` (10:24:58 Asia/Taipei). Original SHA-256: `cada461c37f74824fdf77a0c32cb3af1ca07b9b43b121589bd73959e838dfa15`. Independent complete-row digest, computed with `worker.extract.encode`: `91d4eb1d72610369f5b7fb209304dcb5776599f1a32d7254adde61e98c9d18a7`.

The approved version is registered under `profiles` in ignored `.development/task5/worker-config.json`. Its visual sample identifies the passer, and exact signature/footer exclusions identify officials, so the profile and complete run configuration remain private. Repository `worker/config.json` deliberately retains an empty `profiles` object; no real-name profile or fixture was published. Private evidence includes `review.json`, `visual-transcript.json`, `independent-mupdf.txt`, `page-1.png`, derived `names.json`, `verify.py` and `verification.json`.

The private verification script passes 37 refusal checks covering original-derived name/row/number/date/page-label/marker/footer changes, extra rows/pages, blank/image-only/encrypted/non-PDF files, changed bytes and invalid review metadata. Semantic changes are also rejected with their hashes repinned, demonstrating checks beyond original-hash refusal. Seventeen local worker replays confirm only the original reaches the mocked publication boundary; rejected versions mark checking unavailable and never upload or activate. All 43 worker tests pass. Git exclusion and the unchanged original are checked. These are local replays, not live provider checks. The worker still needs reviewed standard Google Drive download routing; private profile approval alone does not make its linked viewer URL a fetchable PDF. Storage transfer and phone verification remain tasks 6-7.

Reference: [Format validation](format-validation.md).

## 6. Connect and verify real Supabase publication

- [x] Configure the worker-only Storage credential securely; never include it in Flutter or logs.
- [x] Verify available storage/transfer capacity and denied client uploads, overwrites, and deletions.
- [x] Upload the validated immutable JSON and download it through its public URL.
- [x] Verify bytes, hash, size, and Flutter decoding before activating `checkingAvailable` in Firestore.

Completed October 30, 2026 for the task 5 Ocular Pharmacologists version. Restored the paused existing Supabase project `erlnuyltaudetjpriosu` to `ACTIVE_HEALTHY` and rechecked its Free organization. The owner reported organization Usage of 0.026 / 0.5 GB database and zero for other usage, including Storage Size and both egress categories. The current [Free Storage allowance](https://supabase.com/docs/guides/platform/manage-your-usage/storage-size) is 1 GB; [egress allowances](https://supabase.com/docs/guides/platform/manage-your-usage/egress) are separately 5 GB uncached and 5 GB cached. These figures establish capacity for this 781-byte publication and the initial 20-user pilot of this one list; all-exam workload and ongoing quota handling remain separate acceptance work.

The owner supplied the worker key through hidden PowerShell input into ignored `.development/task6/storage-key.dpapi`. Windows DPAPI protects it for the current Windows account; the private worker runner decrypts it only in memory. The key was not passed to Flutter or configured in GitHub. An audit of worker/app sources, workflow files, documentation and task 6 artifacts/logs found no plaintext copy. Private originals, profiles, names JSON and credential files remain Git-ignored; public `worker/config.json` still has no real-name profile.

The public `validated-names` bucket remains JSON-only with a 20 MiB limit, enabled Storage RLS and no client policies. Neither `anon` nor `authenticated` can bypass RLS; security advisors report no findings. Eight live unauthenticated/anonymous API probes refused new uploads, PUT overwrites, POST upserts and deletions. Anonymous deletion returns HTTP 200 with an empty array because no rows are visible; read-back after every attempt confirms the original asset remained unchanged. Duplicate worker uploads are idempotent. A post-upload database audit confirms exactly one object totaling 781 bytes.

The exact approved original was revalidated and its current official announcement/source linkage rechecked. Immutable public JSON SHA-256 is `1474754159a2071d22780645e0200ebb97fc4b96d8bab7467eca9e2a155f90d8` (781 bytes); its document version remains original SHA-256 `cada461c37f74824fdf77a0c32cb3af1ca07b9b43b121589bd73959e838dfa15`. Flutter's actual `ListStore.prepare` downloaded the public URL, checked size/hash, decoded every row and source page/sequence/category, and cleaned its temporary file before Firestore activation. The worker transaction activated result version `7b03ca063ce7e9122217131b1abf6745211f39cc850ff87ba3b6af14f26f6cfb` and superseded the prior unavailable version. At `2026-10-30T02:52:18.248Z` (10:52:18 Asia/Taipei), a separate unauthenticated Firebase client read the current `checkingAvailable` record and retrieved identical public JSON using its URL/size/hash metadata.

Private evidence is retained under ignored `.development/task6/`: capacity and bucket audits, pre-activation metadata backup, client denials, downloaded JSON, Flutter source/output, activated metadata, worker verification, public-client read-back and credential audit. The 43 worker tests and seven focused Flutter schema/storage tests passed during preparation; the real-public-transfer Flutter test passed again before activation. This completes task 6 for one version. Physical-phone checking remains task 7; reviewed Drive download routing, hosted source access, unattended updates, broader coverage and delivery remain pending. Scheduling and outbound delivery stay disabled.

Reference: [Provider setup](provider-setup.md).

## 7. Prove real name checking on Android

- [x] Select the approved exam and download its actual validated list.
- [x] Test exact matches, absent names, accented names, suffixes, and supported candidate matching.
- [x] Verify the displayed source, page, sequence, and document version.
- [ ] Confirm names and personal outcomes stay out of network traffic, logs, and backups.
- [x] Verify cancellation, interrupted downloads, low storage, temporary-file cleanup, and saved offline lists.
- [x] Preserve the 20 MiB download and 50 MiB saved-file limits.

Verified October 30, 2026 on the USB-authorized Infinix X6710, Android 14. The actual Ocular Pharmacologists list from tasks 4–6 downloaded and passed the pinned 781-byte size, SHA-256 and document-version checks. The phone UI produced both an exact published-name match and an absent-name outcome, retained the identity/failure cautions, and displayed entry 1, section `all`, physical PDF page 1, the approved document version and both official source links. The original's printed page label remains `Page: 2 of 2`; the app reports the physical page. Native synthetic tests separately verified composed/decomposed Ñ, accent distinction, suffix-sensitive exact checks and conservative candidates. This real list has no reviewed components, so it correctly offers no possible-match action.

Three Android integration tests and all 28 local Flutter tests passed; `flutter analyze` reported no issues. Android tests exercised a truncated loopback transfer, mid-transfer and pre-start cancellation, injected insufficient-space refusal, abandoned-file cleanup, and exact 50 MiB saved-file capacity with one additional byte refused without eviction. Above-20 MiB download metadata was refused before a request. A new `ListStore` reopened the real saved list with Firestore networking disabled and zero download requests; exact and absent checks still worked. Test lists and temporary files were removed. Low-space refusal was injected on the phone; actual disk exhaustion and process-kill recovery remain broader device acceptance work.

Privacy verification is partial: unsaved names remained absent from secure storage, captured Android/test logs contained neither the real published name nor personal outcome messages, the recorded list request used only its immutable public URL, and local offline checking required no download. Source review found no name/outcome network or logging path. The compiled APK disables backup, and cloud-backup/device-transfer exclusions cover all app storage domains. Full native TLS traffic inspection and a backup/restore exercise were not performed; Backup Manager is disabled on this phone. The combined privacy checkbox therefore remains open.

Private evidence is in ignored `.development/task7/`, including phone-generated metadata, a visually inspected exact-match screenshot, test/analyzer output, log audit and `verify.py`. The first Flutter integration run used the default uninstall behavior and reset local app state; the repeat used `--no-uninstall`. The captured original normal debug APK was restored and its regular exam/sitting/category picker was used to select Ocular Pharmacologists, September 28, All successful examinees. No name or test list remains saved by this work. See [physical-phone evidence](android-studio-acceptance.md#october-30-2026-live-name-checking-on-android).

Milestone: basic PRC browsing and name checking have a demonstrated working path for the validated list. A matching name does not establish identity, and an absent name does not establish exam failure.

## 8. Verify corrections, failures, and automatic updates

- [x] Exercise changed documents, rejected extraction, superseded lists, PRC outages, and failed uploads.
- [x] Confirm failed validation cannot publish a usable list and outages retain last-good data with stale status.
- [x] Confirm known superseded offline lists cannot be used for checking.
- [ ] Enable `PRC_MONITOR_ENABLED=true` after successful manual verification, then observe an actual scheduled run.
- [x] Verify manual reruns, failure detection, and disabling a faulty format.
- [x] Verify automatic retrieval and revalidation of the approved PDF through a permitted source API.

October 30 verification: 65 worker tests, 34 Flutter tests and the analyzer pass. The real original's 37 refusal checks and 17 worker replays pass again. Correction handling now revokes malformed PDFs, changed document links and changed pinned mappings, and supports explicit private-profile disabling. Android blocks known superseded or revoked saved lists, including same-version revocation and temporary failures while enumerating or updating local files; active checking resets when availability changes. Outages and unchanged-version upload failures preserve last-good checking with stale health. A validated correction supersedes old checking before upload, so a failed correction upload leaves checking unavailable. Faults were injected locally; production source and Storage failures were not deliberately induced.

The scoped worker update began with [commit `23f3d01`](https://github.com/j-davidv/ResView/commit/23f3d017745d848c462f85f8c9cc6f36218d9950); the metadata baseline runtime is [commit `d29628d`](https://github.com/j-davidv/ResView/commit/d29628d34eb0404d366e537ea7ba8a196b5a3152). Application changes, original documents, real-name profiles/fixtures and credentials remain local. The workstation import succeeded with zero failures and preserved the approved available list. Hosted access remains intermittent: one attempt timed out, while its rerun and subsequent manual scans succeeded. The [final revision's manual scan](https://github.com/j-davidv/ResView/actions/runs/41004421852) passed all 54 tests and the live import; independent public-client and all-selection read-backs passed afterward. `PRC_MONITOR_ENABLED=true` was enabled at 12:20:22 Asia/Taipei after the earlier successful manual verification. The cadence is hourly at minute 57 UTC: the metadata-only baseline estimate was 14,256 writes/day rather than 28,512 twice hourly; approved-PDF revalidation brings this to 14,280/day rather than 28,560, against 20,000 free writes/day. This estimate excludes app usage, retries and growth.

The owner's later October 30 instruction requires automatic PDF retrieval in addition to metadata updates. [Hosted run 41018013099](https://github.com/j-davidv/ResView/actions/runs/41018013099) passed all 65 tests and automatically downloaded/revalidated the approved 270,838-byte original through the documented Drive API. Its SHA-256 matches the preserved original; independent public-client and all-selection read-backs passed. The existing worker uses read-only OAuth and owner download capabilities, with no new identity/IAM grant or Storage writer secret. The profile is supplied through encrypted repository secret `PRC_PRIVATE_PROFILES`; names remain absent from source and job logs. Direct PRC routes retain web robots checks. Changed originals are rejected before parsing and require independent review; unsupported lists stay unavailable. The earlier metadata-only scope is superseded. Task 8 still awaits an actual scheduled monitor run. The workflow is active on the correct default branch, the monitor flag is true, and Actions is enabled. As of 16:24 Asia/Taipei, recommitting the hourly offset at minute 57 and explicitly enabling the workflow had not produced a scheduled event; see the [scheduler investigation](prc-update-verification.md#scheduled-trigger-investigation). See [correction, failure and update evidence](prc-update-verification.md).

The updated debug APK is built and signed with the same certificate as the task 7 build. The phone is disconnected, so installation and physical-phone verification of these fixes remain pending. A private 90-minute watcher will record the actual scheduled event, verify the monitor and independent public/all-selection read-back, and check only the scheduled-run item after those checks pass. A skipped or failed monitor cannot complete that item. Evidence is written under ignored `.development/task8/`; the watcher exits after completion, failure or timeout.

## 9. Expand validated exam coverage

- [x] Repeat document validation for each supported format/version (four exact versions; broader coverage remains incomplete).
- [x] Keep unsupported lists visibly unavailable for checking, with official links.
- [x] Establish ongoing review for newly published and corrected documents.

October 30 expansion: added May 29-30 Midwives SPLE (3 rows), June 4 Occupational Therapists (66 rows), and June 2-3 Physical Therapists (526 rows). All 595 new rows agree between MuPDF and pypdf; all 14 pages and boundary/accent/suffix samples were visually inspected. The existing single-section parser handles each version. Private validation adds 59 semantic/profile refusal checks and nine worker replays; three real-public-transfer Flutter tests pass before transactional activation. Seventy-three worker tests, all 34 local Flutter tests and the analyzer pass.

The expanded read-only hosted review inspected 87 linked/candidate PDFs: four were accessible and 83 failed the permission/restriction/metadata gate. Qualified successful-list links are retained for review without guessing category mappings. The worker now emits a coverage inventory after live attempts; originals acquired for review are encrypted before leaving CI, and exact profiles remain in the encrypted worker secret. [Final hosted revalidation](https://github.com/j-davidv/ResView/actions/runs/41064241312) passed all four originals. A final unauthenticated read verified 120 current selections (four available, 116 unavailable), no exposed unavailable assets, no stale mapping and denial of the private archive. The maintainer review procedure covers new releases, corrections, evidence retention, validation, activation and revocation. See [coverage evidence and review procedure](prc-coverage-review.md).

Profiles are version-specific. Four approved PDFs do not enable future releases or establish all-exam matching coverage. Unsupported selections and the four existing mapping issues remain pending; physical-phone checks of the new lists are not established.

October 31 manual-viewing addition: official announcements and supported Drive lists can now open inside the Android app, with touch-operated full-document Find/Previous/Next and browser recovery. This provides a manual source-reading option when automatic checking is unavailable; it does not approve additional extraction profiles. See [viewer implementation and acceptance](prc-viewing-compatibility.md#in-app-implementation).

## 10. Implement push alerts

- [ ] Add the missing worker-side FCM delivery adapter; the app currently provides registration/preferences.
- [ ] Configure minimum necessary sending permissions.
- [ ] Implement per-publication/version deduplication, bounded retries, correction handling, invalid-token removal, and inactive-subscription cleanup.
- [ ] Verify device registration, actual receipt, token rotation, opt-out, and pending deletion using authorized test devices.
- [ ] Confirm alerts announce publications and never personal results.

## 11. Implement email subscriptions and delivery

- [ ] Configure the Brevo hosted confirmation form, exam preferences, unsubscribe flow, and app signup link.
- [ ] Add the missing worker-side email adapter and persistent bounded queue.
- [ ] Enforce confirmed active recipients, shared account capacity, retry limits, expiry, correction cancellation, and unsubscribe checks before sending.
- [ ] Implement the agreed retention rules.
- [ ] Verify real confirmation and delivery with authorized test recipients.
- [ ] Recheck current provider limits before activation; do not treat historical plan allowances as current guarantees.

Reference: [Agreed specification](superpowers/specs/2026-10-14-prc-exam-app-design.md) and [implementation plan](superpowers/plans/2026-10-14-prc-exam-app.md), especially Task 10.

## 12. Complete physical-device and operational acceptance

- [ ] Run worker, Flutter, Firestore rules, and Android integration checks.
- [ ] Verify TalkBack, enlarged text, landscape, gestures, slow/offline networks, and large-list performance on a physical phone.
- [ ] Check capacity for the intended initial 20 users without enabling billing.
- [ ] Exercise credential recovery, quota exhaustion, service outages, rollback, and safe cleanup.
- [ ] Update readiness documents, reconciling older task-table entries with later implementation evidence.

References: [Android acceptance](android-studio-acceptance.md), [implementation progress](implementation-progress.md), and [release readiness](release-readiness.md).

## 13. Finish public-release requirements

- [ ] Review and publish the application source deliberately; deployment notes record publication of only the worker subset. Exclude credentials, private exports, original PDFs, and real-name fixtures.
- [ ] Configure private release signing and key backup; test signed installation and updates.
- [ ] Publish an accurate privacy policy and maintainer contact, and verify their app links.
- [ ] Select the distribution route and complete its requirements.
- [ ] Obtain the separate public-launch/delivery authorization recorded in the project plan.

## Evidence log

Record completed steps here with dates and links to test results or updated acceptance notes. Do not include credentials, private names, or subscriber details.

| Date | Step | Evidence | Remaining limits |
| --- | --- | --- | --- |
| October 29, 2026 | 1 | Firebase-configured debug APK built and installed on an Infinix X6710, Android 14. Live catalog, October 8–9 Foresters sitting, category selection, announcement and PRC browser handoff verified without signup. See [physical-phone evidence](android-studio-acceptance.md#october-29-2026-live-firebase-physical-phone-check). | Database has 99 exam labels, 87 sittings (2026 only), five publications and five result versions. Complete coverage from 2026 onward is pending. Foresters source check remains October 15; checking unavailable. |
| October 29, 2026 | 2 | [Fresh GitHub diagnostic](https://github.com/j-davidv/ResView/actions/runs/40863432014) reproduced refusal on both PRC hosts. Workstation manual import succeeded at 11:13:27 UTC (19:13:27 Asia/Taipei); read-back verified 99 refreshed exams, 87 sittings, five new publications/current versions and fresh scan health. Totals: 10 publications and 10 versions. All 34 local worker tests and public-query/private-denial checks passed. See [worker evidence](worker-deployment-review.md#october-29-2026-manual-import). | Hosted connectivity remains unavailable; schedule disabled. Latest-page discovery only, mappings still require task 3 review, no name profiles enabled. |
| October 29, 2026 | 3 (partial) | [Mapping review](prc-mapping-review.md): live backfill completed with zero publication failures; 99 exam labels, 159 active sittings, 95 mapped publication records for 79 announcements, and 95 current unavailable-checking versions. Incorrect oral-to-ordinary mapping archived and removed. Forty worker tests and live public-query/private-denial checks passed. | Seven publications remain pending authoritative sitting evidence. Current menu lists only 2026; future-year rollover tested synthetically. Changes remain local, scheduling/delivery disabled, no checking profiles. |
| October 30, 2026 | 3 (partial follow-up) | [Resolution and alias review](prc-mapping-review.md#october-30-follow-up): zero-failure live import; read-back verified 120 mapped records across 84 announcements, 120 current unavailable-checking versions, and 159 active sittings. Thirteen publication aliases archived privately. Forty-three worker tests and live public-query/private-denial checks passed. | Four distinct review issues remain; two have partial regional mappings. Full-text downloads explicitly owner-restricted. No GitHub publication, schedule activation, name profile or delivery activation. |
| October 30, 2026 | 4 | [Acquisition evidence](#4-obtain-one-accessible-official-passing-list-document): September 28 Ocular Pharmacologists original retrieved through the normal permitted download route; fresh official announcement, redirect chain, original bytes, SHA-256 and visual inspection preserved privately. Private assertions verify source linkage, hashes, PDF readability and Git exclusion. | One physical page is printed as page 2 of 2. No independent extraction approval, checking profile, upload or phone verification. |
| October 30, 2026 | 5 | [Validation evidence](#5-validate-the-document-and-enable-its-extraction-profile): full MuPDF/pypdf/visual row agreement; exact-version profile registered privately; 37 refusal checks, 17 local worker replays and all 43 worker tests pass. Original and private Git exclusion verified. | Public config stays metadata-only because profile samples/footer exclusions contain real names. Live Drive download routing, Supabase transfer and phone verification remain unverified; scheduling/delivery stay disabled. |
| October 30, 2026 | 6 | [Publication evidence](#6-connect-and-verify-real-supabase-publication): worker-only DPAPI credential; Free plan/capacity review; eight client mutation denials; exact immutable 781-byte JSON public read-back; Flutter download/integrity/decoding before transactional Firestore activation; separate unauthenticated app query/download confirms the active version. Secret/source exclusion audit passed. | One Ocular Pharmacologists version only. Workstation credential remains local; no GitHub secret or automatic ingestion was enabled. Physical-phone name checking, reviewed Drive routing, quota failure handling and all-exam coverage remain pending. |
| October 30, 2026 | 7 (partial) | [Android name-check evidence](android-studio-acceptance.md#october-30-2026-live-name-checking-on-android): actual approved list, exact/absent UI outcomes and provenance on Infinix X6710; native accent/suffix/candidate checks; interrupted/cancelled transfers and storage budgets; saved-list reuse with zero download requests. Three Android tests, 28 local tests and analyzer pass. Log/backup-configuration audit passes. | Full native traffic inspection and backup/restore remain unverified. Low-space refusal was injected; actual disk exhaustion and process-kill recovery were not exercised. The initial test runner uninstall reset local app state; normal APK restored and approved exam selected. Scheduling and delivery remain disabled. |

| October 30, 2026 | 9 (coverage expansion) | [Coverage review](prc-coverage-review.md): three additional originals independently validated, published and activated; 595 new rows, 59 refusal checks, nine worker replays and three real public-transfer Flutter tests. Seventy-three worker tests, 34 Flutter tests and analyzer pass. Unauthenticated queries verify four available and 116 unavailable selections with official links. Ongoing review inventory and encrypted acquisition are implemented. | Four exact versions only; 83 linked/candidate PDFs failed the download gate, six selections have no recognized passing-list candidate, and four mapping issues remain. Physical-phone verification of the additions and complete all-exam coverage remain pending. |

Hosted PRC connectivity and access to further documents remain external dependencies. Four accessible originals have privately approved exact-version profiles and verified public JSON assets activated in Firestore. One has demonstrated live name checking on a physical phone. This does not establish complete privacy acceptance, scheduled-event acceptance, alerts, all-exam coverage or release acceptance.
