# Android Studio runbook

Open `app/` as the Flutter project in Android Studio. Install the Flutter/Dart plugins if missing, select an Android emulator or USB-debugging phone, and use Run/Debug. The app requires Android API 24 or newer. CLI equivalent: from `app`, `flutter run -d <android-device-id>`.

On this workstation the shared SDK contains broken junctions to an absent older project. Verification uses an ignored project-private SDK at `E:/USER/Downloads/ResView/.development/android-sdk` and the newly created `prc_ui` Android 15 emulator. `app/android/local.properties` points there. Use these process-local PowerShell settings on this machine before CLI builds/tests; they avoid the nearly-full C: drive:

```powershell
$env:ANDROID_HOME = 'E:\USER\Downloads\ResView\.development\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:TEMP = 'E:\USER\Downloads\ResView\.development\temp'
$env:TMP = $env:TEMP
$env:GRADLE_USER_HOME = 'E:\USER\Downloads\ResView\.development\gradle'
$env:JAVA_TOOL_OPTIONS = '-Djava.io.tmpdir=E:/USER/Downloads/ResView/.development/temp'
```

Configure equivalent environment variables in Android Studio's run configuration as needed. SDK/cache directories are not committed. Other machines should use their own valid SDK and local paths. Kotlin incremental compilation is disabled because plugin source paths on C: and app output paths on E: caused cache failures; keep the workaround until source/cache roots are compatible. Current Firebase plugins also emit Flutter's future Built-in Kotlin migration warning; the current debug build succeeds, but an SDK/plugin upgrade must recheck compatibility.

## Runtime configuration

Normal `flutter run` and `flutter build apk` commands enable Updates and use the live public Firestore project `resview-9240c`. Browsing the exam catalog, Results and Updates requires internet access and no extra run arguments or private Firebase credentials. Override the project with `--dart-define=FIRESTORE_PUBLIC_PROJECT_ID=<project-id>` or disable Updates with `--dart-define=RESVIEW_EXAM_UPDATES=false`. An explicitly empty public project disables the public fallback. Push registration still requires the Firebase SDK configuration below.

Unavailable services show an unavailable state without substituting sample content. For Firebase SDK features, supply reviewed non-secret Firebase client identifiers through Android Studio's Additional run args using `--dart-define` for `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, and `FIREBASE_SENDER_ID`. Never put worker/admin or Brevo service credentials in the mobile app. Before configuring additional real services, verify Spark/no billing, deploy tested owner-only preference rules and worker-only public writes, and establish the permitted PRC source route.

Optional reviewed HTTPS public links use `BREVO_SIGNUP_URL`, `PRIVACY_POLICY_URL`, and `MAINTAINER_CONTACT_URL`. Empty links are not rendered as working controls. Email signup is independent of anonymous installation identity. Opening its form does not establish confirmation. FCM auto-init and analytics collection are disabled by default; notification registration requires contextual consent.

On this workstation, the registered Android SDK configuration for `resview-9240c` was fetched and its project, app ID and package were checked. The four public client values are saved in ignored `.development/firebase-client.json`. From `app/`, use `flutter run --dart-define-from-file=../.development/firebase-client.json -d <android-device-id>`. The local Android Studio `main.dart` run configuration now includes that same argument. This local file contains client configuration only, not worker credentials. Its existence does not establish successful device sign-in or FCM receipt.

On October 29, 2026, unauthenticated live reads returned 99 exam labels (including written/practical/SPLE variants), 87 sittings, five publications and five result versions. All stored sittings were from 2026. This is partial coverage, not the required complete coverage of all PRC exams and publications from 2026 onward. The Foresters result's last successful source check was October 15; an old monitor record saying `fresh` does not establish current freshness. The app also checks the source-check timestamp.

## Checks

From `app`: `flutter analyze`, `flutter test`, then `flutter test integration_test/app_test.dart -d <android-device-id> --no-uninstall`. Use `--no-uninstall` on a phone with an existing installation: Flutter otherwise uninstalls the app after integration tests and removes its local data. Test APKs replace the normal debug APK; restore the normal APK after testing. Isolated widget tests exercise publication conditions using fixtures kept under tests, not runtime assets. Integration tests run the normal unconfigured runtime when no live credentials are supplied, and do not satisfy live PRC/provider acceptance.

For the approved task 7 version only, run `flutter test integration_test/name_check_test.dart -d <android-device-id> --no-uninstall --dart-define-from-file=../.development/firebase-client.json --dart-define=TASK7_LIVE=true`. Without `TASK7_LIVE`, only isolated native matching/storage tests run. The live test pins the approved asset, downloads real names and saves a private screenshot/evidence JSON in the app support directory; pull those privately and remove them from the device after review. It restores the name/selection it read at test start and deletes its created offline list. It does not restore data lost to a previous uninstall. See the dated acceptance evidence for remaining privacy limits.

Run the normal app at system font scale 2.0, light/dark themes, portrait/landscape, with keyboard and TalkBack. Verify long accented name fields and scrollable deletion dialogs. Record actual evidence in android-studio-acceptance.md; missing tests or hardware must remain explicit gaps. Restore device settings after checks.

## Release signing

Copy `app/android/key.properties.example` to ignored `app/android/key.properties` and supply an external private keystore only when release signing is authorized and available. `flutter build apk --release` deliberately refuses a missing signing configuration; release must never use the debug key. No signing key was created by this implementation. Public distribution and outbound-message authorization remain separate gates.
