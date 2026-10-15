# Worker deployment and recovery

Existing Firebase Standard/Spark `resview-9240c` still has billing disabled/no linked account. Supabase remains the existing Free project and public JSON-only `validated-names` bucket. No paid service, service-account key or outbound message was created.

The live metadata checks used existing authorized Firebase CLI sign-in, refreshed in memory and passed to the Firestore SDK. No token was printed or written into source. This is workstation verification, not unattended credentials.

## Deployment pending

`.github/workflows/monitor.yml` is local only. It tests PR/push changes and prepares manual live execution plus cron `7,37 * * * *`. Live jobs require `main`; cron also requires `PRC_MONITOR_ENABLED=true`. PRs receive no live credentials. Verified upstream action revisions are pinned. Permissions are repository read-only plus OIDC issuance for the live job.

Before enabling:

1. Review/publish the worker/workflow to existing `j-davidv/ResView`. This repository is still unborn with the existing application untracked; do not blindly publish the checkout. Exclude `.development`, credentials, PDFs, real-name fixtures and private exports.
2. Provision a dedicated worker identity with necessary Firestore access, never Owner/Editor/Firebase Admin. Firestore IAM bypasses client rules and cannot limit this access to public collections; review private-data exposure. Do not grant FCM access while delivery is unimplemented. Configure GitHub OIDC trust for this repository/default branch/intended workflow only. Stop any path requiring billing.
3. Set repository variables `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_WORKER_SERVICE_ACCOUNT`. Missing variables fail before authentication. OIDC needs no Google JSON key.
4. Verify manual dispatch with `live=true` and public app reads, then set `PRC_MONITOR_ENABLED=true` and observe an actual scheduled run. Twice-hourly polling is not instantaneous PRC push; GitHub can delay schedules.
5. Leave `profiles` empty until [real format validation](format-validation.md). Then store `SUPABASE_SERVICE_ROLE_KEY` only as an encrypted worker secret, verify quota/capacity and actual immutable/public transfer. Never put that credential in Flutter or logs.

No worker IAM/WIF resource, GitHub secret or variable was provisioned. The workflow was not pushed or executed remotely. Local sign-in was not copied into Actions.

## Recovery

Set `PRC_MONITOR_ENABLED=false` and stop live dispatch to pause writes; revoke worker access if compromised. Preserve official links and last-good metadata on outages. Per-selection timestamps expire in Android after 90 minutes; failed scans retain last-success time with stale health.

To disable a faulty checking format, also mark its current public version `checkingUnavailable`. Removing its profile alone deliberately preserves a previously validated unchanged list. Preserve provenance/history. Never restore deleted private preferences or replay alerts during metadata recovery. Actual credential rotation, rollback drills, quota handling, retention, notifications/email and signed physical-device acceptance remain unverified.
