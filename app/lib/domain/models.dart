enum PublicationState {
  notReleased,
  validationPending,
  checkingAvailable,
  checkingUnavailable,
  superseded,
}

enum SourceFreshness { fresh, stale, unknown }

SourceFreshness sourceFreshness(
  String? state,
  DateTime? lastSuccess,
  DateTime now,
) {
  if (state == 'stale') return SourceFreshness.stale;
  if (state != 'fresh' || lastSuccess == null || lastSuccess.isAfter(now)) {
    return SourceFreshness.unknown;
  }
  return now.difference(lastSuccess) > const Duration(minutes: 90)
      ? SourceFreshness.stale
      : SourceFreshness.fresh;
}

class ExamSelection {
  const ExamSelection(this.examId, this.sittingId, this.categoryId);
  final String examId, sittingId, categoryId;
  Map<String, dynamic> toJson() => {
    'examId': examId,
    'sittingId': sittingId,
    'categoryId': categoryId,
  };
  factory ExamSelection.fromJson(Map<String, dynamic> j) => ExamSelection(
    j['examId'] as String,
    j['sittingId'] as String,
    j['categoryId'] as String,
  );
  @override
  bool operator ==(Object other) =>
      other is ExamSelection &&
      examId == other.examId &&
      sittingId == other.sittingId &&
      categoryId == other.categoryId;
  @override
  int get hashCode => Object.hash(examId, sittingId, categoryId);
}

class Exam {
  const Exam(this.id, this.title);
  final String id, title;
}

class Sitting {
  const Sitting({
    required this.id,
    required this.examId,
    required this.start,
    required this.end,
    required this.type,
    required this.location,
    required this.categories,
    this.targetReleaseDate,
    this.catalogUrl,
  });
  final String id, examId, type, location;
  final DateTime start, end;
  final Map<String, String> categories;
  final DateTime? targetReleaseDate;
  final Uri? catalogUrl;
  String get label =>
      '${type[0].toUpperCase()}${type.substring(1)} · ${dateLabel(start)}${start == end ? '' : ' – ${dateLabel(end)}'}${location.isEmpty ? '' : ' · $location'}';
}

String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String sourceTime(DateTime? date) {
  if (date == null) return 'Not yet confirmed';
  final local = date.toUtc().add(const Duration(hours: 8));
  return '${dateLabel(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} UTC+08:00';
}

class Publication {
  const Publication({
    required this.id,
    required this.title,
    required this.url,
    required this.publishedAtUtc,
    this.type = 'PRC announcement',
    this.documents = const {},
  });
  final String id, title, type;
  final Uri url;
  final DateTime publishedAtUtc;
  final Map<Uri, String> documents;
}

Map<Uri, String> successfulExamineeLinks(Map<String, dynamic> record) {
  final links = <Uri, String>{};
  void add(Object? value, String label) {
    if (value is! String) return;
    try {
      links.putIfAbsent(publicUrl(value), () => label);
    } on FormatException {
      // A malformed document link must not hide the PRC announcement.
    }
  }

  final candidates = record['documentCandidates'];
  if (candidates is List) {
    for (final candidate in candidates) {
      if (candidate is Map && candidate['label'] is String) {
        final label = (candidate['label'] as String).trim();
        if (label.isNotEmpty) add(candidate['url'], label);
      }
    }
  }
  final documents = record['documents'];
  if (documents is List) {
    for (final url in documents) {
      add(url, 'successful-examinee list');
    }
  }
  return links;
}

class ResultVersion {
  const ResultVersion({
    required this.selection,
    required this.state,
    required this.documentVersion,
    this.freshness = SourceFreshness.unknown,
    this.lastSuccessfulCheckUtc,
    this.publicationUrl,
    this.documentUrl,
    this.namesUrl,
    this.namesBytes,
    this.namesSha256,
    this.validatedAtUtc,
    this.reason,
  });
  final ExamSelection selection;
  final PublicationState state;
  final SourceFreshness freshness;
  final String documentVersion;
  final DateTime? lastSuccessfulCheckUtc, validatedAtUtc;
  final Uri? publicationUrl, documentUrl, namesUrl;
  final int? namesBytes;
  final String? namesSha256, reason;
}

class ResultMonitorStatus {
  const ResultMonitorStatus({this.freshness, this.lastSuccessfulCheckUtc});
  final String? freshness;
  final DateTime? lastSuccessfulCheckUtc;
}

Uri publicUrl(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.host == 'localhost' ||
      uri.host == '127.0.0.1') {
    throw const FormatException('Invalid public source URL.');
  }
  return uri;
}

typedef ExamUpdate = ({
  String title,
  Uri url,
  DateTime posted,
  String audience,
});

class AdvisoryFeed {
  const AdvisoryFeed._(
    this.start,
    this.end,
    this.lastCheck,
    this.stale,
    this.notices,
  );
  final DateTime start, end;
  final DateTime? lastCheck;
  final bool stale;
  final List<ExamUpdate> notices;
  static const maxAge = Duration(hours: 36);

  factory AdvisoryFeed.fromJson(Map<String, dynamic> data) {
    DateTime utc(Object? value) {
      if (value is! String ||
          !RegExp(
            r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?(?:Z|\+00:00)$',
          ).hasMatch(value)) {
        throw const FormatException('Missing UTC timestamp.');
      }
      final date = DateTime.parse(value).toUtc();
      if (!value.startsWith(date.toIso8601String().substring(0, 19))) {
        throw const FormatException('Invalid UTC timestamp.');
      }
      return date;
    }

    final start = utc(data['coverageStartUtc']),
        end = utc(data['coverageEndUtc']);
    final last = data['lastSuccessfulCheckUtc'] == null
        ? null
        : utc(data['lastSuccessfulCheckUtc']);
    final raw = data['notices'];
    final freshness = data['freshness'];
    if (!start.isBefore(end) ||
        !['fresh', 'stale'].contains(freshness) ||
        raw is! List ||
        start.isBefore(DateTime.utc(2025, 12, 31, 16)) ||
        (last == null && (freshness == 'fresh' || raw.isNotEmpty))) {
      throw const FormatException('Invalid advisory coverage.');
    }
    final notices = <ExamUpdate>[];
    for (final item in raw) {
      if (item is! Map ||
          item['kind'] != 'announcement' ||
          item['title'] is! String ||
          (item['title'] as String).trim().isEmpty ||
          item['publicationUrl'] is! String) {
        throw const FormatException('Invalid exam update.');
      }
      final url = publicUrl(item['publicationUrl']);
      final posted = utc(item['publishedAtUtc']);
      if (!{'www.prc.gov.ph', 'prc.gov.ph'}.contains(url.host) ||
          url.port != 443 ||
          !RegExp(
            r'^/(?:index\.php/)?(?:article/[^/]+|prc-(?:resolution|memorandum-circular)-no-[0-9]+[a-z]?-s-20[0-9]{2}(?:-[0-9]+)?)$',
          ).hasMatch(url.path) ||
          url.hasQuery ||
          url.hasFragment ||
          posted.isBefore(start) ||
          !posted.isBefore(end)) {
        throw const FormatException('Unconfirmed notice source or date.');
      }
      final audience = item['audience'] ?? '';
      if (audience is! String) throw const FormatException('Invalid audience.');
      notices.add((
        title: item['title'] as String,
        url: url,
        posted: posted,
        audience: audience,
      ));
    }
    return AdvisoryFeed._(start, end, last, freshness == 'stale', notices);
  }
}
