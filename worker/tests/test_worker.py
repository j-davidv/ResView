import copy
import io
import hashlib
import json
import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path
from unittest.mock import Mock, patch
from urllib.robotparser import RobotFileParser

from worker.source import SourcePolicy, SourceError, fetch, parse_publication, parse_catalog, associate
from worker.extract import extract_pdf, validate_pages, write_names_file
from worker.publish import publish_validated
from worker.main import run, log_failure, discover


NOW = datetime(2026, 10, 15, tzinfo=timezone.utc)
URL = 'https://www.prc.gov.ph/article/test-result'
SELECTION = {'examId': 'test', 'sittingId': '2026-10', 'categoryId': 'all'}
ENTRIES = [
    {'sequence': 1, 'publishedName': 'TEST, ALPHA', 'sectionId': 'all', 'physicalPage': 1},
    {'sequence': 2, 'publishedName': 'TEST, BÉTA', 'sectionId': 'all', 'physicalPage': 2},
]


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode()).hexdigest()


def profile():
    return {
        'format': 'reviewed-numbered-text-v1', 'reviewEvidence': 'private independent transcript and visual review',
        'reviewedAtUtc': NOW.isoformat(),
        'originalSha256': 'a' * 64, 'selection': SELECTION,
        'publicationUrl': URL, 'documentUrl': 'https://www.prc.gov.ph/sites/default/files/test.pdf',
        'headings': ['TEST EXAM OCTOBER 2026', 'LIST OF SUCCESSFUL EXAMINEES'],
        'endMarker': 'NOTHING FOLLOWS', 'pageCount': 2, 'entryCount': 2,
        'entriesSha256': digest(ENTRIES), 'samples': [ENTRIES[0], ENTRIES[1]],
        'ignoreLines': ['TEST EXAM OCTOBER 2026', 'LIST OF SUCCESSFUL EXAMINEES'],
    }


PAGES = ['TEST EXAM OCTOBER 2026\nLIST OF SUCCESSFUL EXAMINEES\n1 TEST, ALPHA',
         '2 TEST, BÉTA\nNOTHING FOLLOWS']


class SourceTests(unittest.TestCase):
    def test_discovery_accepts_both_official_article_routes(self):
        config = json.loads(Path('worker/config.json').read_text())
        catalog = b'<table><tr><td>1</td><td>Test Engineers</td><td>October 8, 2026</td><td>Thursday</td><td>Manila</td></tr></table>'
        for prefix in ('/article/', '/index.php/article/'):
            with self.subTest(prefix=prefix):
                url = 'https://www.prc.gov.ph' + prefix + 'test-results'
                index = f'<a href="{url}">October 2026 Test Engineers Results Released</a>'.encode()
                config.pop('catalogIndexUrl', None)
                config['catalogUrl'] = 'https://www.prc.gov.ph/2026-schedule-examination'
                pages = {config['catalogUrl']: catalog, config['resultsUrl']: index,
                         url: b'<h1>October 2026 Test Engineers Results Released</h1>Posted on 15 October, 2026'}
                policy = SourcePolicy(config['sourcePolicy'])
                policy.load_robots(lambda *args, **kwargs: b'User-agent: *\nDisallow: /index.php/admin/')
                _, publications = discover(config, policy, NOW, lambda url, _: pages[url])
                self.assertEqual(len(publications), 1)
                self.assertEqual(publications[0]['url'], url)
                self.assertEqual(publications[0]['selection']['sittingId'], 'test-engineers-2026-10-08')
                with self.assertRaises(SourceError):
                    policy.check('https://www.prc.gov.ph/index.php/admin/')

    def policy(self):
        return SourcePolicy({'accessAuthorization': 'owner instruction 2026-10-15',
                             'routes': {'www.prc.gov.ph': ['/article/', '/sites/default/files/']}})

    def test_policy_requires_explicit_live_access_configuration(self):
        with self.assertRaises(SourceError):
            SourcePolicy({'routes': {'www.prc.gov.ph': ['/']}})

    def test_network_rejects_unapproved_urls_and_private_dns_before_transport(self):
        transport = Mock()
        for url in ['http://www.prc.gov.ph/article/a', 'https://evil.test/article/a',
                    'https://www.prc.gov.ph@evil.test/article/a',
                    'https://www.prc.gov.ph/article/../admin',
                    'https://www.prc.gov.ph/article/%2e%2e/admin']:
            with self.subTest(url=url), self.assertRaises(SourceError):
                fetch(url, self.policy(), transport=transport)
        with patch('worker.source.socket.getaddrinfo', return_value=[(2, 1, 6, '', ('127.0.0.1', 443))]):
            with self.assertRaises(SourceError):
                fetch(URL, self.policy(), transport=transport)
        transport.assert_not_called()

    @patch('worker.source.socket.getaddrinfo', return_value=[(2, 1, 6, '', ('8.8.8.8', 443))])
    def test_redirects_checked_and_retry_budget_bounded(self, _):
        transport = Mock(side_effect=[(302, {'location': 'https://evil.test/x'}, b'')])
        with self.assertRaises(SourceError):
            fetch(URL, self.policy(), transport=transport)
        self.assertEqual(transport.call_count, 1)
        transport = Mock(return_value=(429, {'retry-after': '9999'}, b''))
        sleep = Mock()
        with self.assertRaises(SourceError):
            fetch(URL, self.policy(), transport=transport, sleep=sleep)
        self.assertEqual(transport.call_count, 1)
        sleep.assert_not_called()

    @patch('worker.source.socket.getaddrinfo', return_value=[(2, 1, 6, '', ('8.8.8.8', 443))])
    def test_three_attempts_and_content_size_limit(self, _):
        transport = Mock(return_value=(503, {}, b''))
        sleep = Mock()
        with self.assertRaises(SourceError):
            fetch(URL, self.policy(), transport=transport, sleep=sleep)
        self.assertEqual(transport.call_count, 3)
        self.assertEqual([c.args[0] for c in sleep.call_args_list], [1, 4])
        with self.assertRaises(SourceError):
            fetch(URL, self.policy(), transport=Mock(return_value=(200, {}, b'x' * 11)), limit=10)

    def test_publication_keeps_provenance_and_document_chain(self):
        html = '<h1>October Test Results</h1><p>Posted on 15 October, 2026</p><a href="/sites/default/files/test.pdf">List of passers</a>'
        record = parse_publication(URL, html.encode(), NOW)
        self.assertEqual(record['title'], 'October Test Results')
        self.assertEqual(record['publishedAtUtc'], '2026-10-14T16:00:00+00:00')
        self.assertEqual(record['documents'][0], profile()['documentUrl'])
        self.assertEqual(record['sourceSha256'], hashlib.sha256(html.encode()).hexdigest())
        self.assertEqual(record, parse_publication(URL, html.encode(), NOW))
        for bad in [b'<html>Access denied</html>', b'<h1>Title without date</h1>']:
            with self.assertRaises(SourceError):
                parse_publication(URL, bad, NOW)

    def test_catalog_uses_official_dates_and_never_guesses_unrecognized_rows(self):
        body = b'<table><tr><td>1</td><td>Testers (CBLE)</td><td>October 08 and 09, 2026</td><td>Thu</td><td>NCR</td></tr><tr><td>2</td><td>Other Exam</td><td>Cancelled</td><td></td><td></td></tr></table>'
        catalog = parse_catalog(body, 'https://www.prc.gov.ph/2026-schedule-examination', NOW)
        self.assertEqual(len(catalog['exams']), 2)
        self.assertEqual(len(catalog['sittings']), 1)
        self.assertEqual(catalog['sittings'][0]['start'], '2026-10-08T00:00:00+00:00')
        self.assertEqual(len(catalog['review']), 1)
        publication = {'title': 'October 2026 Testers Computer-Based Licensure Examination Results Released'}
        self.assertEqual(associate(publication, catalog)['examId'], catalog['exams'][0]['id'])
        self.assertIsNone(associate({'title': 'Other General Announcement'}, catalog))

    def test_unrelated_navigation_documents_excluded(self):
        body = b'<nav><a href="/privacy.pdf">Privacy</a></nav><article><h5>Test Results</h5>Posted on 15 October, 2026<a href="/list.pdf">List of Successful Examinees</a></article>'
        record = parse_publication(URL, body, NOW)
        self.assertEqual(record['documents'], ['https://www.prc.gov.ph/list.pdf'])

    @patch('worker.source.socket.getaddrinfo', return_value=[(2, 1, 6, '', ('8.8.8.8', 443))])
    def test_robots_restricts_pdf_requests_and_redirect_hops(self, _):
        policy = self.policy()
        robot = RobotFileParser()
        robot.parse(['User-agent: *', 'Disallow: /sites/default/files/'])
        policy.robots = {'www.prc.gov.ph': robot}
        policy.require_robots = True
        transport = Mock(return_value=(302, {'location': '/sites/default/files/list.pdf'}, b''))
        with self.assertRaises(SourceError):
            fetch(URL, policy, transport=transport)
        self.assertEqual(transport.call_count, 1)
        transport.reset_mock()
        with self.assertRaises(SourceError):
            fetch('https://www.prc.gov.ph/sites/default/files/list.pdf', policy, transport=transport)
        transport.assert_not_called()


class ExtractionTests(unittest.TestCase):
    def test_unreviewed_bytes_are_rejected_before_pdf_parser(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'changed.pdf'
            path.write_bytes(b'%PDF-unreviewed-content')
            with patch('pypdf.PdfReader') as reader:
                with self.assertRaises(ValueError):
                    extract_pdf(path, profile(), NOW)
                reader.assert_not_called()

    def test_repeated_extraction_has_identical_bytes(self):
        first = validate_pages(PAGES, 'a' * 64, profile(), NOW)
        repeated = validate_pages(PAGES, 'a' * 64, profile(), NOW + timedelta(hours=1))
        self.assertEqual(first, repeated)

    def test_validated_output_preserves_unicode_provenance_and_page_references(self):
        report = validate_pages(PAGES, 'a' * 64, profile(), NOW)
        self.assertEqual(report['entries'], ENTRIES)
        self.assertFalse(report['componentsReliable'])
        self.assertEqual(report['documentVersion'], 'a' * 64)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'names.json'
            metadata = write_names_file(report, output)
            self.assertEqual(metadata['namesBytes'], len(output.read_bytes()))
            self.assertEqual(metadata['namesSha256'], hashlib.sha256(output.read_bytes()).hexdigest())

    def test_missing_rows_end_marker_wrong_heading_changed_hash_and_extra_text_rejected(self):
        variants = [PAGES[:1], [PAGES[0], PAGES[1].replace('2 TEST, BÉTA\n', '')],
                    [PAGES[0], PAGES[1].replace('NOTHING FOLLOWS', '')],
                    [PAGES[0].replace('OCTOBER', 'NOVEMBER'), PAGES[1]],
                    [PAGES[0], PAGES[1] + '\n3 TEST, EXTRA'],
                    [PAGES[0] + '\nUNREVIEWED LINE', PAGES[1]]]
        for pages in variants:
            with self.subTest(pages=pages), self.assertRaises(ValueError):
                validate_pages(pages, 'a' * 64, profile(), NOW)
        with self.assertRaises(ValueError):
            validate_pages(PAGES, 'b' * 64, profile(), NOW)

    def test_full_independent_transcript_and_review_samples_required(self):
        for field in ['reviewEvidence', 'entriesSha256', 'samples']:
            reviewed = profile()
            reviewed.pop(field)
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_pages(PAGES, 'a' * 64, reviewed, NOW)
        pages = [PAGES[0].replace('ALPHA', 'WRONG'), PAGES[1]]
        with self.assertRaises(ValueError):
            validate_pages(pages, 'a' * 64, profile(), NOW)

    def test_unsupported_documents_and_restarted_sequence_rejected(self):
        for pages in [[''], ['<html>Sign in</html>'],
                      [PAGES[0], PAGES[1].replace('2 TEST', '1 TEST')]]:
            with self.assertRaises(ValueError):
                validate_pages(pages, 'a' * 64, profile(), NOW)


class PublishTests(unittest.TestCase):
    def test_asset_read_back_precedes_atomic_metadata_switch(self):
        report = validate_pages(PAGES, 'a' * 64, profile(), NOW)
        providers = Mock()
        events = []
        providers.upload.side_effect = lambda key, body: events.append('upload')
        providers.download.side_effect = lambda key: events.append('download') or body
        providers.activate.side_effect = lambda record: events.append('activate')
        providers.public_url.return_value = 'https://example.supabase.co/storage/v1/object/public/validated-names/file.json'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'names.json'
            write_names_file(report, path)
            body = path.read_bytes()
            result = publish_validated(report, path, providers)
        self.assertEqual(events, ['upload', 'download', 'activate'])
        self.assertEqual(result['state'], 'checkingAvailable')
        self.assertTrue(result['current'])

    def test_upload_failure_or_corrupt_readback_never_enables_checking(self):
        report = validate_pages(PAGES, 'a' * 64, profile(), NOW)
        for failure in ['upload', 'download']:
            providers = Mock()
            if failure == 'upload':
                providers.upload.side_effect = RuntimeError('quota')
            else:
                providers.download.return_value = b'corrupt'
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'names.json'
                write_names_file(report, path)
                with self.assertRaises((ValueError, RuntimeError)):
                    publish_validated(report, path, providers)
            providers.activate.assert_not_called()

    def test_file_changed_after_validation_rejected_before_upload(self):
        report = validate_pages(PAGES, 'a' * 64, profile(), NOW)
        providers = Mock()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'names.json'
            path.write_text('{}')
            with self.assertRaises(ValueError):
                publish_validated(report, path, providers)
        providers.upload.assert_not_called()


class MainTests(unittest.TestCase):
    def test_operational_logs_redact_provider_exception_contents(self):
        with patch('sys.stderr', new_callable=io.StringIO) as output:
            log_failure('source setup', ValueError('private-token-and-name'))
            self.assertIn('source setup: ValueError', output.getvalue())
            self.assertNotIn('private-token-and-name', output.getvalue())

    def test_missing_source_configuration_prevents_network_or_provider_access(self):
        providers, fetcher = Mock(), Mock()
        with self.assertRaises(SourceError):
            run({}, providers, NOW, fetcher)
        providers.assert_not_called()
        self.assertEqual(providers.method_calls, [])
        fetcher.assert_not_called()

    def test_delivery_modes_cannot_silently_send(self):
        for mode in ['public', 'test']:
            with self.assertRaises(ValueError):
                run({'delivery': mode}, Mock(), NOW, Mock())

    def config(self):
        return {'sourcePolicy': {'accessAuthorization': 'owner instruction',
                                'routes': {'www.prc.gov.ph': ['/article/', '/sites/default/files/']}},
                'publications': [{'url': URL, 'selection': SELECTION}]}

    def test_real_publication_without_validated_list_has_official_link_fallback(self):
        providers = Mock()
        fetcher = Mock(return_value=b'<h1>Test Results</h1>Posted on 15 October, 2026')
        self.assertEqual(run(self.config(), providers, NOW, fetcher), 0)
        providers.publication.assert_called_once()
        providers.unavailable.assert_called_once()
        providers.health.assert_called_once_with(NOW, True)
        providers.upload.assert_not_called()

    def test_source_outage_preserves_publications_and_changes_health(self):
        providers = Mock()
        self.assertEqual(run(self.config(), providers, NOW, Mock(side_effect=SourceError('offline'))), 1)
        providers.publication.assert_not_called()
        providers.unavailable.assert_not_called()
        providers.health.assert_called_once_with(NOW, False)

    def test_observed_invalid_document_disables_previous_checking_version(self):
        config = self.config()
        config['publications'][0]['profile'] = profile()
        providers = Mock()
        html = b'<h1>Test Results</h1>Posted on 15 October, 2026<a href="/sites/default/files/test.pdf">List of Successful Examinees</a>'
        def fetcher(url, policy, **kwargs):
            return b'%PDF-changed' if url.endswith('.pdf') else html
        with patch('worker.main.extract_pdf', side_effect=ValueError('changed document')):
            self.assertEqual(run(config, providers, NOW, fetcher), 1)
        providers.unavailable.assert_called_once()
        self.assertEqual(providers.unavailable.call_args.kwargs['observed_version'], hashlib.sha256(b'%PDF-changed').hexdigest())

    def test_article_provenance_does_not_change_immutable_name_file(self):
        report = validate_pages(PAGES, 'a' * 64, profile(), NOW)
        config = self.config()
        config['publications'][0]['profile'] = profile()
        providers = Mock()
        html = b'<h1>Test Results</h1>Posted on 15 October, 2026<a href="/sites/default/files/test.pdf">List of Successful Examinees</a>'
        with patch('worker.main.extract_pdf', return_value=report), patch('worker.main.publish_validated') as publish:
            self.assertEqual(run(config, providers, NOW, Mock(return_value=html)), 0)
        self.assertNotIn('publicationVersion', publish.call_args.args[0])
        self.assertIn('publicationVersion', publish.call_args.kwargs['publication'])


if __name__ == '__main__':
    unittest.main()
