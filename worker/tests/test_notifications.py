import copy
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import Mock, patch

from worker.notifications import Delivery, changes, digest, run, snapshot

NOW = datetime(2026, 11, 24, 8, tzinfo=timezone.utc)
SELECTION = {'examId': 'test-exam', 'sittingId': 'test-sitting', 'categoryId': 'general'}
SOURCE = 'https://www.prc.gov.ph/article/test-only'
SITTING = {'examId': 'test-exam', 'categories': {'general': 'General'}, 'active': True,
           'start': '2026-11-24T00:00:00+00:00', 'end': '2026-11-24T00:00:00+00:00',
           'location': 'Test only', 'targetReleaseDate': '2026-11-27T00:00:00+00:00',
           'catalogUrl': 'https://www.prc.gov.ph/2026-schedule-examination'}


def publication(url=SOURCE, selection=None, title='TEST ONLY results released'):
    return {'selection': selection or SELECTION, 'title': title,
            'publicationUrl': url, 'publishedAtUtc': '2026-11-23T16:00:00+00:00'}


class Record:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.id = path.split('/')[-1]
        self.reference = self

    def get(self, **kwargs):
        return self

    def to_dict(self):
        return copy.deepcopy(self.db.data.get(self.path))

    def set(self, value):
        self.db.writes.append(self.path)
        self.db.data[self.path] = copy.deepcopy(value)


class Query:
    def __init__(self, db, collection, filters=None, maximum=10000):
        self.db, self.collection, self.filters, self.maximum = db, collection, filters or [], maximum

    def limit(self, count):
        return Query(self.db, self.collection, self.filters, count)

    def where(self, *, filter):
        return Query(self.db, self.collection, self.filters + [(filter.field_path, filter.value)], self.maximum)

    def order_by(self, *args, **kwargs):
        return self

    def stream(self):
        rows = []
        for path, data in self.db.data.items():
            if path.split('/')[0] != self.collection:
                continue
            def matches(field, value):
                saved = data
                for part in field.split('.'):
                    saved = saved.get(part, {})
                return saved == value
            if all(matches(field, value) for field, value in self.filters):
                rows.append(Record(self.db, path))
        return rows[:self.maximum]


class Database:
    def __init__(self):
        self.data = {'pushPreferences/test-user': {'enabled': True, 'selection': SELECTION, 'token': 'TEST-ONLY-TOKEN'},
                     'sittings/test-sitting': SITTING}
        self.writes = []

    def document(self, path):
        return Record(self, path)

    def collection(self, collection):
        return Query(self, collection)

    def transaction(self):
        return self

    def set(self, ref, value):
        ref.set(value)


class SnapshotTests(unittest.TestCase):
    def test_first_observation_and_target_dates_do_not_announce_results(self):
        current = snapshot(SELECTION, [], None, SITTING, NOW)
        self.assertEqual(changes(None, current, SELECTION, NOW), [])
        previous = {'selection': SELECTION, 'snapshot': current, 'baselineAtUtc': NOW.isoformat()}
        self.assertEqual(changes(previous, current, SELECTION, NOW + timedelta(days=5)), [])

    def test_new_same_day_result_is_detected_after_midnight_posting_timestamp(self):
        previous = {'selection': SELECTION, 'snapshot': snapshot(SELECTION, [], None, SITTING, NOW),
                    'baselineAtUtc': NOW.isoformat()}
        current = snapshot(SELECTION, [publication()], None, SITTING, NOW)
        events = changes(previous, current, SELECTION, NOW)
        self.assertEqual([event['kind'] for event in events], ['result'])

    def test_results_win_over_duplicate_exam_news_and_other_sittings_are_excluded(self):
        item = publication()
        feed = {'freshness': 'fresh', 'lastSuccessfulCheckUtc': NOW.isoformat(), 'notices': [item]}
        other = publication(SOURCE + '-other', {**SELECTION, 'sittingId': 'another-sitting'})
        current = snapshot(SELECTION, [item, other], feed, SITTING, NOW)
        self.assertEqual(len(current['events']), 1)
        self.assertEqual(next(iter(current['events'].values()))['kind'], 'result')

    def test_verified_schedule_notice_and_catalog_change_are_schedule_alerts(self):
        item = publication(title='Rescheduling of TEST ONLY examination')
        feed = {'freshness': 'fresh', 'lastSuccessfulCheckUtc': NOW.isoformat(), 'notices': [item]}
        current = snapshot(SELECTION, [], feed, SITTING, NOW)
        self.assertEqual(next(iter(current['events'].values()))['kind'], 'scheduleChange')
        updated = snapshot(SELECTION, [], None, {**SITTING, 'location': 'TEST ONLY new center'}, NOW)
        previous = {'selection': SELECTION, 'snapshot': snapshot(SELECTION, [], None, SITTING, NOW),
                    'baselineAtUtc': NOW.isoformat()}
        self.assertEqual(changes(previous, updated, SELECTION, NOW)[0]['kind'], 'scheduleChange')

    def test_stale_feed_unrelated_source_and_retirement_do_not_create_false_schedule_alerts(self):
        feed = {'freshness': 'stale', 'notices': [publication()]}
        self.assertFalse(snapshot(SELECTION, [], feed, SITTING, NOW)['events'])
        with self.assertRaises(ValueError):
            snapshot(SELECTION, [publication('https://example.com/test')], None, SITTING, NOW)
        before = snapshot(SELECTION, [], None, SITTING, NOW)
        after = snapshot(SELECTION, [], None, {**SITTING, 'active': False}, NOW)
        previous = {'selection': SELECTION, 'snapshot': before, 'baselineAtUtc': NOW.isoformat()}
        self.assertEqual(changes(previous, after, SELECTION, NOW), [])


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.db = Database()
        self.sender = Mock()
        self.sender.send.return_value = 'sent'
        self.tx = patch('worker.notifications.firestore.transactional', lambda action: action)
        self.tx.start()
        self.addCleanup(self.tx.stop)

    def baseline(self):
        return run(self.db, self.sender, NOW, enabled=True)

    def test_disabled_mode_never_sends_or_writes(self):
        run(self.db, self.sender, NOW)
        self.assertEqual(self.db.writes, [])
        self.sender.send.assert_not_called()

    def test_new_result_sends_once_and_next_scan_does_not_repeat(self):
        self.baseline()
        self.sender.send.assert_not_called()
        self.db.data['publications/new-result'] = publication()
        self.assertEqual(self.baseline()['sent'], 1)
        self.assertEqual(self.baseline()['sent'], 0)
        self.sender.send.assert_called_once()

    def test_retry_is_retained_for_the_next_scan(self):
        self.baseline()
        self.db.data['publications/new-result'] = publication()
        self.sender.send.side_effect = ['retry', 'sent']
        self.assertEqual(self.baseline()['retry'], 1)
        self.assertEqual(self.baseline()['sent'], 1)
        self.assertEqual(self.sender.send.call_count, 2)

    def test_ambiguous_network_outcome_is_recorded_without_duplicate_send(self):
        event = next(iter(snapshot(SELECTION, [publication()], None, SITTING, NOW)['events'].values()))
        self.sender.send.side_effect = OSError('TEST ONLY sensitive token')
        delivery = Delivery(self.db, self.sender)
        self.assertEqual(delivery.deliver('test-user', 'TEST-ONLY-TOKEN', event), 'unknown')
        self.assertEqual(delivery.deliver('test-user', 'TEST-ONLY-TOKEN', event), 'recorded')
        self.sender.send.assert_called_once()

    def test_token_rotation_between_snapshot_and_send_retains_detection_for_next_run(self):
        self.baseline()
        self.db.data['publications/new-result'] = publication()
        original = Record.to_dict
        reads = 0
        def read(record):
            nonlocal reads
            if record.path == 'pushPreferences/test-user':
                reads += 1
                if reads == 2:
                    self.db.data[record.path]['token'] = 'TEST-ONLY-ROTATED'
            return original(record)
        with patch.object(Record, 'to_dict', read):
            self.baseline()
        self.sender.send.assert_not_called()
        self.assertEqual(self.baseline()['sent'], 1)

    def test_deleted_preferences_and_new_selection_do_not_receive_old_alerts(self):
        self.baseline()
        self.db.data['publications/new-result'] = publication()
        self.db.data['pushPreferences/test-user']['enabled'] = False
        self.assertEqual(self.baseline()['sent'], 0)
        self.sender.send.assert_not_called()

    def test_new_consent_session_baselines_updates_from_the_disabled_period(self):
        self.baseline()
        self.db.data['publications/new-result'] = publication()
        self.db.data['pushPreferences/test-user']['registrationId'] = 'TEST-ONLY-NEW-CONSENT'
        self.assertEqual(self.baseline()['sent'], 0)
        self.sender.send.assert_not_called()


if __name__ == '__main__':
    unittest.main()
