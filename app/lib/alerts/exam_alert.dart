import '../domain/models.dart';

enum AlertKind { result, announcement, scheduleChange }

Uri officialAlertUrl(String value) {
  final url = publicUrl(value);
  if (!{'prc.gov.ph', 'www.prc.gov.ph'}.contains(url.host) ||
      url.port != 443 ||
      url.hasQuery ||
      url.hasFragment ||
      url.userInfo.isNotEmpty) {
    throw const FormatException('Unconfirmed alert source.');
  }
  return url.replace(
    host: 'www.prc.gov.ph',
    path: url.path.replaceFirst('/index.php/', '/'),
  );
}

class ExamAlert {
  const ExamAlert({
    required this.id,
    required this.kind,
    required this.title,
    required this.url,
    required this.selection,
    required this.posted,
    this.read = false,
  });
  final String id, title;
  final AlertKind kind;
  final Uri url;
  final ExamSelection selection;
  final DateTime posted;
  final bool read;
  String get label => switch (kind) {
    AlertKind.result => 'Results published',
    AlertKind.announcement => 'Official exam update',
    AlertKind.scheduleChange => 'Schedule update',
  };
  ExamAlert asRead() => ExamAlert(
    id: id,
    kind: kind,
    title: title,
    url: url,
    selection: selection,
    posted: posted,
    read: true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'url': url.toString(),
    'selection': selection.toJson(),
    'publishedAtUtc': posted.toUtc().toIso8601String(),
    'read': read,
  };
  factory ExamAlert.fromJson(Map<String, dynamic> data) {
    final id = data['sourceId'] ?? data['id'] ?? data['alertId'];
    final title = data['title'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 2048 ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 1000) {
      throw const FormatException('Invalid alert.');
    }
    final selection = data['selection'] is Map
        ? ExamSelection.fromJson(Map<String, dynamic>.from(data['selection']))
        : ExamSelection.fromJson(data);
    if ([
      selection.examId,
      selection.sittingId,
      selection.categoryId,
    ].any((part) => !RegExp(r'^[a-zA-Z0-9_-]{1,256}$').hasMatch(part))) {
      throw const FormatException('Invalid alert selection.');
    }
    final posted = DateTime.parse(data['publishedAtUtc'] as String).toUtc();
    if (posted.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    )) {
      throw const FormatException('Invalid alert date.');
    }
    return ExamAlert(
      id: id,
      kind: AlertKind.values.byName(data['kind'] as String),
      title: title,
      url: officialAlertUrl(data['url'] as String),
      selection: selection,
      posted: posted,
      read: data['read'] == true,
    );
  }
}

bool isScheduleNotice(String title) => RegExp(
  r'\breschedul\w*|\bpostpon\w*|\bcancel\w*|\b(?:revised|amended|new)\s+(?:examination\s+)?schedule',
  caseSensitive: false,
).hasMatch(title);
