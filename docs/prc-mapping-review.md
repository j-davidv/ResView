# PRC mapping review

Reviewed October 30, 2026. Task 3 is partially complete: archive discovery and schedule rollover are implemented. Four publications still need additional sitting evidence; two of those now have mappings for their confirmed regional sittings.

## October 30 follow-up

Three previously unresolved announcements now have complete reviewed associations:

- The September foreign-medical qualifying assessment belongs to `foreign-medical-professionals-2026-09-01`. The schedule already contained it; a hyphen in `Assessment-Foreign` prevented the title match. The shared matcher now accepts punctuation boundaries while continuing to reject names embedded inside other words.
- The April Professional Electrical Engineers release maps to Doha January 22–28, Dubai February 26–March 4, and NCR April 15–17. Resolution 2138 (2025), pages 1–2, establishes the overseas dates; resolution 2163 (2026), page 2, establishes NCR and its April 28 target release. The announcement names all three locations and was published April 28.
- The September Professional Electrical Engineers release maps to Cagayan de Oro August 3–5, with September 10 target release and September 14 actual publication. Resolution 2163, page 2, separates it from Davao September 21–23, whose target release is December 15. Matching the September article to the September examination would have selected the wrong location.

Two more announcements have partial reviewed associations. The August Professional Mechanical Engineers release maps to twelve regional sittings from April through August; the October Professional Electronics Engineers release maps to eight sittings from April through October. The joins are inferences supported by the resolution's release groups and the announcement's locations, with supplemental schedules from resolutions 2158, 2189 and 2251. They do not establish dates for locations omitted from those schedules. `unresolvedSittings` in the reviewed configuration keeps both announcements in `workerReview`, even after their established mappings are imported.

The January electronics, February mechanical, August mechanical and October electronics full-text result documents were tested through Google's normal download route. Each returned HTML saying that only the owner and editors can download. No viewer-content extraction or alternate download route was used.

Rollover now uses UTC+08:00 for the current year, including the eight hours before UTC reaches January 1. A regression check fails when the new local year's schedule is absent.

The live follow-up also exposed PRC switching article links between `/index.php/article/` and `/article/`. Mapping/profile lookup, discovery deduplication, publication IDs and private review IDs now treat those routes and PRC's two hostnames as aliases. The actual fetched URL remains in publication provenance. After the corrected import, 13 duplicate public publication documents were archived privately and removed transactionally. Three duplicate review entries now point to their canonical review records. This prevents old reviewed mappings from being bypassed when PRC changes a link's route.

Official resolution evidence, retained privately as the original PDF bytes:

| Resolution | Review | SHA-256 |
| --- | --- | --- |
| [2138 (2025)](https://www.prc.gov.ph/sites/default/files/2025-2138%20Scheduling%20The%20PEE%20Oral%20Examination%20Doha%20Qatar%20%20and%20Dubai%20UAE.pdf) | Both pages visually reviewed. | `eb165222b7af477f098286653f85980228a3c00f244e8427e6b3a34cad9c0b8f` |
| [2163 (2026)](https://www.prc.gov.ph/sites/default/files/Reso%202026-2163%20Scheduling%20The%20Technical%20Evaluation%20For%20PME,%20Oral%20Examination%20For%20EE,%20ECE.pdf) | Schedule tables on pages 2–3 visually reviewed. The 32.13 MiB PDF was retrieved for manual review with a separate bounded request; the automated worker's size limits were not changed. | `4bcb4db33cb1960a49c8d436d247b948d9d31addf742dfec98e669840045ac58` |
| [2158 (2026)](https://www.prc.gov.ph/sites/default/files/2026-2158%20Scheduling%20the%20Professional%20Mechanical%20Engineers%20Technical%20Evaluation%20in%20Pampanga%20on%2014%20to%2016%20April%202.pdf) | Establishes San Fernando City, Pampanga on April 14–16. | `aae1f1012c3f945ba2235a1d99ef851b5b8bebc0dfc345ad55ade8cc0a5b4272` |
| [2189 (2026)](https://www.prc.gov.ph/sites/default/files/2026-2189%20Scheduling%20Professional%20Electronics%20Engineers%20Oral%20Examination%20In%20Singapore%20On%2023%20And%2024%20July%202026.pdf) | Establishes Singapore July 23–24. | `35041ee549d30ae9234fd28ba629d6c0ec2c210f0fa54c3bd141b5ccf4e0e61f` |
| [2251 (2026)](https://www.prc.gov.ph/sites/default/files/2026-2251%20Additional%20Schedule%20For%20The%20Professional%20Electronics%20Engineers%20Oral%20Examination%20In%20The%20National.pdf) | Establishes additional NCR examination days on October 8, 9 and 12. | `38c050a51c5c6dc03fd52ce19579e161deba9a36276950ce6bff3ca14f6efda6` |

The worker now follows the [official schedule menu](https://www.prc.gov.ph/exam-schedules-menu) for schedules from 2026 through the next calendar year. It requires the current year's schedule and fails with stale health if that schedule is missing. It preserves each year's source ownership when retiring removed sittings. The menu currently lists 2026; 2027 rollover is covered by synthetic tests, not a live 2027 schedule.

Historical discovery follows the results index's next-page links, checks article publication dates in UTC+08:00, and stops after a page entirely before 2026. The October 29 scan inspected twelve index pages and 96 articles, including the older boundary page. Of those, 86 announcements were published in 2026. The October 30 configuration has 120 exam/sitting/category associations across 84 announcements, including two partially mapped announcements. Pagination cycles, unexpected routes and the 100-page limit fail the scan rather than claiming complete coverage. This establishes coverage of the official results index, not proof that PRC has placed every announcement in that index.

## Mapping decisions

- Combined announcements attach to each named exam separately. Ordinary engineer results cannot match professional oral/technical-evaluation announcements. SPLE results cannot match domestic sittings. Short aliases cannot override a more specific exam name.
- Professional Teachers sittings expose Elementary and Secondary categories. The announcement is shared metadata; each future name-list profile must still validate its own category.
- Written/practical, written/revalida and oral/technical announcements use ten explicit, article-version-pinned mappings in `worker/config.json`. A changed article returns to review. The January revalida uses January 13–14, as stated by the result announcement, rather than January 12–14 from the schedule.
- Twelve exact-row schedule decisions cover rescheduling, location-specific date spans, and one cancellation. Criminologists include the February 8 reschedule; June Architects include June 22/24; Landscape Architects use July 14/15; Psychologists and Psychometricians span September 1–18, including the Pampanga reschedule; Nurses span August 29–September 12. These spans do not imply examination on every intervening day.
- [Resolution 2192](https://www.prc.gov.ph/sites/default/files/2026-2192%20Approving%20The%20Additional%20Days%20For%20The%20PME%20Technical%20Evaluation%20In%20Lucena.pdf) confirms the added technical-evaluation days. [Resolution 2235](https://www.prc.gov.ph/sites/default/files/2026-2235%20Cancelling%20the%20Second%20Day%20of%20the%20Guidance%20Counselors.pdf) moves the second Guidance Counselors day to August 23. The scanned [Resolution 2234](https://www.prc.gov.ph/sites/default/files/2026-2234%20Cancellation%20of%20the%20August%202026%20Professional%20Electronics%20Engineers%20Oral%20Examination%20in%20Cebu.pdf) was visually reviewed and cancels the August 13–14 Cebu oral examination.
- Unknown annotations remain in review. Exact-row overrides stop applying when the official date or testing-center text changes. Resolved private review records are retained with a resolution timestamp; the cancelled row retains a cancellation status.
- Older announcements remain available without switching a selection back to an older result version. No checking profile, names asset, or outbound delivery is enabled.

## Unresolved publications

The following associations remain unconfirmed after the October 30 review. A release month alone is insufficient; the full-text downloads also remain owner-restricted.

| Publication | Missing evidence |
| --- | --- |
| [January Professional Electronics Engineers](https://www.prc.gov.ph/index.php/article/january-2026-results-technical-evaluation-upgrading-professional-electronics-engineers) | January evaluation dates are absent from the inspected 2026 schedule. |
| [February Professional Mechanical Engineers](https://www.prc.gov.ph/index.php/article/february-2026-results-technical-evaluation-upgrading-professional-mechanical-engineers) | February dates for the listed locations are absent from the inspected schedule. |
| [August Professional Mechanical Engineers](https://www.prc.gov.ph/article/august-2026-professional-mechanical-engineers-oral-examinationtechnical-evaluation-results) | Twelve regional sittings mapped. Davao remains unconfirmed: its dated schedule entry is in September with a December target release. |
| [October Professional Electronics Engineers](https://www.prc.gov.ph/index.php/article/october-2026-professional-electronics-engineers-oral-examinationtechnical-evaluation) | Eight sittings mapped. Cebu and Davao remain unconfirmed: Cebu's August sitting was cancelled, and Davao's dated sitting is in November with a December target release. |

To close task 3, obtain an accessible official schedule/resolution or full-text result that establishes those associations, add version-pinned mappings, and verify the public read-back. Do not create fictitious examination dates from publication dates.

## Verification

The 43 worker tests pass. New checks cover cross-month/special dates, annotation rejection, combined exam mappings, teacher categories, rejection of oral-to-ordinary matches, historical version handling, two-year discovery, missing-current-year failure, archive bounds, changed reviewed articles and evidence-based review resolution. October 30 adds punctuation boundaries, partial-mapping review retention, the UTC+08:00 year boundary, stable publication identity with original provenance, and stable review identity across article aliases. `git diff --check` passes.

October 30 live verification: the corrected scan completed with zero publication failures at scan timestamp 01:56:21 UTC (09:56:21 Asia/Taipei). Read-back at 01:58:26 UTC verified 99 exams, 163 sittings (159 active), 120 mapped publication records across 84 canonical announcement URLs, 121 result versions (120 current and one superseded), and 120 selection pointers. All mappings reference active sittings and valid categories; all oral/technical releases attach to oral sittings. Every current version remains `checkingUnavailable` without a names URL and carries this scan's successful-check timestamp. Live public queries/health reads pass and private reads remain denied.

The private review collection now contains 81 resolved entries, four pending issues, 16 retained aliases (13 publications and three reviews), one cancellation and one corrected misassociation. Assertions and the credential-free report are `.development/task3-oct30-verify.py` and `.development/task3-oct30-import-verification.json`. Alias cleanup preserved original metadata in private review documents and `.development/task3-publication-alias-backup.json`. No GitHub push, schedule activation, names profile or outbound delivery occurred.

The initial October 29 workstation import completed with zero publication failures. Its scan timestamp was 11:26:45 UTC (19:26:45 Asia/Taipei); read-back completed at 11:31:35 UTC. Verified totals then: 99 exams, 163 sittings (159 active and four retired), 95 publication records for 79 distinct announcement URLs, 96 result versions (95 current and one superseded), and 95 selection pointers. Every imported selection referenced an active sitting and valid category. All current versions remained `checkingUnavailable` with no names URL. Live unauthenticated app queries and health reads passed; private reads remained denied.

The previous Professional Electronics Engineers oral announcement had been attached to `electronics-engineers-2026-10-17`. After verifying that selection now points to the proper combined Electronics Engineers/Technicians result, the incorrect publication record was archived in private `workerReview` and removed from the public collection in one transaction. Its result version remains superseded. Review counts are 77 resolved, seven pending, one cancelled and one corrected. Verification assertions are saved in `.development/task3-verify.py`; the credential-free result is `.development/task3-import-verification.json`.

Raw pages, resolution PDFs and preparation/read-back evidence are private under ignored `.development/`. No production name-list extraction or Android acceptance is claimed by these worker checks.
