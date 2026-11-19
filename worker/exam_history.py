"""Build the dated, exam-wide PRC news archive used by Release 2."""
import argparse
import hashlib
import http.client
import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from tempfile import NamedTemporaryFile
from functools import partial
from urllib.parse import urlencode, urlsplit

from worker.advisories import archive_rows
from worker.source import Page, SourceError, SourcePolicy, fetch, parse_catalog

PH = timezone(timedelta(hours=8))
START = datetime(2026, 1, 1, tzinfo=PH)
ROOT = 'https://www.prc.gov.ph'
ISSUANCE = r'/prc-(?:resolution|memorandum-circular)-no-[0-9]+[a-z]?-s-20[0-9]{2}(?:-[0-9]+)?'



def monthly_inventory(policy, now, *, fetcher=fetch):
    """Read only exact calendar routes, checking each month's published row count."""
    entries = {}
    local = now.astimezone(PH)
    for year in range(START.year, local.year + 1):
        path = f'/archives/{year}'
        routes = policy.exact_routes['www.prc.gov.ph']
        routes.append(path)
        year_page = fetcher(ROOT + path, policy, limit=2 * 1024 * 1024)
        for month in range(1, (local.month if year == local.year else 12) + 1):
            period = f'{year}{month:02}'
            route = f'{path}/{period}'
            routes.append(route)
            url = ROOT + route
            rows = archive_rows(url, year_page, fetcher(url, policy, limit=2 * 1024 * 1024), unique=True)
            for key, (title, actual) in rows.items():
                if key in entries and entries[key] != (title, actual, period):
                    raise SourceError('Conflicting monthly archive rows.')
                entries[key] = (title, actual, period)
    return entries


def article_metadata(body):
    article = re.search(rb'<article\b[^>]*>(.*?)</article>', body, re.S | re.I)
    if not article:
        raise SourceError('Missing news article.')
    page = Page(article[1])
    date = re.search(r'Posted on\s+(\d{1,2} [A-Za-z]+),? (\d{4})', ' '.join(page.text))
    if not date or not page.headings:
        raise SourceError('Missing PRC posting date or title.')
    posted = datetime.strptime(' '.join(date.groups()), '%d %B %Y').replace(tzinfo=PH)
    paragraphs = [' '.join(' '.join(Page(p).text).split()) for p in re.findall(rb'<p\b[^>]*>(.*?)</p>', article[1], re.S | re.I)]
    lead = next((paragraph for paragraph in paragraphs if len(paragraph) >= 35), '')
    if page.headings[0].startswith(('PRC Resolution', 'PRC Memorandum')):
        description = re.search(r'\bDescription\s+(.+?)\s+(?:Attachment|Type)\b', ' '.join(' '.join(page.text).split()))
        if description:
            lead = description[1]
    return page.headings[0], posted, lead

# Alternatives are profession names and PRC abbreviations from the official notices.
ALIASES = {
    'nutritionist dietitians': ('nutritionists dietitians',),
    'architects': ('LEA',), 'landscape architects': ('LALE',),
    'sanitary engineers': ('SELE', 'SECBLE'), 'respiratory therapists': ('RTLE',),
    'criminologists': ('LEC',), 'certified public accountants': ('CPALE',),
    'professional teachers': ('LEPT',), 'medical technologists': ('MTLE',),
    'interior designers': ('LEID',), 'psychometricians': ('psychometrician',),
    'nurses': ('nursing', 'NLE'), 'midwives': ('midwife', 'midwifery'),
    'naval architects': ('NALE',), 'real estate appraisers': ('REALE',),
    'real estate brokers': ('REBLE',), 'registered electrical engineers': ('REELE',),
    'registered master electricians': ('RMELE',), 'speech language pathologists': ('SLPLE',),
    'physicians': ('PLE',), 'physical therapists': ('PTLE',),
    'professional foresters': ('foresters',), 'professional food technologists': ('food technologists',),
    'veterinary medicine': ('veterinarians',), 'veterinarians': ('veterinary medicine',),
    'professional electronics engineers': ('professional electronics engineer',),
    'optometrists': ('optometry',), 'dentists': ('dentistry',),
    'fisheries professionals': ('fisheries professional',),
}


def words(text):
    return ' '.join(re.findall(r'[a-z0-9]+', text.lower()))


def audience_patterns(exams):
    patterns = []
    for exam in exams:
        key = exam['id']
        name = re.split(r'-(?:sple|written|practical|oral-examination|technical-evaluation|revalida)(?:-|$)', key)[0].replace('-', ' ')
        aliases = {name, *ALIASES.get(name, ())}
        if name == 'professional electronics engineer':
            aliases.add('professional electronics engineers')
        for alias in sorted(aliases):
            alias = words(alias)
            pattern = re.escape(alias)
            if alias.endswith('s') and not alias.endswith(('ss', 'wives')):
                pattern += '?'
            elif name == alias and not alias.endswith('s'):
                pattern += 's?'
            patterns.append((key, re.compile(r'\b' + pattern + r'\b')))
    return patterns


def match_exams(title, patterns):
    text = words(title)
    # Expand coordinated PRC profession names before matching their full spans.
    for short, full in [('radiologic and x ray technologists', 'radiologic technologists and x ray technologists'),
                        ('real estate appraisers and consultants', 'real estate appraisers and real estate consultants')]:
        text = text.replace(short, full)
    special = bool(re.search(r'\bspecial professional licensure|\bsple\b', text))
    hits = [(key, m.start(), m.end()) for key, pattern in patterns for m in pattern.finditer(text)
            if key.endswith('-sple') == special]
    return sorted({key for key, a, b in hits
                   if not any(c <= a and b <= d and (c < a or b < d) for _, c, d in hits)
                   and not ('practical' in key and 'written' in text and 'practical' not in text)
                   and not ('written' in key and 'practical' in text and 'written' not in text)})


def scope_note(url, title, lead, config):
    if 'and all succeeding examination schedules' in lead.lower():
        effective = re.search(r'effective with the ([a-z]+ 20\d{2})\b', lead, re.I)
        if effective:
            return f'{effective[1]} and succeeding sittings'
    for article, review in config['advisoryPilot']['articles'].items():
        if article == url and review['selections']:
            scopes = [s for s in config['advisoryPilot']['scopes'] if s['selection'] in review['selections']]
            return ' · '.join(f"{s['start']} · {s['centers']}" for s in scopes)
    if re.fullmatch(ISSUANCE, urlsplit(url).path):
        return lead
    if 'oathtaking' in title.lower():
        event = re.search(r'\bon\s+((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2}\b.+)', lead, re.I)
        if event:
            detail = re.split(r'\.\s+(?=The |All |Those |Inductees |For |Participants )', event[1])[0]
            if len(detail) <= 320:
                return re.sub(r'\s+([.,])', r'\1', detail).strip(' .')
    return ''


def build_history(config, now, cache, *, inventory=None, fetcher=fetch):
    policy = SourcePolicy(config['sourcePolicy'])
    policy.load_robots(fetcher)
    rows = (inventory or partial(monthly_inventory, fetcher=fetcher))(policy, now)
    catalog = {'exams': [], 'sittings': [], 'review': [], 'catalogUrls': []}
    for year in range(START.year, now.astimezone(PH).year + 1):
        url = f'{ROOT}/{year}-schedule-examination'
        yearly = parse_catalog(fetcher(url, policy), url, now, config['scheduleOverrides'])
        for field in ('exams', 'sittings', 'review'):
            catalog[field].extend(yearly[field])
        catalog['catalogUrls'].append(url)
    catalog['catalogUrl'] = catalog['catalogUrls'][-1]
    catalog['exams'] = list({exam['id']: exam for exam in catalog['exams']}.values())
    patterns = audience_patterns(catalog['exams'])
    feeds = {e['id']: [] for e in catalog['exams']}
    cache.mkdir(parents=True, exist_ok=True)
    for key, (title, url, period) in rows.items():
        route = urlsplit(url).path
        issuance = re.fullmatch(ISSUANCE, route)
        if issuance:
            policy.exact_routes.setdefault(urlsplit(url).hostname, []).append(route)
        if (not (issuance or re.fullmatch(r'/(?:index\.php/)?article/[^/]+', route))
                or re.search(r'\b(invitation to bid|bid opportunity|bid bulletin|request for quotation|procurement of)\b', title, re.I)):
            continue
        policy.check(url)
        # A cache is reusable only for a closed month and the same official title and URL.
        path = cache / (hashlib.sha256((url + '\n' + title).encode()).hexdigest() + '.json')
        cached = (path.exists() and period < now.astimezone(PH).strftime('%Y%m')
                  and now.timestamp() - path.stat().st_mtime < 30 * 86400)
        if cached:
            posted, lead = json.loads(path.read_text(encoding='utf8'))
            date = datetime.fromisoformat(posted)
        else:
            official, date, lead = article_metadata(fetcher(url, policy, limit=2 * 1024 * 1024))
            if words(official) != words(title):
                raise SourceError(f'Archive and article titles disagree: {url}')
        if date < START or date > now or date.strftime('%Y%m') != period:
            raise SourceError(f'News date outside archive month: {url}')
        if not cached:
            with NamedTemporaryFile(mode='w', dir=cache, delete=False, encoding='utf8') as temp:
                json.dump([date.isoformat(), lead], temp)
            Path(temp.name).replace(path)
        targets = match_exams(title, patterns)
        if not targets and (issuance or re.search(r'exam|testing cent|oath|filing|applic|reschedul|postpon|registration|notice to the public|passers|schools|topnotch|placers|achiever', title, re.I)):
            targets = match_exams(title + ' ' + lead[:450], patterns)
        item = {'kind': 'announcement', 'title': title, 'publicationUrl': url,
                'publishedAtUtc': date.astimezone(timezone.utc).isoformat(),
                'audience': scope_note(key, title, lead, config)}
        for exam in targets:
            feeds[exam].append(item)
    for items in feeds.values():
        items.sort(key=lambda n: n['publicationUrl'])
        items.sort(key=lambda n: n['publishedAtUtc'], reverse=True)
    return feeds, catalog



def hosted_transport(url, _address, limit, timeout):
    parsed = urlsplit(url)
    if parsed.query or parsed.fragment:
        raise SourceError('Hosted archive requests do not allow queries or fragments.')
    query = urlencode({'host': parsed.hostname, 'route': parsed.path})
    connection = http.client.HTTPSConnection('erlnuyltaudetjpriosu.supabase.co', timeout=timeout)
    try:
        connection.request('GET', '/functions/v1/prc-archive?' + query,
                           headers={'Authorization': 'Bearer ' + os.environ['PRC_ARCHIVE_TOKEN'],
                                    'x-region': 'ap-southeast-1'})
        response = connection.getresponse()
        if response.status == 502:
            return 502, {}, b''
        if response.status != 200:
            raise SourceError('Hosted PRC reader rejected the request.')
        try:
            status = int(response.headers['X-PRC-Status'])
        except (TypeError, ValueError):
            raise SourceError('Invalid hosted PRC response.') from None
        headers = {}
        for name in ('location', 'retry-after'):
            if value := response.headers.get('X-PRC-' + name):
                headers[name] = value
        return status, headers, response.read(limit + 1)
    finally:
        connection.close()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', required=True, type=Path)
    parser.add_argument('--hosted-source', action='store_true')
    destination = parser.add_mutually_exclusive_group()
    destination.add_argument('--publish-demo', action='store_true')
    destination.add_argument('--publish-live', action='store_true')
    parser.add_argument('--seed-catalog', action='store_true', help='Also initialize the demo picker catalog.')
    args = parser.parse_args()
    now = datetime.now(timezone.utc)
    config = json.loads(Path('worker/config.json').read_text(encoding='utf8'))
    provider = None
    if args.seed_catalog and not args.publish_demo:
        parser.error('--seed-catalog requires --publish-demo')
    if args.publish_demo:
        if (os.environ.get('FIRESTORE_EMULATOR_HOST', '').split(':')[0] not in ('127.0.0.1', 'localhost')
                or os.environ.get('FIREBASE_PROJECT_ID') != 'demo-resview-advisories'):
            raise SourceError('Exam history publication requires the local demo emulator.')
        from worker.providers import Providers
        provider = Providers.from_environment()
    if args.publish_live:
        if (not args.hosted_source or os.environ.get('FIRESTORE_EMULATOR_HOST')
                or os.environ.get('FIREBASE_PROJECT_ID') != 'resview-9240c'
                or os.environ.get('GITHUB_ACTIONS') != 'true'
                or os.environ.get('GITHUB_WORKFLOW_REF') !=
                'j-davidv/ResView/.github/workflows/monitor.yml@refs/heads/main'):
            raise SourceError('Live history publication requires the production GitHub workflow.')
        from worker.providers import Providers
        provider = Providers.from_environment()
    if args.hosted_source and not os.environ.get('PRC_ARCHIVE_TOKEN'):
        parser.error('--hosted-source requires PRC_ARCHIVE_TOKEN')
    reader = partial(fetch, transport=hosted_transport) if args.hosted_source else fetch
    start = START.astimezone(timezone.utc)
    try:
        feeds, catalog = build_history(config, now, args.cache, fetcher=reader)
        if provider:
            if args.seed_catalog:
                provider.catalog(catalog)
            provider.exam_histories(feeds, start, now)
    except (ValueError, OSError, http.client.HTTPException):
        if provider:
            provider.exam_histories(None, start, now)
        raise
    print(f"{sum(bool(items) for items in feeds.values())} exams with notices; "
          f"{len({i['publicationUrl'] for items in feeds.values() for i in items})} distinct articles.")


if __name__ == '__main__':
    main()
