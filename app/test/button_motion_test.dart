import 'package:app/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary button press feedback respects reduced motion', (
    tester,
  ) async {
    for (final reducedMotion in [false, true]) {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => presses++,
                child: const Text('Open official list'),
              ),
            ),
          ),
        ),
      );
      final button = find.byType(FilledButton);
      final originalSize = tester.getSize(button);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 200));
      final scale = tester.widget<AnimatedScale>(
        find.descendant(of: button, matching: find.byType(AnimatedScale)),
      );
      expect(scale.scale, reducedMotion ? 1 : 0.98);
      expect(tester.getSize(button), originalSize);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(presses, 1);
    }
  });
}
