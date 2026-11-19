import hashlib
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import Mock, patch

from worker.main import run_advisories
from worker.providers import Providers

from worker.advisories import archive_rows, inventory_hash, notice, scan, SourceError


def article(title, body):
    return f'<article><h1>{title}</h1><span>Posted on 3 July, 2026</span><p>{body}</p></article>'.encode()


class AdvisorySourceTests(unittest.TestCase):
    url = 'https://www.prc.gov.ph/article/test-only-change'
    selection = {'examId': 'test-only', 'sittingId': 'test-only-2026-07-14', 'categoryId': 'general'}
    scope = {'selection': selection, 'centers': 'TEST ONLY North', 'start': '2026-07-14'}
    sitting = {'id': selection['sittingId'], 'examId': 'test-only', 'start': '2026-07-14T00:00:00+00:00',
               'officialTestingCenters': 'TEST ONLY North', 'categories': {'general': 'General', 'special': 'Special'}}

    def reviewed(self, title, body):
        # Pin the exact announcement, including audience restrictions, as the reviewer saw it.
        return {'contentSha256': hashlib.sha256(article(title, body).removeprefix(b'<article>').removesuffix(b'</article>')).hexdigest(),
                'selections': [self.selection]}

    def test_dated_change_and_postponement_preserve_official_title_and_posting_date(self):
        for title in ['Rescheduling the TEST ONLY examination to July 14', 'Postponement of the TEST ONLY examination']:
            body = 'TEST ONLY North, General category.'
            result = notice(self.url, article(title, body), self.reviewed(title, body))
            self.assertEqual(result, ([self.selection], {'kind': 'scheduleChange', 'title': title,
                'publicationUrl': self.url, 'publishedAtUtc': '2026-07-02T16:00:00+00:00'}))

    def test_changed_region_similar_exam_and_scoped_category_require_review(self):
        title, body = 'Postponement of the TEST ONLY examination', 'For General, TEST ONLY North.'
        review = self.reviewed(title, body)
        for altered in ['For TEST ONLY South only.', 'For the TEST ONLY practical examination.', 'Special category only.']:
            with self.subTest(altered=altered), self.assertRaises(SourceError):
                notice(self.url, article(title, altered), review)

    def test_empty_scope_must_still_match_reviewed_centers_and_date(self):
        pilot = dict(scopes=[self.scope], articles={}, monthUrl=self.url, yearUrl=self.url,
                     catalogUrl=self.url, otherEntriesSha256=inventory_hash({}))
        config = {'advisoryPilot': pilot, 'scheduleOverrides': {}}
        for changed in [{'categories': {'special': 'Special'}}, {'examId': 'test-only-practical'},
                        {'officialTestingCenters': 'TEST ONLY South'}, {'start': '2026-07-15'}]:
            catalog = {'sittings': [{**self.sitting, **changed}]}
            with self.subTest(changed=changed), patch('worker.advisories.archive_rows', return_value={}), \
                    patch('worker.advisories.parse_catalog', return_value=catalog), self.assertRaises(SourceError):
                scan(config, Mock(), None, Mock())

    def test_result_release_is_never_an_advisory(self):
        title, body = 'TEST ONLY Examination Results Released', 'Registration has been rescheduled.'
        with self.assertRaises(SourceError):
            notice(self.url, article(title, body), self.reviewed(title, body))

    def test_alias_cannot_hide_a_missing_reviewed_notice_during_scan(self):
        root = 'https://www.prc.gov.ph/archives/2026/202607'
        other = 'https://www.prc.gov.ph/article/test-unrelated'
        duplicate = 'https://prc.gov.ph/index.php/article/test-unrelated'
        summary = b'<li><a href="/archives/2026/202607">July</a> (2)</li>'
        row = '<div class="article-archive views-row"><div><a href="{}">Other</a></div></div>'
        month = (row.format(other) + row.format(duplicate)).encode()
        pilot = dict(scopes=[self.scope], articles={self.url: {}}, monthUrl=root, yearUrl=root + '/year',
                     catalogUrl=root + '/catalog', otherEntriesSha256=inventory_hash({other: ('Other', other)}))
        with patch('worker.advisories.parse_catalog', return_value={'sittings': [self.sitting]}), self.assertRaises(SourceError):
            scan({'advisoryPilot': pilot, 'scheduleOverrides': {}}, Mock(), None,
                 Mock(side_effect=[summary, month, b'']))

    def test_archive_count_and_aliases(self):
        root = 'https://www.prc.gov.ph/archives/2026/202607'
        summary = b'<ul><li><a href="/archives/2026/202607">July 2026</a> (2)</li></ul>'
        row = '<div class="article-archive views-row"><div><a href="{}">TEST ONLY change</a></div></div>'
        body = (row.format(self.url) + row.format('https://prc.gov.ph/index.php/article/test-only-change')).encode()
        rows = archive_rows(root, summary, body)
        self.assertEqual(rows, {self.url: ('TEST ONLY change', self.url)})
        for unsafe in ['https://review@prc.gov.ph/article/test-only-change',
                       'https://prc.gov.ph:8443/article/test-only-change']:
            with self.subTest(unsafe=unsafe), self.assertRaises(SourceError):
                archive_rows(root, summary, (row.format(self.url) + row.format(unsafe)).encode())
        for partial in [row.format(self.url).encode(), body + b'<a rel="next" href="?page=1">Next</a>']:
            with self.assertRaises(SourceError):
                archive_rows(root, summary, partial)


class AdvisorySnapshotTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 8, 1, tzinfo=timezone.utc)
        self.keys = [('test', sitting, 'all') for sitting in ['one', 'two']]
        self.pilot = {'coverageStartUtc': '2026-07-01T00:00:00+00:00',
                      'coverageEndUtc': '2026-08-01T00:00:00+00:00',
                      'scopes': [{'selection': dict(zip(('examId', 'sittingId', 'categoryId'), k))} for k in self.keys]}
        self.docs = {}
        db = Mock()
        def reference(path):
            ref = Mock(path=path)
            ref.get.return_value.to_dict.side_effect = lambda: self.docs.get(path)
            return ref
        db.document.side_effect = reference
        tx = db.transaction.return_value
        def save(ref, fields, merge=False):
            self.docs[ref.path] = {**(self.docs.get(ref.path, {}) if merge else {}), **fields}
        tx.set.side_effect = save
        tx.delete.side_effect = lambda ref: self.docs.pop(ref.path, None)
        self.provider = Providers(db)
        self.decorator = patch('worker.providers.firestore.transactional', side_effect=lambda f: f)
        self.decorator.start()
        self.addCleanup(self.decorator.stop)
        self.notice = {'title': 'TEST ONLY postponement', 'kind': 'scheduleChange',
                       'publicationUrl': 'https://www.prc.gov.ph/article/test-only',
                       'publishedAtUtc': '2026-07-14T16:00:00+00:00'}
        self.paths = ['advisoryFeeds/test/sittings/' + k[1] + '/categories/all' for k in self.keys]

    def test_rescans_corrections_withdrawals_and_failures_are_isolated(self):
        first, second = self.keys
        feed = {first: [self.notice], second: []}
        for step in [0, 1]:
            self.provider.advisory_snapshots(self.pilot, feed, self.now + timedelta(hours=step))
            self.assertEqual(self.docs[self.paths[0]]['notices'], [self.notice])
            self.assertEqual(self.docs[self.paths[1]]['notices'], [])
        at = self.now + timedelta(hours=2)
        self.provider.advisory_snapshots(self.pilot, {first: [], second: [self.notice]}, at)
        self.assertEqual(self.docs[self.paths[0]]['notices'], [])
        self.provider.advisory_snapshots(self.pilot, None, at + timedelta(hours=1))
        self.provider.advisory_snapshots(self.pilot, feed, self.now)
        prior = self.docs[self.paths[1]]
        self.assertEqual(prior['notices'], [self.notice])
        self.assertEqual(prior['freshness'], 'stale')
        self.assertEqual(prior['lastSuccessfulCheckUtc'], at.isoformat())
        self.assertEqual(prior['coverageEndUtc'], self.pilot['coverageEndUtc'])
        self.assertEqual(prior['coverageStartUtc'], self.pilot['coverageStartUtc'])
        self.assertFalse(any(path.startswith(('publications/', 'resultVersions/', 'monitor/')) for path in self.docs))

    def test_exam_wide_history_retains_last_good_after_failure_and_withdraws_retired_exam(self):
        start = self.now - timedelta(days=90)
        first = {'first': [self.notice], 'empty': []}
        self.provider.exam_histories(first, start, self.now)
        self.provider.exam_histories(None, start, self.now + timedelta(hours=2))
        self.provider.exam_histories({'first': []}, start, self.now + timedelta(hours=1))
        self.assertEqual(self.docs['examUpdates/first']['notices'], [self.notice])
        self.assertEqual(self.docs['examUpdates/first']['lastSuccessfulCheckUtc'], self.now.isoformat())
        self.assertEqual(self.docs['examUpdates/empty']['freshness'], 'stale')
        self.provider.exam_histories({'first': []}, start, self.now + timedelta(hours=3))
        self.assertEqual(self.docs['examUpdates/empty'], {'retired': True})
        self.assertEqual(self.docs['examUpdates/first']['freshness'], 'fresh')
        self.assertFalse(any(path.startswith(('publications/', 'resultVersions/')) for path in self.docs))

    def test_failed_scope_changes_stale_only_previous_paths_within_budget(self):
        feed = {self.keys[0]: [self.notice], self.keys[1]: []}
        self.provider.advisory_snapshots(self.pilot, feed, self.now)
        for step, count in enumerate([2, 9], 1):
            scopes = [{'selection': {'examId': 'test', 'sittingId': f'new-{n}', 'categoryId': 'all'}}
                      for n in range(count)]
            self.provider.advisory_snapshots({**self.pilot, 'scopes': scopes}, None,
                                             self.now + timedelta(hours=step))
            self.assertEqual(self.docs[self.paths[0]]['freshness'], 'stale')
            self.assertEqual(self.docs[self.paths[0]]['notices'], [self.notice])
            self.assertEqual(sorted(p for p in self.docs if p.startswith('advisoryFeeds/')), self.paths)

    def test_unresolved_or_oversized_scan_cannot_publish_a_checked_empty(self):
        from worker.advisories import AdvisoryReview
        cfg = {'advisoryPilot': self.pilot, 'sourcePolicy': {'accessAuthorization': 'TEST ONLY',
               'routes': {'www.prc.gov.ph': ['/robots.txt']}}}
        outcomes = [AdvisoryReview('https://www.prc.gov.ph/article/test-only', 'Unknown region'),
                    {self.keys[0]: [{**self.notice, 'title': 'A' * 300000}], self.keys[1]: []}]
        with patch('worker.advisories.scan', side_effect=outcomes):
            for step in [0, 1]:
                self.assertEqual(run_advisories(cfg, self.provider, self.now + timedelta(hours=step),
                                                lambda *args, **kwargs: b'User-agent: *\nAllow: /'), 1)
                self.assertEqual(self.docs[self.paths[0]]['freshness'], 'stale')
                self.assertIsNone(self.docs[self.paths[1]]['lastSuccessfulCheckUtc'])
        self.assertTrue(any(p.startswith('workerAdvisoryReview/') for p in self.docs))
