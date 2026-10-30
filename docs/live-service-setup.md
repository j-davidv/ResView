# Live service setup without billing

Deployment follow-up (2026-10-15): worker source is now published on existing GitHub main; restricted keyless CI identity and non-secret variables are configured. Cloud tests/authentication pass, but PRC HTTPS connections from the runner are refused. Scheduling remains off until a cloud scan succeeds. Billing stays disabled/no linked account. No provider secret/key or outbound message created. See worker-deployment-review.md; these facts supersede older local-only/unprovisioned statements.

Latest update (2026-10-15): public PRC metadata retrieval/import was exercised with existing authorized Firebase credentials. Live records: 99 schedule labels, 87 dated sittings, five current result publications. Populated public queries/private denials pass; billing remains disabled/no linked account. Current Foresters-list download is owner-disabled; no checking profile/asset is enabled. The worker and gated workflow are local; unattended identity/deployment remain pending. These facts supersede older “worker not implemented/no PRC request” entries below. See [source evidence](source-access.md) and [deployment](provider-setup.md).

Checked 2026-10-15. Owner expects 20 initial users. Firebase project `resview-9240c` is accessible, billing is disabled with no billing account linked (Spark), and its existing services were inspected below. Supabase and Brevo setup remains pending. This is a setup runbook, not evidence of end-to-end delivery.

Firebase inspection (2026-10-15): after owner sign-in, verified authentication and project access through the Firebase plugin's MCP server, launched through its declared CLI command with the repaired cache under ignored `.development/npm-cache`. Used MCP to inspect the Android registration, database and deployed rules. Used the same CLI's authenticated API client for read-only billing and auth-provider checks, and its API-status helper for FCM because those inspection tools are not exposed by MCP. Billing reports `billingEnabled: false` and no linked account. Anonymous sign-in is enabled; email/password and phone sign-in are disabled. FCM HTTP v1 (`fcm.googleapis.com`) is enabled. No remote settings were changed, no messages were sent and no test users were created. Local `.firebaserc` selects the existing project.

Existing Android registration: `org.resview.app`, display name `ResView`, app ID `1:243431288961:android:ef9b932952bacfb4cc1d80`, sender/project number `243431288961`. Existing default Firestore database: Standard edition, native mode, `asia-southeast1` (Singapore), `freeTier: true`, point-in-time recovery disabled. Its deployed rules deny every client read/write. Preserve these rules until application ownership and validation rules pass emulator tests. Native SDK configuration, actual anonymous client sign-in, query/index acceptance and device FCM receipt remain pending; API enablement alone does not prove delivery.

MCP composite-index listing returned no indexes. The app's required query indexes still need preparation and deployment with tested application rules.

Read-only recheck (2026-10-15, approximately 11:41 Asia/Taipei): authenticated inspection again confirmed billing disabled/no linked account, anonymous auth enabled, FCM HTTP v1 enabled, active Android registration `org.resview.app`, and the Standard free-tier default database in `asia-southeast1`. Deployed Firestore rules still deny every client read/write; the composite-index listing is still empty. Local `.firebaserc` selects the correct project, but there is no `firebase.json` or checked-in application rules/index configuration. No remote changes, test sign-ins or notification sends were performed. Account provisioning passes; application integration remains incomplete.

Rules/index deployment (2026-10-15, approximately 11:49-11:54 Asia/Taipei): the earlier deny-all policy was replaced under owner authorization with emulator-tested application rules. All six tests pass; deployed rules exactly match `firebase/firestore.rules`. The `sittings`, `publications` and `resultVersions` composite indexes are all `READY`. A live unauthenticated Firebase client passed the app's four query shapes and `monitor/status` read, while reads of private preferences, worker state and other monitor documents were denied. The pre-deployment collection listing was empty; no live fixtures, writes, sign-ins or messages were created by verification. Billing was rechecked after deployment and remains disabled with no linked account. This record supersedes the earlier deny-all/no-index status above.

The Android client configuration was fetched through the CLI and checked against the registered project/app/package. Its four public values are available in ignored `.development/firebase-client.json`; see [Android Studio run instructions](android-studio-runbook.md). Actual device sign-in, push receipt, worker IAM and populated-source acceptance are still pending. Reproduction and emergency lock-down instructions are in [firebase/README.md](../firebase/README.md).

## Current status

| Item | Observed status |
|---|---|
| GitHub | `https://github.com/j-davidv/ResView` exists, public, owner has admin permission; remote reports size 0 |
| Firebase | `resview-9240c`: Spark/no linked billing account verified; Android app registered; Standard default Firestore in Singapore; tested application rules deployed, three indexes READY, live public/private read checks passed; anonymous provider and FCM HTTP v1 enabled; device sign-in/delivery pending |
| Supabase | Authenticated inspection passed: Free organization, ACTIVE_HEALTHY project, public `validated-names`, JSON-only, 20 MiB limit, Storage RLS enabled/no client policies; actual file transfer remains untested |
| Brevo | Account, sender approval and hosted form pending |
| Python worker / Actions | Not implemented; no ingestion or delivery workflow enabled |
| Capacity | Provisional estimate for 20 users below; real usage and busiest-day alert count unverified |

## 1. Firebase

1. Open the existing project [`resview-9240c`](https://console.firebase.google.com/project/resview-9240c/overview). Do not create a duplicate project. Keep Google Analytics disabled for this setup.
2. Keep the project on **Spark**. Do not link a Cloud Billing account or accept a Blaze upgrade. Stop any setup flow that requires billing. Do not enable Cloud Storage, Cloud Functions, Cloud Run or paid extensions.
3. Add an Android app with package name **`org.resview.app`**, matching `app/android/app/build.gradle.kts`.
4. Create the default Cloud Firestore database using Standard edition and production mode, choosing a suitable nearby region. Record the region before creation because changing it requires migration. Keep default deny rules while preparing tested application rules; do not select test mode or open the database to all writes.
5. In Authentication, enable the **Anonymous** sign-in provider. No email/password or phone provider is needed.
6. In Project settings > Cloud Messaging, check the Firebase Cloud Messaging API (HTTP v1) status. FCM is a no-cost product. Do not create a legacy server key.
7. Before connecting the app, implement and emulator-test Firestore rules: public read-only `exams`, `sittings`, `publications`, `resultVersions` and `monitor/status`; owner-only access to `pushPreferences/{uid}`; validate its exact fields/types and selection; deny every other client path. Test two anonymous users, forbidden cross-user reads/writes, extra fields, and forbidden public writes. Trusted worker writes use IAM, which bypasses client rules.
8. Create required query indexes from `app/lib/data/firestore_repository.dart`: sittings filtered by `examId` and ordered by `start`; publications filtered by all three selection fields and ordered by `publishedAtUtc`; result versions filtered by all three selection fields and `current`. Deploy only verified rules/indexes.

The app currently accepts these public client values through Android Studio Additional run args / `--dart-define`: `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`. They are client identifiers, not worker credentials. Restrict the client API key appropriately and verify anonymous sign-in after restrictions. Never supply a service-account JSON to Flutter. Native FCM configuration and actual receipt still require a device check; client identifiers alone do not prove FCM works.

Official references: [Spark and billing](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans), [Firestore quotas](https://firebase.google.com/docs/firestore/quotas), [FCM worker authentication](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

## 2. Supabase

Authenticated read-only verification (2026-10-15) through the connected Supabase plugin: project `erlnuyltaudetjpriosu` is named `ResView`, region `ap-south-1`, status `ACTIVE_HEALTHY`. Its organization reports `plan: free`, `tier: tier_free`. The `validated-names` bucket exists with `public: true`, `file_size_limit: 20971520` (20 MiB), and `allowed_mime_types: [application/json]`. RLS is enabled on `storage.buckets` and `storage.objects`; there are no Storage RLS policies. Neither `anon` nor `authenticated` has superuser/RLS-bypass privileges, so normal client writes are denied by default. Public asset URLs bypass read policies by design. Security advisors returned no findings. The bucket contains zero objects.

Project URL: `https://erlnuyltaudetjpriosu.supabase.co`. No files, schema, policies, credentials or billing settings were changed. Free subscription was verified; payment-method presence is not exposed by these inspection tools. Actual public download, unauthorized mutation and worker upload behavior remain untested because this inspection deliberately performed no writes and no validated public asset exists yet. JSON MIME restrictions do not validate file contents; the future worker must enforce the names-file schema, validation and source-permission gates before upload.

1. Sign in at https://supabase.com/dashboard/project/erlnuyltaudetjpriosu and verify this existing project belongs to a **Free** organization. Use the provider subdomain. Save the database password in a password manager. Do not add a payment method, custom domain or paid add-on.
2. Create a public Storage bucket named `validated-names`. Allow JSON (`application/json`) only and cap uploads at 20 MiB to match the app's individual-file limit.
3. Public download is intentional for permitted, validated published lists. Keep anonymous/client insert, update and delete forbidden. Do not create broad write policies. The app downloads public HTTPS URLs and needs no Supabase administrative credential.
4. Upload only after source reuse permission, extraction and validation gates pass. Do not upload raw documents, private entered names, local outcomes, email contacts or push tokens. Use immutable versioned filenames and publish metadata only after verifying the uploaded bytes and SHA-256.
5. Keep the worker's secret/service-role credential outside the app. It can bypass RLS; treat it as administrative, not as a public client key. Record the project URL and bucket name separately as non-secret configuration.
6. Check project availability before an expected result release. If paused, restore it from the dashboard and verify file retrieval before claiming availability. Free projects can pause after low activity over seven days; no always-on guarantee is included.

Official references: [bucket access](https://supabase.com/docs/guides/storage/buckets/fundamentals), [storage quota](https://supabase.com/docs/guides/storage/pricing), [egress quota](https://supabase.com/docs/guides/platform/manage-your-usage/egress), [pausing](https://supabase.com/docs/guides/platform/free-project-pausing).

## 3. Brevo

1. Create an account at https://www.brevo.com/ using **Free**. Complete truthful account verification. Do not choose a paid trial, credits, SMS or automatic upgrade.
2. Under Settings > Senders, Domains, IPs > Senders, add the intended sender name and an email address you control. Complete inbox verification. If an existing owned domain is available, authenticate it as Brevo directs. Do not purchase a domain under the zero-spending requirement. A free mailbox cannot authenticate its domain; verify Brevo accepts the proposed sender and actual delivery before declaring this channel approved. Sender verification and account sending approval are separate checks.
3. Create a dedicated ResView list and a hosted subscription form. Collect email, explicit consent and exam preferences using stable identifiers that the future worker can map to app selections. Do not ask for the user's exam-result name.
4. Select **Double confirmation** and a confirmation template. Unconfirmed contacts must not be eligible for alerts. Use Brevo-hosted confirmation pages and retain the Brevo-hosted form URL.
5. Include Brevo's supported unsubscribe link in alert templates and verify that an unsubscribed contact is excluded from subsequent sends. Never import the initial users without opt-in.
6. After an owner designates a consenting test recipient, test submission, confirmation, preference selection and unsubscribe. Record redacted evidence only. Account creation alone does not authorize a broadcast.
7. Supply the reviewed public form URL as `BREVO_SIGNUP_URL`. The app also accepts `PRIVACY_POLICY_URL` and `MAINTAINER_CONTACT_URL`; provide real HTTPS pages before public launch. Store the Brevo API key only in private worker secrets.

Official references: [Free plan and shared daily sends](https://help.brevo.com/hc/en-us/articles/208589409-About-Brevo-s-pricing-plans), [sender verification](https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email), [hosted forms and double confirmation](https://help.brevo.com/hc/en-us/articles/208771869-Create-a-sign-up-form-in-Brevo).

## 4. GitHub Actions and credentials

The public repository already exists. Local files remain untracked; review the exact publication file set for secrets and personal information before the first push. Do not publish IDE caches, downloaded documents, subscriber exports, local credentials or runtime files.

1. In repository Settings > Actions > General, enable Actions as needed and keep workflow token permissions read-only. Use a standard `ubuntu-latest` runner; public-repository standard runners are free. Do not choose larger runners or paid add-ons.
2. Create a dedicated worker service account with only the necessary Firestore data access and FCM sending permission. Do not grant Owner, Editor or Firebase Admin. Firestore IAM access is broader than collection rules; isolate the project and review account access accordingly. Prefer GitHub OIDC / Google Workload Identity Federation to avoid a long-lived JSON key. If that cannot be provisioned without a billing requirement, stop that path; do not enable billing. A dedicated, narrowly privileged service-account JSON may instead be held as an encrypted GitHub Actions secret and rotated.
3. Store worker credentials under Settings > Secrets and variables > Actions: Supabase administrative credential, Brevo API key, and any service-account JSON fallback. Project IDs, bucket name, sender ID and federation identifiers are non-secret variables. These are provisioning categories; final environment variable names must match the worker when implemented.
4. Local credential files belong outside this workspace, such as a password-manager-controlled private folder. Existing `.gitignore` entries are a secondary safeguard, not permission to place secrets in source. Do not paste secrets into chat, CLI arguments, logs or app build defines. Never upload subscriber lists or device tokens as Actions artifacts.
5. Implement and test the actual Python worker before adding its workflow. The existing plan specifies manual dispatch, concurrency preventing overlap, read-only repository permissions and eventual cron `7,37 * * * *` (48 runs/day). Keep scheduled live ingestion off until source/provider checks pass. Default delivery stays disabled; test delivery needs designated recipients and public delivery needs its separate launch gate. Do not run a fake successful worker.
6. Keep provider credentials out of pull-request jobs, untrusted checked-out code and `pull_request_target` execution. Use reviewed action revisions and short redacted-log retention. Restrict secret-bearing workflow edits to trusted maintainers.
7. Verify manual execution before enabling cron, then observe an actual scheduled run. GitHub schedules can be delayed and public-repository schedules can disable after 60 days without repository activity.

Official references: [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [schedule behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).

## 5. Capacity estimate for 20 users

These are estimates, not measured acceptance. User count alone does not determine request volume. Assume all 20 subscribe to email and each receives one alert on a busy day; revise when actual alert frequency is known.

| Resource | Current free allowance | Illustrative load and remaining check |
|---|---|---|
| Brevo | 300 emails/day across the account | 20 alerts + 20 confirmation requests = 40 sends; an optional final confirmation email would make 60. Other sends and retries share the allowance. Budget using actual account usage. |
| Firestore | 50,000 reads/day; 20,000 writes/day; 20,000 deletes/day; 1 GiB stored | At an assumed 500 document reads/user/day, 20 users use 10,000 reads before worker/rules overhead. Measure actual document counts; queries are not billed as one read regardless of result count. |
| Supabase storage | 1 GB | Twenty distinct 20 MB files occupy about 400 MB. Files are shared between users; user count does not multiply stored bytes. Keep retained versions bounded. |
| Supabase transfer | Separate 5 GB uncached and 5 GB cached monthly allowances | 20 users downloading one 20 MB list = 400 MB. Ten such downloads/user/month = 4 GB before retries and other transfer. Budget against uncached allowance without assuming cache hits. |
| GitHub Actions | Standard hosted runners free for public repositories | Proposed 48 runs/day = about 1,440 runs per 30 days. Runtime, concurrency and source access constraints still apply. |

Twenty users appear suitable for a controlled pilot under these assumptions. This is not a guarantee of unlimited alerts or file downloads. Reserve capacity for onboarding, retries and maintainer checks; pause/queue work at limits without enabling billing. The worker must implement quota handling, suppression and the existing plan's 48-hour email expiry before delivery is enabled.

## Acceptance evidence still required

- Firebase billing-disabled/no linked account and Supabase Free subscription verified via authenticated inspection; Brevo Free-plan check remains pending. Supabase payment-method presence was not inspected.
- Firestore ownership/validation emulator tests passed; rules deployed and read back; three indexes READY; live public query/private denial checks passed. Actual Android owner registration/deletion remains pending.
- Worker IAM/secret handling reviewed; public repo file set inspected before publication.
- Supabase unauthenticated download succeeds while unauthorized mutation fails.
- Approved Brevo sender, hosted double opt-in and unsubscribe verified with a designated consenting recipient.
- Actual manual and scheduled worker runs, FCM device receipt and measured pilot usage recorded.

Keep the release-readiness gates unchecked until this evidence exists.
