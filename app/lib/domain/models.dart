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

class NameInput {
  const NameInput(this.surname, this.givenNames, this.middleName, this.suffix);
  final String surname, givenNames, middleName, suffix;
  Map<String, dynamic> toJson() => {
    'surname': surname,
    'givenNames': givenNames,
    'middleName': middleName,
    'suffix': suffix,
  };
  factory NameInput.fromJson(Map<String, dynamic> j) => NameInput(
    j['surname'] as String,
    j['givenNames'] as String,
    j['middleName'] as String,
    j['suffix'] as String,
  );
}

class NameEntry {
  const NameEntry({
    required this.sequence,
    required this.publishedName,
    required this.sectionId,
    required this.physicalPage,
    this.components,
  });
  final int sequence, physicalPage;
  final String publishedName, sectionId;
  final NameInput? components;
}

class NamesDocument {
  const NamesDocument({
    required this.selection,
    required this.documentVersion,
    required this.entries,
    this.componentsReliable = false,
    this.nameFormat = 'surnameCommaNamesV1',
  });
  final ExamSelection selection;
  final String documentVersion, nameFormat;
  final List<NameEntry> entries;
  final bool componentsReliable;
  factory NamesDocument.fromJson(
    Map<String, dynamic> j, {
    required ExamSelection expectedSelection,
    required String expectedVersion,
  }) {
    try {
      final selection = ExamSelection.fromJson(
        j['selection'] as Map<String, dynamic>,
      );
      if (j['formatVersion'] != 1 ||
          selection != expectedSelection ||
          j['documentVersion'] != expectedVersion ||
          j['nameFormat'] != 'surnameCommaNamesV1') {
        throw const FormatException('Unsupported or mismatched list.');
      }
      for (final key in ['publicationUrl', 'documentUrl']) {
        publicUrl(j[key] as String);
      }
      DateTime.parse(j['validatedAtUtc'] as String);
      if (!RegExp(r'^[a-fA-F0-9]{64}$')
          .hasMatch(j['originalSha256'] as String)) {
        throw const FormatException('Invalid checksum.');
      }
      final reliable = j['componentsReliable'] as bool;
      final seen = <String>{};
      final entries = (j['entries'] as List).map((value) {
        final e = value as Map<String, dynamic>;
        final sequence = e['sequence'] as int, page = e['physicalPage'] as int;
        final section = e['sectionId'] as String,
            name = e['publishedName'] as String;
        if (sequence < 1 ||
            page < 1 ||
            section.isEmpty ||
            name.trim().isEmpty ||
            !seen.add('$section/$sequence')) {
          throw const FormatException('Invalid entry.');
        }
        final components = e['components'] == null
            ? null
            : NameInput.fromJson(e['components'] as Map<String, dynamic>);
        if (reliable &&
            (components == null ||
                components.surname.isEmpty ||
                components.givenNames.isEmpty)) {
          throw const FormatException('Missing reviewed name components.');
        }
        return NameEntry(
          sequence: sequence,
          publishedName: name,
          sectionId: section,
          physicalPage: page,
          components: components,
        );
      }).toList();
      if (entries.isEmpty || j['entryCount'] != entries.length) {
        throw const FormatException('Incomplete list.');
      }
      return NamesDocument(
        selection: selection,
        documentVersion: expectedVersion,
        entries: entries,
        componentsReliable: reliable,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid list format.');
    }
  }
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
