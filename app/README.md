# PRC Exam Updates Android app

Open this folder as a Flutter project in Android Studio. Use a valid Android SDK and an emulator or connected phone. See ../docs/android-studio-runbook.md for configuration and workstation-specific setup.

From this folder run flutter analyze, flutter test, and flutter run -d <android-device-id>. Native checks: flutter test integration_test/app_test.dart -d <android-device-id>.

Normal runs and builds enable Updates and use the live public Firestore catalog in `resview-9240c`. No extra `--dart-define` arguments or private Firebase credentials are required for browsing. Override `FIRESTORE_PUBLIC_PROJECT_ID` to use another public project, or set `RESVIEW_EXAM_UPDATES=false` to disable Updates. Push registration and email signup require separate configuration.

Runtime data comes only from live repositories. Unavailable services show honest unavailable states. Synthetic fixtures and screenshot references are restricted to tests. No PRC requests or real outbound messages are authorized by these setup instructions.
