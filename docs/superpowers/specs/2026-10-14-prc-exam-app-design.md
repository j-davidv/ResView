# PRC exam updates Android app: design for review

Date: 14 October 2026, Asia/Taipei

## Purpose and agreed scope

Help Philippine board-exam takers receive relevant PRC announcements, view public exam results, and privately check their name against a validated official list. Include all PRC board exams in the exam catalog. PRC is the sole information source; documents hosted elsewhere are acceptable only when linked directly by an official PRC publication, with the source chain preserved.

Build an Android app with Dart and Flutter that is intended for live deployment. First run and test it through Android Studio, using an Android emulator and a connected physical Android device for device-dependent checks. The installed app uses real PRC publications and configured live services, with the same functional flows intended for release. Android Studio testing is the first acceptance milestone; public distribution follows separately, with its route selected before launch. Spend nothing on services: use no-cost plans without enabling billing or automatically upgrading. Keep the entered name and personal matching results exclusively on-device. Email addresses, exam subscriptions, and push identifiers may leave the device with explicit user consent.

Do not ship or display seeded announcements, fictional result lists, sample subscribers, simulated delivery success, demo banners, or placeholder controls. Empty, loading, offline, stale, restricted-source, and service-unavailable states must describe actual conditions and provide the applicable retry or official-link action. Missing configuration must be reported as unavailable rather than replaced with sample content. Synthetic fixtures and mocked failures are allowed only in automated tests and must never populate the installed app or live databases. Do not hide real availability or validation limitations to make the app appear complete.

Do not access individual ratings, application numbers, birthdates, or private PRC accounts. Do not claim affiliation with PRC or that a matching name establishes identity. Universal automatic name matching cannot be advertised until permitted access and validation cover every supported exam format.

## Agreed technology

| Responsibility | Technology |
|---|---|
| Android interface and local matching | Dart and Flutter |
| Small private values on-device | flutter_secure_storage |
| Temporary downloads and explicitly saved offline files | path_provider and Dart file operations |
| Anonymous user identity | Firebase Authentication, Spark |
| Exam catalog, announcements, validation metadata, private push preferences | Cloud Firestore, Spark |
| Android push delivery | Firebase Cloud Messaging |
| Official-publication monitoring and public PDF extraction | Python and pypdf |
| Scheduled processing | Standard GitHub Actions runners in a public code repository |
| Hosting permitted validated public result files | Supabase Storage, Free |
| Confirmed email subscriptions and email delivery | Brevo, Free |

Do not use Firebase Cloud Functions, Firebase Cloud Storage, billing-enabled Google Cloud services, paid domains, or paid upgrades. Use provider subdomains. Repository contents and build logs must exclude email addresses, device tokens, secrets, and subscriber exports.

Supabase provides file storage only; Firestore is the application's database. Large lists belong in files, not one Firestore document per passer. No separate mobile API server is included.

## Onboarding and user flows

Browsing does not require a sign-up screen. Firebase anonymous authentication establishes an installation-associated account when protected preferences are needed. Restrict private Firestore records to their authenticated owner; public announcement metadata is readable by users but writable only by the trusted worker.

The user selects an exam, sitting date or date range, and applicable category, such as teachers elementary/secondary. Special or overseas sittings remain distinct from domestic sittings. Name entry is optional, with surname, given names, middle name, and suffix reflecting the PRC application. The selected exam remains usable without entering a name.

Main destinations are the selected exam's updates, public results, name checking, and settings. Settings include exam selection, edit/delete saved name, push consent, email signup/unsubscribe, saved offline lists, and deletion of local data and server-side push preferences. These functions do not require an additional dashboard, social feature, or paid account.

Push permission is requested when the user chooses alerts. Optional email signup uses a Brevo-hosted double-opt-in flow with exam preferences. This avoids constructing an email-verification server and lets Brevo handle confirmation and unsubscribe. The user may need to confirm their exam preference in that form; email preferences are independent of their anonymous device account. Email contacts are stored by Brevo rather than duplicated in Firestore unless a demonstrated requirement warrants it. The worker must use confirmed, active subscriptions only. Provider form availability and account approval must be verified before launch.

Uninstalling or clearing app data may lose the anonymous identity, saved name, and local files. Email subscriptions are independent and remain until unsubscribed. Do not imply that uninstalling cancels email. No cross-device synchronization of names is included.

## Publication monitoring and alerts

The Python worker reads only permitted public PRC publications. Record the source URL, official title, publication date, exam association, document links, retrieval time, and content/version identifiers. Any displayed summary must be attributable to PRC; avoid generated factual additions. Ambiguous exam relevance is held for review rather than sent as a targeted notification.

Proposed initial polling interval: every 30 minutes, offset from the hour. This is a reviewable design default, not a delivery guarantee. Respect provider terms, robots guidance, rate limits, and access restrictions. GitHub schedules can be delayed or disabled; monitoring health and manual reruns must be available to the maintainer.

Use stable publication/version identifiers to avoid sending the same alert repeatedly. Retry transient failures with bounded backoff. Record per-channel sending attempts and do not claim exactly-once delivery, particularly for push retries. Distinguish result-release alerts from later PRC corrections or announcements.

Notification and email content announce an official publication and link to it. They must not include the user's entered name or personal match outcome. Result-release alerts remain available when automatic checking is unavailable. Relevant notices include schedules, postponements, registration, and oath-taking; clearly general notices may appear as general PRC notices.

## Result publication states

Publication state is separate from a personal matching outcome. Show these states explicitly:

| State | Meaning and action |
|---|---|
| Not released | No official release has been found for the selected sitting. Display the last successful source-check time. |
| Released; validation pending | PRC's publication exists, but automatic checking has not passed validation. Offer the official link. |
| Checking available | The current list/version passed validation. Enable local checking. |
| Checking unavailable | Access is restricted or validation failed. Show **Automatic name checking unavailable** and the official link. |
| Superseded | A newer official version is known. Mark a saved old version outdated and direct the user to the latest publication. |

A monitoring outage does not reset a released exam to not released. Mark source freshness as unknown/stale separately. A successful match is not a publication state.

## Document provenance and validation

Follow document links from the official publication, not search-engine copies or guessed files. Permit supported external file hosts only through that verified source chain, validate redirects, and keep worker network access restricted to intended public hosts. Reject restricted download pages and unexpected content even when the HTTP response is 200. Do not circumvent owner restrictions.

Automatic checking is enabled only when all of these checks pass:

1. The accessible content is a readable, valid result document.
2. Document headings establish the correct exam, sitting, and category.
3. The content is the successful-examinee list, not room assignments, school performance, or topnotchers.
4. Every relevant page and section is accounted for, with complete entry numbering and a recognized end marker where supplied.
5. Extracted totals reconcile with PRC's corresponding published section totals, or an explicitly reviewed official exception.
6. Names can be extracted without unresolved layout or character problems.

Some PDFs contain multiple exams and restart numbering. Validate each section independently. Printed page numbers may refer to a larger original packet; physical page count alone must not mark such a list incomplete. Scanned, unfamiliar, inconsistent, or inaccessible documents are held for review and have automatic checking disabled. OCR is excluded from the initial automatic-checking path.

The phone downloads a compact, UTF-8 JSON names file rather than the original PDF for automatic checking. Python extracts and validates the permitted original document. Preserve published names, sequence numbers, exam sections, and physical PDF page references in the derived file. Include a format version, exam/sitting/category identifiers, PRC publication URL, original document URL, document version, validation timestamp, entry count, and original-file checksum. Publish the download size and derived-file checksum in trusted metadata and verify them on the device before parsing. Do not embed the user's entered name or personal outcome in the public file.

Validate the derived file against the original, then publish its availability metadata only after the file is complete. Treat the derived file as a representation of PRC data, not a separate information source. Permitted retrieval and reuse are still prerequisites. Original and derived assets must identify the same version. A checksum checks byte integrity and version consistency; it is not proof that PRC authored a document.

Keep the original PRC publication/document links available for viewing. Optional offline saving retains the compact names file, not a second PDF copy. Reject unsupported JSON format versions and mismatched exam identifiers instead of attempting a best-effort match.

Corrected releases create a new version. Mark old saved versions outdated once the device learns of the correction. Offline results always show their publication/version and last-check time; the app cannot know about unseen corrections while offline.

## Local matching

Match only against the selected exam, sitting, category, and validated document version. Normalize capitalization, repeated whitespace, and Unicode canonical equivalence. Preserve accents, Ñ/N distinctions, punctuation differences, compound surnames, and suffixes. A document-format rule may map separate input fields to PRC's published surname-comma-given-names order; ambiguous field mapping disables automatic checking for that format.

Show exact matches first. Display the actual published entry, sequence/page reference, and PRC source. If several identical names appear, show each entry without selecting an identity.

Show a separate **Show possible matches** button, as approved. Never silently substitute a possible match for an exact one.

Proposed conservative first-version candidate rule: a candidate must share the complete normalized surname and given names. It may differ in, or omit, middle-name information or suffix. Preserve and prominently display those differences. Do not use arbitrary spelling-distance scores, accent removal, or partial surname matching in the initial version. Enable this rule only for formats where those name components are reliably established. Do not infer the middle-name boundary from the last word or another unverified heuristic. Where boundaries are ambiguous, leave full-name exact checking available if reliable, disable possible matching, and direct the user to inspect the published list. The candidate rule still requires validation against supported PRC formats.

### Matching examples and acceptance behavior

These are synthetic names, not PRC results. Compare complete names within the same exam/version; do not apply these examples across exam categories.

| Entered / published difference | Expected behavior |
|---|---|
| Case or repeated spaces only | Exact match after normalization |
| Canonically equivalent Unicode representation of Ñ | Exact match after normalization |
| PEÑA / PENA | Not an exact match; no automatic accent removal |
| DELA CRUZ / CRUZ | Not an exact match; no partial surname matching |
| ANA MARIE / ANA | Not an exact match; no dropping given names |
| ANA-MARIE / ANA MARIE | Not an exact match; preserve punctuation |
| Same complete surname/given names; middle name omitted or different | Possible candidate only when component boundaries are reliable and the user requests it |
| Same complete surname/given names; JR differs or is omitted | Possible candidate only under the same reliable-boundary rule |
| Same normalized full name appears twice | Show both exact entries; do not infer which person is the user |
| Relevant section is inaccessible or incomplete | Checking unavailable, never no-match |

Use distinct result messages:

- Exact entry: **A matching name appears in PRC's published list.**
- No exact entry: **No exact match found. Check your entered name and the official PRC list.**
- Candidate: **Possible match — confirm the published details.**
- Invalid or inaccessible list: **Automatic name checking unavailable.** Include the PRC publication link.

Absence from a list never becomes a failed-exam conclusion. Withheld results, corrections, incomplete inputs, and shared names prevent that inference.

## Agreed device-storage behavior

Download only the relevant validated list when the user requests checking. Before downloading, disclose a known size and handle inadequate free space. Interrupted downloads use temporary partial files and are not searchable. Validate the completed file/version before use.

Remove temporary files after the operation. Because Android may terminate the app before cleanup, also remove abandoned temporary files at startup and before the next download. Keep app-owned files private and exclude the name, match history, and downloaded lists from cloud backup. Do not include those values in analytics or crash reports.

Initial app limits distinguish transient working space from saved files: cap each compact names-file download at 20 MiB and process one file at a time. Abort a stream that exceeds the limit, including when the server omits or misstates its size, and remove the partial file. Do not retain a background cache after checking. Download on demand and clear temporary files as agreed. A larger list shows the official PRC link and checking-unavailable explanation rather than silently exceeding the limit.

Agreed total budget for explicitly saved offline lists: 50 MiB. Reuse the saved version instead of creating a duplicate. If saving a new list would exceed the budget, ask the user to delete a saved list; do not silently delete their chosen offline copies. These limits concern file bytes, not peak RAM usage. Matching must avoid loading unnecessary duplicate representations on a low-memory device. No automatic permanent saving of lists or personal match history.

These storage budgets are agreed initial limits, not measured optima. No promise of instantaneous forensic erasure from flash storage is made.

## Zero-spending limits

Leave Firebase on Spark and external services on Free. No paid overages or automatic upgrades. Monitor free quotas and stop or queue work when necessary. Display degraded availability honestly rather than fabricated empty results.

Brevo's checked Free allowance is 300 emails/day across the account. Persist a bounded sending queue, discard unsubscribed recipients before sending, and preserve the original publication date in delayed messages. Do not promise immediate email to a national subscriber base. Push and in-app updates remain separate channels.

Supabase file hosting has storage/transfer limits and free-project availability limitations. GitHub scheduled execution is not guaranteed punctual. Free-plan terms can change. These limits constrain reliability and capacity even though the exam catalog covers all exams.

The first delivery is a complete Flutter project runnable through Android Studio against configured live services. Include reproducible setup, backend rules and worker deployment instructions, documented required credentials, and an Android release-build and signing procedure. Keep signing keys and service credentials outside source control. Public distribution and paid publishing steps are deferred until after Android Studio acceptance and a distribution-route decision; they are not required for the initial test milestone.

## Agreed email backlog and retention rules

The following backlog and retention rules apply to real delivery. Once configured and explicitly authorized for controlled testing, exercise actual push and email delivery only to designated test devices and consenting test recipients. Do not send to existing subscriber lists during development. In the later public deployment, delivery uses active subscriptions and the consent rules above. An unconfigured or disabled channel reports its actual status; it must not simulate a successful send.

- Give active, confirmed subscribers one queued release alert per publication/version. Avoid re-enqueueing the same recipient/release pair.
- Priority is result releases and urgent exam changes before routine notices, then oldest publication first within each class. Process each class in a persisted deterministic order and show the consequences of capacity limits honestly.
- Expire an unsent release email after 48 hours; keep the announcement available in-app. A corrected release replaces an obsolete queued message before it is sent. Unsubscribed recipients are removed from pending sends immediately.
- The 300-email daily allowance is shared with confirmation messages and other sends. Confirm available provider capacity before sending; never try to bypass it or auto-upgrade. Do not claim instant delivery or exactly-once email.
- Delete the local name on request; retain it otherwise until the user deletes it or clears app data. Save no personal matching history by default.
- Delete temporary files after use and abandoned files on startup. Keep explicitly saved offline lists until deletion, subject to the proposed saved-files budget; mark outdated versions visibly.
- Treat provider-reported invalid push tokens as inactive and remove them from sending. Clean up stale subscriptions after 90 days without app activity. Make this maintenance worker-owned rather than a billing-required Firestore TTL feature.
- On email unsubscribe, stop sending immediately. Retain only the minimal suppression information necessary to prevent accidental resubscription through a stale queue; a verified fresh opt-in may reactivate subscription. A request for full deletion needs provider-specific verification of what is retained and cannot be described as immediate total erasure until verified.
- Redacted operational-log retention is 7 days and delivery metadata retention is 30 days. Retain no names or email addresses in operational logs. Keep active subscriber addresses only in the email provider, and keep private push preferences in Firestore. Retry records use opaque internal references.

## Maintenance and live operation

The project owner/developer is the agreed maintainer; no dedicated admin website or additional staff role is included. Use existing provider consoles, validation reports, and manually runnable worker jobs.

The maintainer reviews rejected formats, verifies source mappings and corrections, checks the last successful scan and free quotas, and handles revoked credentials or unavailable services. A manual override may approve a documented official exception, but must not label an incomplete list valid or bypass access restrictions. Changes to published data need a record of the source, reason, time, and changed version.

The app must show an unavailable/stale condition honestly rather than depend on the maintainer being continuously online. No around-the-clock support commitment is included. Document how to detect a failed worker run, rerun safely, rotate credentials, disable a faulty checking format or delivery channel, and restore public metadata without restoring deleted private preferences or replaying obsolete alerts. Validate these procedures before public launch.

## User-facing privacy explanation

Proposed plain-language text:

> Your name stays on this device and is used here to check a validated PRC list. We do not send your entered name or personal matching result to our servers. Public result lists may contain names already published by PRC.
>
> If you enable push alerts, Firebase processes an anonymous account identifier, your exam preferences, and a device notification token. No password is required, but this does not mean no information leaves the device.
>
> If you subscribe to emails, Brevo stores your email address and selected exam preferences to confirm your subscription and send updates. You can unsubscribe from an email. Uninstalling the app does not unsubscribe you from email updates.
>
> Downloaded lists are temporary unless you choose to save them offline. You can delete your saved name and offline files in Settings. A matching published name does not confirm your identity, and an absent name does not mean you failed the exam.

Match this explanation to actual implemented network behavior, provider configuration, and deletion controls before enabling real subscriptions. Publish an accurate privacy policy and maintainer contact before public launch. The text above is product disclosure text, not a completed legal privacy policy.

## Validation evidence and Android Studio acceptance checks

Existing evidence is in validation/validation-report.md: ten sampled result articles were accessible; twelve linked Google Drive files refused normal downloads. Three archival PRC PDFs yielded 24,602 entries over 494 pages with agreement between two text readers. Four exam-category counts matched published totals, and nine visually checked entries matched. This does not establish current all-exam accuracy.

Before enabling each document format, maintain PRC-sourced fixtures and manually checked expected rows covering its exam sections and names. Test extraction omissions, wrong documents, restricted HTML responses, numbering resets, Unicode names, suffixes, duplicate names, changed versions, and incomplete files. Unsupported formats remain available as official links with checking disabled.

Test local exact and candidate matching independently. Test Firestore isolation between two anonymous users and worker-only writes. Check network traffic, logs, and Android backup configuration for name leakage. Test temporary-file cleanup after cancellation, crashes, low storage, and repeated checks. Test double opt-in, unsubscribe, email quota exhaustion, duplicate alerts, and retries. Test permissions, TalkBack, enlarged text, and slow/offline connections on Android.

The first deliverable is the real app running through Android Studio. Verify exam selection, retrieval of actual official publications, local exact checks against a permitted validated document, user-requested possible checks where supported, official-link fallback, temporary-file cleanup, offline save/delete, and privacy controls. Verify actual push and email delivery to authorized test recipients when those channels are configured. A feature with no successful real integration evidence remains an acceptance blocker for that feature; a sample screen or simulated send does not satisfy it.

Use actual permitted PRC documents for extraction and on-device checks. Keep synthetic matching fixtures and injected publication/error states within isolated automated tests, outside the app's runtime data and live services. Test publication states that cannot currently be observed using those isolated tests. Real messages may be sent only to explicitly authorized test recipients after separate instructions.

The catalog may cover all exams while extraction coverage remains limited to validated formats. Android Studio acceptance does not establish national-scale capacity, store approval, guaranteed delivery, or all-exam matching. A later all-exam matching claim requires a permitted feed and validation coverage across every supported format.

## Readiness for public deployment

After Android Studio acceptance, verify the following before describing the app as ready to deploy:

- A permitted PRC retrieval route works end to end. Live publications retain their source chain; unsupported or restricted lists use the official-link fallback without fabricated checking results.
- Required live provider accounts and email forms are approved and configured. Recheck current free-plan limits, estimate reads, file transfers, worker usage, and email volume for the intended initial audience, and document the capacity ceiling without enabling billing.
- Deploy and test Firestore ownership rules, worker-only writes, least-privilege credentials, redacted logs, and deletion controls. No worker or email-provider secret is embedded in the Android app.
- Verify scheduled processing, correction/version handling, delivery retries, quota exhaustion, and unsubscribe behavior. Confirm failure detection and the recovery procedures described above.
- Run the app on a physical Android device, including notification permissions and delivery, low-storage cleanup, offline use, accessibility, and update behavior. Complete a signed release build and verify its installation and core flows; exclude test fixtures and debug-only controls from that build.
- Document environment setup, worker deployment, credential provisioning, signing-key storage, backup and recovery, and release rollback. Publish the privacy policy and contact details, then select the public distribution route and address its requirements.

No public deployment, subscriber broadcast, or paid publishing action is authorized merely by approving this spec. Launch readiness depends on evidence from implementation and integration checks, not on removing demo wording.

## Review and next stage

This revised design targets a real Android app, with Android Studio testing first and public-deployment readiness afterward. It retains the compact JSON download format, distinct publication states, matching examples, privacy requirements, email backlog and retention rules, maintenance responsibilities, and 20 MiB/50 MiB file budgets. No demo data or simulated delivery is part of the installed app. The zero-spending constraint remains an assumption carried forward from the original scope. The 30-minute polling interval and conservative candidate details remain concrete defaults for whole-document review. No app, backend deployment, external account, or paid service has been created by this spec revision.

After written-spec approval, create a separate implementation plan. Source-access work must include identifying a permitted PRC feed or documented retrieval route; no outbound request to PRC is sent without explicit instructions.
