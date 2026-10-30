# PRC document viewing compatibility

October 31, 2026. The original compatibility study below established viewer support. ResView now implements an in-app Android viewer and touch search; see the implementation evidence at the end of this report.

## Environment and scope

The test used the existing Android 15/API 35 emulator, a 720 × 1280 display at density 320, system text scale 2.0, and Google Android System WebView 124.0.6367.219. No physical phone was connected. A separate debug-only probe enabled JavaScript and DOM storage, disabled file access and backup, and loaded official Google Drive viewer URLs. It did not change or replace ResView.

The 87 distinct document URLs came from the Task 9 acquisition inventory. Each original `/view` URL was presented through the same Drive file ID's `/preview` route. The probe used ordinary public viewing, without authentication or retrieving restricted PDF originals. This does not test new documents published after that inventory.

## Results

| Check | Observed result |
| --- | --- |
| Android WebView rendering | 87 of 87 first pages rendered actual document images, with no preview/access error detected. |
| Visual review | All 87 first-page screenshots were inspected in six contact sheets. Every screenshot contains document content; none is a blank or access-request screen. |
| Download-restricted documents | Viewer rendering works for these too, including the Foresters list. Viewing does not grant permission to download the original. |
| Android WebView native text search | Found two first-page surname occurrences in the Physical Therapists list. Returned zero for a known name on page 11 while only three page images were loaded. An absent test string also returned zero. |
| Drive's own document search | Four asserted tests passed: a unique first-page name, a page-11 name, an absent string, and a first-page name in the download-restricted Foresters list. Positive tests showed one match; the late-page test navigated to page 11 of 11. The absent test showed zero matches. |
| Search opening and phone usability | The tested search flow used Ctrl+F with the document region focused, followed by the query and Enter. Shortcut attempts with focus on the page body did not open search. A touch-only route to open search was not established. At text scale 2.0, the Drive search bar extends beyond the left edge of the 360-CSS-pixel viewport. |

Native WebView text search must not be presented as a complete search of a long passing list: a zero count can mean that the relevant page has not loaded. Drive's own search reached beyond the initially loaded pages in the tested document, but it remains a search aid rather than a validated personal exam outcome.

The `/view` route also rendered the Foresters document in the Android probe. Its checked mobile controls did not establish a touch-operated find action. ResView currently opens official sources externally and has no embedded WebView or search controls. The probe's successful keyboard-driven tests do not establish that the production app already provides this flow.

## Evidence and limits

Private evidence remains in ignored `.development/viewing-check/`: `android-rendering.json`, all 87 `android-pages/*.png` screenshots, six `contact-*.png` sheets, `native-search.json`, `drive-search-tests.json`, and search/control screenshots. The private probe and scripts are retained there for reproduction. No real-name screenshot or search query is added to public source files by this report.

Only the first page of each of the 87 documents was visually checked. This is not an inspection of every page, a review of complete-list accuracy, or extraction approval. Some documents begin at later printed page numbers. Search was tested on two documents, not all 87; the four exact checking profiles remain the only approved automatic-checking versions. This original probe did not establish physical-phone, other Android/WebView version, offline, or touch-only search acceptance; the later implementation checks are recorded below.

## In-app implementation

The preceding sections describe the temporary compatibility probe. The application now opens approved PRC announcement links and Drive lists in an Android platform WebView embedded in its existing Material interface. Other links, direct PDFs outside the supported viewer route, privacy/contact links and explicit browser recovery retain external handling. No new runtime dependency was added.

Find, Previous and Next are native app controls outside the page, so users do not need a hardware keyboard or Drive's clipped mobile search bar. Search uses Drive's full-document engine rather than Android's loaded-page find. It displays text-match counts, a neutral zero-match explanation, or a recoverable unavailable message. It never interprets a match as a personal outcome or changes automatic-checking availability.

The input adapter uses Android's normal text input connection. It clears and confirms the previous query, waits for the requested text, then submits only if Drive has not already searched while typing. This handles the different behavior observed on the approved Physical Therapists list and the download-restricted Foresters list. It does not erase Drive's counter or take a previous query's counter as a new result. Next/Previous preserve the current query and move through its matches. Requests have bounded waits and are cancelled on navigation or disposal. An unavailable search never becomes a zero-match answer.

The screen identifies the source host and explains the PRC/Google connection. It does not read the saved name, save the manual query, or log it. Search text is separate from automatic on-device checking. WebView has no JavaScript-to-native bridge; file/content access and mixed HTTP content are disabled. Both Dart entry routing and native navigation check HTTPS, exact hosts, credentials/ports and supported Drive paths. Unapproved navigation offers an explicit external action. Release builds do not enable WebView debugging.

Physical acceptance: four integration tests passed on the Infinix X6710, Android 14, WebView 156.0.8078.47, system text scale 1.0. They cover untrusted-origin refusal and retry, a page-11 match, repeating Find, a changed query, Next/Previous across two matches, absent text, the restricted Foresters list, Back and landscape. Tests use ignored private configuration for the official document IDs and public-name samples; no real-name fixture was added to source. The test update used `--no-uninstall` and did not clear application data. Test orientation preferences are restored.

The same four final tests also passed on the Android 15 emulator with WebView 124.0.6367.219 and system text scale 2.0, including landscape. Independent review found no additional confirmed correctness or security issue.

All 36 local Flutter tests and the analyzer passed. The normal Firebase-configured debug APK was rebuilt without the test entry point or test definitions and restored on both devices with application data preserved. Its kernel was checked for the private test-only markers. In the normal phone app, the existing official-publication button opened the actual Ocular Pharmacologists PRC announcement inside ResView; a touch on its passing-list link opened and rendered the linked Drive document in the same app. The existing selected exam was retained. Private evidence includes `normal-flow.json`, `normal-viewer.png`, `implementation-evidence.json` and the build/test logs.

Private implementation evidence: `.development/viewing-check/phone-reset-input.log`, `emulator-final.log`, Android integration source and local test configuration, plus the earlier page-11 app screenshot. A diagnostic run that supplied browser keyboard input was used only to identify the event-handling problem; it is not counted as a passing acceptance run. Earlier failed runs remain available privately.

The original 87-document rendering study still establishes only first-page viewing compatibility. The full-document search adapter was tested on two actual lists, not all 87. Full TalkBack interaction, every page, offline behavior, other document formats and future Drive DOM changes remain outside this acceptance. Changed/unavailable source UI produces a search-unavailable message and browser recovery.

## Direct successful-examinee links

The app now reads the document URLs already stored on each publication, including labeled passing-list candidates. Updates and the source sections in Results and Check name offer these links directly, alongside a separate PRC-publication button. Automatic-checking approval is not required to open a source manually. No worker/database change or additional Firestore query is needed.

Qualified links retain PRC's labels; multiple unlabeled links are numbered. The app does not infer an exam/category association from a combined announcement. Results matches the publication to its result provenance, including the established PRC host and index.php aliases, and does not borrow links from another release. If version metadata is missing, it still exposes the latest known selection-specific announcement. A reviewed document URL remains a fallback when publication links are absent. Malformed or unsafe link entries are omitted without hiding the announcement.

A direct link cannot be fabricated when PRC supplies no recognizable passing-list link. Those cases keep the publication button. Direct manual access does not approve extraction or change the four validated checking versions.

Verification: eight new regression tests cover source parsing/safety, label preservation, deduplication, multiple-list controls at enlarged text, version-metadata absence, unavailable checking, reviewed-document fallback, URL aliases and exclusion of another release's links. All 44 local Flutter tests and the analyzer passed, and the normal Firebase-configured APK was rebuilt and installed on the Infinix without clearing data. In the existing March 26–27 Civil Engineers selection, automatic checking remained unavailable while both the direct list and PRC-publication buttons appeared. One tap opened the actual Drive document in-app; one Back returned to Updates. Results independently showed both links. The selected exam was not changed. Private evidence is in `.development/direct-links/`; not every direct link was individually retested on the phone.
