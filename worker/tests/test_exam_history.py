import unittest
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

from worker.exam_history import START, article_metadata, audience_patterns, build_history, hosted_transport, match_exams
from worker.source import SourceError


class ExamHistoryTests(unittest.TestCase):
    def test_index_php_issuances_are_fetched_and_matched_by_description(self):
        now = datetime(2026, 7, 14, tzinfo=timezone.utc)
        catalog = {'exams': [{'id': 'criminologists'}], 'sittings': [], 'review': []}
        for kind in ('resolution', 'memorandum-circular'):
            url = f'https://www.prc.gov.ph/index.php/prc-{kind}-no-1-s-2026'
            title = 'PRC Resolution No. 1' if kind == 'resolution' else 'PRC Memorandum No. 1'
            body = (f'<article><h1>{title}</h1>Posted on 3 July, 2026'
                    '<p>Description Adding a testing center for Criminologists Attachment PDF</p></article>').encode()
            config = {'sourcePolicy': {'accessAuthorization': 'test',
                      'routes': {'www.prc.gov.ph': ['/robots.txt']},
                      'exactRoutes': {'www.prc.gov.ph': []}}, 'scheduleOverrides': [],
                      'advisoryPilot': {'articles': {}}}
            fetcher = Mock(side_effect=lambda target, *_, **kwargs: body if target == url else b'User-agent: *\nAllow: /')
            with self.subTest(kind=kind), TemporaryDirectory() as folder, patch('worker.exam_history.parse_catalog', return_value=catalog):
                feeds, _ = build_history(config, now, Path(folder),
                                         inventory=lambda *_: {url: (title, url, '202607')}, fetcher=fetcher)
                self.assertEqual([item['publicationUrl'] for item in feeds['criminologists']], [url])

    def test_abbreviated_special_profession_title_stays_in_sple_history(self):
        patterns = audience_patterns([{'id': key} for key in
                                     ('certified-public-accountants', 'certified-public-accountants-sple')])
        for special in ('Special Prof.', 'Special Professional', 'SPLE'):
            with self.subTest(special=special):
                self.assertEqual(match_exams(f'May 2026 Certified Public Accountants {special} Licensure Exam. Results Released', patterns),
                                 ['certified-public-accountants-sple'])
        self.assertEqual(match_exams('May 2026 Certified Public Accountants Licensure Examination Results Released', patterns),
                         ['certified-public-accountants'])

    def test_hosted_transport_preserves_source_retry_and_region(self):
        response = Mock(status=200, headers={'X-PRC-Status': '429', 'X-PRC-retry-after': '5'})
        response.read.return_value = b''
        with patch.dict('os.environ', {'PRC_ARCHIVE_TOKEN': 'test-only'}), \
                patch('worker.exam_history.http.client.HTTPSConnection') as connect:
            connection = connect.return_value
            connection.getresponse.return_value = response
            status, headers, body = hosted_transport('https://www.prc.gov.ph/robots.txt', '', 1024, 8)
            self.assertEqual((status, headers, body), (429, {'retry-after': '5'}, b''))
            self.assertEqual(connection.request.call_args.kwargs['headers']['x-region'], 'ap-southeast-1')
            response.read.assert_called_once_with(1025)
            connection.close.assert_called_once()
        with self.assertRaises(SourceError):
            hosted_transport('https://www.prc.gov.ph/robots.txt?x=1', '', 1024, 8)

    def test_overlapping_names_combined_announcements_and_special_exams(self):
        ids = ['architects', 'landscape-architects', 'architect-sple',
               'electronics-engineers', 'professional-electronics-engineers-oral-examination']
        patterns = audience_patterns([{'id': key} for key in ids])
        self.assertEqual(match_exams('Landscape Architects results', patterns), ['landscape-architects'])
        self.assertEqual(match_exams('Special Professional Licensure Examination for Architects', patterns), ['architect-sple'])
        self.assertEqual(match_exams('Oathtaking of Professional Electronics Engineers and Electronics Engineers', patterns),
                         sorted(ids[-2:]))
        self.assertEqual(match_exams('Application deadline for an unidentified exam', patterns), [])

    def test_resolution_keeps_subject_and_philippine_posting_day(self):
        html = (b'<article><h1>PRC Resolution No. 1</h1>Posted on 1 January, 2026'
                b'<p>Description Moving the Architects exam in Cebu Attachment PDF</p></article>')
        title, posted, lead = article_metadata(html)
        self.assertEqual(posted, START)
        self.assertEqual(title, 'PRC Resolution No. 1')
        self.assertEqual(lead, 'Moving the Architects exam in Cebu')

    def test_multiple_sittings_share_one_sorted_verified_history(self):
        now = datetime(2026, 7, 14, tzinfo=timezone.utc)
        catalog = {'exams': [{'id': 'architects'}, {'id': 'nurses'}], 'sittings': [], 'review': []}
        config = {'sourcePolicy': {'accessAuthorization': 'test',
                  'routes': {'www.prc.gov.ph': ['/article/', '/robots.txt']},
                  'exactRoutes': {'www.prc.gov.ph': []}}, 'scheduleOverrides': [],
                  'advisoryPilot': {'articles': {}}}
        rows, pages = {}, {}
        for name, title, date, month in [
            ('jan', 'December 2025 Architects results', '1 January', '202601'),
            ('jul', 'July 2026 Architects regional schedule', '13 July', '202607'),
        ]:
            url = 'https://www.prc.gov.ph/article/' + name
            rows[url] = (title, url, month)
            pages[url] = f'<article><h1>{title}</h1>Posted on {date}, 2026</article>'.encode()

        def fetcher(url, *_, **kwargs):
            return pages.get(url, b'User-agent: *\nAllow: /')
        with TemporaryDirectory() as folder, patch('worker.exam_history.parse_catalog', return_value=catalog):
            feeds, _ = build_history(config, now, Path(folder), inventory=lambda *_: rows, fetcher=fetcher)
            self.assertEqual([item['title'] for item in feeds['architects']],
                             ['July 2026 Architects regional schedule', 'December 2025 Architects results'])
            self.assertEqual(feeds['nurses'], [])
            pages[url] = b'<article>Incomplete response</article>'
            with self.assertRaises(SourceError):
                build_history(config, now, Path(folder), inventory=lambda *_: rows, fetcher=fetcher)
