# PRC corrections and update verification

Checked October 30, 2026 for core checklist task 8.

## Correction and failure checks

The worker's synthetic recovery suite uses the production provider switching logic with isolated in-memory records. It verifies changed document bytes, rejected extraction, changed official document links, version-pinned announcement changes, explicit profile disabling, source outages, failed uploads, incomplete HTTP responses and repeat scans. Failed validation exposes no usable names URL; superseded versions cannot be reactivated. Source and upload failures retain the last-good list while health becomes stale and the last-success timestamp stays unchanged. Upload/read-back refusal tests also verify that availability is never activated on failure.

Changed pinned mappings produce revocation-only observations for the previously reviewed selections, remain in review, and prevent an older announcement from becoming the latest result. They do not publish a new unreviewed association. A profile with `disabled: true` revokes its reviewed original without downloading or uploading names. Removing the profile alone intentionally preserves an unchanged, previously validated list.

Flutter tests verify that learning of a newer version or a same-version revocation blocks saved-list use. Successful invalidation persists across a new `ListStore`; temporary storage failures retain the known revocation in memory, including failures before saved-file enumeration. The active checking screen resets when availability changes. A metadata outage retains the last-good checking state with a stale warning. A device that has not learned of a correction cannot infer it offline. If revocation cannot be persisted, the in-memory block lasts for that process; the visible error requires retrying before offline reuse after restarting.

Final local checks: 51 worker tests, 34 Flutter tests and `flutter analyze` pass. A real malformed-PDF parser regression also verifies that parser exceptions revoke prior checking instead of escaping the failure path. The private real-document replay passes its 37 refusal checks and 17 worker replays; the original PDF is unchanged and excluded from Git. These are local failure-injection checks, not induced production PRC or Storage outages. Live Firestore transaction conflict/retry injection and physical disk exhaustion were not performed.

## Hosted execution and capacity

The [first fresh GitHub manual run](https://github.com/j-davidv/ResView/actions/runs/40999592528) ran the older deployed revision and failed processing a publication. Its diagnostics received HTTP 200 from both PRC robots URLs, superseding the earlier connection-refusal finding. No proxy or access workaround was used. The current workstation import then completed with zero publication failures; Firestore read-back verified all 120 current selections, fresh health and the unchanged approved public names asset.

The scoped worker update is [commit `23f3d01`](https://github.com/j-davidv/ResView/commit/23f3d017745d848c462f85f8c9cc6f36218d9950). Publication includes only the workflow and worker source/configuration/tests/README. It includes the earlier route, archive, mapping and rollover fixes needed by the deployed monitor. The application, private exact-version profile, original documents, real-name fixtures and credentials were excluded. Repository `profiles` remains empty; no Storage secret or delivery adapter was enabled.

The read-back snapshot contains 99 exams, 163 sittings, 121 publication records, 122 result versions, 120 worker selection pointers and 105 review records. Of the 120 current result versions, one has checking available and 119 remain unavailable. All public publication IDs pass the canonical identity audit; no alias cleanup was needed.

An unchanged-scan upper estimate is 594 writes: 262 catalog/retirement writes, 121 publication writes, 120 selection-check updates, four pending reviews, 86 review-status updates and one health write. This is approximately 28,512 writes/day twice hourly, exceeding the current [20,000 free Firestore writes/day](https://firebase.google.com/docs/firestore/quotas). Hourly cron `17 * * * *` lowers the estimate to 14,256/day. This snapshot estimate excludes client activity, retries, manual scans, corrections and catalog growth; it is not a quota-exhaustion recovery guarantee. Billing remains disabled. Reassess usage as coverage grows.

The updated worker's [manual hosted verification](https://github.com/j-davidv/ResView/actions/runs/41000787196) passed its tests but failed source setup with `TimeoutError`; both subsequent PRC robots diagnostics also timed out. Hosted access is intermittent, so the earlier HTTP 200 diagnostic does not establish recovery. A failed-job rerun was requested. `PRC_MONITOR_ENABLED=false` remains the required state unless a current manual attempt and independent public read-back pass. An actual `schedule` event must execute the monitor successfully before scheduled operation is marked verified; a tests-only scheduled run with a skipped monitor is insufficient.

## Scope still requiring verification

Scheduled metadata ingestion does not establish unattended PDF revalidation. The approved exact-version profile and worker Storage credential remain local. The reviewed standard Drive download route and a private automated-profile deployment are still needed to detect changed PDF bytes at an unchanged document URL. Public metadata monitoring can observe changed announcement text, links and pinned mappings; unsupported lists remain unavailable for checking. Alerts, email and public app distribution remain outside task 8.

Private evidence is retained in ignored `.development/task8/`: failing/passing regression output, local test/analyzer results, original-document replay output, source/deployment manifests, manual import/read-back, public-client verification, budget calculations and GitHub run records. It contains no published credentials or real-name fixtures.
