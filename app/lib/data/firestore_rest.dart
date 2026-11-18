import 'dart:convert';
import 'dart:io';

typedef FirestoreRecord = ({String id, Map<String, dynamic> fields});

class FirestoreRest {
  FirestoreRest(String projectId)
    : _documents = '/v1/projects/$projectId/databases/(default)/documents';

  static const _timeout = Duration(seconds: 15);
  final String _documents;

  Future<List<FirestoreRecord>> query(
    String collection, {
    required int limit,
    required Map<String, Object> equals,
    required String? orderBy,
    required bool descending,
  }) async {
    final filters = [
      for (final entry in equals.entries)
        {
          'fieldFilter': {
            'field': {'fieldPath': entry.key},
            'op': 'EQUAL',
            'value': {
              if (entry.value is bool)
                'booleanValue': entry.value
              else
                'stringValue': entry.value,
            },
          },
        },
    ];
    final rows = await _read(
      '$_documents:runQuery',
      structuredQuery: {
        'from': [
          {'collectionId': collection},
        ],
        if (filters.isNotEmpty)
          'where': filters.length == 1
              ? filters.single
              : {
                  'compositeFilter': {'op': 'AND', 'filters': filters},
                },
        if (orderBy != null)
          'orderBy': [
            {
              'field': {'fieldPath': orderBy},
              'direction': descending ? 'DESCENDING' : 'ASCENDING',
            },
          ],
        'limit': limit,
      },
    );
    return [
      for (final row in rows as List<dynamic>)
        if (row case {'document': final Map<String, dynamic> document})
          (
            id: (document['name'] as String).split('/').last,
            fields: _fields(document),
          ),
    ];
  }

  Future<Map<String, dynamic>?> getDocument(String path) async {
    final document = await _read('$_documents/$path');
    return document == null ? null : _fields(document as Map<String, dynamic>);
  }

  Future<Object?> _read(
    String path, {
    Map<String, Object>? structuredQuery,
  }) async {
    final uri = Uri.https('firestore.googleapis.com', path);
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client
          .openUrl(structuredQuery == null ? 'GET' : 'POST', uri)
          .timeout(_timeout);
      request.followRedirects = false;
      if (structuredQuery != null) {
        request.headers.contentType = ContentType.json;
        request.add(
          utf8.encode(jsonEncode({'structuredQuery': structuredQuery})),
        );
      }
      final response = await request.close().timeout(_timeout);
      if (response.statusCode == HttpStatus.notFound &&
          structuredQuery == null) {
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Firestore returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      return jsonDecode(
        await utf8.decoder.bind(response).join().timeout(_timeout),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, dynamic> _fields(Map<String, dynamic> document) =>
      (document['fields'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, _value(value as Map<String, dynamic>)),
      );

  static Object? _value(Map<String, dynamic> value) =>
      switch (value.entries.single) {
        MapEntry(key: 'nullValue') => null,
        MapEntry(key: 'integerValue', value: final String number) => int.parse(
          number,
        ),
        MapEntry(key: 'mapValue', value: final Map<String, dynamic> map) =>
          _fields(map),
        MapEntry(key: 'arrayValue', value: final Map<String, dynamic> array) =>
          [
            for (final item in array['values'] as List<dynamic>? ?? [])
              _value(item as Map<String, dynamic>),
          ],
        MapEntry(value: final data) => data,
      };
}
