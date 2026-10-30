import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/matching.dart';

void main() {
  String nfc(String s) =>
      s.replaceAll('N\u0303', 'Ñ').replaceAll('n\u0303', 'ñ');
  test(
    'exact normalization preserves accents punctuation and complete names',
    () {
      expect(normalizeName('  Peña, Ana  Marie ', nfc: nfc), 'PEÑA, ANA MARIE');
      expect(normalizeName('PEN\u0303A', nfc: nfc), 'PEÑA');
      expect(normalizeName('PENA', nfc: nfc), isNot('PEÑA'));
      expect(normalizeName('ANA-MARIE', nfc: nfc), isNot('ANA MARIE'));
    },
  );
  test('duplicates remain separate and unreliable components cannot produce candidates', () {
    final entries = [
      const NameEntry(
        sequence: 1,
        publishedName: 'PEÑA, ANA',
        sectionId: 'test',
        physicalPage: 1,
      ),
      const NameEntry(
        sequence: 2,
        publishedName: 'PEÑA, ANA',
        sectionId: 'test',
        physicalPage: 2,
      ),
    ];
    final doc = NamesDocument(
      selection: const ExamSelection('test', 'test', 'general'),
      documentVersion: 'test-v1',
      entries: entries,
    );
    expect(findExact(doc, 'PEÑA, ANA').length, 2);
    expect(findExact(doc, 'PENA, ANA'), isEmpty);
    expect(findPossible(doc, const NameInput('PEÑA', 'ANA', '', '')), isEmpty);
  });
  test('candidate requires complete surname and given names', () {
    final doc = NamesDocument(
      selection: const ExamSelection('test', 'test', 'general'),
      documentVersion: 'test-v1',
      componentsReliable: true,
      entries: [
        const NameEntry(
          sequence: 1,
          publishedName: 'DELA CRUZ, ANA MARIE SANTOS',
          sectionId: 'test',
          physicalPage: 1,
          components: NameInput('DELA CRUZ', 'ANA MARIE', 'SANTOS', ''),
        ),
      ],
    );
    expect(
      findPossible(
        doc,
        const NameInput('DELA CRUZ', 'ANA MARIE', '', ''),
      ).length,
      1,
    );
    expect(
      findPossible(doc, const NameInput('CRUZ', 'ANA MARIE', '', '')),
      isEmpty,
    );
    expect(
      findPossible(doc, const NameInput('DELA CRUZ', 'ANA', '', '')),
      isEmpty,
    );
  });
}
