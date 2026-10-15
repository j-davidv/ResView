import hashlib

from worker.extract import MAX_BYTES, encode


def publish_validated(report, names_path, providers, *, publication=None):
    body = names_path.read_bytes()
    if body != encode(report) or not 0 < len(body) <= MAX_BYTES or not report.get('entries'):
        raise ValueError('Validated asset changed or exceeded the file limit.')
    checksum = hashlib.sha256(body).hexdigest()
    selection = report['selection']
    key = '/'.join([selection['examId'], selection['sittingId'], selection['categoryId'],
                    report['documentVersion'], checksum + '.json'])
    providers.upload(key, body)
    if providers.download(key) != body:
        raise ValueError('Public asset read-back failed.')
    record = {key: report[key] for key in ('selection', 'documentVersion', 'publicationUrl',
                                         'documentUrl', 'validatedAtUtc', 'originalSha256')}
    record.update(state='checkingAvailable', current=True, namesUrl=providers.public_url(key),
                  namesBytes=len(body), namesSha256=checksum)
    if publication:
        record['publicationVersion'] = publication['publicationVersion']
        record['lastSuccessfulCheckUtc'] = publication['retrievedAtUtc']
    providers.activate(record)
    return record
