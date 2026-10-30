import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from worker import review
from worker.source import SourceError
from worker.tests.test_worker import NOW, SELECTION, URL


class ReviewTests(unittest.TestCase):
    def test_inventory_keeps_every_selection_and_only_current_versions(self):
        publications = [{'selection': SELECTION, 'publicationUrl': URL,
                         'publicationVersion': 'announcement', 'documents': ['official-pdf']}]
        versions = [{'selection': SELECTION, 'publicationUrl': URL, 'current': False,
                     'state': 'checkingAvailable', 'documentVersion': 'old'},
                    {'selection': SELECTION, 'publicationUrl': URL, 'current': True,
                     'state': 'checkingUnavailable', 'documentVersion': 'new', 'reason': 'Review required'}]
        report = review.inventory(publications, versions, NOW)
        self.assertEqual(len(report['selections']), 1)
        row = report['selections'][0]
        self.assertEqual(row['state'], 'checkingUnavailable')
        self.assertEqual(row['documentVersion'], 'new')
        self.assertEqual(row['documents'], ['official-pdf'])
        self.assertEqual(row['publicationUrl'], URL)
        self.assertEqual(row['reason'], 'Review required')
        self.assertEqual(review.inventory(publications, [], NOW)['selections'][0]['state'], 'notPublished')

    def test_acquisition_deduplicates_encrypts_and_never_approves(self):
        report = {'selections': [{'documents': ['allowed', 'restricted']}, {'documents': ['allowed']}]}
        body = b'%PDF-private original name'
        with tempfile.TemporaryDirectory() as directory:
            with patch('worker.review.fetch_pdf', side_effect=[body, SourceError('Restricted')]) as fetcher, \
                 patch('worker.review.subprocess.run', return_value=Mock(stdout=b'encrypted')) as encrypt:
                review.acquire(report, Mock(), Path(directory), Path('public.pem'))
            self.assertEqual(fetcher.call_count, 2)
            self.assertEqual(len(report['downloads']), 2)
            self.assertEqual(report['downloads'][0]['status'], 'awaitingIndependentReview')
            self.assertEqual(report['downloads'][1]['status'], 'unavailable')
            self.assertEqual(encrypt.call_args.kwargs['input'], body)
            files = list(Path(directory).glob('*.cms'))
            self.assertEqual(len(files), 1)
            self.assertEqual(files[0].read_bytes(), b'encrypted')
            self.assertEqual(json.loads((Path(directory) / 'coverage.json').read_bytes()), report)
            self.assertNotIn('private original name', json.dumps(report))

    def test_encryption_failure_stops_without_plaintext_artifact(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch('worker.review.fetch_pdf', return_value=b'%PDF-private'), \
                 patch('worker.review.subprocess.run', side_effect=OSError('encryption unavailable')):
                with self.assertRaises(OSError):
                    review.acquire({'selections': [{'documents': ['allowed']}]}, Mock(), Path(directory), Path('public.pem'))
            self.assertEqual(list(Path(directory).iterdir()), [])
