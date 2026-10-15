# Name-list format validation

Status on 2026-10-15: **no production format/version approved**. The plan's archival PDFs, independent transcripts and visual checks are absent from this checkout; their reported counts are not reproduced evidence. The inspected current Foresters list refuses downloading.

`worker/extract.py` accepts only a reviewed single-section numbered text-PDF version. Profiles require exact original SHA-256, independent complete row digest, official source chain, exam/sitting/category headings, physical page/published entry counts, terminal marker, review timestamp, exact ignored lines and visual samples. Non-PDF HTML, encryption, blank/scanned pages, unknown lines, numbering gaps/restarts, count/page/text mismatch or a changed version refuse checking. There is no OCR, multi-section adapter, wrapped-name guess or inferred component capability.

Before enabling a real profile:

1. Retrieve an accessible original linked by PRC without bypassing restrictions; retain provenance and bytes privately.
2. Independently extract every row with another reader. Compare exact Unicode names, sequence, section and physical page. Compute `entriesSha256` from those independent entries using `worker.extract.encode`; rehashing this parser's own output is not independent evidence.
3. Check headings, dates, category, successful-list type, published total and completion. Visually transcribe samples including page boundaries and accented/suffixed names. Record UTC review time privately.
4. Register that exact version, reviewing any real-name profile exposure before repository publication. Current config has no real-name profiles.
5. Run original-document mutation tests, verify real immutable upload/public download/hash/size and Flutter decoding, then exercise local checking on Android. Unit tests alone cannot approve a format.

Synthetic tests verify validation/refusal logic. A successful real-PDF-to-phone path and actual Supabase transfer remain unverified. Automatic name checking is **not live-ready**.
