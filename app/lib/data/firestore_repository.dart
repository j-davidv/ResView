import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models.dart';
import 'exam_repository.dart';

class FirestoreExamRepository implements ExamRepository {
  FirestoreExamRepository(this.database);
  final FirebaseFirestore? database;
  FirebaseFirestore get db => database ?? (throw const ServiceUnavailable());
  DateTime _date(dynamic value) => value is Timestamp
      ? value.toDate().toUtc()
      : DateTime.parse(value as String).toUtc();
  Query<Map<String, dynamic>> _selected(String path, ExamSelection selection) =>
      db
          .collection(path)
          .where('selection.examId', isEqualTo: selection.examId)
          .where('selection.sittingId', isEqualTo: selection.sittingId)
          .where('selection.categoryId', isEqualTo: selection.categoryId);
  @override
  Future<List<Exam>> loadCatalog() async {
    final records = await db
        .collection('exams')
        .orderBy('title')
        .limit(250)
        .get(const GetOptions(source: Source.server));
    return records.docs
        .map((d) => Exam(d.id, d.data()['title'] as String))
        .toList();
  }

  @override
  Future<List<Sitting>> loadSittings(String examId) async {
    final records = await db
        .collection('sittings')
        .where('examId', isEqualTo: examId)
        .orderBy('start')
        .limit(250)
        .get(const GetOptions(source: Source.server));
    return records.docs.where((d) => d.data()['active'] != false).map((d) {
      final j = d.data();
      final type = j['type'] as String;
      if (!['domestic', 'special', 'overseas'].contains(type)) {
        throw const FormatException('Invalid sitting type.');
      }
      return Sitting(
        id: d.id,
        examId: examId,
        start: _date(j['start']),
        end: _date(j['end']),
        type: type,
        location: j['location'] as String,
        categories: Map<String, String>.from(j['categories'] as Map),
      );
    }).toList();
  }

  @override
  Future<List<Publication>> loadPublications(ExamSelection selection) async {
    final records = await _selected('publications', selection)
        .orderBy('publishedAtUtc', descending: true)
        .limit(50)
        .get(const GetOptions(source: Source.server));
    return records.docs.map((d) {
      final j = d.data();
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
  Future<ResultVersion?> loadResultVersion(ExamSelection selection) async {
    final records = await _selected('resultVersions', selection)
        .where('current', isEqualTo: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (records.docs.isEmpty) return null;
    final j = records.docs.single.data();
    final health = await db
        .doc('monitor/status')
        .get(const GetOptions(source: Source.server));
    final h = health.data() ?? {};
    Uri? uri(String key) => j[key] == null ? null : publicUrl(j[key] as String);
    DateTime? date(dynamic value) => value == null ? null : _date(value);
    final lastSuccess = date(j['lastSuccessfulCheckUtc']);
    return ResultVersion(
      selection: selection,
      state: PublicationState.values.byName(j['state'] as String),
      documentVersion: j['documentVersion'] as String,
      freshness: sourceFreshness(
        h['freshness'] as String?,
        lastSuccess,
        DateTime.now().toUtc(),
      ),
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
