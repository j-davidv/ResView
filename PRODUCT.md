# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter / Dart / Material 3. Firebase Spark metadata and consent-based push preferences; official PRC and Google Drive source viewing; Python worker; Brevo hosted confirmed email subscriptions. Legacy Supabase name-list files are no longer consumed by the app.

## Users and purpose

Philippine board-exam takers browse official PRC announcements and successful-examinee lists. Supported Google Drive documents offer manual text search. A text match does not establish identity; an absent match does not establish exam failure. Automatic name validation has been removed.

## Constraints

No browsing signup, mandatory name entry, ratings access, extra dashboard, fictional runtime data, or simulated success. Results is the landing screen. Settings holds exam selection, preferences and privacy controls. All exams in the official catalog retain their official source links independently of legacy name-validation status. The app does not save names or download lists for automatic matching. Upgrades delete previously saved checker names and list files. Manual Drive search sends search text to Google and requires a connection. Initial Android Studio milestone precedes public deployment. Spend nothing; do not enable billing.

## Exam updates

Updates follows the selected exam across sittings. The latest official post includes its PRC date and source. View all updates opens the complete verified history, including the latest post, newest first. Coverage begins with posts dated January 1, 2026 in Philippine time. Reading notices leaves Results unchanged. Normal builds enable Updates and read the live public Firestore catalog in `resview-9240c` without extra run arguments. The emulator-only entry point remains available for isolated tests.

## Evidence

Authoritative specifications and implementation plans are under `docs/superpowers`. Live catalog and hosted archive-refresh evidence are recorded in `docs/source-access.md`. Physical device checks and signed-release acceptance remain separate from widget test results.

## Accessibility

48 dp targets, TalkBack, 200% text, complete wrapping names, Android Back, keyboard and landscape support.
