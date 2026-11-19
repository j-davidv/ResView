import argparse
import hashlib
import http.client
import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.parse import urljoin, urlsplit

from worker import advisories
from worker.extract import extract_pdf, write_names_file
from worker.documents import fetch_pdf
from worker.publish import publish_validated
from worker.source import SourceError, SourcePolicy, fetch, parse_publication, parse_catalog, associations, Page, publication_identity_url


def log_failure(stage, error):
    detail = str(error) if type(error) is SourceError else type(error).__name__
    cause = f' ({type(error.__cause__).__name__})' if error.__cause__ else ''
    print(f'{stage}: {detail}{cause}', file=sys.stderr)


def discover(config, policy, now, fetcher):
    first_year = config.get('coverageStartYear', 2026)
    current_year = now.astimezone(timezone(timedelta(hours=8))).year
    catalog_urls = [config['catalogUrl']] if config.get('catalogUrl') else []
    if config.get('catalogIndexUrl'):
        menu_url = config['catalogIndexUrl']
        policy.check(menu_url)
        catalog_urls = []
        for link, _ in Page(fetcher(menu_url, policy)).links:
            url = urljoin(menu_url, link)
            match = re.fullmatch(r'/(20\d{2})-schedule-examination', urlsplit(url).path)
            if match and first_year <= int(match[1]) <= current_year + 1 and url not in catalog_urls:
                catalog_urls.append(url)
        if not catalog_urls or not any(f'/{current_year}-' in url for url in catalog_urls):
            raise SourceError('Current-year schedule missing from official menu; rollover requires review.')
    catalog = {'exams': [], 'sittings': [], 'review': [], 'catalogUrls': catalog_urls}
    for url in sorted(catalog_urls):
        policy.check(url)
        yearly = parse_catalog(fetcher(url, policy), url, now, config.get('scheduleOverrides', []))
        for key in ('exams', 'sittings', 'review'):
            catalog[key].extend(yearly[key])
    catalog['exams'] = list({exam['id']: exam for exam in catalog['exams']}.values())
    if not catalog_urls:
        raise SourceError('No official schedules found.')
    catalog['catalogUrl'] = catalog_urls[0]
    results_url = config['resultsUrl']
    mappings = {publication_identity_url(url): value for url, value in config.get('publicationMappings', {}).items()}
    profiles = {publication_identity_url(url): value for url, value in config.get('profiles', {}).items()}
    publications = []
    seen, visited = set(), set()
    while results_url:
        if results_url in visited or len(visited) >= config.get('maxIndexPages', 100):
            raise SourceError('Results pagination loop or limit; history is incomplete.')
        visited.add(results_url)
        policy.check(results_url)
        index = Page(fetcher(results_url, policy))
        dates = []
        for link, title in index.links:
            url = urljoin(results_url, link)
            identity = publication_identity_url(url)
            if (not urlsplit(url).path.startswith(('/article/', '/index.php/article/'))
                    or 'result' not in title.lower() or identity in seen):
                continue
            seen.add(identity)
            policy.check(url)
            publication = parse_publication(url, fetcher(url, policy), now)
            published = datetime.fromisoformat(publication['publishedAtUtc']).astimezone(timezone(timedelta(hours=8)))
            dates.append(published)
            if published.year < first_year:
                continue
            reviewed = mappings.get(identity)
            mapping_changed = bool(reviewed and reviewed['publicationVersion'] != publication['publicationVersion'])
            selections = associations(publication, catalog)
            if reviewed:
                selections = reviewed['selections']
            for selection in selections:
                if not any(s['id'] == selection['sittingId'] and s['examId'] == selection['examId']
                           and selection['categoryId'] in s['categories'] for s in catalog['sittings']):
                    raise SourceError('Reviewed mapping references an unknown sitting/category.')
                publications.append({'url': url, 'selection': selection, 'publication': publication,
                                     'profile': profiles.get(identity), 'mappingChanged': mapping_changed})
            if not selections or mapping_changed or (reviewed and reviewed.get('unresolvedSittings')):
                catalog['review'].append({'publicationUrl': url, 'title': publication['title'],
                                          'reason': 'Exam/sitting/category association requires review.'})
        if not dates:
            raise SourceError('Results index contains no new dated publications.')
        if all(date.year < first_year for date in dates):
            break
        next_links = {urljoin(results_url, link) for link, title in index.links if 'next' in title.lower()}
        if len(next_links) > 1:
            raise SourceError('Ambiguous results pagination.')
        next_url = next(iter(next_links), None)
        if next_url and (urlsplit(next_url).netloc != urlsplit(config['resultsUrl']).netloc
                         or urlsplit(next_url).path != urlsplit(config['resultsUrl']).path
                         or not re.fullmatch(r'page=\d+', urlsplit(next_url).query)):
            raise SourceError('Unexpected results pagination route.')
        results_url = next_url
    catalog['discovery'] = {'indexPages': len(visited), 'articleUrls': len(seen), 'coverageStartYear': first_year}
    # The index is newest-first, including announcements with the same posted date.
    publications.reverse()
    publications.sort(key=lambda item: item['publication']['publishedAtUtc'])
    return catalog, publications


def run(config, providers, now, fetcher=fetch):
    if config.get('delivery', 'disabled') != 'disabled':
        raise ValueError('Outbound delivery is not enabled by this worker.')
    policy = SourcePolicy(config.get('sourcePolicy', {}))
    try:
        policy.load_robots(fetcher)
    except (ValueError, OSError) as error:
        log_failure('Source setup failed', error)
        providers.health(now, False)
        return 1
    publications = config.get('publications', [])
    if (config.get('catalogUrl') or config.get('catalogIndexUrl')) and config.get('resultsUrl'):
        try:
            catalog, publications = discover(config, policy, now, fetcher)
            providers.catalog(catalog)
            providers.review(catalog['review'], catalog=catalog, publications=publications, now=now)
        except (ValueError, OSError) as error:
            log_failure('Catalog discovery failed', error)
            providers.health(now, False)
            raise
    if not publications:
        providers.health(now, False)
        raise SourceError('No reviewed publication-to-sitting mappings configured.')
    failures = 0
    latest = {json.dumps(item['selection'], sort_keys=True): item['url'] for item in publications}
    for item in publications:
        try:
            publication = dict(item['publication'] if 'publication' in item else
                               parse_publication(item['url'], fetcher(item['url'], policy), now))
            publication['selection'] = item['selection']
            if item.get('mappingChanged'):
                if item['url'] == latest[json.dumps(item['selection'], sort_keys=True)]:
                    providers.unavailable(publication, 'The changed announcement mapping requires review.')
                    failures += 1
                continue
            providers.publication(publication)
            if item['url'] != latest[json.dumps(item['selection'], sort_keys=True)]:
                continue
            reviewed = item.get('profile')
            if not reviewed:
                providers.unavailable(publication, 'This document format has not passed validation.')
                continue
            if (reviewed['selection'] != item['selection'] or
                    publication_identity_url(reviewed['publicationUrl']) != publication_identity_url(item['url'])):
                raise ValueError('Reviewed profile does not match the publication selection.')
            if reviewed.get('disabled'):
                providers.unavailable(publication, 'Checking for this reviewed format has been disabled.',
                                      observed_version=reviewed['originalSha256'])
                continue
            linked_documents = publication['documents'] + [candidate['url']
                for candidate in publication.get('documentCandidates', [])]
            if reviewed['documentUrl'] not in linked_documents:
                providers.unavailable(publication, 'The official document link changed and requires review.',
                                      observed_version=publication['sourceSha256'])
                failures += 1
                continue
            with TemporaryDirectory() as directory:
                original = Path(directory) / 'source.pdf'
                body = fetch_pdf(reviewed['documentUrl'], policy, fetcher=fetcher)
                original.write_bytes(body)
                try:
                    report = extract_pdf(original, reviewed, now)
                except ValueError:
                    providers.unavailable(publication, 'The current document has not passed validation.',
                                          observed_version=hashlib.sha256(body).hexdigest())
                    failures += 1
                    continue
                print(f'Validated official PDF: {len(body)} bytes; SHA-256 {report["originalSha256"]}')
                providers.unavailable(publication, 'The validated current document awaits asset publication.',
                                      observed_version=report['documentVersion'], pending=True)
                names = Path(directory) / 'names.json'
                write_names_file(report, names)
                publish_validated(report, names, providers, publication=publication)
        except (ValueError, OSError, http.client.HTTPException) as error:
            log_failure('Publication processing failed', error)
            failures += 1
            # Keep last-good publication data; source failure changes health only.
    providers.health(now, failures == 0)
    return failures


def run_advisories(config, providers, now, fetcher=fetch):
    pilot = config['advisoryPilot']
    policy = SourcePolicy(config['sourcePolicy'])
    try:
        policy.load_robots(fetcher)
        feeds = advisories.scan(config, policy, now, fetcher)
        providers.advisory_snapshots(pilot, feeds, now)
    except (ValueError, OSError, http.client.HTTPException) as error:
        log_failure('Advisory scan incomplete', error)
        review = error if isinstance(error, advisories.AdvisoryReview) else None
        providers.advisory_snapshots(pilot, None, now, review=review)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description='Fetch reviewed PRC publications; names remain on-device.')
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--live-sources', action='store_true')
    parser.add_argument('--advisories-only', action='store_true')
    parser.add_argument('--delivery', choices=['disabled'], default='disabled')
    args = parser.parse_args()
    try:
        config = json.loads(args.config.read_text(encoding='utf-8'))
        if os.environ.get('PRC_PRIVATE_PROFILES'):
            profiles = json.loads(os.environ['PRC_PRIVATE_PROFILES'])
            if not isinstance(profiles, dict) or any(not isinstance(value, dict) for value in profiles.values()):
                raise ValueError('Private profiles must be a map of reviewed profiles.')
            config['profiles'] = {**config.get('profiles', {}), **profiles}
        SourcePolicy(config.get('sourcePolicy', {}))
        if not args.live_sources:
            raise SourceError('Use --live-sources explicitly; there is no demo fallback.')
        from worker.providers import Providers
        if args.advisories_only and (os.environ.get('FIRESTORE_EMULATOR_HOST', '').split(':')[0] not in
                                     ('localhost', '127.0.0.1') or
                                     os.environ.get('FIREBASE_PROJECT_ID') != 'demo-resview-advisories'):
            raise SourceError('The advisory pilot is qualified for the local demo project only.')
        operation = run_advisories if args.advisories_only else run
        return 1 if operation(config, Providers.from_environment(), datetime.now(timezone.utc)) else 0
    except Exception as error:
        log_failure('Worker failed', error)
        return 1


if __name__ == '__main__':
    sys.exit(main())
