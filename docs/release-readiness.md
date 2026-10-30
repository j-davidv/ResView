# Release readiness

Status: not ready for public deployment. Local Android UI/build verification is recorded in android-studio-acceptance.md.

Task 3 follow-up (2026-10-30): live read-back now verifies 120 mapped records across 84 announcements and 159 active sittings. Three announcements were fully resolved; confirmed portions of two regional releases were added while their unresolved locations remain in review. Four distinct issues still prevent task 3 completion. Article-route aliases now share record/mapping identities; 13 duplicate public records were archived privately. Forty-three worker tests and live public-query/private-denial checks pass. No GitHub push, schedule activation, checking profile or delivery activation occurred. See [current mapping evidence](prc-mapping-review.md#october-30-follow-up).

Task 3 update (2026-10-29): historical metadata backfill and schedule-menu rollover implemented locally. The live database now has 159 active sittings and 95 verified publication mappings across 79 announcements; an incorrect oral-to-ordinary mapping was corrected. Forty worker tests and public-query/private-denial checks pass. Seven releases still require exact sitting evidence, so task 3 remains partial. No checking profiles, scheduling or delivery enabled. See [mapping evidence](prc-mapping-review.md).

Task 2 verification (2026-10-29): GitHub HTTPS refusal was reproduced, but an authorized workstation manual import succeeded after fixing discovery of PRC's `/index.php/article/` links. Read-back confirmed 99 refreshed exam labels, 87 sittings, five new publications/current versions (10 total each), and fresh scan health. All 34 local worker tests and live public-query/private-denial checks pass. The route fix remains local; scheduled ingestion stays disabled. See [current worker evidence](worker-deployment-review.md#october-29-2026-manual-import). Complete mappings, historical coverage and real name checking remain pending.

Worker deployment follow-up (2026-10-15): reviewed source is published and restricted keyless CI identity is configured. 33 worker tests pass locally/on GitHub. Manual cloud runs authenticate but PRC's public HTTPS endpoint refuses connections from the runner; scheduled ingestion remains disabled. This network blocker is separate from the inspected list's owner-disabled downloads. Billing remains disabled/no linked account. See worker-deployment-review.md.

Firebase verification (2026-10-15): Spark/no linked billing account, Standard Firestore, tested application rules and three READY indexes. Live metadata imports contain 99 official schedule labels, 87 dated sittings and five current result publications. Populated unauthenticated queries/private denials pass. Device sign-in/notification receipt remain unverified.

Owner-authorized PRC retrieval works. The inspected Foresters list explicitly refuses downloads; no checking profile/asset is enabled. The GitHub schedule is deployed, but ingestion is gated off by `PRC_MONITOR_ENABLED=false`. See source-access.md, format-validation.md and provider-setup.md. Metadata availability does not establish name-checking or unattended-update readiness.

- [x] Approved Material UI and normal unconfigured runtime implemented without demo data.
- [x] Debug APK build and emulator integration verified.
- [x] Release build refuses missing private signing configuration; no debug-key release fallback.
- [x] Owner-authorized public PRC access and actual 2026 schedule labels imported; ambiguous aliases/special sittings remain in review.
- [ ] Python extraction/validation/publication worker and source provenance verified against permitted current documents.
- [ ] Firebase ownership rules/emulator isolation, approved Supabase hosting and Brevo signup/delivery configured and verified.
- [ ] Actual opt-in/unsubscribe, alert delivery, retries, quota exhaustion and scheduled processing verified with authorized test recipients.
- [ ] Physical Android device accessibility, speech, gestures, performance, backup/network privacy and update behavior verified.
- [ ] Private signing key backup, signed release install/update, capacity/recovery/rollback evidence completed.
- [ ] Accurate legal privacy policy/contact published and public distribution route selected.
- [ ] Public deployment and delivery mode explicitly authorized.

Live PRC metadata retrieval/import occurred during worker implementation. No outbound message, name-list upload, provider account creation, public app distribution or signing key creation occurred. Do not present disabled checking, undeployed scheduling or alerts as working.
