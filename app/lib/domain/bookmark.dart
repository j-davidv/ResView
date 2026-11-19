import 'package:flutter/foundation.dart';

import 'models.dart';

enum BookmarkKind { announcement, result }

@immutable
class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.kind,
    required this.examId,
    required this.examName,
    required this.title,
    required this.url,
    required this.savedAtUtc,
    this.publishedAtUtc,
    this.sittingLabel,
  });

  final String id;
  final BookmarkKind kind;
  final String examId;
  final String examName;
  final String title;
  final Uri url;
  final DateTime savedAtUtc;
  final DateTime? publishedAtUtc;
  final String? sittingLabel;

  String get key => '${kind.name}:$id';
  String get kindLabel =>
      kind == BookmarkKind.announcement ? 'Announcement' : 'Result publication';

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'examId': examId,
    'examName': examName,
    'title': title,
    'url': url.toString(),
    'savedAtUtc': savedAtUtc.toUtc().toIso8601String(),
    'publishedAtUtc': publishedAtUtc?.toUtc().toIso8601String(),
    'sittingLabel': sittingLabel,
  };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid bookmark $key.');
      }
      return value;
    }

    final kindName = requiredText('kind');
    final kind = BookmarkKind.values.byName(kindName);
    final savedAtValue = requiredText('savedAtUtc');
    final publishedAtValue = json['publishedAtUtc'];
    final sittingValue = json['sittingLabel'];
    if (publishedAtValue != null && publishedAtValue is! String ||
        sittingValue != null && sittingValue is! String) {
      throw const FormatException('Invalid optional bookmark metadata.');
    }

    return BookmarkItem(
      id: requiredText('id'),
      kind: kind,
      examId: requiredText('examId'),
      examName: requiredText('examName'),
      title: requiredText('title'),
      url: publicUrl(requiredText('url')),
      savedAtUtc: DateTime.parse(savedAtValue).toUtc(),
      publishedAtUtc: publishedAtValue == null
          ? null
          : DateTime.parse(publishedAtValue as String).toUtc(),
      sittingLabel: sittingValue as String?,
    );
  }
}
