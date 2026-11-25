"""Opt-in FCM delivery from verified public metadata; disabled unless requested."""
import argparse
import hashlib
import http.client
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

from google.auth import default
from google.auth.transport.requests import Request
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

FIELDS = ('examId', 'sittingId', 'categoryId')
SCHEDULE = re.compile(r'\breschedul\w*|\bpostpon\w*|\bcancel\w*|\b(?:revised|amended|new)\s+(?:examination\s+)?schedule', re.I)
MAX_EVENTS = 100


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def official_url(value):
    parsed = urlsplit(value)
    if (parsed.scheme != 'https' or parsed.hostname not in ('prc.gov.ph', 'www.prc.gov.ph')
            or parsed.port not in (None, 443) or parsed.username or parsed.password
            or parsed.query or parsed.fragment):
        raise ValueError('Unconfirmed official alert source.')
    return 'https://www.prc.gov.ph' + parsed.path.replace('/index.php/', '/', 1)


def timestamp(value):
    parsed = value if isinstance(value, datetime) else datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('A timezone is required.')
    return parsed.astimezone(timezone.utc)


def snapshot(selection, publications, feed, sitting, now):
    """Never manufacture a result from a target date or a retired sitting."""
    events = {}
    feed_ready = False
    def add(kind, title, url, posted):
        url = official_url(url)
        posted = timestamp(posted)
        if posted > now or not isinstance(title, str) or not title.strip():
            raise ValueError('Invalid official alert metadata.')
        key = digest([selection, url])
        events[key] = {'id': key, 'sourceId': url, 'kind': kind, 'title': title[:240], 'url': url,
                       'publishedAtUtc': posted.isoformat(), 'selection': selection}

    # Exam-wide notices retain their official title; they do not claim that the
    # notice applies to every sitting. Results below take precedence by URL.
    if feed and feed.get('retired') is not True and feed.get('freshness') == 'fresh':
        checked = timestamp(feed['lastSuccessfulCheckUtc'])
        if timedelta(0) <= now - checked <= timedelta(hours=36):
            feed_ready = True
            for item in feed.get('notices', []):
                add('scheduleChange' if SCHEDULE.search(item['title']) else 'announcement',
                    item['title'], item['publicationUrl'], item['publishedAtUtc'])
    for item in publications:
        if item.get('selection') == selection:
            add('result', item['title'], item['publicationUrl'], item['publishedAtUtc'])
    schedule = None
    if sitting and sitting.get('active') is not False:
        if sitting.get('examId') != selection['examId'] or selection['categoryId'] not in sitting.get('categories', {}):
            raise ValueError('Unconfirmed alert selection.')
        source = official_url(sitting['catalogUrl'])
        schedule = {key: timestamp(sitting[key]).date().isoformat() if sitting.get(key) else None
                    for key in ('start', 'end', 'targetReleaseDate')}
        schedule['location'] = sitting.get('location', '')
        schedule['url'] = source
    events = dict(sorted(events.items(), key=lambda item: item[1]['publishedAtUtc'], reverse=True)[:MAX_EVENTS])
    return {'events': events, 'schedule': schedule, 'feedReady': feed_ready}


def changes(previous, current, selection, now):
    """The first successful observation establishes a baseline, without a flood."""
    if not previous or previous.get('selection') != selection:
        return []
    # PRC dates have day precision. A notice published later on the baseline
    # day must not be discarded just because its timestamp is midnight.
    ph = timezone(timedelta(hours=8))
    baseline = timestamp(previous['baselineAtUtc']).astimezone(ph).replace(hour=0, minute=0, second=0, microsecond=0)
    events = [event for key, event in current['events'].items()
              if key not in previous['snapshot']['events'] and
              (previous['snapshot'].get('feedReady') or event['kind'] == 'result') and
              baseline <= timestamp(event['publishedAtUtc']) and
              now - timestamp(event['publishedAtUtc']) <= timedelta(days=7)]
    before, after = previous['snapshot'].get('schedule'), current.get('schedule')
    if before and after and any(before.get(key) != after.get(key)
                               for key in ('start', 'end', 'location', 'targetReleaseDate')):
        revision = '|'.join(str(after.get(key) or '')[:10] if key != 'location' else str(after.get(key) or '')
                            for key in ('start', 'end', 'location', 'targetReleaseDate'))
        events.append({'id': digest([selection, after]), 'sourceId': 'schedule:' + revision, 'kind': 'scheduleChange',
                       'title': 'The official schedule for your selected exam has changed.',
                       'url': after['url'], 'publishedAtUtc': now.isoformat(), 'selection': selection})
    return sorted(events, key=lambda event: event['publishedAtUtc'])[-MAX_EVENTS:]


class FcmSender:
    def __init__(self, project):
        if not re.fullmatch(r'[a-z][a-z0-9-]{4,62}', project):
            raise ValueError('Invalid Firebase project.')
        self.project = project
        self.credentials, _ = default(scopes=['https://www.googleapis.com/auth/firebase.messaging'])

    def send(self, token, event):
        if not self.credentials.valid:
            self.credentials.refresh(Request())
        labels = {'result': 'Results published', 'announcement': 'Official exam update', 'scheduleChange': 'Schedule update'}
        body = {'message': {'token': token,
                           'notification': {'title': 'ResView · ' + labels[event['kind']], 'body': event['title']},
                           'data': {**event['selection'], 'alertId': event['id'], 'kind': event['kind'],
                                    'title': event['title'], 'url': event['url'], 'publishedAtUtc': event['publishedAtUtc']},
                           'android': {'priority': 'high', 'ttl': '86400s',
                                       'notification': {'channel_id': 'resview_alerts', 'tag': event['id']}}}}
        body['message']['data']['sourceId'] = event.get('sourceId', event['url'])
        connection = http.client.HTTPSConnection('fcm.googleapis.com', timeout=30)
        try:
            connection.request('POST', '/v1/projects/' + self.project + '/messages:send',
                               json.dumps(body).encode(), {'Authorization': 'Bearer ' + self.credentials.token,
                                                          'Content-Type': 'application/json'})
            response = connection.getresponse()
            payload = json.loads(response.read(65536))
            if response.status == 200 and payload.get('name'):
                return 'sent'
            codes = [detail.get('errorCode') for detail in payload.get('error', {}).get('details', [])
                     if detail.get('@type', '').endswith('FcmError')]
            if 'UNREGISTERED' in codes:
                return 'unregistered'
            if response.status in (429, 500, 503):
                return 'retry'
            return 'rejected'
        finally:
            connection.close()


class Delivery:
    """Receipts deliberately avoid re-sending ambiguous network outcomes."""
    def __init__(self, database, sender):
        self.db, self.sender = database, sender

    def deliver(self, uid, token, event):
        receipt = self.db.document('deliveryAttempts/' + digest([uid, event['id']]))
        @firestore.transactional
        def claim(tx):
            saved = receipt.get(transaction=tx).to_dict()
            if saved and saved.get('state') != 'retry':
                return False
            tx.set(receipt, {'state': 'sending', 'at': firestore.SERVER_TIMESTAMP})
            return True
        if not claim(self.db.transaction()):
            return 'recorded'
        try:
            outcome = self.sender.send(token, event)
        except Exception:
            # FCM might have accepted the message before the connection failed.
            # Do not log the exception, token, payload, credentials, or user id.
            outcome = 'unknown'
        receipt.set({'state': outcome, 'at': firestore.SERVER_TIMESTAMP})
        return outcome


def run(database, sender, now, *, enabled=False, uid=None, max_devices=200):
    if uid and not re.fullmatch(r'[a-zA-Z0-9_-]{1,128}', uid):
        raise ValueError('Invalid registration document identifier.')
    query = database.collection('pushPreferences')
    rows = [database.document('pushPreferences/' + uid).get()] if uid else list(query.limit(max_devices + 1).stream())
    if len(rows) > max_devices:
        raise ValueError('Registration limit exceeded; review capacity before increasing it.')
    delivery = Delivery(database, sender) if enabled else None
    cache, counts = {}, {'devices': 0, 'new': 0, 'sent': 0, 'retry': 0, 'failed': 0}
    for row in rows:
        preference = row.to_dict() or {}
        if preference.get('enabled') is not True:
            continue
        selection = preference.get('selection', {})
        token = preference.get('token')
        if (set(selection) != set(FIELDS) or any(not isinstance(selection[k], str) or
                not re.fullmatch(r'[\w-]{1,256}', selection[k]) for k in FIELDS)
                or not isinstance(token, str) or not 0 < len(token) <= 4096):
            counts['failed'] += 1
            continue
        key = digest(selection)
        try:
            if key not in cache:
                publications = database.collection('publications')
                for field in FIELDS:
                    publications = publications.where(filter=FieldFilter('selection.' + field, '==', selection[field]))
                publications = [item.to_dict() for item in publications.order_by('publishedAtUtc', direction=firestore.Query.DESCENDING).limit(50).stream()]
                feed = database.document('examUpdates/' + selection['examId']).get().to_dict()
                sitting = database.document('sittings/' + selection['sittingId']).get().to_dict()
                if not sitting or sitting.get('examId') != selection['examId'] or selection['categoryId'] not in sitting.get('categories', {}):
                    raise ValueError('Selection is outside the published catalog.')
                cache[key] = snapshot(selection, publications, feed, sitting, now)
            current = cache[key]
            ref = database.document('workerState/push-' + digest(row.id))
            previous = ref.get().to_dict()
            registration = preference.get('registrationId')
            same = previous and previous.get('selection') == selection and previous.get('registrationId') == registration
            events = changes(previous if same else None, current, selection, now)
            pending = {event['id']: event for event in (previous.get('pending', []) if same else [])}
            pending.update({event['id']: event for event in events})
            counts['devices'] += 1
            counts['new'] += len(events)
            if not enabled:
                continue
            retry = []
            consent_changed = False
            for event in sorted(pending.values(), key=lambda event: event['publishedAtUtc'])[-MAX_EVENTS:]:
                if now - timestamp(event['publishedAtUtc']) > timedelta(days=7):
                    continue
                # Recheck consent and token before every send; a deletion or new
                # selection invalidates this run's earlier registration snapshot.
                latest = row.reference.get().to_dict() or {}
                if latest.get('enabled') is not True or latest.get('selection') != selection or latest.get('token') != token:
                    consent_changed = True
                    break
                outcome = delivery.deliver(row.id, token, event)
                if outcome == 'retry':
                    retry.append(event)
                    counts['retry'] += 1
                elif outcome == 'sent':
                    counts['sent'] += 1
                elif outcome == 'unregistered':
                    # Keep preference ownership/deletion with the client. A later
                    # rotation replaces the invalid token without exposing it.
                    counts['failed'] += 1
                    break
                elif outcome not in ('recorded',):
                    counts['failed'] += 1
            if consent_changed:
                continue
            state = {'selection': selection, 'snapshot': current, 'pending': retry,
                     'registrationId': registration,
                     'baselineAtUtc': previous['baselineAtUtc'] if same else now.isoformat()}
            if state != previous:
                ref.set(state)
        except Exception:
            counts['failed'] += 1
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delivery', choices=['disabled', 'send'], default='disabled')
    parser.add_argument('--uid', help='Restrict processing to a single consenting registration.')
    args = parser.parse_args()
    try:
        project = os.environ['FIREBASE_PROJECT_ID']
        sending = args.delivery == 'send'
        counts = run(firestore.Client(project=project), FcmSender(project) if sending else None,
                     datetime.now(timezone.utc), enabled=sending, uid=args.uid)
    except Exception as error:
        print('Notification worker failed: ' + type(error).__name__, file=sys.stderr)
        raise SystemExit(1) from None
    print(json.dumps(counts, sort_keys=True))
    if counts['failed'] or counts['retry']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
