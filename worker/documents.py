import hashlib
import json
import re
from urllib.parse import urlencode, urlsplit

import google.auth
from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import Request

from worker.source import MAX_DOCUMENT_BYTES, SourceError, SourcePolicy, _request, fetch


def fetch_pdf(url, policy, *, fetcher=fetch, credentials=None, transport=_request):
    parsed = urlsplit(url)
    if parsed.hostname != 'drive.google.com':
        policy.check(url)
        return fetcher(url, policy)
    # shortcut: only reviewed /file/d/.../view links; add other Drive link shapes after review.
    match = re.fullmatch(r'/file/d/([A-Za-z0-9_-]{10,200})/view/?', parsed.path)
    if (not policy.drive_api_enabled or parsed.scheme != 'https' or not match
            or parsed.username or parsed.password or parsed.port not in (None, 443) or parsed.fragment):
        raise SourceError('Unapproved Drive document route.')
    try:
        if credentials is None:
            credentials, _ = google.auth.default(scopes=['https://www.googleapis.com/auth/drive.readonly'])
        if not credentials.valid:
            credentials.refresh(Request())
    except GoogleAuthError as error:
        raise SourceError('Drive API authentication is unavailable.') from error
    if not isinstance(credentials.token, str) or not credentials.token:
        raise SourceError('Drive API authentication is unavailable.')

    base = 'https://www.googleapis.com/drive/v3/files/' + match[1]
    metadata_url = base + '?' + urlencode({'fields':
        'id,mimeType,size,md5Checksum,trashed,capabilities(canDownload),copyRequiresWriterPermission'})
    media_url = base + '?alt=media'
    # API access is authorized through OAuth and the owner's download capabilities.
    api_policy = SourcePolicy({'accessAuthorization': 'Documented read-only Drive API for a linked PRC PDF.',
                               'routes': {'www.googleapis.com': ['/drive/v3/files/' + match[1]]}})

    def authenticated_transport(target, address, limit, timeout):
        if target not in (metadata_url, media_url):
            raise SourceError('Unapproved Drive API route.')
        result = transport(target, address, limit, timeout,
                           headers={'Authorization': 'Bearer ' + credentials.token})
        if 300 <= result[0] < 400:
            raise SourceError('Drive API redirects are not permitted.')
        return result

    try:
        metadata = json.loads(fetch(metadata_url, api_policy, limit=256 * 1024,
                                    transport=authenticated_transport))
        size = metadata.get('size', '')
        checksum = metadata.get('md5Checksum', '')
        if (metadata.get('id') != match[1] or metadata.get('mimeType') != 'application/pdf'
                or metadata.get('trashed') is not False
                or metadata.get('capabilities', {}).get('canDownload') is not True
                or metadata.get('copyRequiresWriterPermission', False)
                or not isinstance(size, str) or not re.fullmatch(r'[1-9]\d*', size)
                or int(size) > MAX_DOCUMENT_BYTES
                or not isinstance(checksum, str) or not re.fullmatch(r'[a-fA-F0-9]{32}', checksum)):
            raise SourceError('Drive PDF download is restricted or its metadata is unusable.')
    except (TypeError, AttributeError, ValueError) as error:
        if isinstance(error, SourceError):
            raise
        raise SourceError('Drive API file metadata is invalid.') from error
    body = fetch(media_url, api_policy, limit=int(size), transport=authenticated_transport)
    if (len(body) != int(size)
            or hashlib.md5(body, usedforsecurity=False).hexdigest() != checksum.lower()):
        raise SourceError('Drive PDF transfer is incomplete or the file changed during download.')
    return body
