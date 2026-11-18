# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter / Dart / Material 3. Firebase Spark metadata and consent-based push preferences; official PRC and Google Drive source viewing; Python worker; Brevo hosted confirmed email subscriptions. Legacy Supabase name-list files are no longer consumed by the app.

## Users and purpose

Philippine board-exam takers browse official PRC announcements and successful-examinee lists. Supported Google Drive documents offer manual text search. A text match does not establish identity; an absent match does not establish exam failure. Automatic name validation has been removed.

## Constraints

No browsing signup, mandatory name entry, ratings access, extra dashboard, fictional runtime data, or simulated success. Three destinations: Updates, Results, Settings. All exams in the official catalog retain their official source links independently of legacy name-validation status. The app does not save names or download lists for automatic matching. Upgrades delete previously saved checker names and list files. Manual Drive search sends search text to Google and requires a connection. Initial Android Studio milestone precedes public deployment. Spend nothing; do not enable billing.

## Evidence

Authoritative spec and implementation plan copied to docs/superpowers. Empty repository at start of implementation. No PRC retrieval or provider setup performed. Physical device and live-service evidence must be reported separately.

## Accessibility

48 dp targets, TalkBack, 200% text, complete wrapping names, Android Back, keyboard and landscape support.
