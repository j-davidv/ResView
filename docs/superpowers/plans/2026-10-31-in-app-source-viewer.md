# In-app source viewer implementation plan

Goal: let Android users read official PRC announcements and linked Drive lists inside ResView, with touch-operated full-document search.

Approach: embed the platform WebView using Flutter's existing native-channel pattern. Keep Material search/navigation controls outside the web content. Use Drive's own document search rather than WebView's incomplete loaded-page search. A downloadable-PDF reader cannot cover the restricted originals; external browsing remains the recovery option. No additional runtime dependency is required.

Scope: shared source navigation, one Flutter viewer screen, one Android platform view registered by MainActivity, focused widget/domain and real Android integration checks, and updated compatibility/privacy documentation. Work in the current checkout because the app and supporting files are untracked work in progress; do not move or commit unrelated changes.

- [x] Write and run failing tests for official URL routing, safe navigation, touch search/result states and large-text layout.
- [x] Register a native WebView with HTTPS origin checks, disabled file/content access, no JavaScript-to-native bridge, bounded search readiness checks, cancellation on navigation/disposal and explicit error recovery.
- [x] Add Material Find/Previous/Next, source identity, loading/failure states, browser fallback and Back handling. Search text is ephemeral, separate from the saved name, and never logged. Disclose the PRC/Google connection.
- [x] Run the Flutter suite/analyzer and Android build. Verify a real page-11 match, absent search, restricted document, PRC-to-Drive navigation, failure recovery, Back, keyboard and enlarged-text/landscape layout.
- [x] Review the final connected flow and document exact evidence and remaining physical-device limits. Preserve the prior compatibility evidence; no worker or live database writes.
