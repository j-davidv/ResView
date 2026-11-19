# Live PRC source evidence

## Exam update history from January 2026

The November 19 local backfill checked 846 entries in 11 counted PRC monthly archives. It matched 509 distinct dated posts to 91 exams. The importer reads each official posting date in Philippine time, including announcements about earlier sittings. It uses named professions, exam variants and PRC abbreviations in titles and, for relevant announcements, the article opening or resolution description. A post with multiple named audiences can appear under each exam. The latest card and the history use the same sorted snapshot. [Official 2026 archive](https://www.prc.gov.ph/archives/2026)

Coverage includes matched articles and indexed PRC resolutions and memorandum circulars. Procurement, unverified associations, and notices published only outside the checked archive are outside the feed. The screen shows the last checked window. A failed scan preserves the prior snapshot. An interrupted worker is detected after 36 hours. Closed-month article metadata can be reused for up to 30 days if the title and URL still match. Removing the private cache forces a full recheck. No PDF name lists are read by this importer.

The expanded worker published 99 exam documents and one checkpoint in the demo database, or 100 writes for a successful scan of this catalog. Eight exams had no verified matches. Seeding the picker is a separate, one-time operation. Each Updates open or refresh reads one document. Opening the full list uses the existing snapshot. The earlier three-write daily estimate below applies only to the original two-sitting pilot. The hosted rollout and schedule are documented below.

To run the expanded pilot, start the Firestore emulator on loopback port 8185 and run the following from the repository root with worker and Firebase test dependencies installed. Seed the local picker catalog once. Omit `--seed-catalog` on routine history refreshes.

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8185'
$env:FIREBASE_PROJECT_ID = 'demo-resview-advisories'
node --test firebase/tests/firestore.test.mjs
python -m worker.exam_history --cache .development/history-cache --publish-demo --seed-catalog
Set-Location app
flutter run -t lib/main_pilot.dart -d <android-emulator-id>
```

For a USB-connected phone, run `adb reverse tcp:8185 tcp:8185` for that device and add `--dart-define=RESVIEW_USB=true` to the pilot launch. The end-to-end check runs with `flutter test integration_test/advisory_pilot_test.dart -d <android-emulator-id> --dart-define=RESVIEW_LOCAL_ADVISORY_TEST=true`.

### November 19 production readiness check

Billing is disabled and the default database is eligible for the free tier. Over November 4-17, the highest observed daily counts were 6,234 reads and 3,000 writes. One expanded daily scan would bring the observed write peak to 3,100 before retries. The historical API response-size metric reported about 2.24 MB for the month to date. That metric samples API payloads and does not establish billable Firestore transfer. The 99 local exact-read exam responses averaged 5,313 bytes and peaked at 25,443 bytes. At that maximum size, 10,000 additional feed reads per day would produce about 7.35 GiB of response payload over 31 days, excluding existing traffic and overhead. The quota is 10 GiB per month. [Firestore quotas](https://firebase.google.com/docs/firestore/quotas)

Both attempts of the dedicated read-only GitHub Actions check ended in a connection refusal during source setup, before any archive read. The two preceding scheduled monitor runs failed at the same stage. The official year archive loaded on the workstation through the worker's source policy. A follow-up on GitHub's standard Linux ARM runner also ended in connection refusal during source setup. The rollout requires a hosted runner with verified PRC access. [Standard Linux check](https://github.com/j-davidv/ResView/actions/runs/44466922683) [Linux ARM check](https://github.com/j-davidv/ResView/actions/runs/44467576640)

### Hosted archive reader

The Supabase source check returned HTTP 200 for the PRC robots file, year index, July index and the Landscape Architects rescheduling article. The deployed reader accepts only an authenticated request to an allowlisted public PRC route. The Python worker still checks robots rules, bounded responses, redirects, archive counts and posting dates. The reader has no Firebase credentials. GitHub invokes it in Singapore, the same Supabase region that passed the source checks, and uses the existing workflow identity for Firebase publication. [Supabase regional invocations](https://supabase.com/docs/guides/functions/regional-invocation)

A warm scan through the reader made 55 requests and returned 8,832,348 bytes for 99 exam feeds. Thirty-one similar daily scans would return about 274 MB before protocol overhead, within the 5 GB Supabase Free egress allowance before existing usage. Cold scans and daily source volume vary. [Supabase pricing](https://supabase.com/pricing)

The full hosted read-only scan found 510 distinct articles matched to 91 exams. The first hosted production run then refreshed 99 exam documents. Anonymous exact document reads returned 17 Architect, 7 Landscape Architect, and 13 Master Plumber notices, newest first. Anonymous listing and reads of the private checkpoint were denied. The internet-connected Android build loaded Results and All updates on an Infinix X6710 with the USB data tunnel removed. Firebase billing remains disabled. [Full hosted dry run](https://github.com/j-davidv/ResView/actions/runs/44469196788) [Live Firebase refresh](https://github.com/j-davidv/ResView/actions/runs/44471639930)

The daily GitHub refresh is enabled at 02:13 UTC (10:13 a.m. Taipei and Philippine time). The first timed run has yet to be observed. The existing hourly PRC monitor retains its original cron and worker. The production archive reader's dedicated token is configured only in Supabase and GitHub Actions. The refresh requires no workstation.

## November 18, 2026 · Schedule-change pilot qualification

The pilot covers PRC news articles in the July 1–31, 2026 archive (Philippine time), for two domestic sittings and their `all` category. The official year index reported 86 July entries. All 86 appeared on one month page, inside a year accordion, with no next-page link. An absent row, unexpected pagination or count mismatch makes a scan incomplete. The same index check found 118 October and 46 November entries on their respective pages. The general news index had 341 pages at inspection. [PRC year index](https://www.prc.gov.ph/archives/2026) · [July archive](https://www.prc.gov.ph/archives/2026/202607) · [General news](https://www.prc.gov.ph/articles)

PRC posted the Landscape Architects rescheduling on July 15. The article moves the July sitting to July 14–15 and links Resolution 2209. The schedule names NCR and Cebu under that same resolution. Both the parsed schedule and an anonymous Firestore read identified the active `landscape-architects-2026-07-14/all` sitting. PRC had also announced the return to a two-day exam on July 3. The articles print the posting date as “Posted on 15 July, 2026” or “Posted on 3 July, 2026”. The stored date represents midnight in the Philippines. [Rescheduling notice](https://www.prc.gov.ph/article/rescheduling-landscape-architects-licensure-examination) · [Two-day schedule notice](https://www.prc.gov.ph/article/removing-manual-drawing-component-landscape-architects-licensure-examination-lale-and) · [Annual schedule](https://www.prc.gov.ph/2026-schedule-examination)

The July 16 release names the same examination and centers and discusses registration. It belongs in Results. The two generically titled July public notices concern network maintenance. The pilot pins their article contents along with the two schedule notices and checks the remaining reviewed archive titles and URLs on every scan. A new or changed item requiring review prevents a checked-empty claim. The July 11 Master Plumbers sitting was active on public read-back and had no qualifying article in this archive. The window excludes standalone resolutions, regional social media and articles posted in other months. [Result publication](https://www.prc.gov.ph/article/july-2026-landscape-architects-computer-based-licensure-examination-results-released-one-1) · [July 30 maintenance notice](https://www.prc.gov.ph/article/notice-public-3) · [July 31 maintenance notice](https://www.prc.gov.ph/article/notice-public-4)

### Local read-back and operating cost

A normal pilot scan makes nine bounded HTTPS requests: two robots files, the year and month indexes, the annual schedule and four reviewed news articles. The local Firestore emulator returned two notices for Landscape Architects, an empty verified snapshot for Master Plumbers and a missing document for an uncovered sitting through anonymous exact reads. Clients cannot list the feeds, write any snapshot or read the private review record. A missing reviewed article or changed testing centers requires review, including for a sitting with zero notices. A failed scan marks the last successful snapshot stale. Both public snapshots and the worker checkpoint change in one transaction.

For this closed archive the proposed cadence is daily. After 36 hours a client treats a missed check as stale. Each successful scan adds one checkpoint read and three writes, including the checkpoint. A review issue adds one private write. Each Updates open or refresh adds one exact document read. Retries can add requests and transaction reads. The October worker estimate was 14,280 daily writes. A daily pilot would bring that estimate to 14,283, against the free allowance of 20,000 writes and 50,000 reads per day. On November 19 (Taipei), the Cloud Billing API reported billing disabled for resview-9240c and Firestore reported the default database eligible for the free tier. Cloud Monitoring peaks over November 4-17 (14 complete Pacific days) were 6,234 document reads and 3,000 writes per day. A successful two-feed scan would add one read and three writes before client traffic. Peak data and index storage over the preceding 24 hours was 3,190,915 bytes. These operational metrics support the two-feed pilot at observed traffic. They do not establish billable monthly outbound transfer or predict demand from broader coverage. [Worker budget estimate](prc-update-verification.md#hosted-execution-and-capacity) · [Firestore quotas](https://firebase.google.com/docs/firestore/quotas)

The pilot command is restricted to a loopback Firestore emulator and the `demo-resview-advisories` project. Its read rule lives under `firebase/tests/`. Production rules, scheduling and navigation remain on Release 1.

The original two-sitting scan remains available through the isolated worker command `--advisories-only`. The current Android integration check uses the exam history described above.

## October 30: automatic retrieval through the official Drive API

The later owner instruction requires automatic PDF retrieval. The documented Google Drive API is a permitted API route distinct from the browser download route: the existing worker identity obtains `drive.readonly` OAuth access and must pass owner `capabilities.canDownload` and restriction checks before retrieving content. No owner-disabled download, browser robots restriction, viewer extraction or private API is bypassed. PRC website requests retain their existing robots checks.

[Hosted run 41018013099](https://github.com/j-davidv/ResView/actions/runs/41018013099) retrieved the approved Ocular Pharmacologists PDF automatically, matched all 270,838 bytes' SHA-256 to the preserved original, and passed extraction validation. The public names asset remained unchanged; the job log contains no real sample name. One private reviewed profile is automated. See [retrieval verification and limits](prc-update-verification.md#hosted-automatic-pdf-retrieval). The earlier browser-route restrictions below remain historical source evidence and do not establish an API authorization failure.

## October 15 source checks

Checked 2026-10-15, Asia/Taipei. The owner instructed public PRC access without a separate permission approval. This supersedes the earlier approval gate; actual source access controls remain binding. No private PRC account, ratings, personal identifiers or contact request was used.

Successfully retrieved through normal HTTPS:

- [PRC robots rules](https://www.prc.gov.ph/robots.txt): the public schedule/result/article routes are not disallowed. Robots rules are not presented as a reuse license.
- [2026 schedule](https://www.prc.gov.ph/2026-schedule-examination): 99 distinct official labels, including written/practical/SPLE variants; 87 numbered sittings with recognized dates. Other rows are held for review.
- [Latest results](https://www.prc.gov.ph/articles/exam-results): eight links observed; five unambiguously associated with Professional Foresters, Naval Architects, Fisheries Professionals, Civil Engineers and Geodetic Engineers. Three mappings require review.
- [October 2026 Foresters result](https://www.prc.gov.ph/article/october-2026-professional-foresters-licensure-examination-results-released-two-2-working): published 13 October; scheduled sitting 8–9 October. Only the successful-examinee list is eligible for checking; topnotchers, school performance and sidebar PDFs are excluded.

The Foresters article directly links [its successful-examinee list](https://drive.google.com/file/d/1IuIsJK2t02ScD1Wq5weJbz7-kZdCwFcU/view?usp=sharing). The public viewer loads. A normal download returned HTTP 200 **HTML** explicitly stating that the owner disabled downloading and only owners/editors can download. No alternate host, private API, viewer extraction or restriction workaround was attempted. This route cannot enable automatic checking. Other current lists have not passed download/format validation either.

Actual metadata was imported into the existing Firebase project. Populated unauthenticated queries verified the Foresters catalog, correct sitting date, publication, unavailable-checking fallback and scan health. Private reads remain denied. Repeated scans retained five publication/current-version records without duplicates. No original/derived name list was uploaded and no entered name or personal outcome was collected. Raw responses remain ignored under `.development/`.

The latest feed is not evidence of absence for historical sittings. Freshness belongs to each successfully fetched selection; an unrelated scan cannot renew it. No checking profile is enabled.

Cloud deployment check (2026-10-15): the worker is published and GitHub OIDC authentication succeeds. Normal HTTPS connections from GitHub's runner to both public PRC hostnames (`122.53.86.248`) fail with `ConnectionRefusedError`, including robots requests. This differs from successful workstation access. No proxy/restriction workaround was used. The schedule remains disabled pending a successful cloud scan; see [deployment evidence](worker-deployment-review.md).
