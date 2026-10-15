# PRC publication worker

Imports the official 2026 schedule and unambiguous recent PRC result announcements into Firestore. Names entered in Android never reach this worker. There is no delivery adapter; delivery remains disabled.

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r worker/requirements.txt
.venv/Scripts/python -m unittest discover -s worker/tests -v
$env:FIREBASE_PROJECT_ID = 'resview-9240c'
.venv/Scripts/python -m worker.main --config worker/config.json --live-sources --delivery disabled
```

Use authorized Application Default Credentials outside this checkout, or the dedicated GitHub identity described in [provider setup](../docs/provider-setup.md). Running the last command writes the real public database. Tests use isolated synthetic data. Production has no fixture/demo mode. Missing configuration fails.

The owner authorized public PRC access on 2026-10-15 without a separate permission approval. The worker checks each host's robots rules before requests, including document URLs/redirects; allows configured HTTPS routes only; pins checked public DNS addresses; and bounds bytes, time and retries. It does not circumvent disabled downloads or login.

Coverage is the latest results-index page, not a complete historical archive. Ambiguous mappings and unparsed special/oral dates go to private `workerReview`. The imported 99 labels include written/practical/SPLE variants; they are not 99 distinct professional boards. Sitting dates use UTC midnight to preserve the official calendar day in Flutter. Removed source-owned sittings are marked inactive; rows awaiting parsing review are preserved.

`profiles` is empty. No real name-list format is enabled. The version-specific adapter requires an exact original hash, independent full-row digest, reviewed headings/ignored lines, physical page count, published count, terminal marker, review timestamp and visual samples. It supports one contiguous numbered section and never infers name components. See [format validation](../docs/format-validation.md).

Assets are immutable and read back publicly before a transactional availability switch. Changing article provenance stays outside the immutable names file. Observed document validation failure revokes current checking; network failures retain last-good data with stale health. Successful checks refresh only the selection actually fetched. Android also expires freshness after 90 minutes.

The worker is published and GitHub OIDC identity is configured without a long-lived key. Actual cloud runs fail because HTTPS connections to PRC are refused from the hosted runner; `PRC_MONITOR_ENABLED=false`. Workstation access works. Restore source connectivity and verify a manual run before enabling the schedule. Real extraction profiles, Storage transfer, quota preflight, retention, alerts and history backfill remain unverified or unimplemented. See [deployment evidence](../docs/worker-deployment-review.md).
