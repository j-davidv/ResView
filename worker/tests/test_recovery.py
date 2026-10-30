import copy
import hashlib
import http.client
import unittest
from datetime import timedelta
from unittest.mock import Mock, patch

from worker.extract import validate_pages
from worker.main import run
from worker.providers import Providers, identifier
from worker.source import SourceError, parse_publication
from worker.tests.test_worker import NOW, URL, SELECTION, PAGES, profile


class MemoryDocument:
    def __init__(self, database, path):
        self.database, self.path = database, path

    def get(self, **kwargs):
        return Mock(to_dict=lambda: copy.deepcopy(self.database.rows.get(self.path)))

    def set(self, value, merge=False):
        if merge:
            self.database.rows.setdefault(self.path, {}).update(copy.deepcopy(value))
        else:
            self.database.rows[self.path] = copy.deepcopy(value)


class MemoryDatabase:
    def __init__(self):
        self.rows = {}

    def document(self, path):
        return MemoryDocument(self, path)

    def collection(self, path):
        return Mock(document=lambda key: self.document(path + '/' + key))

    def transaction(self):
        return self

    def set(self, document, value):
        document.set(value)

    def update(self, document, value):
        document.set(value, merge=True)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.db = MemoryDatabase()
        self.provider = Providers(self.db, 'example.supabase.co', 'test-only')
        self.provider.upload = Mock()
        self.provider.download = Mock()
        self.reviewed = profile()
        self.reviewed['originalSha256'] = hashlib.sha256(b'%PDF-original').hexdigest()
        self.report = validate_pages(PAGES, self.reviewed['originalSha256'], self.reviewed, NOW)
        self.html = (b'<h1>Test Results</h1>Posted on 15 October, 2026'
                     b'<a href="/sites/default/files/test.pdf">List of Successful Examinees</a>')
        self.body = b'%PDF-original'
        self.outage = False
        self.config = {'sourcePolicy': {'accessAuthorization': 'synthetic test',
                       'routes': {'www.prc.gov.ph': ['/article/', '/sites/default/files/']}},
                       'publications': [{'url': URL, 'selection': SELECTION, 'profile': self.reviewed}]}
        self.patch = patch('worker.providers.firestore.transactional', side_effect=lambda f: f)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.now = NOW
        self.assertEqual(self.scan(), 0)
        self.original = copy.deepcopy(self.current())
        self.now += timedelta(minutes=30)
        self.provider.upload.reset_mock()

    def current(self):
        pointer = self.db.rows['workerState/' + identifier(SELECTION)]
        return self.db.rows['resultVersions/' + pointer['versionId']]

    def scan(self):
        def fetcher(url, policy, **kwargs):
            if self.outage:
                raise SourceError('Synthetic source outage.')
            if url.endswith('/robots.txt'):
                return b'User-agent: *\nDisallow:'
            return self.body if url.endswith('.pdf') else self.html

        def extract(path, reviewed, now):
            if hashlib.sha256(path.read_bytes()).hexdigest() != reviewed['originalSha256']:
                raise ValueError('Unreviewed changed bytes.')
            return self.report

        def upload(key, body):
            self.provider.download.return_value = body

        if self.provider.upload.side_effect is None:
            self.provider.upload.side_effect = upload
        with patch('worker.main.extract_pdf', side_effect=extract):
            return run(self.config, self.provider, self.now, fetcher)

    def test_changed_bytes_revoke_checking_and_reruns_remain_unavailable(self):
        self.body = b'%PDF-corrected-unreviewed'
        self.assertEqual(self.scan(), 1)
        self.assertEqual(self.current()['state'], 'checkingUnavailable')
        self.assertNotIn('namesUrl', self.current())
        old_id = identifier([SELECTION, self.original['documentVersion']])
        self.assertEqual(self.db.rows['resultVersions/' + old_id]['state'], 'superseded')
        self.assertEqual(self.scan(), 1)
        self.provider.upload.assert_not_called()

    def test_malformed_pdf_revokes_the_previous_available_version(self):
        broken = b'%PDF-1.7\ntruncated'
        def fetcher(url, policy, **kwargs):
            if url.endswith('/robots.txt'):
                return b'User-agent: *\nDisallow:'
            return broken if url.endswith('.pdf') else self.html
        self.assertEqual(run(self.config, self.provider, self.now, fetcher), 1)
        self.assertEqual(self.current()['state'], 'checkingUnavailable')
        self.assertNotIn('namesUrl', self.current())
        self.provider.upload.assert_not_called()

    def test_changed_link_revokes_old_list_without_fetching_unreviewed_document(self):
        self.html = self.html.replace(b'test.pdf', b'correction.pdf')
        self.assertEqual(self.scan(), 1)
        self.assertEqual(self.current()['state'], 'checkingUnavailable')
        self.assertNotIn('namesUrl', self.current())
        self.provider.upload.assert_not_called()

    def test_disabled_profile_revokes_same_version_and_does_not_upload(self):
        self.reviewed['disabled'] = True
        self.assertEqual(self.scan(), 0)
        self.assertEqual(self.current()['state'], 'checkingUnavailable')
        self.assertNotIn('namesUrl', self.current())
        self.assertEqual(self.scan(), 0)
        self.provider.upload.assert_not_called()

    def test_changed_pinned_mapping_revokes_without_publishing_unreviewed_association(self):
        catalog_url = 'https://www.prc.gov.ph/2026-schedule-examination'
        results_url = 'https://www.prc.gov.ph/articles/exam-results'
        mapped_selection = {'examId': 'testers', 'sittingId': 'testers-2026-05-01', 'categoryId': 'all'}
        config = {'sourcePolicy': {'accessAuthorization': 'test', 'routes': {
            'www.prc.gov.ph': ['/article/', '/articles/', '/2026-schedule-examination']}},
            'catalogUrl': catalog_url, 'resultsUrl': results_url,
            'publicationMappings': {URL: {
                'publicationVersion': parse_publication(URL, self.html, NOW)['publicationVersion'],
                'selections': [mapped_selection]}}}
        old = {**self.original, 'selection': mapped_selection}
        self.provider.activate(old)
        old_url = URL + '-old'
        pages = {
            catalog_url: b'<table><tr><td>1</td><td>Testers</td><td>May 1, 2026</td><td></td><td>NCR</td></tr></table>',
            results_url: f'<a href="{URL}">Test Results</a><a href="{old_url}">Older Testers Results</a>'.encode(),
            URL: self.html.replace(b'test.pdf', b'corrected.pdf'),
            old_url: b'<h1>May 2026 Testers Results</h1>Posted on 2 May, 2026',
        }
        self.provider.catalog = Mock()
        self.provider.review = Mock()
        with patch.object(self.provider, 'publication', wraps=self.provider.publication) as publish:
            self.assertEqual(run(config, self.provider, self.now,
                lambda u, p, **kw: b'User-agent: *\nDisallow:' if u.endswith('/robots.txt') else pages[u]), 1)
        self.assertTrue(all(c.args[0]['publicationUrl'] != URL for c in publish.call_args_list))
        pointer = self.db.rows['workerState/' + identifier(mapped_selection)]
        current = self.db.rows['resultVersions/' + pointer['versionId']]
        self.assertEqual(current['state'], 'checkingUnavailable')
        self.assertNotIn('namesUrl', current)
        self.assertEqual(self.db.rows['monitor/status']['freshness'], 'stale')
        self.assertEqual(self.provider.review.call_args.args[0][0]['publicationUrl'], URL)

    def test_outage_retains_last_good_and_success_timestamp_with_stale_status(self):
        self.outage = True
        self.assertEqual(self.scan(), 1)
        self.assertEqual(self.current(), self.original)
        health = self.db.rows['monitor/status']
        self.assertEqual(health['freshness'], 'stale')
        self.assertEqual(health['lastSuccessfulCheckUtc'], NOW.isoformat())
        self.assertEqual(health['lastAttemptUtc'], self.now.isoformat())

    def test_failed_upload_retains_last_good_and_marks_stale(self):
        for error in (ValueError('Synthetic upload failure.'),
                      http.client.IncompleteRead(b'partial')):
            with self.subTest(error=type(error).__name__):
                self.provider.upload.side_effect = error
                self.assertEqual(self.scan(), 1)
                self.assertEqual(self.current(), self.original)
                self.assertEqual(self.db.rows['monitor/status']['freshness'], 'stale')

    def test_successful_manual_rerun_is_idempotent_and_refreshes_health(self):
        before = set(self.db.rows)
        self.assertEqual(self.scan(), 0)
        self.assertEqual(set(self.db.rows), before)
        self.assertEqual(self.current()['state'], 'checkingAvailable')
        self.assertEqual(self.current()['lastSuccessfulCheckUtc'], self.now.isoformat())
        self.assertEqual(self.db.rows['monitor/status']['freshness'], 'fresh')


if __name__ == '__main__':
    unittest.main()
