# All-exam PRC coverage audit

Source snapshot: November 23, 2026; verification completed November 24 (Asia/Taipei). This audit compares anonymous production reads with the official 2026 PRC schedule and every counted monthly archive from January through November. The initial audit read production without changing it. The fixes were subsequently deployed as recorded below. Counts and future/in-progress labels in the original audit use its November 23 snapshot.

## Deployment verified November 24, 2026

The code is published in [commit 18d7867](https://github.com/j-davidv/ResView/commit/18d7867040e2a9bb0e6f1523cbf4f18026176dfa). Supabase `prc-archive` version 2 is active with its existing authentication settings. [Production run 45217741768](https://github.com/j-davidv/ResView/actions/runs/45217741768) passed worker tests, the results monitor, and the exam-history refresh on that revision. The existing hourly result monitor and daily history refresh remain enabled.

Independent anonymous reads verified the Nutritionist-Dietitians publication for the November 12 sitting, the CPA SPLE notice in its own feed and absent from domestic CPAs, and all 15 Criminologists notices including the official `/index.php/` resolution. All 99 update feeds have the new successful-check timestamp, `2026-11-23T16:33:23.528231+00:00` (November 24 at 00:33:23 Taipei): 92 contain notices and seven are checked empty. The results monitor reports a fresh successful check at `2026-11-23T16:33:22.501737+00:00`.

[ResView 1.0.1](https://github.com/j-davidv/ResView/releases/tag/v1.0.1), Android build 3, contains the app-side source URL fix. Its 57,514,581-byte APK was signed with the existing release certificate and verified as `org.resview.app`, version `1.0.1`, code `3`, without the debuggable flag. APK SHA-256: `085700a9661feb05094b0e649a4480c58f24635e5082feab61f4d2b245d1d2aa`. An independent unauthenticated download matched that exact byte count and digest. Existing users receive shared data changes on refresh and need to install the APK for the app-side fix.

## Original audit

The database contains 99 exam labels (including SPLE and exam phases), 159 active sittings, and 126 publication associations. The archives contain 867 entries; 723 eligible news/issuance pages were fetched and checked for posting date and archive month. There are 93 distinct result announcements. The local corrected scan matches updates to 92 exam labels.

Production results last checked: `2026-11-23T15:38:51.128673+00:00`. Production updates last checked: `2026-11-23T10:47:22.968069+00:00`. Source replay began: `2026-11-23T15:59:12.489207+00:00`. These are separate checks; one does not renew the other.

## Confirmed bugs

- Nutritionist-Dietitians: the schedule uses the singular first word, while the November result title uses **Nutritionists-Dietitians**. The results matcher now accepts that published form. The corrected association targets the November 12 sitting. The announcement was already present in Updates.
- CPA SPLE: the May release says **Special Prof. Licensure Exam.** The update matcher previously filed it under domestic CPAs. It now belongs only to CPA SPLE. The Results association was already correct.
- Official resolutions and memorandum circulars under `/index.php/` were skipped by the importer and rejected by the hosted reader and app. PRC moved Resolution 2141 to this route, which would have removed an existing Criminologists testing-center notice on the next refresh. All three layers now accept the exact official route variants; the replay preserves all 15 Criminologists updates.

Regression tests reproduced these failures before the changes. All 90 worker tests and all five Flutter update-feed tests pass. Hosted route assertions preserve the permitted routes and reject unrelated paths and queries.

The full Flutter suite reports 73 passing tests and 10 failures in screenshot comparisons (`visual_test.dart`). Those screenshot differences were not investigated or accepted as new baselines in this coverage task. Generated failure images are retained with the local audit evidence; tracked comparison artifacts were restored.

The source-to-production result comparison contains 127 expected associations against 126 stored associations: exactly one missing association (Nutritionist-Dietitians), no unexpected stored associations, and no changed reviewed mapping fingerprints. The January Professional Electronics Engineers and February Professional Mechanical Engineers releases still have no established sitting mapping; the August mechanical and October electronics releases retain partial regional mappings.

## Results with no production announcement

| Exam label | Explanation at the audit date |
| --- | --- |
| Aeronautical Engineers (SPLE) | May SPLE sitting is listed in the schedule; no matching result/update post found in the checked archive. This does not establish cancellation or zero passers. |
| Agricultural and Biosystems Engineers | November 19–20 sitting has ended; no result announcement found in the checked archive or latest results index. |
| Agriculturists | Future sitting starts 2026-12-01; no 2026 result announcement found in the checked archive. |
| Dental Technologists (Practical) | Future sitting starts 2026-12-08; no 2026 result announcement found in the checked archive. |
| Dental Technologists (Written-CBLE) | Future sitting starts 2026-12-07; no 2026 result announcement found in the checked archive. |
| Environmental Planners (SPLE) | May SPLE sitting is listed in the schedule; no matching result/update post found in the checked archive. This does not establish cancellation or zero passers. |
| Geologists | Future sitting starts 2026-11-25; no 2026 result announcement found in the checked archive. |
| Nutritionist-Dietitians | Confirmed import bug; November 19 official release exists. Fixed locally. |
| Physical Therapists (SPLE) | May SPLE sitting is listed in the schedule; no matching result/update post found in the checked archive. This does not establish cancellation or zero passers. |
| Psychologists (SPLE) | May SPLE sitting is listed in the schedule; no matching result/update post found in the checked archive. This does not establish cancellation or zero passers. |
| Radiologic Technologists | Future sitting starts 2026-12-10; no 2026 result announcement found in the checked archive. |
| Sanitary Engineer (SPLE) | May SPLE sitting is listed in the schedule; no matching result/update post found in the checked archive. This does not establish cancellation or zero passers. |
| X-Ray Technologists | Future sitting starts 2026-12-10; no 2026 result announcement found in the checked archive. |
| X-Ray Technologists (SPLE) | May SPLE sitting is listed in the schedule; no matching result/update post found in the checked archive. This does not establish cancellation or zero passers. |

## Releases without passers-list links

Six SPLE announcements contain no successful-examinee list. Each official article explicitly reports that nobody passed; the release itself remains accessible through its PRC announcement link. These are expected missing lists, rather than missing result announcements.

- [May 2026 Chemical Technicians Special Professional Licensure Examination Results Released](https://www.prc.gov.ph/article/may-2026-chemical-technicians-special-professional-licensure-examination-results-released)
- [May 2026 Customs Brokers Special Professional Licensure Examination Results Released](https://www.prc.gov.ph/article/may-2026-customs-brokers-special-professional-licensure-examination-results-released)
- [May 2026 Medical Technologists Special Professional Licensure Examination Results Released](https://www.prc.gov.ph/article/may-2026-medical-technologists-special-professional-licensure-examination-results-released)
- [May 2026 Professional Food Technologists Special Professional Licensure Examination Results Released](https://www.prc.gov.ph/article/may-2026-professional-food-technologists-special-professional-licensure-examination-results)
- [May 2026 Radiologic Technologists Special Professional Licensure Examination Results Released](https://www.prc.gov.ph/article/may-2026-radiologic-technologists-special-professional-licensure-examination-results)
- [May 2026 Respiratory Therapists Special Professional Licensure Examination Results Released](https://www.prc.gov.ph/article/may-2026-respiratory-therapists-special-professional-licensure-examination-results-released)

## Every exam label

Results are production publication associations, including separate teacher categories and regional sittings. “List links” counts associations with at least one published direct or qualified successful-examinee link; it does not confirm document availability or validate individual names. Update counts compare the production snapshot with the corrected local source replay.

| Exam label | Active sittings | Results | List links | Updates live → verified |
| --- | ---: | ---: | ---: | ---: |
| Aeronautical Engineers | 1 | 1 | 1 | 7 → 7 |
| Aeronautical Engineers (SPLE) | 1 | 0 | 0 | 0 → 0 |
| Agricultural and Biosystems Engineers | 1 | 0 | 0 | 2 → 2 |
| Agriculturists | 1 | 0 | 0 | 8 → 8 |
| Agriculturists (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Architect (SPLE) | 1 | 1 | 1 | 2 → 2 |
| Architects | 2 | 2 | 2 | 17 → 17 |
| Certified Plant Mechanics | 2 | 2 | 2 | 11 → 11 |
| Certified Plant Mechanics (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Certified Public Accountants | 2 | 2 | 2 | 18 → 17 |
| Certified Public Accountants (SPLE) | 1 | 1 | 1 | 0 → 1 |
| Chemical Engineers | 2 | 2 | 2 | 7 → 7 |
| Chemical Engineers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Chemical Technician (SPLE) | 1 | 1 | 0 | 1 → 1 |
| Chemical Technicians | 1 | 1 | 1 | 11 → 11 |
| Chemists | 1 | 1 | 1 | 11 → 11 |
| Civil Engineers | 2 | 2 | 2 | 23 → 23 |
| Civil Engineers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Criminologists | 2 | 2 | 2 | 15 → 15 |
| Criminologists (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Customs Broker (SPLE) | 1 | 1 | 0 | 1 → 1 |
| Customs Brokers | 1 | 1 | 1 | 3 → 3 |
| Dental Hygienists (Practical) | 1 | 1 | 1 | 5 → 5 |
| Dental Hygienists (Written-CBLE) | 1 | 1 | 1 | 5 → 5 |
| Dental Technologists (Practical) | 1 | 0 | 0 | 1 → 1 |
| Dental Technologists (Written-CBLE) | 1 | 0 | 0 | 1 → 1 |
| Dentists (Practical) | 2 | 1 | 1 | 7 → 7 |
| Dentists (Written) | 2 | 1 | 1 | 7 → 7 |
| Electronics Engineers | 2 | 2 | 2 | 10 → 10 |
| Electronics Engineers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Electronics Technicians | 2 | 2 | 2 | 10 → 10 |
| Electronics Technicians (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Environmental Planners | 1 | 1 | 1 | 11 → 11 |
| Environmental Planners (SPLE) | 1 | 0 | 0 | 0 → 0 |
| Fisheries Professionals | 1 | 1 | 1 | 5 → 5 |
| Food Technologist (SPLE) | 1 | 1 | 0 | 1 → 1 |
| Foreign Medical Professionals | 1 | 1 | 1 | 1 → 1 |
| Geodetic Engineers | 1 | 1 | 1 | 5 → 5 |
| Geologists | 1 | 0 | 0 | 0 → 0 |
| Guidance Counselors | 1 | 1 | 1 | 8 → 8 |
| Interior Designers | 1 | 1 | 1 | 8 → 8 |
| Landscape Architects | 1 | 1 | 1 | 7 → 7 |
| Librarians | 1 | 1 | 1 | 4 → 4 |
| Master Plumbers | 2 | 2 | 2 | 13 → 13 |
| Master Plumbers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Mechanical Engineers | 2 | 2 | 2 | 12 → 12 |
| Mechanical Engineers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Medical Technologists | 2 | 2 | 2 | 17 → 17 |
| Medical Technologists (SPLE ) | 1 | 1 | 0 | 1 → 1 |
| Metallurgical Engineers | 1 | 1 | 1 | 5 → 5 |
| Midwives | 2 | 2 | 2 | 11 → 11 |
| Midwives (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Mining Engineers | 1 | 1 | 1 | 4 → 4 |
| Naval Architects | 1 | 1 | 1 | 4 → 4 |
| Nurses | 2 | 2 | 2 | 35 → 35 |
| Nurses (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Nutritionist-Dietitians | 1 | 0 | 0 | 6 → 6 |
| Occupational Therapists | 2 | 1 | 1 | 6 → 6 |
| Ocular Pharmacologists | 1 | 1 | 1 | 3 → 3 |
| Optometrists (Practical) | 1 | 1 | 1 | 8 → 8 |
| Optometrists (Written-CBLE) | 1 | 1 | 1 | 10 → 10 |
| Pharmacists | 2 | 2 | 2 | 12 → 12 |
| Physical Therapists | 2 | 1 | 1 | 9 → 9 |
| Physical Therapists (SPLE) | 1 | 0 | 0 | 0 → 0 |
| Physicians | 2 | 2 | 2 | 12 → 12 |
| Professional Electrical Engineers (Oral Examination) | 7 | 4 | 4 | 9 → 9 |
| Professional Electronics Engineer Oral Examination | 1 | 1 | 1 | 14 → 14 |
| Professional Electronics Engineers (Oral Examination) | 8 | 7 | 7 | 14 → 14 |
| Professional Food Technologists | 1 | 1 | 1 | 7 → 7 |
| Professional Foresters | 1 | 1 | 1 | 6 → 6 |
| Professional Mechanical Engineers (Technical Evaluation) | 23 | 12 | 12 | 21 → 21 |
| Professional Teachers | 2 | 2 | 2 | 20 → 20 |
| Professional Teachers (SPLE) | 1 | 2 | 2 | 3 → 3 |
| Psychologists | 1 | 1 | 1 | 15 → 15 |
| Psychologists (SPLE) | 1 | 0 | 0 | 0 → 0 |
| Psychometricians | 1 | 1 | 1 | 13 → 13 |
| Psychometricians (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Radiologic Technologists | 1 | 0 | 0 | 5 → 5 |
| Radiologic Technologists (SPLE) | 1 | 1 | 0 | 1 → 1 |
| Real Estate Appraisers | 1 | 1 | 1 | 7 → 7 |
| Real Estate Appraisers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Real Estate Brokers | 1 | 1 | 1 | 8 → 8 |
| Real Estate Consultants (Revalida) | 2 | 2 | 2 | 5 → 5 |
| Real Estate Consultants (Written) | 1 | 1 | 1 | 5 → 5 |
| Registered Electrical Engineers | 2 | 2 | 2 | 13 → 13 |
| Registered Electrical Engineers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Registered Master Electricians | 2 | 2 | 2 | 12 → 12 |
| Registered Master Electricians (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Respiratory Therapists | 1 | 1 | 1 | 9 → 9 |
| Respiratory Therapists (SPLE) | 1 | 1 | 0 | 1 → 1 |
| Sanitary Engineer (SPLE) | 1 | 0 | 0 | 0 → 0 |
| Sanitary Engineers | 2 | 2 | 2 | 11 → 11 |
| Social Workers | 1 | 1 | 1 | 7 → 7 |
| Social Workers (SPLE) | 1 | 1 | 1 | 1 → 1 |
| Speech-Language Pathologists | 2 | 1 | 1 | 6 → 6 |
| Veterinarians | 1 | 1 | 1 | 5 → 5 |
| Veterinary Medicine (SPLE) | 1 | 1 | 1 | 1 → 1 |
| X-Ray Technologists | 1 | 0 | 0 | 5 → 5 |
| X-Ray Technologists (SPLE) | 1 | 0 | 0 | 0 → 0 |

## Sittings without a production result association

An exam can have results for one sitting and none for another. These rows use the current official schedule. Professional oral/technical evaluation releases need regional evidence; an absent match is not proof that PRC has not released a result.

| Exam label | Sitting start | Scope | Status |
| --- | --- | --- | --- |
| Aeronautical Engineers (SPLE) | 2026-05-29 | Hong Kong | No production association |
| Environmental Planners (SPLE) | 2026-05-29 | Singapore | No production association |
| Physical Therapists (SPLE) | 2026-05-29 | Taiwan | No production association |
| Psychologists (SPLE) | 2026-05-29 | Hong Kong and Singapore | No production association |
| Sanitary Engineer (SPLE) | 2026-05-29 | Singapore | No production association |
| X-Ray Technologists (SPLE) | 2026-05-29 | Hong Kong | No production association |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-08-24 | Iloilo | Regional oral/technical evaluation mapping requires evidence |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-09-01 | Davao | Regional oral/technical evaluation mapping requires evidence |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-09-14 | Cebu | Regional oral/technical evaluation mapping requires evidence |
| Professional Teachers | 2026-09-20 | domestic | No production association |
| Professional Electrical Engineers (Oral Examination) | 2026-09-21 | Davao | Regional oral/technical evaluation mapping requires evidence |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-09-29 | Baguio | Regional oral/technical evaluation mapping requires evidence |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-10-19 | NCR | Regional oral/technical evaluation mapping requires evidence |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-11-09 | Butuan | Regional oral/technical evaluation mapping requires evidence |
| Nutritionist-Dietitians | 2026-11-12 | domestic | Confirmed matcher bug; fixed locally |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-11-13 | Dubai, United Arab Emirates | Regional oral/technical evaluation mapping requires evidence |
| Agricultural and Biosystems Engineers | 2026-11-19 | domestic | No production association |
| Professional Electronics Engineers (Oral Examination) | 2026-11-19 | Davao | Regional oral/technical evaluation mapping requires evidence |
| Dentists (Written) | 2026-11-22 | domestic | In progress |
| Geologists | 2026-11-25 | domestic | Future sitting |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-11-25 | Tacloban | Future sitting |
| Dentists (Practical) | 2026-11-28 | domestic | Future sitting |
| Professional Electrical Engineers (Oral Examination) | 2026-11-29 | Dubai, United Arab Emirates | Future sitting |
| Speech-Language Pathologists | 2026-11-29 | domestic | Future sitting |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-11-30 | Cagayan de Oro, Cebu | Future sitting |
| Agriculturists | 2026-12-01 | domestic | Future sitting |
| Occupational Therapists | 2026-12-04 | domestic | Future sitting |
| Physical Therapists | 2026-12-05 | domestic | Future sitting |
| Dental Technologists (Written-CBLE) | 2026-12-07 | domestic | Future sitting |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-12-07 | Cebu | Future sitting |
| Dental Technologists (Practical) | 2026-12-08 | domestic | Future sitting |
| Professional Electrical Engineers (Oral Examination) | 2026-12-09 | NCR | Future sitting |
| Radiologic Technologists | 2026-12-10 | domestic | Future sitting |
| X-Ray Technologists | 2026-12-10 | domestic | Future sitting |
| Professional Mechanical Engineers (Technical Evaluation) | 2026-12-14 | NCR | Future sitting |

## Limits and remaining work

- Service deployment and the initial production refresh are complete. Existing Android users need version 1.0.1 for the app-side source URL fix.
- Seven exam labels remain without a verified update match after the CPA SPLE correction: Aeronautical Engineers SPLE, Environmental Planners SPLE, Geologists, Physical Therapists SPLE, Psychologists SPLE, Sanitary Engineer SPLE, and X-Ray Technologists SPLE.
- Four previously documented regional oral/technical evaluation releases retain unresolved sitting evidence; confirmed associations remain imported. See [mapping review](prc-mapping-review.md).
- Standalone PDFs, regional social posts, and sources outside the counted archives are not evidence of archive completeness. The six old SPLE gaps require additional official evidence before being described as cancelled or having no examinees.
- No passer-name extraction, new checking profile, or PDF download was performed. This checks announcement/update coverage and published links.

Sources: [2026 schedule](https://www.prc.gov.ph/2026-schedule-examination), [2026 archive](https://www.prc.gov.ph/archives/2026), [latest exam results](https://www.prc.gov.ph/articles/exam-results). Raw anonymous reads, cached source HTML, source-to-production comparison, and test output are retained locally under ignored `.development/coverage-audit/`.
