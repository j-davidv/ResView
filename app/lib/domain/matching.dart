import 'models.dart';

String normalizeName(String value, {required String Function(String) nfc}) =>
    nfc(value)
        .toUpperCase()
        .replaceAll(RegExp(r'\s+', unicode: true), ' ')
        .trim();
String renderQuery(NameInput input, String nameFormat) {
  if (nameFormat != 'surnameCommaNamesV1') {
    throw const FormatException('Unsupported name ordering.');
  }
  return '${input.surname}, ${[input.givenNames, input.middleName, input.suffix].where((s) => s.trim().isNotEmpty).join(' ')}';
}

List<NameEntry> findExact(NamesDocument document, String publishedQuery) =>
    document.entries.where((e) => e.publishedName == publishedQuery).toList();
List<NameEntry> findPossible(NamesDocument document, NameInput input) {
  if (!document.componentsReliable) return [];
  return document.entries
      .where(
        (e) =>
            e.components != null &&
            e.components!.surname == input.surname &&
            e.components!.givenNames == input.givenNames &&
            (e.components!.middleName != input.middleName ||
                e.components!.suffix != input.suffix),
      )
      .toList();
}
