# Impeccable critique, polish and native Android audit

15 October 2026. Scope: Flutter/Material 3 local interface, source, widget renders, Android emulator integration and native captures. No web detector was used: it does not audit native Flutter.

## Platform verdict

Pass at the observed local UI scope: Material navigation, buttons, fields, dialogs and native keyboard; semantic light/dark theming, wrapping content and window/IME insets. Physical-device gesture and spoken-accessibility acceptance remains open.

## Provisional audit score

| Dimension | Score / 4 | Evidence and limitation |
|---|---|---|
| Accessibility | 3 | 48 dp/label checks, 200% layouts and bound TalkBack focus; human speech verification remains open |
| Performance | 2 | Matching moved off Dart/Android UI threads and bounded NFC batches; large-fixture timer/cancellation test passed. Software-rendered debug emulator logged skipped frames; no physical profiling |
| Appearance/theming | 4 | Shared Material color roles, system light/dark schemes and SDK-font golden checks; no graphics/fictitious data added |
| Platform conformance | 3 | Material controls, native notification settings fallback, normal Back/IME behavior and adaptive navigation; predictive Back on physical hardware not verified |
| Adaptivity | 3 | 200% narrow portrait and short landscape regression plus native verification; foldables/tablets not certified |
| Total | 15 / 20 | Good at the stated scope; not production certification |

## Material findings and focused fixes

- P1 resolved in source/integration: complete-list normalization ran on UI threads and retained redundant full representations. Dart matching now runs in a cancellable background isolate, native normalization on an Android background queue, processing only 256-entry batches. Published entries remain the sole complete list. A near-limit isolated fixture proved root responsiveness/cancellation on the emulator; peak memory on a physical low-memory phone remains unverified.
- P2 resolved: saved lists displayed internal identifiers. Local sidecar metadata now retains readable exam/sitting/type/location/category context and the offline checking view reuses it. Tests verify context survives saving/reuse. Older metadata without this field uses an honest unavailable-context explanation rather than inventing labels.
- P2 resolved with red/green regression: Retry after server-deletion failure only refreshed local files and announced success. Settings now captures/retries the failed operation with its original success message, retaining pending intent until server acknowledgement.
- P2 resolved: large-text landscape overflowed NavigationRail. Short landscape windows use the standard labeled bar; rail remains for widths/heights that accommodate it.
- P2 resolved in render review: optional field labels were truncated. Middle name/Suffix use separate Optional helper text. Navigation label typography compensates for Material's own scaling so complete labels remain readable at 200%.

## Preserved practices

Four destinations only; optional name and no browsing signup; separate publication/freshness/personal outcome; exact copy and published references; no pass/fail identity claim; local name storage and backup exclusions; explicit saving and no eviction; contextual push consent; independent hosted email flow; no simulated success.

## Evidence gaps, not inferred passes

Physical hardware, human TalkBack speech assessment, actual PRC source/format access, live provider/security-rule verification and release/distribution acceptance remain open. Source-configuration failures are intentionally unavailable UI states. See android-studio-acceptance.md for the checklist and runbook for workstation cache/toolchain constraints.
