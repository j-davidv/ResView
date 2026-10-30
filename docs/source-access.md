# Live PRC source evidence

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
