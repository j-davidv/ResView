# Give Results and Updates distinct jobs

Design proposal · November 18, 2026 · [Implementation plan](../plans/2026-11-18-exam-updates.md)

An examinee who has selected an exam sees the same release announcement on two tabs. The first release should give them one place to check the result and open its sources. A later release can give Updates a distinct purpose by answering “Has PRC changed anything I need to do for this sitting?”

## Approaches considered

Renaming Updates to Announcements would keep the same content in both destinations. Building a general PRC news feed immediately would require reliable source coverage and could show irrelevant notices. The recommended sequence delivers a useful first release independently, then restores Updates when a specific official advisory source has demonstrated coverage.

## First release

- Offer **Results** and **Settings** on compact and expanded layouts. Open Results after skipping onboarding or restoring a selection. “Choose my exam” opens the existing picker. Selecting an exam from Results opens its results, and cancelling preserves the previous selection. Keep the Settings selection flow usable.
- Results owns the release status, official publication title and date, links to PRC, and labeled successful-examinee lists. Keep the current release prominent. If other result articles exist for the selection, put them under **Other result publications**, newest first. Show each article once and keep its own list links with it. Preserve manual Find text in supported Drive documents.
- Preserve distinctions among loading, an explicit unreleased state, unavailable information, a known release, and a failed refresh with previous data. A missing result version must still allow access to all known articles. Keep results isolated by exam, sitting and category.
- Update onboarding and selection labels to describe the destination users can open. The first release uses today's result data and saved selection. It requires no worker, Firestore or notification changes.

If the current result version links to an article outside the fetched history, keep that official link and list the fetched articles separately. With no result version, feature the newest known result article. A reschedule can change the sitting identifier. When a saved sitting has been retired, prompt the user to choose a current sitting before showing its information.

## When Updates returns

Keep Results as the default. Restore **Updates** between Results and Settings once a supported advisory category has real, verified coverage. Keep navigation stable across selections, including those with no notices. My proposed first category is **Schedule change**, including postponements. A wrong date or a notice for the wrong region could affect attendance, so the source must explicitly identify the affected sitting and any location or category restriction. Show the official title, category, PRC posting date and **Open PRC notice**. Where only a postponement is confirmed, preserve that wording without inferring a replacement date.

Possible later categories include filing deadlines, room assignments, exam programs, oath-taking and initial registration. Each needs an identifiable official source and a way to match notices to the right audience. A scheduled exam date alone is catalog metadata. A release article that mentions registration stays in Results. General news and result releases do not qualify as advisory cards.

Store advisory records separately from result publications. Current clients treat any result publication as evidence of release. Only publish a notice to an explicitly matched selection. If its region is narrower than the available selection and the audience cannot be identified reliably, hold it for review. One notice can apply to several confirmed selections. Repeated scans must produce one card per notice per selection. Verified corrections update or remove obsolete associations. A temporary fetch failure must preserve previously verified records and indicate that coverage may be stale.

The feed distinguishes a successful scan with zero matches (“No schedule-change notices found for this selection”) from a failed or incomplete check (“Schedule-change notices unavailable”). For a selection outside the pilot's verified scope, explain that coverage is unavailable. Keep official source access within existing worker protections, the zero-spend constraint and existing public browsing/privacy boundaries. Delivering alerts, storing names and reviving automatic name checking are outside these releases.

Define pilot coverage by official source, time window and supported selections. Show the coverage window alongside an empty feed. A potentially relevant unresolved notice makes the affected scope incomplete. A rescheduled sitting can receive a notice only when the official source establishes that association.

## Acceptance

1. A returning user can reach the same official article and labeled lists from Results, including older articles and releases without a result version. An empty, offline or unselected screen never implies a release.
2. A first-time user can pick, skip, return, change exams and access Settings at phone and tablet widths, including at 200% text. The first release has no Updates destination or instructions pointing to it.
3. In the pilot, an advisory by itself cannot produce “Results released”, including on an older client. A result article cannot appear in Updates. Replaying a scan or switching sittings cannot duplicate or misattribute a card.
4. Enable the pilot only after confirming an official source, correctly matching a real notice, verifying the three feed states (matched, checked-empty and unavailable), and checking source traffic and Firestore use against the existing free budget. The first release can ship if the pilot source proves unsuitable.
