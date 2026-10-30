import hashlib
import http.client
import ipaddress
import re
import socket
import ssl
import time
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from urllib.parse import unquote, urljoin, urlsplit
from urllib.robotparser import RobotFileParser

USER_AGENT = 'ResView/0.1 (public exam publication monitor)'
MAX_DOCUMENT_BYTES = 20 * 1024 * 1024


class SourceError(ValueError):
    pass


def publication_identity_url(url):
    parsed = urlsplit(url)
    if parsed.hostname in ('www.prc.gov.ph', 'prc.gov.ph'):
        path = parsed.path.removeprefix('/index.php') if parsed.path.startswith('/index.php/article/') else parsed.path
        return parsed._replace(netloc='www.prc.gov.ph', path=path).geturl()
    return url


class SourcePolicy:
    def __init__(self, config):
        if not config.get('accessAuthorization') or not config.get('routes'):
            raise SourceError('Live source access is not configured.')
        self.routes = config['routes']
        self.robots = {}
        self.require_robots = False

    def check(self, url):
        parsed = urlsplit(url)
        path = unquote(parsed.path)
        if (parsed.scheme != 'https' or parsed.hostname not in self.routes
                or parsed.username or parsed.password or parsed.port not in (None, 443)
                or '\\' in url or any(part in ('.', '..') for part in path.split('/'))
                or not any((re.fullmatch(re.escape(route).replace(r'\{year\}', r'20\d{2}'), path)
                            if '{year}' in route else path.startswith(route))
                           for route in self.routes[parsed.hostname])):
            raise SourceError('Unapproved source route.')
        if self.require_robots and (parsed.hostname not in self.robots
                                   or not self.robots[parsed.hostname].can_fetch(USER_AGENT, url)):
            raise SourceError('Source robots rules restrict this route.')
        return parsed

    def load_robots(self, fetcher):
        for host in self.routes:
            robot = RobotFileParser()
            body = fetcher(f'https://{host}/robots.txt', self, limit=256 * 1024)
            robot.parse(body.decode('utf-8').splitlines())
            self.robots[host] = robot
        self.require_robots = True


def _request(url, address, limit, timeout):
    parsed = urlsplit(url)
    connection = http.client.HTTPSConnection(parsed.hostname, timeout=timeout)
    # Pin the checked address while retaining hostname verification and TLS SNI.
    connection.sock = ssl.create_default_context().wrap_socket(
        socket.create_connection((address, 443), timeout=timeout), server_hostname=parsed.hostname)
    try:
        connection.request('GET', parsed.path + ('?' + parsed.query if parsed.query else ''),
                           headers={'User-Agent': USER_AGENT, 'Accept-Encoding': 'identity'})
        response = connection.getresponse()
        headers = dict((key.lower(), value) for key, value in response.getheaders())
        if int(headers.get('content-length', '0')) > limit:
            raise SourceError('Source exceeds the size limit.')
        deadline = time.monotonic() + timeout
        chunks, count = [], 0
        while True:
            if time.monotonic() > deadline:
                raise SourceError('Source response timed out.')
            chunk = response.read(min(65536, limit + 1 - count))
            if not chunk:
                break
            chunks.append(chunk)
            count += len(chunk)
            if count > limit:
                raise SourceError('Source exceeds the size limit.')
        return response.status, headers, b''.join(chunks)
    finally:
        connection.close()


def fetch(url, policy, *, limit=MAX_DOCUMENT_BYTES, transport=_request,
          sleep=time.sleep, budget=90):
    deadline = time.monotonic() + budget
    redirects = attempts = 0
    while True:
        parsed = policy.check(url)
        addresses = {item[4][0] for item in socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)}
        if not addresses or any(not ipaddress.ip_address(ip).is_global for ip in addresses):
            raise SourceError('Source DNS returned a non-public address.')
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise SourceError('Source run budget exhausted.')
        attempts += 1
        try:
            status, headers, body = transport(url, sorted(addresses)[0], limit, min(20, remaining))
        except (OSError, http.client.HTTPException) as error:
            raise SourceError('Source connection failed.') from error
        if len(body) > limit:
            raise SourceError('Source exceeds the size limit.')
        if status in (301, 302, 303, 307, 308):
            redirects += 1
            if redirects > 3 or not headers.get('location'):
                raise SourceError('Source redirect limit exceeded.')
            url = urljoin(url, headers['location'])
            policy.check(url)
            continue
        if status == 429 or 500 <= status <= 599:
            if attempts >= 3:
                raise SourceError('Source retry limit exceeded.')
            retry = headers.get('retry-after', '')
            try:
                delay = float(retry) if retry else (1, 4)[attempts - 1]
            except ValueError:
                try:
                    delay = (parsedate_to_datetime(retry) - datetime.now(timezone.utc)).total_seconds()
                except (TypeError, ValueError):
                    raise SourceError('Invalid source retry interval.') from None
            if not 0 <= delay <= deadline - time.monotonic():
                raise SourceError('Source retry exceeds the run budget.')
            sleep(delay)
            continue
        if status != 200:
            raise SourceError('Source unavailable or restricted.')
        return body


class Page(HTMLParser):
    def __init__(self, body):
        super().__init__(convert_charrefs=True)
        self.text, self.links, self.headings, self.rows = [], [], [], []
        self._heading = self._link = self._cell = None
        self._row = None
        self.feed(body.decode('utf-8', errors='strict'))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('h1', 'h5'):
            self._heading = []
        if tag == 'a' and attrs.get('href'):
            self._link = [attrs['href'], []]
        if tag == 'tr':
            self._row = []
        if tag in ('td', 'th'):
            self._cell = []

    def handle_data(self, data):
        self.text.append(data)
        if self._heading is not None:
            self._heading.append(data)
        if self._link is not None:
            self._link[1].append(data)
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('h1', 'h5') and self._heading is not None:
            self.headings.append(' '.join(' '.join(self._heading).split()))
            self._heading = None
        if tag == 'a' and self._link is not None:
            self.links.append((self._link[0], ' '.join(' '.join(self._link[1]).split())))
            self._link = None
        if tag in ('td', 'th') and self._cell is not None:
            if self._row is not None:
                self._row.append(' '.join(' '.join(self._cell).split()))
            self._cell = None
        if tag == 'tr' and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def parse_publication(url, body, now):
    if urlsplit(url).hostname not in ('www.prc.gov.ph', 'prc.gov.ph'):
        raise SourceError('Publication must be on PRC.')
    article = re.search(rb'<article\b[^>]*>(.*?)</article>', body, re.S | re.I)
    page = Page(article[1] if article else body)
    text = ' '.join(page.text)
    match = re.search(r'Posted on\s+(\d{1,2} [A-Za-z]+,? \d{4})', text)
    titles = [title for title in page.headings if 'result' in title.lower()]
    if not match or not titles:
        raise SourceError('Official publication title/date not found.')
    date = datetime.strptime(match[1].replace(',', ''), '%d %B %Y').replace(
        tzinfo=timezone(timedelta(hours=8))).astimezone(timezone.utc)
    documents = sorted({urljoin(url, link) for link, label in page.links
                        if label.strip().lower() in ('list of successful examinees', 'list of passers')})
    version = hashlib.sha256((titles[0] + text + repr(documents)).encode()).hexdigest()
    return {'title': titles[0], 'publicationUrl': url, 'publishedAtUtc': date.isoformat(),
            'retrievedAtUtc': now.isoformat(), 'sourceSha256': hashlib.sha256(body).hexdigest(),
            'publicationVersion': version, 'documents': documents, 'type': 'PRC result publication'}


def _exam_title(title):
    return ' '.join(re.sub(r'\(CBLE\)|Computer-Based', '', title, flags=re.I).split())


def _slug(title):
    return re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')


def schedule_dates(value):
    match = re.fullmatch(r'([A-Za-z]+ [\d\s,\-–]+(?:and |to )?[^()]*?),?\s+(20\d{2})', value)
    if not match:
        raise ValueError('Unrecognized schedule dates.')
    year = int(match[2])
    tokens = re.findall(r'[A-Za-z]+|\d+|[^\w\s]', match[1])
    dates, month = [], None
    for token in tokens:
        if token in (',', '-', '–', 'and', 'to'):
            continue
        if token.isdigit():
            dates.append(datetime(year, month, int(token), tzinfo=timezone.utc))
        else:
            month = datetime.strptime(token, '%B').month
    if not dates or dates != sorted(dates):
        raise ValueError('Unrecognized schedule order.')
    return dates[0], dates[-1]


def parse_catalog(body, url, now, overrides=()):
    page = Page(body)
    exams, sittings, review = {}, [], []
    provenance = {'catalogUrl': url, 'retrievedAtUtc': now.isoformat(),
                  'sourceSha256': hashlib.sha256(body).hexdigest()}
    for row in page.rows:
        if len(row) < 5 or not (row[0].isdigit() or not row[0]) or not row[1]:
            continue
        title = _exam_title(row[1])
        exam_id = _slug(title)
        exams[exam_id] = {'id': exam_id, 'title': title, **provenance}
        try:
            dates = row[2]
            override = next((item for item in overrides if item['catalogUrl'] == url
                             and item['examId'] == exam_id and item['officialDates'] == dates
                             and item['officialTestingCenters'] == row[4]), None)
            if override:
                if override.get('cancelled'):
                    review.append({'examId': exam_id, 'reason': 'Schedule row needs date/type review.',
                                   'officialDates': dates, 'status': 'cancelled'})
                    continue
                start, end = schedule_dates(override['reviewedDates'])
            else:
                if re.search(r'cancel|resched|additional days', row[4], re.I):
                    raise ValueError('Location-specific schedule change requires review.')
                start, end = schedule_dates(dates)
            special = bool(re.search(r'\(SPLE\s*\)', title, re.I))
            oral = bool(re.search(r'oral|technical evaluation', title, re.I))
            if not row[0].isdigit() and not (special or oral):
                raise ValueError('Unrecognized unnumbered sitting.')
            sitting_id = f'{exam_id}-{start.date().isoformat()}'
            sittings.append({'id': sitting_id, 'examId': exam_id, 'start': start.isoformat(),
                             'end': end.isoformat(), 'type': 'special' if special else 'oral' if oral else 'domestic',
                             'location': row[4].split('Resolution')[0].split('Reso no.')[0].strip() if special or oral else '',
                             'categories': ({'elementary': 'Elementary', 'secondary': 'Secondary'}
                                            if 'Professional Teachers' in title else {'all': 'All successful examinees'}),
                             'officialDates': dates, 'officialTestingCenters': row[4], **provenance})
        except (ValueError, TypeError, IndexError):
            review.append({'examId': exam_id, 'reason': 'Schedule row needs date/type review.',
                           'officialDates': row[2]})
    if not exams or not sittings:
        raise SourceError('Official catalog table not found.')
    return {'exams': list(exams.values()), 'sittings': sittings, 'review': review, 'catalogUrl': url}


def associations(publication, catalog):
    title = _exam_title(publication['title']).lower()
    month = re.match(r'([a-z]+) (20\d{2})\b', title)
    if not month:
        return []
    special = bool(re.search(r'special prof|\bsple\b', title))
    candidates = []
    matches = []
    for exam in catalog['exams']:
        name = exam['title'].lower()
        if bool(re.search(r'\(sple\s*\)', name)) != special:
            continue
        if re.search(r'oral|technical evaluation|written|practical|revalida', name):
            continue
        name = re.sub(r'\s*\(sple\s*\)', '', name)
        name = {'veterinary medicine': 'veterinarians', 'food technologist': 'food technologists',
                'architect': 'architects', 'customs broker': 'customs brokers',
                'chemical technician': 'chemical technicians', 'sanitary engineer': 'sanitary engineers'}.get(name, name)
        if not re.search(r'(?<!\w)' + re.escape(name) + r'(?!\w)', title):
            continue
        # Professional/oral announcements must never attach to the ordinary engineer exam.
        if re.search(r'professional (?:electronics|electrical|mechanical) engineers', title):
            continue
        matches.append((exam, name))
    for exam, name in matches:
        if any(name != other and name in other for _, other in matches):
            continue
        sittings = []
        for sitting in catalog['sittings']:
            date = datetime.fromisoformat(sitting['start'])
            if (sitting['examId'] == exam['id'] and date.strftime('%B').lower() == month[1]
                    and date.year == int(month[2]) and (sitting['type'] == 'special') == special
                    and sitting['type'] != 'oral'):
                sittings.append(sitting)
        if len(sittings) > 1:
            return []
        for sitting in sittings:
            for category in sitting['categories']:
                candidates.append({'examId': exam['id'], 'sittingId': sitting['id'], 'categoryId': category})
    return candidates


def associate(publication, catalog):
    candidates = associations(publication, catalog)
    return candidates[0] if len(candidates) == 1 else None
