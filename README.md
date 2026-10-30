# PRC Exam Updates

Native Android Flutter app implementing the approved Material 3 UI. Open `app/` in Android Studio. Without live configuration it reports services unavailable; no sample catalog/results or simulated delivery are substituted.

- [Approved design](DESIGN.md)
- [Setup and Android Studio runbook](docs/android-studio-runbook.md)
- [Free live-service account setup](docs/live-service-setup.md)
- [Implementation progress and pending gates](docs/implementation-progress.md)
- [PRC worker and run instructions](worker/README.md)
- [Actual live source evidence](docs/source-access.md)
- [Android verification evidence](docs/android-studio-acceptance.md)
- [Impeccable native UI audit](docs/ui-audit.md)

From `app`, run `flutter analyze` and `flutter test`. Android integration checks use `flutter test integration_test/app_test.dart -d <android-device-id>` and isolate synthetic fixtures to tests.

PRC access, provider configuration, outbound messages, physical-device acceptance and public distribution retain their separate gates. This repository does not claim complete live-service or release acceptance.
