# PRC Exam Updates Android design

Approved Impeccable UI/UX proposal, 14 October 2026. The spec governs product truth; this file records the approved visual rules.

## Visual rules

- Native Material 3, system light/dark theme, static deep teal seed. Semantic ColorScheme roles throughout; no dynamic-color dependency.
- Roboto / Material text roles: titleLarge 22, titleMedium 18, bodyLarge 16, bodyMedium 16, bodySmall 14. Honor the system TextScaler without clamping.
- 4 dp spacing rhythm, 16 dp phone gutters, 8 dp between related controls, 24 dp between sections. Content determines height.
- Flat lists and dividers, modest tonal sections, restrained elevation. No artwork, government seals, decorative gradients, invented statistics, or demo branding.
- Four always-labeled destinations: Updates, Results, Check name, Settings. Material NavigationBar on compact widths, labeled NavigationRail at expanded widths. Navigation labels wrap at large text.
- Exam context is visible and wraps: exam, sitting dates, explicit Domestic/Special/Overseas type, location, applicable category, Change action.
- Publication state, source freshness, and personal outcome occupy distinct sections. Neutral exact-match presentation; no celebration, pass/fail inference, or identity claim.
- Source timestamps include Philippine time UTC+08:00. Refresh retrieves app metadata and never fabricates a newer PRC source-check timestamp.
- Known superseded versions stay visible/deletable but cannot start a new automatic check. Offline versions show the unseen-correction limitation.
- Exact matching first. Show possible matches runs only on explicit request and only for reliable component mappings.
- Minimum 48 dp interaction targets, scalable scrollable dialogs/forms, visible keyboard focus, TalkBack labels/headings/live status, wrapping long text, system Back and insets.
- Standard Material transitions; honor Remove animations. Progress conveys real operation state, never simulated completion.
- Checking availability and its recovery action precede name entry. Optional name saving stays available when checking is unavailable.
- Unsaved name drafts survive destination changes in memory only. Explicit deletion clears drafts; leaving Check name still cancels work and clears personal outcomes.
- Name controls distinguish deferred “Save when I check” from immediate “Save name now”; unchecking does not delete an existing saved name.
- Completion reveals checking feedback without moving accessibility focus. Honor Remove animations when scrolling feedback into view.

## Screens and interactions

Selection uses searchable official exam choices, concrete sitting selection (date range filters, never merges sittings), and applicable category. No mandatory name or consent. Updates lists actual official titles and sources. Results leads with the five publication states and provenance. Check name has surname/given/middle/suffix, optional unchecked name saving, download-size disclosure, cancel, exact outcomes, supported possible matches, and explicit offline save. Settings separates local name, push consent, independent email signup/unsubscribe, saved lists, privacy and scoped deletion.

## Existing plan and verification mapping

| Task | UI rules and owning checks |
|---|---|
| 1 | Theme, shell, no-signup/no-fixture runtime: shell_test.dart |
| 2 | Selection/version/state boundaries: contracts_test.dart |
| 3 | Optional private name retention and scoped deletion: private_store_test.dart |
| 4 | Accent/punctuation/duplicate/candidate behavior: matching_test.dart; background/native NFC and cancellation: integration_test/app_test.dart |
| 5 | Bounded files, cancellation, storage budgets and readable saved context: list_store_test.dart, list_save_test.dart |
| 6 | Context, five publication states, independent freshness, exact copy, name forms and privacy: flows_test.dart |
| 6 refinement | Draft retention without disk writes, availability before input with selection recovery, explicit saving timing, and visible checking feedback at 200%: flows_test.dart; refreshed light/dark goldens in visual_test.dart |
| 11 | Live-only repository, consent, denied/unavailable/pending states and pending deletion after restart: push_preferences_test.dart and integration_test/privacy_test.dart |
| 12 | Native emulator screenshots, TalkBack, 200% text, long names, keyboard, landscape: app_test.dart and docs/android-studio-acceptance.md |
| 13 | Signed release and policy/contact readiness: release-readiness.md; never infer deployment readiness from UI tests |

## Safety decisions

An email form launch is not proof of confirmation. Alert registration is not proof of delivery. Pending server deletion must retain the anonymous identity and retry intent; local deletion must not silently destroy that intent. Channel health is shown only when observable. Unconfigured services show unavailable and Retry, never test records. Synthetic fixtures exist only under tests, never app assets or live databases.
