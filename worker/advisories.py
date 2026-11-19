"""Review-pinned PRC news notices for the bounded schedule-change pilot."""
import hashlib
import json
import re
from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlsplit

from worker.source import Page, SourceError, parse_catalog, publication_identity_url


class AdvisoryReview(SourceError):
    def __init__(self, url, reason):
        super().__init__(reason)
        self.url = url


def archive_rows(url, year_index, month_index, *, unique=False):
    path = urlsplit(url).path.encode()
    counts = re.findall(rb'<li>\s*<a href="' + re.escape(path) +
                        rb'">[^<]+</a>\s*\((\d+)\)\s*</li>', year_index)
    rows = re.split(rb'<div class="article-archive views-row">', month_index)[1:]
    if rows and b'<h3 class="js-views-accordion-group-header">' in rows[0]:
        rows = rows[1:]
    if (len(counts) != 1 or not 0 < len(rows) <= 150 or len(rows) != int(counts[0])
            or re.search(rb'href="[^"]*[?&]page=|rel="next"', month_index)):
        raise SourceError('Monthly archive is incomplete or paginated.')
    entries = {}
    for row in rows:
        field = row.partition(b'</div>')[0]
        links = Page(field).links
        if len(links) != 1 or not links[0][1]:
            raise SourceError('Archive entry missing its title or link.')
        href, title = links[0]
        actual = urljoin(url, href)
        parsed = urlsplit(actual)
        if parsed.scheme != 'https' or parsed.netloc not in ('prc.gov.ph', 'www.prc.gov.ph') or parsed.query or parsed.fragment:
            raise SourceError('Unexpected link in monthly archive.')
        identity = publication_identity_url(actual)
        if identity in entries and entries[identity][0] != title:
            raise AdvisoryReview(actual, 'Conflicting titles for the same archive entry.')
        entries.setdefault(identity, (title, actual))
    if unique and len(entries) != len(rows):
        raise SourceError("Duplicate rows in the counted news archive.")
    return entries


def inventory_hash(entries):
    # Reviewed titles outside the pilot include procurement, unrelated exams and result releases.
    titles = sorted((url, title) for url, (title, _) in entries.items())
    return hashlib.sha256(json.dumps(titles, ensure_ascii=False).encode()).hexdigest()


def notice(url, body, review):
    match = re.search(rb'<article\b[^>]*>(.*?)</article>', body, re.S | re.I)
    if not match or hashlib.sha256(match[1]).hexdigest() != review['contentSha256']:
        raise AdvisoryReview(url, 'Official article changed or could not be read.')
    page = Page(match[1])
    if not page.headings:
        raise AdvisoryReview(url, 'Missing official title.')
    title = page.headings[0]
    date = re.search(r'Posted on\s+(\d{1,2} [A-Za-z]+,? \d{4})\b', ' '.join(page.text))
    if not date:
        raise AdvisoryReview(url, 'Missing posting date.')
    posted = datetime.strptime(date[1].replace(',', ''), '%d %B %Y').replace(
        tzinfo=timezone(timedelta(hours=8))).astimezone(timezone.utc)
    selections = review['selections']
    if selections and (re.search(r'\bresults?\s+released\b', title, re.I) or
                       not re.search(r'reschedul|postpon|examination schedule|cancell|additional day', title, re.I)):
        raise AdvisoryReview(url, 'Article does not identify an exam schedule change.')
    return selections, {'kind': 'scheduleChange', 'title': title, 'publicationUrl': url,
                        'publishedAtUtc': posted.isoformat()}


def scan(config, policy, now, fetcher):
    pilot = config['advisoryPilot']
    if not 0 < len(pilot['scopes']) <= 8 or len(pilot['articles']) > 8:
        raise SourceError('Pilot exceeds the scoped scan budget.')

    def read(url):
        policy.check(url)
        return fetcher(url, policy, limit=2 * 1024 * 1024)

    rows = archive_rows(pilot['monthUrl'], read(pilot['yearUrl']), read(pilot['monthUrl']))
    remaining = dict(rows)
    catalog = parse_catalog(read(pilot['catalogUrl']), pilot['catalogUrl'], now, config['scheduleOverrides'])
    scopes = pilot['scopes']
    feeds = {tuple(s['selection'][k] for k in ('examId', 'sittingId', 'categoryId')): [] for s in scopes}
    for scope in scopes:
        sel = scope['selection']
        if not any(s['id'] == sel['sittingId'] and s['examId'] == sel['examId']
                   and sel['categoryId'] in s['categories'] and s['start'][:10] == scope['start']
                   and s['officialTestingCenters'] == scope['centers'] for s in catalog['sittings']):
            raise AdvisoryReview(pilot['catalogUrl'], 'Reviewed sitting, region or category has changed.')
    for url, review in pilot['articles'].items():
        entry = remaining.pop(url, None)
        if entry is None:
            raise AdvisoryReview(url, 'Reviewed article missing from the monthly archive.')
        title, actual = entry
        selections, item = notice(actual, read(actual), review)
        if title != item['title'] or not pilot['coverageStartUtc'] <= item['publishedAtUtc'] < pilot['coverageEndUtc']:
            raise AdvisoryReview(actual, 'Archive title or posting window requires review.')
        for sel in selections:
            key = (sel['examId'], sel['sittingId'], sel['categoryId'])
            if key not in feeds:
                raise AdvisoryReview(actual, 'Notice targets an unverified selection.')
            if item not in feeds[key]:
                feeds[key].append(item)
    if inventory_hash(remaining) != pilot['otherEntriesSha256']:
        raise AdvisoryReview(pilot['monthUrl'], 'Archive contains changes outside the reviewed notices.')
    for notices in feeds.values():
        notices.sort(key=lambda n: publication_identity_url(n['publicationUrl']))
        notices.sort(key=lambda n: n['publishedAtUtc'], reverse=True)
    return feeds
