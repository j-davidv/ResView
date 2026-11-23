import unittest
from datetime import datetime, timezone
from unittest.mock import Mock

from worker.source import SourcePolicy, SourceError, parse_catalog, associate, associations
from worker.main import discover, run

NOW = datetime(2027, 1, 2, tzinfo=timezone.utc)
ROOT = 'https://www.prc.gov.ph'


def table(rows):
    return ('<table>' + ''.join('<tr>' + ''.join('<td>' + c + '</td>' for c in row)
                               + '</tr>' for row in rows) + '</table>').encode()


class MappingTests(unittest.TestCase):
    def test_nutritionists_dietitians_result_matches_singular_schedule_label(self):
        catalog = parse_catalog(table([
            ['1', 'Nutritionist-Dietitians', 'November 12 and 13, 2026', '', 'NCR'],
        ]), ROOT + '/2026-schedule-examination', NOW)
        for profession in ('Nutritionists-Dietitians', 'Nutritionist-Dietitians'):
            with self.subTest(profession=profession):
                self.assertEqual(associations({'title': f'November 2026 {profession} Computer-Based Licensure Examination Results Released'}, catalog), [
                    {'examId': 'nutritionist-dietitians', 'sittingId': 'nutritionist-dietitians-2026-11-12', 'categoryId': 'all'},
                ])

    def test_same_day_correction_uses_newest_official_index_entry(self):
        config = {'sourcePolicy': {'accessAuthorization': 'test', 'routes': {
            'www.prc.gov.ph': ['/article/', '/articles/', '/2026-schedule-examination']}},
            'catalogUrl': ROOT + '/2026-schedule-examination',
            'resultsUrl': ROOT + '/articles/exam-results'}
        pages = {
            config['catalogUrl']: table([['1', 'Testers', 'May 1, 2026', '', 'NCR']]),
            config['resultsUrl']: b'<a href="/article/newer">Testers Results</a><a href="/article/older">Testers Results</a>',
            ROOT + '/article/newer': b'<h1>May 2026 Testers Results Corrected</h1>Posted on 2 May, 2026',
            ROOT + '/article/older': b'<h1>May 2026 Testers Results</h1>Posted on 2 May, 2026',
        }
        provider = Mock()
        self.assertEqual(run(config, provider, NOW, lambda u, p, **kw:
            b'User-agent: *\nDisallow:' if u.endswith('/robots.txt') else pages[u]), 0)
        provider.unavailable.assert_called_once()
        self.assertEqual(provider.unavailable.call_args.args[0]['publicationUrl'], ROOT + '/article/newer')

    def test_exam_name_can_follow_punctuation_without_matching_inside_words(self):
        catalog = parse_catalog(table([
            ['1', 'Foreign Medical Professionals', 'September 1 and 2, 2026', '', 'NCR'],
        ]), ROOT + '/2026-schedule-examination', NOW)
        selection = associate({'title': 'September 2026 Qualifying Assessment-Foreign Medical Professionals (Computer-Based) Results Released'}, catalog)
        self.assertIsNotNone(selection)
        self.assertEqual(selection['sittingId'], 'foreign-medical-professionals-2026-09-01')
        self.assertIsNone(associate({'title': 'September 2026 OtherForeign Medical Professionals Results Released'}, catalog))

    def test_combined_results_and_teacher_categories(self):
        catalog = parse_catalog(table([
            ['1', 'Electronics Engineers', 'May 1, 2026', '', 'NCR'],
            ['2', 'Electronics Technicians', 'May 2, 2026', '', 'NCR'],
            ['3', 'Professional Teachers', 'May 3, 2026', '', 'NCR'],
        ]), ROOT + '/2026-schedule-examination', NOW)
        found = associations({'title': 'May 2026 Electronics Engineers and Electronics Technicians Results Released'}, catalog)
        self.assertEqual({s['examId'] for s in found}, {'electronics-engineers', 'electronics-technicians'})
        found = associations({'title': 'May 2026 Professional Teachers Results Released'}, catalog)
        self.assertEqual({s['categoryId'] for s in found}, {'elementary', 'secondary'})
        self.assertEqual(associations({'title': 'May 2026 Professional Electronics Engineers Oral Examination Results Released'}, catalog), [])

    def test_history_keeps_announcements_but_only_switches_latest(self):
        selection = {'examId': 'testers', 'sittingId': 'testers-2026-05-01', 'categoryId': 'all'}
        config = {'sourcePolicy': {'accessAuthorization': 'test', 'routes': {'www.prc.gov.ph': ['/article/']}},
                  'publications': [{'url': ROOT + '/article/' + name, 'selection': selection}
                                   for name in ('older', 'newer')]}
        provider = Mock()
        def fetcher(url, policy, **kwargs):
            return b'<h1>May 2026 Testers Results Released</h1>Posted on 3 May, 2026'
        self.assertEqual(run(config, provider, NOW, fetcher), 0)
        self.assertEqual(provider.publication.call_count, 2)
        provider.unavailable.assert_called_once()
        self.assertTrue(provider.unavailable.call_args.args[0]['publicationUrl'].endswith('/newer'))

    def test_special_and_cross_month_dates_preserve_scope(self):
        catalog = parse_catalog(table([
            ['', 'Test Engineers (SPLE)', 'May 29 and 30, 2026', '', 'Singapore'],
            ['', 'Professional Test Engineers (Oral Examination)',
             'November 29 to December 06, 2026', '', 'Dubai'],
        ]), ROOT + '/2026-schedule-examination', NOW)
        self.assertEqual(len(catalog['sittings']), 2)
        self.assertEqual(catalog['sittings'][0]['type'], 'special')
        self.assertEqual(catalog['sittings'][0]['location'], 'Singapore')
        self.assertEqual(catalog['sittings'][1]['end'], '2026-12-06T00:00:00+00:00')
        self.assertIsNone(associate({'title': 'May 2026 Test Engineers Results Released'}, catalog))
        self.assertIsNotNone(associate({'title': 'May 2026 Test Engineers Special Professional Licensure Examination Results Released'}, catalog))

    def test_annotations_are_not_silently_ignored(self):
        catalog = parse_catalog(table([
            ['1', 'Testers', 'May 1, 2026', '', 'NCR'],
            ['2', 'Other Testers', 'May 2, 2026 (Rescheduled to June 3, 2026)', '', 'NCR'],
        ]), ROOT + '/2026-schedule-examination', NOW)
        self.assertEqual(len(catalog['sittings']), 1)
        self.assertEqual(len(catalog['review']), 1)

    def test_archive_and_rollover_follow_official_links(self):
        config = {'sourcePolicy': {'accessAuthorization': 'test', 'routes': {
            'www.prc.gov.ph': ['/exam-schedules-menu', '/{year}-schedule-examination',
                              '/articles/exam-results', '/article/']}},
            'catalogIndexUrl': ROOT + '/exam-schedules-menu', 'coverageStartYear': 2026,
            'resultsUrl': ROOT + '/articles/exam-results'}
        pages = {
            config['catalogIndexUrl']: b'<a href="/2026-schedule-examination">2026</a><a href="/2027-schedule-examination">2027</a>',
            ROOT + '/2026-schedule-examination': table([['1', 'Testers', 'May 1, 2026', '', 'NCR']]),
            ROOT + '/2027-schedule-examination': table([['1', 'Testers', 'May 1, 2027', '', 'NCR']]),
            config['resultsUrl']: b'<a href="/article/new">May 2027 Testers Results Released</a><a href="?page=1">Next page</a>',
            config['resultsUrl'] + '?page=1': b'<a href="/article/old">May 2026 Testers Results Released</a>',
            ROOT + '/article/new': b'<h1>May 2027 Testers Results Released</h1>Posted on 2 May, 2027',
            ROOT + '/article/old': b'<h1>May 2026 Testers Results Released</h1>Posted on 2 May, 2026',
        }
        catalog, publications = discover(config, SourcePolicy(config['sourcePolicy']), NOW,
                                          lambda u, p: pages[u])
        self.assertEqual(len(catalog['sittings']), 2)
        self.assertEqual(len(publications), 2)
        self.assertEqual(len(catalog['catalogUrls']), 2)
        config['publicationMappings'] = {ROOT + '/index.php/article/new': {
            'publicationVersion': publications[-1]['publication']['publicationVersion'],
            'selections': [publications[-1]['selection']], 'unresolvedSittings': ['Other location']}}
        partial, mapped = discover(config, SourcePolicy(config['sourcePolicy']), NOW,
                                   lambda u, p: pages[u])
        self.assertEqual(len(mapped), 2)
        self.assertEqual(partial['review'][0]['publicationUrl'], ROOT + '/article/new')
        config['publicationMappings'] = {ROOT + '/article/new': {
            'publicationVersion': 'different-reviewed-version', 'selections': [publications[-1]['selection']]}}
        changed, publications = discover(config, SourcePolicy(config['sourcePolicy']), NOW,
                                         lambda u, p: pages[u])
        self.assertEqual(len(publications), 2)
        self.assertTrue(publications[-1]['mappingChanged'])
        self.assertEqual(changed['review'][0]['publicationUrl'], ROOT + '/article/new')
        config.pop('publicationMappings')
        policy = SourcePolicy(config['sourcePolicy'])
        with self.assertRaises(SourceError):
            policy.check(ROOT + '/2027-schedule-examination/admin')
        config['maxIndexPages'] = 1
        with self.assertRaisesRegex(SourceError, 'history is incomplete'):
            discover(config, policy, NOW, lambda u, p: pages[u])
        config['maxIndexPages'] = 100
        pages[config['catalogIndexUrl']] = b'<a href="/2026-schedule-examination">2026</a>'
        with self.assertRaisesRegex(SourceError, 'Current-year schedule missing'):
            discover(config, policy, NOW, lambda u, p: pages[u])
        with self.assertRaisesRegex(SourceError, 'Current-year schedule missing'):
            discover(config, policy, datetime(2026, 12, 31, 16, tzinfo=timezone.utc), lambda u, p: pages[u])


if __name__ == '__main__':
    unittest.main()
