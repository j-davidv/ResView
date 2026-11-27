# PRC Exam Updates Android app

Open this folder as a Flutter project in Android Studio. Use a valid Android SDK and an emulator or connected phone. See ../docs/android-studio-runbook.md for configuration and workstation-specific setup.

From this folder run flutter analyze, flutter test, and flutter run -d <android-device-id>. Native checks: flutter test integration_test/app_test.dart -d <android-device-id>.

Normal runs and builds enable Updates and use the live public Firestore catalog in `resview-9240c`. No extra `--dart-define` arguments or private Firebase credentials are required for browsing. Override `FIRESTORE_PUBLIC_PROJECT_ID` to use another public project, or set `RESVIEW_EXAM_UPDATES=false` to disable Updates. Push registration requires separate configuration.

## Exam alerts

The Alerts bell opens saved alerts for the selected exam, sitting, and category. New result publications, official exam-wide updates (including schedule notices), and changes to the selected official schedule create unread alerts. Refresh, returning to the app, and foreground FCM messages update the inbox. The first successful read establishes a baseline without notifying about existing history. Reaching an expected release date never creates a result alert. A retired sitting is not treated as a confirmed cancellation; choose its replacement in Settings when needed.

Phone alerts require the Firebase Android app registered as `org.resview.app` in the same project as the public metadata:

1. Download its **Android client** `google-services.json` from Firebase Project settings → General, and save it as `app/android/app/google-services.json` (ignored by Git). The Google Services plugin is applied when this file exists. No service-account private key belongs in the app.
2. Enable Anonymous sign-in and the FCM HTTP v1 API in that project. Deploy the repository's owner-only preference rules; `registrationId` is an optional consent-session identifier, preserving compatibility with existing registrations.
3. Rebuild the app. Native Firebase configuration initializes without Dart defines. Existing explicit builds can still supply `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, and `FIREBASE_SENDER_ID` together, using the same Android app's configuration.
4. Choose an exam and sitting, enable **Settings → Push alerts**, and allow Android notifications. Tokens reconnect on restart, rotate, and follow changes to the saved selection. Turning phone alerts off keeps local alerts available.
5. Test a notification to that phone's token in Firebase Messaging with the app in the background. Firebase Analytics is not required for basic delivery. The Android **Exam alerts** notification channel controls sound and banners. A device that force-stops the app in Android Settings must reopen it before receiving messages again.

Messages from `worker.notifications` contain a notification payload for Android background delivery and validated data for foreground inbox display and source opening. Unrelated selections and non-PRC source URLs are ignored. Generic Firebase console tests show in the system tray in the background; add the worker's data fields to exercise foreground handling. See `worker/README.md` for automatic sending and its rollout requirements. No live sender is enabled by an app build alone.

Runtime data comes only from live repositories. Unavailable services show honest unavailable states. Synthetic fixtures and screenshot references are restricted to tests. No PRC requests or real outbound messages are authorized by these setup instructions.

## Release APK

Run `flutter build apk --release` with the Android Firebase client configuration above and the private `android/key.properties` signing setup. Release builds require both files so a missing notification configuration cannot silently ship. Both files remain ignored by Git. The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
