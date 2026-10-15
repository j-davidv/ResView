import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.parse import urljoin, urlsplit

from worker.extract import extract_pdf, write_names_file
from worker.publish import publish_validated
from worker.source import SourceError, SourcePolicy, fetch, parse_publication, parse_catalog, associate, Page


def discover(config, policy, now, fetcher):
    catalog_url, results_url = config['catalogUrl'], config['resultsUrl']
    for url in (catalog_url, results_url):
        policy.check(url)
    catalog = parse_catalog(fetcher(catalog_url, policy), catalog_url, now)
    index = Page(fetcher(results_url, policy))
    publications = []
    seen = set()
    for link, title in index.links:
        url = urljoin(results_url, link)
        if (not urlsplit(url).path.startswith('/article/') or 'results released' not in title.lower()
                or url in seen):
            continue
        seen.add(url)
        policy.check(url)
        selection = associate({'title': title}, catalog)
        if selection:
            publications.append({'url': url, 'selection': selection,
                                 'profile': config.get('profiles', {}).get(url)})
        else:
            catalog['review'].append({'publicationUrl': url, 'title': title,
                                      'reason': 'Exam/sitting/category association requires review.'})
    return catalog, publications


def run(config, providers, now, fetcher=fetch):
    if config.get('delivery', 'disabled') != 'disabled':
        raise ValueError('Outbound delivery is not enabled by this worker.')
    policy = SourcePolicy(config.get('sourcePolicy', {}))
    try:
        policy.load_robots(fetcher)
    except (ValueError, OSError):
        providers.health(now, False)
        return 1
    publications = config.get('publications', [])
    if config.get('catalogUrl') and config.get('resultsUrl'):
        try:
            catalog, publications = discover(config, policy, now, fetcher)
            providers.catalog(catalog)
            providers.review(catalog['review'])
        except (ValueError, OSError):
            providers.health(now, False)
            raise
    if not publications:
        providers.health(now, False)
        raise SourceError('No reviewed publication-to-sitting mappings configured.')
    failures = 0
    for item in publications:
        try:
            publication = parse_publication(item['url'], fetcher(item['url'], policy), now)
            publication['selection'] = item['selection']
            providers.publication(publication)
            reviewed = item.get('profile')
            if not reviewed:
                providers.unavailable(publication, 'This document format has not passed validation.')
                continue
            if reviewed['selection'] != item['selection'] or reviewed['publicationUrl'] != item['url']:
                raise ValueError('Reviewed profile does not match the publication selection.')
            if reviewed['documentUrl'] not in publication['documents']:
                raise ValueError('Document is not linked by the official publication.')
            with TemporaryDirectory() as directory:
                original = Path(directory) / 'source.pdf'
                body = fetcher(reviewed['documentUrl'], policy)
                original.write_bytes(body)
                try:
                    report = extract_pdf(original, reviewed, now)
                except ValueError:
                    providers.unavailable(publication, 'The current document has not passed validation.',
                                          observed_version=hashlib.sha256(body).hexdigest())
                    failures += 1
                    continue
                names = Path(directory) / 'names.json'
                write_names_file(report, names)
                publish_validated(report, names, providers, publication=publication)
        except (ValueError, OSError):
            failures += 1
            # Keep last-good publication data; source failure changes health only.
    providers.health(now, failures == 0)
    return failures


def main():
    parser = argparse.ArgumentParser(description='Fetch reviewed PRC publications; names remain on-device.')
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--live-sources', action='store_true')
    parser.add_argument('--delivery', choices=['disabled'], default='disabled')
    args = parser.parse_args()
    try:
        config = json.loads(args.config.read_text(encoding='utf-8'))
        SourcePolicy(config.get('sourcePolicy', {}))
        if not args.live_sources:
            raise SourceError('Use --live-sources explicitly; there is no demo fallback.')
        from worker.providers import Providers
        return 1 if run(config, Providers.from_environment(), datetime.now(timezone.utc)) else 0
    except Exception:
        print('Worker failed. Check configuration, source availability and private provider access.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
