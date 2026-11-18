# PRC Exam Updates Android design

Visual design follows the team's green ResView handoff. The product spec governs exam data, privacy, and availability.

## Visual rules

- Native Material 3 with the handoff's light and dark colors, botanical green header, and off-white or dark canvas. Use the bundled Inter font and Iconify Material Symbols outlined assets.
- Set screen titles at 28/34, app-bar titles at 22/28, section titles at 18/24, body at 16/24, metadata at 14/20, and navigation labels at 12/16. Honor the system TextScaler without clamping.
- Use 20 dp phone gutters and the welcome screen's 24 dp gutter. Use 16 dp card padding, 24 dp between sections, 12 dp card corners, 8 dp control corners, and 24 dp sheet corners. Content determines height.
- Show the supplied RV mark during launch and first-use welcome. Keep the welcome visible until the user chooses or skips. Restore the exact saved exam identity when available, and show loading, unavailable and retry states in the main shell.
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

Selection uses searchable official exam choices, concrete sitting selection (date range filters, never merges sittings), and applicable category. No mandatory name or consent. Updates lists actual official titles and sources. Results has separate publication status, freshness, and official source sections. Check name has surname/given/middle/suffix, optional unchecked name saving, download-size disclosure, cancel, exact outcomes, supported possible matches, and explicit offline save. Settings groups the exam, device data, alerts, and privacy actions. Detail pages retain local name, independent email signup/unsubscribe, saved lists, and scoped deletion.

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
