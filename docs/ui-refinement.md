# Critique-driven UI refinement

The 15 October critique of `app/lib/main.dart` and `app/lib/ui` informed this focused refinement. The approved Material 3 theme, four destinations, matching messages, privacy disclosure, architecture and service gates remain authoritative.

- The shell retains name drafts in memory across destination changes. It never automatically writes them to private storage. Explicit name/local deletion clears the draft; closing the app discards it. Leaving Check name still cancels work, disposes temporary lists and clears personal outcomes.
- Checking availability and Choose exam/View results recovery lead the name form. Optional local saving remains available without a usable result list.
- Save when I check names deferred retention; Save name now names immediate retention. Unchecking is explicitly distinguished from deleting an existing saved name.
- Checking completion reveals feedback through the existing scroll container without moving accessibility focus. Remove animations disables the scrolling animation.
- Shorter selection guidance brings unavailable-state recovery closer to the first viewport. Navigation labels retain accessible scaling and wrapping.

Regression coverage in `flows_test.dart` verifies draft survival without a storage write, prerequisite/action ordering, and visible checking failure at 200% text. The existing publication-state, consent/deletion, large-text landscape and light/dark golden checks remain in place. Refreshed widget goldens were visually inspected; they are not new Android device screenshots.

Verification after the changes: `flutter analyze` reported no issues; `flutter test` passed all 27 tests, including the refreshed goldens without update mode.

Current native acceptance is still pending: a connected Infinix X6710 was detected through read-only ADB inspection, but this refinement did not install or exercise the revised build on that phone. Earlier Android captures and integration results describe the previous build. TalkBack speech, successful matching completion on this build, populated-list scrolling performance and live-service journeys require fresh evidence. No PRC access, provider configuration, real outbound messages or public distribution occurred.
