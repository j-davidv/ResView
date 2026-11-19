# ResView Android design

Visual design follows the team's green ResView handoff. The current app browses official announcements and result documents; automatic name validation is retired. Historical specifications under `docs/superpowers` describe the earlier checker design.

## Visual rules

- Native Material 3 with the handoff's light and dark colors, botanical green header, and off-white or dark canvas. Use the bundled Inter font and Material Symbols assets.
- Honor the system TextScaler without clamping. Content determines height; long exam names and navigation labels wrap.
- Show the supplied RV mark during launch, first-use welcome, and in the Android launcher. The phone app name is ResView.
- Three labeled destinations: Results, Updates and Settings, with Results selected on launch. Use a NavigationBar on compact widths and a labeled NavigationRail on expanded widths.
- Exam context shows the exam, sitting dates, Domestic/Special/Overseas type, location, applicable category, and Change action.
- Results shows publication status and official links. A failed refresh identifies previously retrieved information. Legacy validation states never prevent opening an available official list. Do not display validation reasons or document-version hashes.
- Source timestamps include Philippine time UTC+08:00. Refresh retrieves metadata and never fabricates a newer PRC source-check timestamp.
- Use standard Material transitions and a subtle 120 ms filled-button press scale. Honor Remove animations. Progress conveys actual operation state.
- Minimum 48 dp interaction targets, scalable scrollable dialogs, visible keyboard focus, TalkBack labels/headings/live status, system Back, and system insets.

## Screens and interactions

Selection uses searchable official exam choices, concrete sittings, and applicable categories. Results features the current PRC publication with its posting date and labeled lists. Other result publications follow in descending posting order and retain their own lists. Supported Google Drive documents retain manual Find text, Previous/Next matches, and browser fallback. Search reports text matches without inferring an exam outcome.

Settings retains exam selection, optional alerts, independent email signup/unsubscribe instructions, privacy, local-data deletion, and retry of pending server deletion. No saved-name or offline checker-list controls remain. On upgrade, remove legacy saved names and checker files while preserving the exam preference and pending push-deletion intent.

In Release 2, Updates sits between Results and Settings. Show one latest exam update with its posting date, official title, known audience and source action. View all updates opens a scrollable history using the same cards and showing the exam title and coverage window. Both screens support large text and both themes.

## Verification mapping

| Behavior | Checks |
|---|---|
| Default Updates destination, onboarding, large text and landscape | default_launch_test.dart, shell_test.dart, visual_test.dart |
| Publication links across legacy states and metadata outages | flows_test.dart, publication_links_test.dart, integration_test/app_test.dart |
| Source freshness and catalog boundaries | contracts_test.dart, firestore_rest_test.dart |
| Legacy name/list cleanup and scoped local deletion | private_store_test.dart, list_cleanup_test.dart, integration_test/privacy_test.dart |
| Press feedback, reduced motion and unchanged hit targets | button_motion_test.dart |
| Manual document search and source recovery | source_viewer_test.dart, integration_test/source_viewer_test.dart |
| Alert consent, unconfigured services and retry intent | push_preferences_test.dart, flows_test.dart |

## Service availability

An email form launch is not proof of confirmation. Alert registration is not proof of delivery. Pending server deletion retains the anonymous identity and retry intent until acknowledged. Unconfigured services report unavailable; synthetic fixtures stay in tests. Physical-device checks and public release readiness remain separate from widget test results.
