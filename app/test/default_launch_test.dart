import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flows_test.dart' show TestListStore;

void main() {
  testWidgets('normal startup enables Updates and keeps Results selected', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'introSeen': 'true'});

    await tester.pumpWidget(app.ExamApp(listStore: TestListStore()));
    await tester.pumpAndSettle();

    expect(find.text('Updates'), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );

    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
