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
}
