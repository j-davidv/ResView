"""Read-only coverage inventory and encrypted originals for independent review."""
import argparse
import hashlib
import http.client
import json
import os
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin

from worker.documents import fetch_pdf
from worker.extract import encode
from worker.source import Page, SourceError, SourcePolicy, fetch, publication_identity_url


def inventory(publications, versions, now):
    current = {encode(row['selection']): row for row in versions if row.get('current')}
    rows = []
    for publication in publications:
        version = current.get(encode(publication['selection']), {})
        if version and publication_identity_url(version['publicationUrl']) != publication_identity_url(publication['publicationUrl']):
            version = {'state': 'notCurrent'}
        row = {key: publication[key] for key in
               ('selection', 'publicationUrl', 'publicationVersion', 'documents')}
        row.update({key: version[key] for key in
                    ('documentVersion', 'reason', 'lastSuccessfulCheckUtc') if key in version})
        row['state'] = version.get('state', 'notPublished')
        rows.append(row)
    return {'generatedAtUtc': now.isoformat(), 'selections': rows,
            'states': dict(Counter(row['state'] for row in rows))}


def acquire(report, policy, output, certificate):
    report['downloads'] = []
    candidates = {}
    for row in report['selections']:
        if row['documents']:
            continue
        url = row['publicationUrl']
        if url not in candidates:
            try:
                candidates[url] = [{'url': urljoin(url, link), 'label': label}
                    for link, label in Page(fetch(url, policy)).links
                    if label.lower().startswith(('list of successful examinees', 'roll of successful examinees'))
                    and 'top' not in label.lower()]
            except (ValueError, OSError, http.client.HTTPException) as error:
                candidates[url] = []
                row['candidateReviewError'] = type(error).__name__
        row['candidateDocuments'] = candidates[url]
    urls = sorted({url for row in report['selections'] for url in row['documents']}
                  | {item['url'] for links in candidates.values() for item in links})
    for url in urls:
        record = {'documentUrl': url, 'attemptedAtUtc': datetime.now(timezone.utc).isoformat()}
        try:
            body = fetch_pdf(url, policy)
            if not body.startswith(b'%PDF-'):
                raise ValueError('Not a PDF')
        except (ValueError, OSError, http.client.HTTPException) as error:
            record.update(status='unavailable', errorType=type(error).__name__,
                          reason=str(error) if type(error) is SourceError else type(error).__name__)
        else:
            checksum = hashlib.sha256(body).hexdigest()
            encrypted = subprocess.run(['openssl', 'cms', '-encrypt', '-binary', '-aes-256-cbc',
                                        '-outform', 'DER', str(certificate)],
                                       input=body, capture_output=True, check=True).stdout
            if not encrypted:
                raise ValueError('Empty encrypted review artifact')
            filename = checksum + '.pdf.cms'
            (output / filename).write_bytes(encrypted)
            record.update(status='awaitingIndependentReview', bytes=len(body), sha256=checksum,
                          encryptedFile=filename)
        report['downloads'].append(record)
        (output / 'coverage.json').write_bytes(encode(report))
        print(json.dumps(record), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--acquire', action='store_true')
    args = parser.parse_args()
    from google.cloud import firestore
    database = firestore.Client(project=os.environ['FIREBASE_PROJECT_ID'])
    report = inventory([row.to_dict() for row in database.collection('publications').stream()],
                       [row.to_dict() for row in database.collection('resultVersions').stream()],
                       datetime.now(timezone.utc))
    report['monitor'] = database.document('monitor/status').get().to_dict()
    report['mappingReviews'] = []
    for snapshot in database.collection('workerReview').stream():
        row = snapshot.to_dict()
        if row.get('status') == 'pending':
            report['mappingReviews'].append({key: row[key] for key in
                ('publicationUrl', 'examId', 'officialDates', 'reason') if key in row})
    args.output.mkdir(parents=True, exist_ok=True)
    if args.acquire:
        certificate = os.environ.get('PRC_REVIEW_CERTIFICATE', '')
        if not certificate.startswith('-----BEGIN CERTIFICATE-----'):
            raise ValueError('Review encryption certificate is required')
        certificate_path = args.output / 'recipient.pem'
        certificate_path.write_text(certificate, encoding='ascii')
        policy = SourcePolicy(json.loads(args.config.read_bytes())['sourcePolicy'])
        policy.load_robots(fetch)
        acquire(report, policy, args.output, certificate_path)
    (args.output / 'coverage.json').write_bytes(encode(report))
    print(json.dumps({'selections': len(report['selections']), 'states': report['states']}))


if __name__ == '__main__':
    main()
