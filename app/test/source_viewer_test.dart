import 'package:app/ui/source_viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:app/main.dart';

void main() {
  testWidgets(
    'PRC notice floats above the viewer and closes after three seconds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: SourceViewer(
            uri: Uri.parse('https://www.prc.gov.ph/article/test'),
            openExternal: (_) async {},
          ),
        ),
      );
      final notice = find.textContaining('You are viewing PRC online');
      final content = find.textContaining('In-app viewing is available');
      final contentPosition = tester.getTopLeft(content);
      expect(notice, findsOneWidget);
      expect(find.byTooltip('Close notice'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      expect(
        contentPosition.dy,
        tester.getBottomLeft(find.byType(AppBar)).dy + 16,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(.5, .01),
      );
      await tester.pump(const Duration(milliseconds: 1499));
      expect(notice, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(notice, findsNothing);
      expect(find.text('www.prc.gov.ph'), findsNothing);
      expect(tester.getTopLeft(content), contentPosition);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('PRC notice can be closed manually before the timeout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: SourceViewer(
          uri: Uri.parse('https://www.prc.gov.ph/article/test'),
          openExternal: (_) async {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Close notice'));
    await tester.pump();
    expect(find.textContaining('You are viewing PRC online'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byTooltip('Close notice'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'unsupported platform keeps an accessible browser recovery at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SourceViewer(
            uri: Uri.parse('https://www.prc.gov.ph/article/test'),
            openExternal: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('In-app viewing is available on Android'),
        findsOneWidget,
      );
      expect(find.byTooltip('Open in browser'), findsOneWidget);
      expect(find.byTooltip('Close notice').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  test('only official HTTPS sources enter the embedded viewer', () {
    expect(
      sourceViewerUrl(Uri.parse('https://www.prc.gov.ph/article/test')),
      Uri.parse('https://www.prc.gov.ph/article/test'),
    );
    expect(
      sourceViewerUrl(
        Uri.parse(
          'https://drive.google.com/file/d/1234567890/view?usp=sharing',
        ),
      ),
      Uri.parse('https://drive.google.com/file/d/1234567890/preview?hl=en'),
    );
    for (final value in [
      'http://www.prc.gov.ph/article/test',
      'https://www.prc.gov.ph.attacker.test/article/test',
      'https://user@www.prc.gov.ph/article/test',
      'https://www.prc.gov.ph:8443/article/test',
      'https://drive.google.com/drive/my-drive',
      'https://drive.google.com/file/d/1234567890/edit',
      'https://example.org/privacy',
      'javascript:alert(1)',
    ]) {
      expect(sourceViewerUrl(Uri.parse(value)), isNull, reason: value);
    }
  });
}
