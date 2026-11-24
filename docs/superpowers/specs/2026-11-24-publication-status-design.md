# Schedule-aware publication status

Approved in conversation on November 24, 2026: combine the official schedule with verified releases. Preserve existing Material layout and source links.

The worker imports each sitting's optional target release date, original target text and existing schedule provenance. Missing or ambiguous targets remain unknown; invalid targets must not remove a valid sitting. Schedule corrections replace prior targets on subsequent scans.

Flutter shows verified releases first, then upcoming, in progress, awaiting results through the target day, or no verified announcement found. Dates use Philippine calendar days; reaching a target never proves release. Optional target metadata remains compatible with existing documents. Oral sittings must load.

The app refreshes schedule metadata and reads the existing result monitor's successful-check timestamp. It displays the source and last check for unreleased selections, warns when checks are stale or unknown, and preserves prior information after failed refreshes. An initial failure says Couldn't refresh. Schedule retrieval timestamps must never stand in for a successful results scan.

Approaches considered: a wording-only change cannot show verified targets; creating unreleased result-version records adds synthetic publication data. The approved approach extends schedule metadata and derives display status in Flutter, retaining releases as independent evidence.

No inferred release dates, outcomes for unresolved SPLE cases, new infrastructure, or automatic production deployment. Tests cover the Teachers example, UTC+08 day boundaries, inclusive end/target days, invalid dates, releases overriding schedules, corrections, partial failures and stale data.
