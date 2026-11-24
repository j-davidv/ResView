# Firestore configuration

The root `firebase.json` deploys these rules and indexes to the project selected in `.firebaserc`. Always specify `--project resview-9240c` for deployment; use the demo project below for tests. No test fixture is written to the live project.

Install test dependencies and run from the repository root (Node 20+ and Java 21+):

```powershell
npm --prefix firebase ci
npx -y firebase-tools@latest emulators:exec --only firestore --project demo-resview-rules "npm --prefix firebase test"
```

The tests require an emulator and use simulated identities only. They cover public reads, the app's four query shapes, forbidden client public/worker writes, owner registration/restoration/token rotation/deletion, cross-user isolation, and rejection of invalid create/update fields and timestamps. Emulator query success verifies rules compatibility; production composite-index readiness is checked separately after deployment.

Verification on 2026-10-15: the prior deny-all policy produced five expected failing tests and one passing denial test. With the application rules, all six tests passed. Deployed rules were read back and exactly matched the tested file. A read-only pre-deployment collection listing was empty. Billing remained disabled with no linked account after deployment. No live fixtures, test identities or messages were created.

All three deployed composite indexes subsequently reached `READY`. A live unauthenticated client passed the same four app query shapes and `monitor/status` read, and was denied private preference/worker/other-monitor reads. Empty collections are not evidence of populated-source correctness. Device sign-in, device FCM receipt and trusted-worker IAM remain unverified.

On 2026-11-24 the live rules were read back and found to reject the new app's optional `registrationId` field. After seven emulator rule tests passed, rules-only deployment to `resview-9240c` accepted that bounded field while retaining owner-only access. Read-back matched the local rule source exactly. Anonymous sign-in and the FCM API were also confirmed enabled. This fixes a server-side registration incompatibility; device registration and notification receipt require separate confirmation and do not imply that the scheduled sender has been deployed.

Deploy only after the emulator suite passes:

```powershell
npx -y firebase-tools@latest deploy --only firestore:rules,firestore:indexes --project resview-9240c --non-interactive
```

Public metadata is readable without login by design. Only the trusted worker's IAM credentials can write it. Never place private data in public documents. Clients can get/delete only their own `pushPreferences/{uid}` document; create/update requires `enabled`, `selection`, `token` and `lastActiveAtUtc`, with an optional bounded string `registrationId` identifying a new consent session. Disable deletes the preference. Activity timestamps must be server timestamps. No private collection listing or descendant access is allowed. Private alert delivery state and receipts remain denied to clients.

Selection identifiers are bounded and reject whitespace/slashes. These rules do not verify canonical catalog membership or that a token belongs to a device; trusted delivery processing must validate targets against published selections and provider responses. No real catalog has been imported yet. Admin SDK/IAM bypasses these client rules and requires a separate least-privilege review.

Prototype rules still require review before broad distribution. The rules cannot prevent public-read traffic from exhausting Spark quotas. Billing must remain disabled.

To lock clients out during an incident, replace the contents of `firestore.rules` with the prior deny-all policy below and deploy **rules only**. This blocks public metadata reads and preference deletion too; paused clients may retain pending deletions. It does not revoke worker IAM credentials or stop a worker. Disable worker execution/revoke compromised credentials separately. Re-run tests before restoring the application rules.

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

```powershell
npx -y firebase-tools@latest deploy --only firestore:rules --project resview-9240c --non-interactive
```

On this workstation, the CLI/npm and emulator caches live under ignored `.development/` on E:. Set `npm_config_cache` to `.development/npm-cache`, `FIREBASE_EMULATORS_PATH` to `.development/firebase-emulators`, and use Android Studio's JBR as `JAVA_HOME` with its `bin` on `PATH` if the shared Java is older than 21. Keep npm cache, emulator binaries and debug logs out of commits. No credentials belong in this directory.
