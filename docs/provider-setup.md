# Worker deployment and recovery

October 30 automatic-retrieval update: the approved PDF is now fetched and revalidated through the documented Drive API using the existing worker's read-only OAuth credentials. Hosted run 41018013099 passes. The Drive API is enabled with billing disabled/no account linked. Private profiles are supplied through encrypted `PRC_PRIVATE_PROFILES`; the public config stays empty. Existing immutable public names assets can be reused without giving CI a Storage writer credential. New assets still require the private publisher. Owner download restrictions remain enforced. See [live retrieval evidence](prc-update-verification.md#hosted-automatic-pdf-retrieval). Actual scheduled invocation remains pending.

Existing Firebase Standard/Spark `resview-9240c` still has billing disabled/no linked account. Supabase remains the existing Free project and public JSON-only `validated-names` bucket. No paid service, service-account key or outbound message was created.

The live metadata checks used existing authorized Firebase CLI sign-in, refreshed in memory and passed to the Firestore SDK. No token was printed or written into source. This is workstation verification, not unattended credentials.

## Deployment state on 2026-10-15

The reviewed worker/workflow is published on `j-davidv/ResView:main`. It tests PR/push changes and supports manual live execution. The October 30 task 8 update changes cron to `57 * * * *` to fit the current archive's free write budget; the earlier deployment used `7,37 * * * *`. Live jobs require `main`; cron also requires `PRC_MONITOR_ENABLED=true`. PRs receive no live credentials. Verified upstream action revisions are pinned. Permissions are repository read-only plus OIDC issuance for the live job.

Dedicated Google OIDC identity/custom role and GitHub identity variables are configured and read back. The role has exactly five required Firestore permissions, no delete or administration, and no user-managed key. Repository/owner numeric IDs, main, exact workflow and approved events constrain federation. See [deployment evidence](worker-deployment-review.md).

GitHub's tests and authentication pass. Source access is intermittent: on October 30 one attempt and its diagnostics timed out, then a rerun and the final runtime's manual scan succeeded. Independent public-client and all-selection verification passed. `PRC_MONITOR_ENABLED=true` was enabled at approximately 12:20 Asia/Taipei after those checks; an actual scheduled monitor run remains to be observed. Workstation archive imports also work. Name-list download routing/restrictions remain separate from metadata access. See [task 8 evidence](prc-update-verification.md).

Reproduction and activation:

1. Keep publication scoped to the reviewed worker/workflow/docs. The existing application remains local/untracked; do not blindly publish the checkout. Exclude `.development`, credentials, PDFs, real-name fixtures and private exports.
2. Provision a dedicated worker identity with necessary Firestore access, never Owner/Editor/Firebase Admin. Firestore IAM bypasses client rules and cannot limit this access to public collections; review private-data exposure. Do not grant FCM access while delivery is unimplemented. Configure GitHub OIDC trust for this repository/default branch/intended workflow only. Stop any path requiring billing.
3. Set repository variables `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_WORKER_SERVICE_ACCOUNT`. Missing variables fail before authentication. OIDC needs no Google JSON key.
4. Verify manual dispatch with `live=true` and public app reads, then set `PRC_MONITOR_ENABLED=true` and observe an actual scheduled run. Hourly polling is not instantaneous PRC push; GitHub can delay schedules. The current write estimate excludes retries, app use and archive growth, so recheck usage as coverage expands.
5. Leave `profiles` empty until [real format validation](format-validation.md). Then store `SUPABASE_SERVICE_ROLE_KEY` only as an encrypted worker secret, verify quota/capacity and actual immutable/public transfer. Never put that credential in Flutter or logs.

Worker IAM/WIF resources and three non-secret GitHub variables were provisioned under owner approval. No GitHub credential secret was created and local sign-in was not copied into Actions. Billing remains disabled/no linked account.

## October 30, 2026: validated Storage publication

Restored the existing paused Supabase project to `ACTIVE_HEALTHY` and rechecked its Free organization. The owner reported 0.026 / 0.5 GB database usage and zero other Usage categories, including Storage Size and cached/uncached egress. Current Free allowances are [1 GB Storage](https://supabase.com/docs/guides/platform/manage-your-usage/storage-size) and [5 GB uncached plus 5 GB cached egress](https://supabase.com/docs/guides/platform/manage-your-usage/egress). The 781-byte approved Ocular Pharmacologists list fits those limits. A final database audit confirms exactly one object totaling 781 bytes.

The worker credential is stored in ignored `.development/task6/storage-key.dpapi`, encrypted by Windows DPAPI for the current Windows account. The private verification runner decrypts it in memory and passes it directly to `Providers`; Flutter receives only public asset metadata. No GitHub secret was configured. A scan of relevant source/configuration/documentation/task artifacts found no plaintext credential; private source/profile/asset/credential files remain Git-ignored.

Fresh inspection confirms `validated-names` is public, JSON-only, capped at 20 MiB, with enabled RLS, no Storage client policies and no client RLS bypass. Security advisors return no findings. Eight live unauthenticated/anonymous upload, overwrite, upsert and delete probes leave the public bytes unchanged. Anonymous deletion returns HTTP 200 with `[]`, reflecting no visible rows. Identical worker retries preserve the immutable asset.

The private runner revalidated the unchanged original and current official announcement, uploaded the approved immutable JSON, and verified public bytes/size/SHA-256. Flutter's actual downloader and decoder passed before the worker's existing transaction activated `checkingAvailable` and superseded its previous unavailable version. A separate unauthenticated Firebase client subsequently fetched the current version and downloaded the exact asset. The JSON is 781 bytes with SHA-256 `1474754159a2071d22780645e0200ebb97fc4b96d8bab7467eca9e2a155f90d8`. No production worker or app code change was required.

Private scripts and evidence are in ignored `.development/task6/`; `verify.py --activate` requires the encrypted credential and reviewed capacity, and refuses activation on any validation, transfer or Flutter failure. Python execution uses the existing `.development/worker-python` packages on `PYTHONPATH`. At Task 6 completion this was one manually published, approved version using the previously acquired original, with scheduling and delivery disabled. The later automatic-retrieval update above verifies hosted download and enables hourly monitoring for this private reviewed profile; delivery remains disabled. See [Task 6 evidence](prc-core-checklist.md#6-connect-and-verify-real-supabase-publication); phone acceptance remains task 7.

## Recovery

Set `PRC_MONITOR_ENABLED=false` and stop live dispatch to pause writes; revoke worker access if compromised. Preserve official links and last-good metadata on outages. Per-selection timestamps expire in Android after 90 minutes; failed scans retain last-success time with stale health.

To disable a faulty checking format, set `disabled: true` on its current reviewed private profile and rerun that configuration. The worker marks the reviewed version `checkingUnavailable` without uploading names. Removing its profile alone deliberately preserves a previously validated unchanged list. Preserve provenance/history. Local revocation, outage, upload-refusal and rerun checks are recorded in [task 8 evidence](prc-update-verification.md). Actual credential rotation, quota-exhaustion recovery, retention, notifications/email and signed physical-device acceptance remain unverified.
