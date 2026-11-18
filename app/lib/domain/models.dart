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
  });
  final String id, examId, type, location;
  final DateTime start, end;
  final Map<String, String> categories;
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
