import 'package:app/data/firestore_repository.dart';
import 'package:app/data/firestore_rest.dart';
import 'package:app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rest extends FirestoreRest {
  _Rest() : super('test-only');
  Map<String, dynamic> sitting = {
    'examId': 'teachers',
    'start': '2026-09-20T00:00:00+00:00',
    'end': '2026-09-20T00:00:00+00:00',
    'type': 'oral',
    'location': 'Davao',
    'categories': {'all': 'All'},
    'targetReleaseDate': '2026-11-27T00:00:00+00:00',
    'catalogUrl': 'https://www.prc.gov.ph/2026-schedule-examination',
  };
  Map<String, dynamic>? health = {
    'freshness': 'stale',
    'lastSuccessfulCheckUtc': '2026-11-23T16:33:00+00:00',
    'lastAttemptUtc': '2026-11-24T01:00:00+00:00',
  };
  List<FirestoreRecord> versions = [];
  bool monitorFails = false;
  @override
  Future<List<FirestoreRecord>> query(
    String collection, {
    required int limit,
    required Map<String, Object> equals,
    required String? orderBy,
    required bool descending,
  }) async {
    return collection == 'sittings'
        ? [(id: 'sitting', fields: sitting)]
        : versions;
  }

  @override
  Future<Map<String, dynamic>?> getDocument(String path) async {
    expect(path, 'monitor/status');
    if (monitorFails) throw StateError('offline');
    return health;
  }
}

void main() {
  test('wrong optional target types do not hide valid sittings', () async {
    final rest = _Rest();
    final repository = FirestoreExamRepository.public('test-only', rest: rest);
    for (final value in [42, <String>[], <String, String>{}]) {
      rest.sitting['targetReleaseDate'] = value;
      final sitting = (await repository.loadSittings('teachers')).single;
      expect(sitting.targetReleaseDate, isNull);
    }
  });
  test(
    'calendar overflow targets cannot silently become a different release day',
    () async {
      final rest = _Rest();
      rest.sitting['targetReleaseDate'] = '2026-11-31T00:00:00+00:00';
      final repository = FirestoreExamRepository.public(
        'test-only',
        rest: rest,
      );
      expect(
        (await repository.loadSittings('teachers')).single.targetReleaseDate,
        isNull,
      );
    },
  );
  test(
    'verified version remains readable when the independent monitor fails',
    () async {
      final rest = _Rest()..monitorFails = true;
      rest.versions = [
        (
          id: 'release',
          fields: {
            'state': 'checkingUnavailable',
            'documentVersion': 'release-v1',
            'publicationUrl': 'https://www.prc.gov.ph/article/test-release',
            'lastSuccessfulCheckUtc': '2026-11-23T16:33:00+00:00',
          },
        ),
      ];
      final repository = FirestoreExamRepository.public(
        'test-only',
        rest: rest,
      );
      final version = (await repository.loadResultVersion(
        const ExamSelection('teachers', 'sitting', 'all'),
      ))!;
      expect(version.state, PublicationState.checkingUnavailable);
      expect(
        version.publicationUrl.toString(),
        'https://www.prc.gov.ph/article/test-release',
      );
    },
  );
  test(
    'oral sittings decode optional target and schedule provenance',
    () async {
      final rest = _Rest();
      final repository = FirestoreExamRepository.public(
        'test-only',
        rest: rest,
      );
      final sitting = (await repository.loadSittings('teachers')).single;
      expect(sitting.type, 'oral');
      expect(sitting.targetReleaseDate, DateTime.utc(2026, 11, 27));
      expect(
        sitting.catalogUrl.toString(),
        'https://www.prc.gov.ph/2026-schedule-examination',
      );
      rest.sitting.remove('targetReleaseDate');
      rest.sitting.remove('catalogUrl');
      expect(
        (await repository.loadSittings('teachers')).single.targetReleaseDate,
        isNull,
      );
    },
  );
  test('invalid optional targets preserve the valid sitting', () async {
    final rest = _Rest();
    final repository = FirestoreExamRepository.public('test-only', rest: rest);
    for (final target in ['TBA', '2026-09-19T00:00:00+00:00']) {
      rest.sitting['targetReleaseDate'] = target;
      expect(
        (await repository.loadSittings('teachers')).single.targetReleaseDate,
        isNull,
      );
    }
  });
  test(
    'empty versions still allow the actual monitor successful check to load',
    () async {
      final rest = _Rest();
      final repository = FirestoreExamRepository.public(
        'test-only',
        rest: rest,
      );
      expect(
        await repository.loadResultVersion(
          const ExamSelection('teachers', 'sitting', 'all'),
        ),
        isNull,
      );
      final monitor = (await repository.loadResultMonitorStatus())!;
      expect(
        monitor.lastSuccessfulCheckUtc,
        DateTime.utc(2026, 11, 23, 16, 33),
      );
      expect(monitor.freshness, 'stale');
      rest.health = null;
      expect(await repository.loadResultMonitorStatus(), isNull);
    },
  );
}
