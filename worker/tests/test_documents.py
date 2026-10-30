import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from google.auth.exceptions import DefaultCredentialsError

from worker.documents import fetch_pdf
from worker.main import main, run
from worker.source import SourceError, SourcePolicy
from worker.tests.test_worker import NOW, URL, SELECTION, PAGES, profile
from worker.extract import validate_pages


DRIVE_ID = 'synthetic-public-file-id'
DRIVE_URL = f'https://drive.google.com/file/d/{DRIVE_ID}/view?usp=sharing'
BODY = b'%PDF-synthetic-reviewed-content'


class DocumentTests(unittest.TestCase):
    def setUp(self):
        self.policy = SourcePolicy({'accessAuthorization': 'test', 'driveApi': True,
            'routes': {'www.prc.gov.ph': ['/sites/default/files/']}})
        self.credentials = Mock(valid=True, token='private-test-token')
        self.metadata = {'id': DRIVE_ID, 'mimeType': 'application/pdf', 'size': str(len(BODY)),
            'md5Checksum': hashlib.md5(BODY).hexdigest(), 'trashed': False,
            'capabilities': {'canDownload': True}, 'copyRequiresWriterPermission': False}
        self.dns = patch('worker.source.socket.getaddrinfo',
            return_value=[(2, 1, 6, '', ('8.8.8.8', 443))])
        self.dns.start()
        self.addCleanup(self.dns.stop)

    def transport(self, metadata=None, body=BODY):
        return Mock(side_effect=[(200, {}, json.dumps(self.metadata if metadata is None else metadata).encode()),
                                 (200, {}, body)])

    def test_drive_api_download_uses_owner_capability_and_exact_id(self):
        transport = self.transport()
        result = fetch_pdf(DRIVE_URL, self.policy, credentials=self.credentials, transport=transport)
        self.assertEqual(result, BODY)
        self.assertEqual(transport.call_count, 2)
        for call in transport.call_args_list:
            self.assertTrue(call.args[0].startswith(f'https://www.googleapis.com/drive/v3/files/{DRIVE_ID}?'))
            self.assertNotIn('private-test-token', call.args[0])
            self.assertEqual(call.kwargs['headers']['Authorization'], 'Bearer private-test-token')
        self.assertTrue(transport.call_args_list[-1].args[0].endswith('?alt=media'))

    def test_unapproved_drive_or_invalid_viewer_url_never_reaches_network(self):
        for url in (DRIVE_URL.replace('https:', 'http:'), DRIVE_URL.replace('drive.google.com', 'evil.test'),
                    DRIVE_URL.replace('drive.google.com', 'user@drive.google.com'),
                    DRIVE_URL.replace('/view', '/view/../other'),
                    f'https://drive.google.com/open?id={DRIVE_ID}'):
            transport = Mock()
            with self.subTest(url=url), self.assertRaises(SourceError):
                fetch_pdf(url, self.policy, credentials=self.credentials, transport=transport)
            transport.assert_not_called()
        self.policy.drive_api_enabled = False
        transport = Mock()
        with self.assertRaises(SourceError):
            fetch_pdf(DRIVE_URL, self.policy, credentials=self.credentials, transport=transport)
        transport.assert_not_called()

    def test_restricted_unexpected_or_oversized_file_never_downloads_content(self):
        for changes in ({'capabilities': {'canDownload': False}}, {'capabilities': {'canDownload': 'true'}},
                        {'copyRequiresWriterPermission': True}, {'trashed': True}, {'id': 'other-file'},
                        {'mimeType': 'text/html'}, {'size': str(20 * 1024 * 1024 + 1)},
                        {'size': '0'}, {'size': '-1'}, {'md5Checksum': ''}):
            transport = self.transport({**self.metadata, **changes})
            with self.subTest(changes=changes), self.assertRaises(SourceError):
                fetch_pdf(DRIVE_URL, self.policy, credentials=self.credentials, transport=transport)
            self.assertEqual(transport.call_count, 1)

    def test_incomplete_or_changed_transfer_is_refused(self):
        for body in (BODY[:-1], b'x' * len(BODY)):
            with self.subTest(body=body), self.assertRaises(SourceError):
                fetch_pdf(DRIVE_URL, self.policy, credentials=self.credentials,
                          transport=self.transport(body=body))

    def test_drive_api_redirect_does_not_forward_credentials(self):
        transport = Mock(return_value=(302, {'location': 'https://drive.usercontent.google.com/download'}, b''))
        with self.assertRaises(SourceError):
            fetch_pdf(DRIVE_URL, self.policy, credentials=self.credentials, transport=transport)
        self.assertEqual(transport.call_count, 1)

    def test_direct_prc_pdf_keeps_existing_fetch_policy(self):
        fetcher = Mock(return_value=BODY)
        url = 'https://www.prc.gov.ph/sites/default/files/test.pdf'
        self.assertEqual(fetch_pdf(url, self.policy, fetcher=fetcher), BODY)
        fetcher.assert_called_once_with(url, self.policy)

    def test_missing_api_identity_fails_without_disclosing_exception_details(self):
        with patch('worker.documents.google.auth.default',
                   side_effect=DefaultCredentialsError('private-test-token')):
            with self.assertRaises(SourceError) as error:
                fetch_pdf(DRIVE_URL, self.policy, transport=Mock())
        self.assertNotIn('private-test-token', str(error.exception))

    def test_worker_downloads_linked_drive_document_before_validation(self):
        reviewed = {**profile(), 'documentUrl': DRIVE_URL, 'originalSha256': hashlib.sha256(BODY).hexdigest()}
        report = validate_pages(PAGES, reviewed['originalSha256'], reviewed, NOW)
        config = {'sourcePolicy': {'accessAuthorization': 'test', 'driveApi': True,
                    'routes': {'www.prc.gov.ph': ['/article/']}},
                  'publications': [{'url': URL, 'selection': SELECTION, 'profile': reviewed}]}
        html = f'<h1>Test Results</h1>Posted on 15 October, 2026<a href="{DRIVE_URL}">List of Successful Examinees</a>'.encode()
        fetcher = Mock(return_value=html)
        transport = self.transport()
        with patch('worker.main.fetch_pdf', side_effect=lambda url, policy, **kw:
                   fetch_pdf(url, policy, credentials=self.credentials, transport=transport)), \
             patch('worker.main.extract_pdf', return_value=report) as extract, \
             patch('worker.main.publish_validated') as publish:
            self.assertEqual(run(config, Mock(), NOW, fetcher), 0)
        extract.assert_called_once()
        publish.assert_called_once()
        self.assertEqual(transport.call_count, 2)
        self.assertFalse(any('drive.google.com' in c.args[0] for c in fetcher.call_args_list))

    def test_private_profiles_load_from_environment_without_changing_public_config(self):
        for value, expected in ((json.dumps({URL: profile()}), 0), ('[]', 1)):
            with self.subTest(value=value[:1]), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'config.json'
                public = {'profiles': {}, 'sourcePolicy': {'accessAuthorization': 'test',
                          'routes': {'www.prc.gov.ph': ['/article/']}}}
                path.write_text(json.dumps(public))
                with patch.dict('os.environ', {'PRC_PRIVATE_PROFILES': value}), \
                     patch('sys.argv', ['worker', '--config', str(path), '--live-sources']), \
                     patch('worker.providers.Providers.from_environment'), \
                     patch('worker.main.run', return_value=0) as scan, \
                     patch('sys.stderr', new_callable=io.StringIO):
                    self.assertEqual(main(), expected)
                if expected == 0:
                    self.assertEqual(scan.call_args.args[0]['profiles'], {URL: profile()})
                else:
                    scan.assert_not_called()
                self.assertEqual(json.loads(path.read_text()), public)


if __name__ == '__main__':
    unittest.main()
