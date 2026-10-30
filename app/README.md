# PRC Exam Updates Android app

Open this folder as a Flutter project in Android Studio. Use a valid Android SDK and an emulator or connected phone. See ../docs/android-studio-runbook.md for configuration and workstation-specific setup.

From this folder run flutter analyze, flutter test, and flutter run -d <android-device-id>. Native checks: flutter test integration_test/app_test.dart -d <android-device-id>.

Runtime data comes only from configured live repositories. Missing services show honest unavailable states. Synthetic fixtures and screenshot references are restricted to tests. No PRC requests or real outbound messages are authorized by these setup instructions.
