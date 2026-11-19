import 'package:flutter/foundation.dart';

import 'models.dart';

enum HistoryKind { announcement, result }

@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.sourceId,
    required this.kind,
    required this.examId,
    required this.examName,
    required this.title,
    required this.url,
    required this.viewedAtUtc,
    this.publishedAtUtc,
    this.sittingLabel,
  });

  /// Stable identifier for deduplication. For announcements: canonical URL
  /// string. For results: `examId:sittingId:categoryId:documentVersion` or
  /// the publication id.
  final String sourceId;

  final HistoryKind kind;
  final String examId;
  final String examName;
  final String title;
  final Uri url;
  final DateTime viewedAtUtc;
  final DateTime? publishedAtUtc;
  final String? sittingLabel;

  String get kindLabel =>
      kind == HistoryKind.announcement ? 'Announcement' : 'Result publication';

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'kind': kind.name,
    'examId': examId,
    'examName': examName,
    'title': title,
    'url': url.toString(),
    'viewedAtUtc': viewedAtUtc.toUtc().toIso8601String(),
    'publishedAtUtc': publishedAtUtc?.toUtc().toIso8601String(),
    'sittingLabel': sittingLabel,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid history entry $key.');
      }
      return value;
    }

    final kindName = required('kind');
    final kind = HistoryKind.values.byName(kindName);
    final viewedAtValue = required('viewedAtUtc');
    final publishedAtValue = json['publishedAtUtc'];
    final sittingValue = json['sittingLabel'];
    if (publishedAtValue != null && publishedAtValue is! String ||
        sittingValue != null && sittingValue is! String) {
      throw const FormatException('Invalid optional history metadata.');
    }

    return HistoryEntry(
      sourceId: required('sourceId'),
      kind: kind,
      examId: required('examId'),
      examName: required('examName'),
      title: required('title'),
      url: publicUrl(required('url')),
      viewedAtUtc: DateTime.parse(viewedAtValue).toUtc(),
      publishedAtUtc: publishedAtValue == null
          ? null
          : DateTime.parse(publishedAtValue as String).toUtc(),
      sittingLabel: sittingValue as String?,
    );
  }

  HistoryEntry withViewedAt(DateTime viewedAtUtc) => HistoryEntry(
    sourceId: sourceId,
    kind: kind,
    examId: examId,
    examName: examName,
    title: title,
    url: url,
    viewedAtUtc: viewedAtUtc,
    publishedAtUtc: publishedAtUtc,
    sittingLabel: sittingLabel,
  );
}
