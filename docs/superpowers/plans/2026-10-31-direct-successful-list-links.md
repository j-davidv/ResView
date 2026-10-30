# Direct successful-examinee links

Goal: open the official passing list directly while retaining the PRC announcement as a separate option, including when automatic checking is unavailable.

Reuse the worker's existing `publications.documents` and labeled `documentCandidates`; no worker change, database write, extraction approval or additional query is needed. Carry these links through `Publication` and show them in Updates, Results and the existing source section in Check name. Result versions use only the publication matching their provenance, including the existing PRC host/index.php aliases. If result-version metadata is missing, Results still offers the latest known selection-specific publication's source links. Keep qualified labels and all supplied alternatives; never infer a category association or fabricate a missing link. Retain the reviewed document URL as a fallback when publication links are absent.

- [x] Test safe parsing, deduplication, multiple labels, unavailable-state links, retained announcements, aliases and exclusion of unrelated releases.
- [x] Connect the existing metadata to the model, repository and shared source controls in Updates/Results/Check name.
- [x] Run the Flutter suite/analyzer, rebuild the normal APK, verify direct opening on the phone and record limits.
