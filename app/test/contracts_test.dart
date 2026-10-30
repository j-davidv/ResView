import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models.dart';

void main() {
  test('source freshness expires when the scheduled worker stops', () {
    final now = DateTime.utc(2026, 10, 15, 12);
    expect(
      sourceFreshness('fresh', now.subtract(const Duration(minutes: 30)), now),
      SourceFreshness.fresh,
    );
    expect(
      sourceFreshness('fresh', now.subtract(const Duration(hours: 2)), now),
      SourceFreshness.stale,
    );
    expect(sourceFreshness('fresh', null, now), SourceFreshness.unknown);
    expect(sourceFreshness('stale', now, now), SourceFreshness.stale);
    expect(
      sourceFreshness('fresh', now.add(const Duration(hours: 1)), now),
      SourceFreshness.unknown,
    );
  });
  const selection = ExamSelection('test', 'test-sitting', 'general');
  Map<String, dynamic> fixture() => {
    'formatVersion': 1,
    'selection': selection.toJson(),
    'publicationUrl': 'https://www.prc.gov.ph/test-only',
    'documentUrl': 'https://www.prc.gov.ph/test-only.pdf',
    'documentVersion': 'test-v1',
    'validatedAtUtc': '2026-10-14T00:00:00Z',
    'entryCount': 1,
    'originalSha256': 'a' * 64,
    'nameFormat': 'surnameCommaNamesV1',
    'componentsReliable': false,
    'entries': [
      {
        'sequence': 1,
        'publishedName': 'TEST ONLY, NAME',
        'sectionId': 'general',
        'physicalPage': 1,
      },
    ],
  };
  test(
    'wrong selection unsupported schema counts and physical pages are rejected',
    () {
      NamesDocument parse(Map<String, dynamic> data) => NamesDocument.fromJson(
        data,
        expectedSelection: selection,
        expectedVersion: 'test-v1',
      );
      expect(parse(fixture()).entries.length, 1);
      expect(
        () => parse({...fixture(), 'formatVersion': 2}),
        throwsFormatException,
      );
      expect(
        () => parse({
          ...fixture(),
          'selection': const ExamSelection(
            'wrong',
            'test-sitting',
            'general',
          ).toJson(),
        }),
        throwsFormatException,
      );
      expect(
        () => parse({...fixture(), 'entryCount': 2}),
        throwsFormatException,
      );
      expect(
        () => parse({...fixture(), 'documentVersion': 'test-v2'}),
        throwsFormatException,
      );
      final bad = fixture();
      (bad['entries'] as List)[0]['physicalPage'] = 0;
      expect(() => parse(bad), throwsFormatException);
    },
  );
}
