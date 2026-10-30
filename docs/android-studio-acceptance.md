# Android verification evidence

Recorded 15 October 2026, Asia/Taipei. This is evidence for the approved local interface, not live PRC/service or public-release acceptance.

## Observed checks

| Check | Result and scope |
|---|---|
| Flutter analyzer | No issues found after the focused fixes |
| Local unit/widget/golden suite | 24 tests passed; all five publication states, independent freshness, exact/candidate policy, invalid lists, optional name retention, deletion intent, scoped offline deletion, saved-file budget, 200% portrait/landscape and light/dark layouts |
| Android debug build | Passed with Flutter 3.47.5 / Dart 3.13.4 and the project-private SDK |
| Android integration | Four tests passed on `emulator-5556`, Android 15/API 35, 720×1280 phone, system `font_scale=2.0` |
| Large list / cancellation | Isolated 38,000-entry fixture with JSON entry bytes between 18 and 20 MiB; root-isolate timer continued during matching; cancellation terminated matching. Synthetic fixture stayed inside integration tests, not runtime data |
| Native normalization | Decomposed Ñ matched NFC Ñ; N stayed distinct; published mixed-case spelling survived result handling |
| Publication states | All five states rendered independently of stale freshness in an isolated native integration test; no synthetic state was imported to normal runtime/live databases |
| Long name / accessibility labels | Normal unconfigured app accepted long accented test input and passed Android touch-target/label guidelines; tests did not save names or send them externally |
| Native keyboard | TalkBack-enabled surname/given-name focus opened the real Android keyboard, and the focused field scrolled above the IME at 200% text |
| TalkBack | Android Accessibility Suite service was enabled and confirmed bound via `dumpsys accessibility`; native focus and exported destination labels/selected states inspected. Spoken-output quality has not been human-verified |
| Release signing safeguard | Release build failed for the expected missing private signing configuration; debug signing is forbidden for release |
| Compiled backup flag | Native `dumpsys package` flags exclude ALLOW_BACKUP; backup and device-transfer exclusions are declared. Real backup/restore operation remains unverified |

## Render evidence

`app/test/goldens/` contains Flutter widget renders using SDK Roboto/Material Icons. These are regression references, not Android screenshots. Native captures and accessibility trees are in ignored `.impeccable/review/`; inspect each capture's orientation/theme before using it as evidence. Native normal-runtime screenshots contain no fabricated PRC publications or result lists.

Impeccable critique found truncated optional-field labels and navigation-label scaling drift; labels were shortened with separate Optional helper text and Material navigation scaling was corrected. Fresh review additionally identified main-thread large-list work, missing readable offline context, and wrong Retry behavior; all received focused source fixes and regression/integration checks. See ui-audit.md and implementation-progress.md.

## Remaining gates

- No physical Android phone is connected. Real-device TalkBack speech, touch/back gestures, low-memory behavior, high-refresh performance and backup/network inspection remain unverified. Debug software-rendered emulator logs include skipped frames; the timer test is not a physical-device performance guarantee.
- Android Studio and its bundled JDK/toolchain are installed; the project builds/runs through Flutter CLI. The IDE's Run/Debug workflow and plugin configuration were not manually exercised.
- No PRC retrieval/reuse authorization has been exercised. No current permitted result document, complete official catalog import, Python worker extraction/publication, or live format coverage is verified.
- Firebase/Brevo/Supabase credentials and live accounts were not configured. Owner-rule isolation, actual opt-in/unsubscribe, quota handling and real push/email receipt remain live-service acceptance gates.
- No real outbound messages, public deployment, signing key, signed release verification or public APK distribution occurred.

Use docs/implementation-progress.md rather than interpreting passing local checks as whole-plan completion.

## October 29, 2026: live Firebase physical-phone check

Task 1 was verified on a USB-authorized Infinix X6710 running Android 14. This dated evidence supersedes the earlier statements that no physical phone was connected and Firebase client configuration was unavailable; it does not close the other acceptance gates above.

- Built with `flutter build apk --debug --dart-define-from-file=../.development/firebase-client.json` using the project-private Android SDK. Build exited successfully; existing Kotlin migration and SDK XML warnings remain. Installed and launched `org.resview.app` on the phone. The local Android Studio `main.dart` run configuration now supplies the same Firebase argument; IDE Run/Debug itself was not exercised.
- Read the live Firestore collections without authentication or writes: 99 exam labels, 87 sittings, five publications and five result versions. All stored sittings were from 2026. Labels include written/practical/SPLE variants, not 99 distinct boards.
- On the phone, opened the live exam picker, searched for Professional Foresters, selected the domestic October 8–9, 2026 sitting, explicitly opened the category picker and selected All successful examinees, then opened Updates. No signup or notification opt-in was performed.
- Updates displayed the October 2026 Foresters result announcement. The official-source button opened the matching `prc.gov.ph/article/october-2026-professional-foresters-licensure-examination-results-released-two-2-working` page in the phone browser; the page title and article body loaded.
- The app correctly displayed Source information may be outdated and the October 15, 2026, 14:39 UTC+08:00 source-check timestamp. Results displayed Checking unavailable and the unvalidated-format explanation. The stored monitor value alone still says `fresh`; the app's timestamp check prevents presenting this old result as fresh.
- Private evidence is under ignored `.development/task1-phone-*.xml` and `.development/task1-phone-updates.png`. The screenshot was visually inspected. No personal names were entered, no alerts were enabled, and no backend content was changed.

The required scope is all PRC exams and publications from 2026 onward. This successful browsing smoke check does not prove complete coverage: source ingestion, missing mappings, historical 2026 backfill and validated lists remain tasks 2–9. Full physical-device accessibility, privacy/network, offline, performance and release acceptance were not repeated for task 1.

## October 30, 2026: live name checking on Android

Task 7 has a demonstrated working path for the approved September 28 Ocular Pharmacologists list on the Infinix X6710, Android 14. Its combined privacy requirement remains incomplete. These observations supersede the earlier lack of live document, provider and physical-phone checking evidence for this one version.

| Check | Observed result |
|---|---|
| Actual source and asset | Unauthenticated Firestore repository read returned `checkingAvailable`; the real public Supabase download passed its pinned 781-byte size, JSON SHA-256 `1474754159a2071d22780645e0200ebb97fc4b96d8bab7467eca9e2a155f90d8` and original document version `cada461c37f74824fdf77a0c32cb3af1ca07b9b43b121589bd73959e838dfa15`. |
| Phone UI | Entered the real published name using the test harness, obtained an exact match, then obtained the cautious absent-name outcome for a synthetic absent surname. Both outcomes retained the identity/failure warning. A private screenshot was visually inspected. No examinee name is reproduced here. |
| Provenance | UI assertions verified both `SourceButton` destinations against live metadata, entry 1, section `all`, physical PDF page 1 and the full approved document version. Physical page 1 corresponds to the original's printed `Page: 2 of 2`. |
| Matching coverage | Native normalization/matching passed composed/decomposed Ñ, Ñ versus N, exact suffix requirements and candidates requiring the full surname and given names. Accent/suffix/candidate coverage uses isolated synthetic data. The real document has unreviewed components and correctly hides possible matching. |
| Failed transfers | An isolated on-device loopback server exercised truncated transfer and cancellation after receiving bytes. Pre-cancelled operations and oversized metadata also refused checking. Temporary files were absent after refusal. |
| Storage | Injected zero free space refused before a request. Actual on-device saved files totaling exactly 50 MiB were accepted; one extra byte was refused without eviction. Cleanup preserved saved files and removed abandoned partial/temporary files. The 20 MiB download and 50 MiB saved-file constants are unchanged. |
| Offline | A fresh `ListStore` reopened and integrity-checked the real saved list with Firestore networking disabled and zero recorded download requests. Native exact and absent checks worked. Test-created saved lists were deleted afterwards. |
| Privacy evidence | Unsaved real/synthetic inputs were absent from secure storage. Full published-name and personal-outcome searches found no hits in captured Android or test logs. The recorded public-download URL contained only exam/sitting/category and immutable hashes. Source review found no name/outcome logging or network path. |
| Backup configuration | Original/restored APK manifest has `allowBackup=false`; installed package flags omit `ALLOW_BACKUP`. Cloud backup and device transfer exclude root, files, databases, preferences and external app storage. Backup Manager is disabled; actual backup/restore was not tested. |
| Fresh checks | Three Android tests passed in `integration_test/name_check_test.dart`, gated by `TASK7_LIVE=true` for the live case. All 28 local Flutter tests passed and the analyzer reported no issues. No production code or provider configuration change was needed. |

Phone-generated evidence timestamp: `2026-10-30T03:06:12.034467Z` (11:06:12 Asia/Taipei). Ignored `.development/task7/` holds the screenshot, metadata, Android/test logs, compiled manifest, storage inventory and assertion-based audit. The audit verifies private Git exclusion and no real examinee names in application/test sources or documentation. Evidence screenshots and logs remain private.

The first successful integration run used Flutter's default post-test uninstall, which removed the installed app and local app state. The normal APK had been captured beforehand and was reinstalled; the repeat used `--no-uninstall` so evidence could be retrieved. The captured normal APK was then restored again. Its ordinary picker selected Ocular Pharmacologists, September 28, All successful examinees and loaded the live announcement. No test name, list or screenshot was left in app storage. Prior local preferences were reset, not recovered.

Remaining task 7 limit: full native TLS payload capture and backup/restore verification are outstanding, so the privacy checkbox remains open. Injected low-space and seeded orphan cleanup checks do not prove behavior during actual disk exhaustion or Android process termination. Broader accessibility, backup/transfer behavior, correction handling and release acceptance remain separate gates. No scheduling, alert delivery, signing or public distribution was enabled.
