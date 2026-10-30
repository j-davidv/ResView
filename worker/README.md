# PRC publication worker

Imports official schedules and reviewed PRC result announcements from 2026 onward into Firestore. Names entered in Android never reach this worker. There is no delivery adapter; delivery remains disabled.

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r worker/requirements.txt
.venv/Scripts/python -m unittest discover -s worker/tests -v
$env:FIREBASE_PROJECT_ID = 'resview-9240c'
.venv/Scripts/python -m worker.main --config worker/config.json --live-sources --delivery disabled
```

Use authorized Application Default Credentials outside this checkout, or the dedicated GitHub identity described in [provider setup](../docs/provider-setup.md). Running the last command writes the real public database. Tests use isolated synthetic data. Production has no fixture/demo mode. Missing configuration fails.

The owner authorized public PRC access on 2026-10-15 without a separate permission approval. The worker checks each host's robots rules before requests, including document URLs/redirects; allows configured HTTPS routes only; pins checked public DNS addresses; and bounds bytes, time and retries. It does not circumvent disabled downloads or login.

Discovery follows official results pagination through the pre-2026 boundary, bounded to 100 pages. Publication dates determine coverage, including results titled 2025 but released in 2026. The official schedule menu supplies annual sources, including next year's schedule when available; a missing current-year schedule fails the scan. Removed sittings are retired only within their source year. All requests retain the existing source/robots checks.

Official `/article/` and `/index.php/article/` routes share mapping, publication and review identities, including PRC's two hostnames. Records retain the actual fetched official URL as provenance.

Combined releases can map to multiple exams/categories. Special sittings stay separate from domestic sittings; professional oral releases cannot match ordinary engineer examinations. Exact-row schedule corrections and version-pinned phase/regional mappings are in `config.json`. Unknown or changed mappings go to private `workerReview`; resolved records are retained. A mapping with `unresolvedSittings` imports its established associations while retaining the announcement in review. The 99 labels include written/practical/SPLE variants, not 99 distinct professional boards. Sitting dates use UTC midnight to preserve calendar days in Flutter, and date spans can include different regional reschedules. Rollover uses UTC+08:00. See [mapping evidence and four unresolved releases](../docs/prc-mapping-review.md).

Repository `config.json` has empty `profiles`. The exact September 28, 2026 Ocular Pharmacologists PDF is approved for extraction in ignored `.development/task5/worker-config.json` under `profiles`; its real-name sample and signature/footer exclusions remain private. The existing parser suffices. The version-specific adapter requires an exact original hash, independent full-row digest, reviewed headings/ignored lines, physical page count, published count, terminal marker, review timestamp and visual samples. It supports one contiguous numbered section and never infers name components. Manual Storage publication and phone checking are verified for that version. Reviewed standard Drive download routing remains necessary for unattended revalidation. See [format validation](../docs/format-validation.md).

Assets are immutable and read back publicly before a transactional availability switch. Changing article provenance stays outside the immutable names file. Observed document validation failure revokes current checking; network failures retain last-good data with stale health. Successful checks refresh only the selection actually fetched. Android also expires freshness after 90 minutes.

To suspend a faulty reviewed profile, set its `disabled` field to `true` and rerun with that private configuration. The worker revokes that profile's document version without uploading names. Removing the profile alone preserves a previously validated list when the announcement is unchanged. Changed official document links revoke old checking until review. Saved Android copies are blocked after the device learns of a superseded or revoked version, including revocation without a document-version change; corrections published while the device is offline remain unknowable.

The scheduled archive scan is hourly at minute 17 UTC, gated by `PRC_MONITOR_ENABLED`. The October 30 metadata snapshot estimates about 14,300 writes/day hourly, versus 28,500 twice hourly, against Firestore's [20,000 free writes/day](https://firebase.google.com/docs/firestore/quotas). This excludes app activity, retries, manual scans and growth; review usage before expanding coverage. Delivery remains disabled. Public configuration has no extraction profiles, so a successful metadata schedule does not verify unattended PDF checking updates.

The worker uses the existing GitHub OIDC identity without a long-lived key. October 30 diagnostics reached both PRC hosts after earlier connection refusals. The older deployed worker still failed; the current workstation archive import passed. Enable the schedule only after its deployed revision passes a manual run and the current scan budget is reviewed. One exact extraction profile remains private; unattended document retrieval, quota-exhaustion recovery, retention and alerts remain pending. See [deployment evidence](../docs/worker-deployment-review.md).
