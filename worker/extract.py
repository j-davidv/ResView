import hashlib
import json
import re
from pathlib import Path

MAX_BYTES = 20 * 1024 * 1024


def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')


def validate_pages(pages, original_sha256, expected, now):
    required = ('reviewEvidence', 'reviewedAtUtc', 'entriesSha256', 'samples', 'headings', 'endMarker')
    if (any(not expected.get(key) for key in required)
            or expected.get('format') != 'reviewed-numbered-text-v1'
            or expected.get('originalSha256') != original_sha256
            or len(pages) != expected.get('pageCount') or not all(page.strip() for page in pages)):
        raise ValueError('Document format/version has not passed independent review.')
    text = '\n'.join(pages)
    if any(heading not in text for heading in expected['headings']):
        raise ValueError('Exam, sitting or list heading is missing.')
    entries, ended = [], False
    ignored = set(expected.get('ignoreLines', []))
    for page_number, page in enumerate(pages, 1):
        for line in page.splitlines():
            line = line.strip()
            if not line or line in ignored:
                continue
            if line == expected['endMarker'] and not ended:
                ended = True
                continue
            match = re.fullmatch(r'(\d+)\s+([^\d,]+,\s*[^\d]+)', line)
            if ended or not match or int(match[1]) != len(entries) + 1:
                raise ValueError('Unexpected layout or incomplete numbered sequence.')
            entries.append({'sequence': int(match[1]), 'publishedName': match[2],
                            'sectionId': expected['selection']['categoryId'], 'physicalPage': page_number})
    if (not ended or not entries or len(entries) != expected.get('entryCount')
            or hashlib.sha256(encode(entries)).hexdigest() != expected['entriesSha256']
            or any(sample not in entries for sample in expected['samples'])):
        raise ValueError('Count, independent transcript or visual review disagrees.')
    return {'formatVersion': 1, 'nameFormat': 'surnameCommaNamesV1',
            'selection': expected['selection'], 'documentVersion': original_sha256,
            'publicationUrl': expected['publicationUrl'], 'documentUrl': expected['documentUrl'],
            'validatedAtUtc': expected['reviewedAtUtc'], 'originalSha256': original_sha256,
            'entryCount': len(entries), 'componentsReliable': False, 'entries': entries}


def extract_pdf(path, expected, now):
    from pypdf import PdfReader
    path = Path(path)
    if path.stat().st_size > MAX_BYTES:
        raise ValueError('Original document exceeds the size limit.')
    body = path.read_bytes()
    if not body.startswith(b'%PDF-'):
        raise ValueError('Source is not a PDF.')
    checksum = hashlib.sha256(body).hexdigest()
    if checksum != expected.get('originalSha256'):
        raise ValueError('The PDF version has not passed independent review.')
    try:
        reader = PdfReader(path, strict=True)
        if reader.is_encrypted or len(reader.pages) != expected.get('pageCount'):
            raise ValueError('Encrypted or unexpected page count.')
        pages = [page.extract_text() or '' for page in reader.pages]
    except Exception as error:
        # Broken PDFs can also raise built-in exceptions inside the parser.
        raise ValueError('The source PDF could not be validated.') from error
    return validate_pages(pages, checksum, expected, now)


def write_names_file(report, output):
    body = encode(report)
    if not 0 < len(body) <= MAX_BYTES:
        raise ValueError('Derived list exceeds the mobile download limit.')
    Path(output).write_bytes(body)
    return {'namesBytes': len(body), 'namesSha256': hashlib.sha256(body).hexdigest()}
