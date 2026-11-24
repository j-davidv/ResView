import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/models.dart';
import 'exam_repository.dart';
import 'firestore_rest.dart';

class FirestoreExamRepository implements ExamRepository {
  FirestoreExamRepository(this.database) : _rest = null;
  FirestoreExamRepository.public(String projectId, {FirestoreRest? rest})
    : database = null,
      _rest = rest ?? FirestoreRest(projectId);

  factory FirestoreExamRepository.fromEnvironment() {
    if (Firebase.apps.isNotEmpty) {
      return FirestoreExamRepository(FirebaseFirestore.instance);
    }
    const project = String.fromEnvironment(
      'FIRESTORE_PUBLIC_PROJECT_ID',
      defaultValue: 'resview-9240c',
    );
    return project.isEmpty
        ? FirestoreExamRepository(null)
        : FirestoreExamRepository.public(project);
  }

  final FirebaseFirestore? database;
  final FirestoreRest? _rest;
  FirebaseFirestore get db => database ?? (throw const ServiceUnavailable());
  DateTime _date(dynamic value) => value is Timestamp
      ? value.toDate().toUtc()
      : DateTime.parse(value as String).toUtc();
  Map<String, String> _selectionFilters(ExamSelection selection) => {
    'selection.examId': selection.examId,
    'selection.sittingId': selection.sittingId,
    'selection.categoryId': selection.categoryId,
  };

  Future<List<FirestoreRecord>> _query(
    String collection, {
    required int limit,
    Map<String, Object> equals = const {},
    String? orderBy,
    bool descending = false,
  }) async {
    if (_rest case final rest?) {
      return rest.query(
        collection,
        limit: limit,
        equals: equals,
        orderBy: orderBy,
        descending: descending,
      );
    }
    Query<Map<String, dynamic>> query = db.collection(collection);
    for (final entry in equals.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    final snapshot = await query
        .limit(limit)
        .get(const GetOptions(source: Source.server));
    return [
      for (final document in snapshot.docs)
        (id: document.id, fields: document.data()),
    ];
  }

  Future<Map<String, dynamic>?> _getDocument(String path) async {
    if (_rest case final rest?) return rest.getDocument(path);
    return (await db.doc(path).get(const GetOptions(source: Source.server)))
        .data();
  }

  @override
  Future<List<Exam>> loadCatalog() async {
    final records = await _query('exams', orderBy: 'title', limit: 250);
    return [
      for (final record in records)
        Exam(record.id, record.fields['title'] as String),
    ];
  }

  @override
  Future<List<Sitting>> loadSittings(String examId) async {
    final records = await _query(
      'sittings',
      equals: {'examId': examId},
      orderBy: 'start',
      limit: 250,
    );
    return records.where((d) => d.fields['active'] != false).map((d) {
      final j = d.fields;
      final type = j['type'] as String;
      if (!['domestic', 'special', 'overseas', 'oral'].contains(type)) {
        throw const FormatException('Invalid sitting type.');
      }
      final end = _date(j['end']);
      DateTime? target;
      Uri? catalogUrl;
      final rawTarget = j['targetReleaseDate'];
      if (rawTarget is Timestamp) {
        target = _date(rawTarget);
      } else if (rawTarget is String &&
          RegExp(r'^\d{4}-\d{2}-\d{2}T00:00:00(?:Z|\+00:00)$')
              .hasMatch(rawTarget)) {
        final parsed = DateTime.tryParse(rawTarget);
        if (parsed != null &&
            parsed.toIso8601String().startsWith(rawTarget.substring(0, 10))) {
          target = parsed;
        }
      }
      if (target != null &&
          (target.isBefore(end) ||
              target != DateTime.utc(target.year, target.month, target.day))) {
        target = null;
      }
      try {
        if (j['catalogUrl'] is String) catalogUrl = publicUrl(j['catalogUrl']);
      } on FormatException {
        catalogUrl = null;
      }
      return Sitting(
        id: d.id,
        examId: examId,
        start: _date(j['start']),
        end: end,
        type: type,
        location: j['location'] as String,
        categories: Map<String, String>.from(j['categories'] as Map),
        targetReleaseDate: target,
        catalogUrl: catalogUrl,
      );
    }).toList();
  }

  @override
  Future<List<Publication>> loadPublications(ExamSelection selection) async {
    final records = await _query(
      'publications',
      equals: _selectionFilters(selection),
      orderBy: 'publishedAtUtc',
      descending: true,
      limit: 50,
    );
    return records.map((d) {
      final j = d.fields;
      return Publication(
        id: d.id,
        title: j['title'] as String,
        url: publicUrl(j['publicationUrl'] as String),
        publishedAtUtc: _date(j['publishedAtUtc']),
        type: j['type'] as String? ?? 'PRC announcement',
        documents: successfulExamineeLinks(j),
      );
    }).toList();
  }

  @override
  Future<AdvisoryFeed?> loadAdvisories(String examId) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,180}$').hasMatch(examId)) {
      throw const FormatException('Invalid exam identifier.');
    }
    final fields = await _getDocument('examUpdates/$examId');
    if (fields == null || fields['retired'] == true) return null;
    return AdvisoryFeed.fromJson(fields);
  }

  @override
  Future<ResultMonitorStatus?> loadResultMonitorStatus() async {
    final health = await _getDocument('monitor/status');
    if (health == null) return null;
    return ResultMonitorStatus(
      freshness: health['freshness'] as String?,
      lastSuccessfulCheckUtc: health['lastSuccessfulCheckUtc'] == null
          ? null
          : _date(health['lastSuccessfulCheckUtc']),
    );
  }

  @override
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async {
    final records = await _query(
      'resultVersions',
      equals: {..._selectionFilters(selection), 'current': true},
      limit: 1,
    );
    if (records.isEmpty) return null;
    final j = records.single.fields;
    Uri? uri(String key) => j[key] == null ? null : publicUrl(j[key] as String);
    DateTime? date(dynamic value) => value == null ? null : _date(value);
    final lastSuccess = date(j['lastSuccessfulCheckUtc']);
    return ResultVersion(
      selection: selection,
      state: PublicationState.values.byName(j['state'] as String),
      documentVersion: j['documentVersion'] as String,
      lastSuccessfulCheckUtc: lastSuccess,
      publicationUrl: uri('publicationUrl'),
      documentUrl: uri('documentUrl'),
      namesUrl: uri('namesUrl'),
      namesBytes: j['namesBytes'] as int?,
      namesSha256: j['namesSha256'] as String?,
      validatedAtUtc: date(j['validatedAtUtc']),
      reason: j['reason'] as String?,
    );
  }
}
