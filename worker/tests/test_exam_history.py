import unittest
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from worker.exam_history import START, article_metadata, audience_patterns, build_history, match_exams
from worker.source import SourceError


class ExamHistoryTests(unittest.TestCase):
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
