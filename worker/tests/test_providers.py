import unittest
from unittest.mock import Mock, patch

from worker.providers import Providers, identifier, review_identifier


class ProviderTests(unittest.TestCase):
    def test_review_aliases_remain_one_pending_issue(self):
        record = {'title': 'Test Results', 'publicationUrl': 'https://www.prc.gov.ph/index.php/article/result',
                  'reason': 'Requires review.'}
        canonical = {**record, 'publicationUrl': 'https://www.prc.gov.ph/article/result'}
        self.assertEqual(review_identifier(record), review_identifier(canonical))
        db = Mock()
        db.collection.return_value.stream.return_value = [
            Mock(id=identifier(record), to_dict=lambda: {**record, 'status': 'pending'})]
        Providers(db).review([canonical], catalog={'sittings': []}, now=Mock())
        db.collection.return_value.document.return_value.update.assert_called_once_with(
            {'status': 'alias', 'canonicalReviewId': review_identifier(canonical)})

    def test_article_aliases_use_one_publication_identity(self):
        db = Mock()
        provider = Providers(db)
        record = {'selection': {'examId': 'test', 'sittingId': 'sitting', 'categoryId': 'all'},
                  'publicationUrl': 'https://www.prc.gov.ph/index.php/article/result'}
        provider.publication(record)
        provider.publication({**record, 'publicationUrl': 'https://www.prc.gov.ph/article/result'})
        calls = db.collection.return_value.document.call_args_list
        self.assertEqual(calls[0].args, calls[1].args)
        self.assertEqual(db.collection.return_value.document.return_value.set.call_args_list[0].args[0]['publicationUrl'],
                         'https://www.prc.gov.ph/index.php/article/result')

    def setUp(self):
        self.db = Mock()
        self.providers = Providers(self.db, 'example.supabase.co', 'private-worker-key')
        self.pointer, self.target = Mock(), Mock()
        self.db.collection.return_value.document.side_effect = [self.pointer, self.target, Mock()]
        self.pointer.get.return_value.to_dict.return_value = {}
        self.target.get.return_value.to_dict.return_value = {}
        self.record = {'selection': {'examId': 'exam', 'sittingId': 'sitting', 'categoryId': 'all'},
                       'documentVersion': 'version', 'publicationVersion': 'publication-v1',
                       'state': 'checkingAvailable', 'namesSha256': 'a' * 64, 'current': True}
        self.decorator = patch('worker.providers.firestore.transactional', side_effect=lambda f: f)
        self.decorator.start()
        self.addCleanup(self.decorator.stop)

    def test_correction_supersedes_previous_version_in_same_transaction(self):
        self.pointer.get.return_value.to_dict.return_value = {'versionId': 'old-version'}
        self.providers.activate(self.record)
        transaction = self.db.transaction.return_value
        transaction.update.assert_called_once()
        self.assertEqual(transaction.update.call_args.args[1], {'current': False, 'state': 'superseded'})
        self.assertEqual(transaction.set.call_count, 2)

    def test_known_historical_version_cannot_be_reactivated(self):
        self.pointer.get.return_value.to_dict.return_value = {'versionId': 'new-version'}
        self.target.get.return_value.to_dict.return_value = {'state': 'superseded'}
        with self.assertRaises(ValueError):
            self.providers.activate(self.record)
        self.db.transaction.return_value.set.assert_not_called()

    def test_successful_repeated_publication_is_idempotent_and_checksum_immutable(self):
        version_id = identifier([self.record['selection'], self.record['documentVersion']])
        self.pointer.get.return_value.to_dict.return_value = {'versionId': version_id}
        self.target.get.return_value.to_dict.return_value = dict(self.record)
        self.providers.activate(self.record)
        self.db.transaction.return_value.set.assert_not_called()
        self.db.collection.return_value.document.side_effect = [self.pointer, self.target]
        self.record['namesSha256'] = 'b' * 64
        with self.assertRaises(ValueError):
            self.providers.activate(self.record)

    def test_same_publication_scan_does_not_downgrade_available_list(self):
        self.pointer.get.return_value.to_dict.return_value = {
            'versionId': 'validated-list', 'publicationVersion': 'publication-v1'}
        self.providers._switch(self.record, fallback=True)
        self.db.transaction.return_value.set.assert_not_called()

    def test_same_publication_updates_only_current_selection_check_timestamp(self):
        self.record['lastSuccessfulCheckUtc'] = 'now'
        self.pointer.get.return_value.to_dict.return_value = {
            'versionId': 'validated-list', 'publicationVersion': 'publication-v1'}
        self.providers._switch(self.record, fallback=True)
        self.db.transaction.return_value.update.assert_called_once()
        self.assertEqual(self.db.transaction.return_value.update.call_args.args[1], {'lastSuccessfulCheckUtc': 'now'})

    def test_observed_invalid_current_document_can_revoke_available_state(self):
        version_id = identifier([self.record['selection'], self.record['documentVersion']])
        self.pointer.get.return_value.to_dict.return_value = {'versionId': version_id}
        self.target.get.return_value.to_dict.return_value = dict(self.record)
        self.record['state'] = 'checkingUnavailable'
        self.record.pop('namesSha256')
        self.providers._switch(self.record)
        self.db.transaction.return_value.set.assert_called()

    def test_cancelled_sitting_retired_but_unparsed_exam_preserved_for_review(self):
        self.db.collection.return_value.where.return_value.stream.return_value = [
            Mock(id='old', to_dict=lambda: {'examId': 'cancelled'}),
            Mock(id='unparsed', to_dict=lambda: {'examId': 'needs-review'})]
        self.providers.catalog({'exams': [], 'sittings': [], 'catalogUrl': 'official',
                                'review': [{'examId': 'needs-review'}]})
        self.db.batch.return_value.update.assert_called_once()
        self.assertEqual(self.db.batch.return_value.update.call_args.args[1], {'active': False})

    def test_failed_health_check_preserves_last_success_timestamp(self):
        self.providers.health(Mock(isoformat=lambda: 'now'), False)
        self.db.document.return_value.set.assert_called_once_with(
            {'freshness': 'stale', 'lastAttemptUtc': 'now'}, merge=True)

    def test_review_resolves_only_evidenced_rows_without_deleting_history(self):
        db = Mock()
        db.collection.return_value.stream.return_value = [
            Mock(id='mapped', to_dict=lambda: {'publicationUrl': 'official-result'}),
            Mock(id='parsed', to_dict=lambda: {'examId': 'exam', 'officialDates': 'May 1, 2026'}),
            Mock(id='unknown', to_dict=lambda: {'publicationUrl': 'unknown-result'})]
        Providers(db).review([], catalog={'sittings': [{'examId': 'exam', 'officialDates': 'May 1, 2026'}]},
                             publications=[{'url': 'official-result'}], now=Mock(isoformat=lambda: 'now'))
        self.assertEqual([c.args[0] for c in db.collection.return_value.document.call_args_list], ['mapped', 'parsed'])
        self.assertEqual(db.collection.return_value.document.return_value.update.call_count, 2)
        db.collection.return_value.document.return_value.delete.assert_not_called()

    def test_upload_conflict_only_accepted_when_existing_bytes_identical(self):
        self.providers._storage = Mock(return_value=(409, b''))
        self.providers.download = Mock(return_value=b'original')
        self.providers.upload('version/file.json', b'original')
        with self.assertRaises(ValueError):
            self.providers.upload('version/file.json', b'changed')

    def test_admin_credentials_never_sent_for_public_readback(self):
        with patch('worker.providers.http.client.HTTPSConnection') as connection:
            response = connection.return_value.getresponse.return_value
            response.status, response.read.return_value = 200, b'public'
            self.providers.download('version/file.json')
            headers = connection.return_value.request.call_args.kwargs['headers']
            self.assertNotIn('Authorization', headers)
            self.assertNotIn('apikey', headers)


if __name__ == '__main__':
    unittest.main()
