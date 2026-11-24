import hashlib
import http.client
import os
import re
from urllib.parse import quote

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from worker.extract import MAX_BYTES, encode
from worker.source import SourceError, publication_identity_url


def identifier(value):
    return hashlib.sha256(encode(value)).hexdigest()


def review_identifier(record):
    identity = {key: record[key] for key in ('examId', 'officialDates', 'publicationUrl', 'title', 'reason') if key in record}
    if identity.get('publicationUrl'):
        identity['publicationUrl'] = publication_identity_url(identity['publicationUrl'])
    return identifier(identity)


class Providers:
    def __init__(self, database, storage_host='', storage_key=''):
        if storage_host and not re.fullmatch(r'[a-z0-9]+\.supabase\.co', storage_host):
            raise ValueError('Use the provider Supabase project hostname.')
        self.db, self.storage_host, self.storage_key = database, storage_host, storage_key

    @classmethod
    def from_environment(cls):
        project = os.environ['FIREBASE_PROJECT_ID']
        return cls(firestore.Client(project=project), os.environ.get('SUPABASE_STORAGE_HOST', ''),
                   os.environ.get('SUPABASE_SERVICE_ROLE_KEY', ''))

    def catalog(self, catalog):
        # Batches stay below Firestore's write limit, and never touch private preferences.
        for collection in ('exams', 'sittings'):
            rows = catalog[collection]
            for offset in range(0, len(rows), 400):
                batch = self.db.batch()
                for row in rows[offset:offset + 400]:
                    record = {key: value for key, value in row.items() if key != 'id'}
                    if collection == 'sittings':
                        record['active'] = True
                    batch.set(self.db.collection(collection).document(row['id']), record)
                batch.commit()
        current = {row['id'] for row in catalog['sittings']}
        unparsed_exams = {row.get('examId') for row in catalog['review']
                         if row.get('status') != 'cancelled' and row.get('field') != 'targetReleaseDate'}
        retired = [row for url in catalog.get('catalogUrls', [catalog['catalogUrl']])
            for row in self.db.collection('sittings').where(
            filter=FieldFilter('catalogUrl', '==', url)).stream()
            if row.id not in current and row.to_dict().get('examId') not in unparsed_exams]
        for offset in range(0, len(retired), 400):
            batch = self.db.batch()
            for row in retired[offset:offset + 400]:
                batch.update(self.db.collection('sittings').document(row.id), {'active': False})
            batch.commit()

    def publication(self, record):
        key = identifier([record['selection'], publication_identity_url(record['publicationUrl'])])
        self.db.collection('publications').document(key).set(record)

    def _switch(self, record, *, fallback=False, pending=False):
        record = dict(record)
        selection_id = identifier(record['selection'])
        version_id = identifier([record['selection'], record['documentVersion']])
        pointer = self.db.collection('workerState').document(selection_id)
        target = self.db.collection('resultVersions').document(version_id)

        @firestore.transactional
        def switch(transaction):
            prior = pointer.get(transaction=transaction).to_dict() or {}
            existing = target.get(transaction=transaction).to_dict() or {}
            old_id = prior.get('versionId')
            if pending and old_id == version_id and existing.get('state') == 'checkingAvailable':
                return
            if fallback and prior.get('publicationVersion') == record.get('publicationVersion') and old_id:
                if record.get('lastSuccessfulCheckUtc'):
                    transaction.update(self.db.collection('resultVersions').document(old_id),
                                       {'lastSuccessfulCheckUtc': record['lastSuccessfulCheckUtc']})
                return
            if old_id and old_id != version_id and existing:
                raise ValueError('Refusing to reactivate a historical version.')
            if existing.get('namesSha256'):
                if record['state'] == 'checkingAvailable' and existing['namesSha256'] != record.get('namesSha256'):
                    raise ValueError('Immutable document version changed bytes.')
                if record['state'] == 'checkingUnavailable':
                    record['namesSha256'] = existing['namesSha256']
            if existing.get('state') == 'checkingAvailable' and record['state'] == 'checkingAvailable':
                if fallback:
                    return
                if record.get('lastSuccessfulCheckUtc'):
                    transaction.update(target, {'lastSuccessfulCheckUtc': record['lastSuccessfulCheckUtc'],
                                                'publicationVersion': record.get('publicationVersion')})
                    transaction.set(pointer, {'versionId': version_id, 'publicationVersion': record.get('publicationVersion')})
                return
            if old_id and old_id != version_id:
                transaction.update(self.db.collection('resultVersions').document(old_id),
                                   {'current': False, 'state': 'superseded'})
            transaction.set(target, record)
            transaction.set(pointer, {'versionId': version_id, 'publicationVersion': record.get('publicationVersion')})
        switch(self.db.transaction())

    def unavailable(self, publication, reason, *, observed_version=None, pending=False):
        record = {key: publication[key] for key in ('selection', 'publicationUrl')}
        record.update(documentVersion=observed_version or publication['publicationVersion'],
                      publicationVersion=publication['publicationVersion'], current=True,
                      lastSuccessfulCheckUtc=publication['retrievedAtUtc'],
                      state='checkingUnavailable', reason=reason)
        self._switch(record, fallback=observed_version is None, pending=pending)

    def activate(self, record):
        self._switch(record)

    def health(self, now, succeeded):
        record = {'freshness': 'fresh' if succeeded else 'stale', 'lastAttemptUtc': now.isoformat()}
        if succeeded:
            record['lastSuccessfulCheckUtc'] = now.isoformat()
        self.db.document('monitor/status').set(record, merge=True)

    def review(self, records, *, catalog=None, publications=(), now=None):
        for record in records:
            self.db.collection('workerReview').document(review_identifier(record)).set({'status': 'pending', **record})
        if catalog is None:
            return
        pending = {review_identifier(record) for record in records}
        mapped = {publication_identity_url(item['url']) for item in publications}
        parsed = {(s['examId'], s['officialDates']) for s in catalog['sittings']}
        for row in self.db.collection('workerReview').stream():
            record = row.to_dict()
            key = review_identifier(record)
            if key in pending and row.id != key:
                self.db.collection('workerReview').document(row.id).update({'status': 'alias', 'canonicalReviewId': key})
            elif key not in pending and (publication_identity_url(record.get('publicationUrl', '')) in mapped or
                    (record.get('examId'), record.get('officialDates')) in parsed):
                self.db.collection('workerReview').document(row.id).update(
                    {'status': 'resolved', 'resolvedAtUtc': now.isoformat()})

    def advisory_snapshots(self, pilot, feeds, now, review=None):
        scopes = [scope['selection'] for scope in pilot['scopes']]
        keys = [tuple(s[k] for k in ('examId', 'sittingId', 'categoryId')) for s in scopes]
        if len(keys) > 8 or any(not re.fullmatch(r'[\w-]{1,180}', part) for key in keys for part in key):
            if feeds is not None:
                raise SourceError('Advisory selection limit or identifier is invalid.')
            keys = []
        stamp = now.isoformat()
        paths = {key: 'advisoryFeeds/{}/sittings/{}/categories/{}'.format(*key) for key in keys}
        if feeds is not None and (set(feeds) != set(keys) or
                any(len(items) > 64 or len(encode(items)) > 256 * 1024 for items in feeds.values())):
            raise SourceError('Advisory snapshot exceeds the reviewed bounds.')
        marker = self.db.document('workerState/advisoryPilot')

        @firestore.transactional
        def publish(tx):
            prior = marker.get(transaction=tx).to_dict() or {}
            if prior.get('attempt', '') >= stamp:
                return
            previous = set(prior.get('paths', []))
            current = set(paths.values())
            if feeds is None and previous:
                current = previous
                for path in previous:
                    tx.set(self.db.document(path), {'freshness': 'stale'}, merge=True)
            else:
                for key, path in paths.items():
                    tx.set(self.db.document(path), {
                        'coverageStartUtc': pilot['coverageStartUtc'], 'coverageEndUtc': pilot['coverageEndUtc'],
                        'lastSuccessfulCheckUtc': stamp if feeds is not None else None,
                        'freshness': 'fresh' if feeds is not None else 'stale',
                        'notices': feeds[key] if feeds is not None else [],
                    })
                for path in previous - current:
                    tx.delete(self.db.document(path))
            if review is not None:
                ref = self.db.document('workerAdvisoryReview/' + identifier(review.url))
                tx.set(ref, {'url': review.url, 'reason': str(review), 'observedAtUtc': stamp})
            tx.set(marker, {'attempt': stamp, 'paths': sorted(current)})
        publish(self.db.transaction())

    def exam_histories(self, feeds, start, now):
        stamp = now.isoformat()
        documents = {}
        for exam, items in (feeds or {}).items():
            if not re.fullmatch(r'[a-z0-9-]{1,180}', exam):
                raise SourceError('Invalid exam history identifier.')
            data = {'coverageStartUtc': start.isoformat(), 'coverageEndUtc': stamp,
                    'lastSuccessfulCheckUtc': stamp, 'freshness': 'fresh', 'notices': items}
            if len(encode(data)) > 800 * 1024:
                raise SourceError('Exam history exceeds the single-document budget.')
            documents[exam] = data
        checkpoint = self.db.document('workerState/examHistory')

        @firestore.transactional
        def publish(tx):
            saved = checkpoint.get(transaction=tx).to_dict() or {}
            if saved.get('checked', '') >= stamp:
                return
            if feeds is None:
                for exam in saved.get('exams', []):
                    tx.set(self.db.document('examUpdates/' + exam), {'freshness': 'stale'}, merge=True)
                tx.set(checkpoint, {'checked': stamp}, merge=True)
                return
            retired = set(saved.get('exams', [])) - documents.keys()
            if len(documents) + len(retired) >= 500:
                raise SourceError('Exam history exceeds the transaction budget.')
            for exam, data in documents.items():
                tx.set(self.db.document('examUpdates/' + exam), data)
            for exam in retired:
                # The production worker can replace documents, but cannot delete them.
                tx.set(self.db.document('examUpdates/' + exam), {'retired': True})
            tx.set(checkpoint, {'checked': stamp, 'exams': sorted(documents)})
        publish(self.db.transaction())

    def public_url(self, key):
        if not self.storage_host:
            raise ValueError('Public Storage hostname is missing.')
        return f'https://{self.storage_host}/storage/v1/object/public/validated-names/{quote(key, safe="/")}'

    def _storage(self, method, path, body=None):
        if not self.storage_host or (method != 'GET' and not self.storage_key):
            raise ValueError('Worker Storage credentials are missing.')
        connection = http.client.HTTPSConnection(self.storage_host, timeout=30)
        headers = {'Content-Type': 'application/json', 'x-upsert': 'false'}
        if method != 'GET':
            headers['Authorization'] = 'Bearer ' + self.storage_key
            headers['apikey'] = self.storage_key
        try:
            connection.request(method, path, body=body, headers=headers)
            response = connection.getresponse()
            result = response.read(MAX_BYTES + 1)
            if len(result) > MAX_BYTES:
                raise ValueError('Storage response exceeds the limit.')
            return response.status, result
        finally:
            connection.close()

    def upload(self, key, body):
        if not self.storage_key:
            if self.download(key) == body:
                return
            raise ValueError('A new asset requires worker Storage credentials.')
        path = '/storage/v1/object/validated-names/' + quote(key, safe='/')
        status, _ = self._storage('POST', path, body)
        if status in (400, 409) and self.download(key) == body:
            return
        if status not in (200, 201):
            raise ValueError('Immutable Storage upload failed; availability was not published.')

    def download(self, key):
        status, body = self._storage('GET', '/storage/v1/object/public/validated-names/' + quote(key, safe='/'))
        if status != 200:
            raise ValueError('Public Storage read-back failed.')
        return body
