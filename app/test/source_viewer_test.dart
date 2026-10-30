import 'package:app/ui/source_viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:app/main.dart';

void main() {
  testWidgets(
    'unsupported platform keeps an accessible browser recovery at large text',
    (tester) async {
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
      await tester.pumpAndSettle();
      expect(
        find.textContaining('In-app viewing is available on Android'),
        findsOneWidget,
      );
      expect(find.byTooltip('Open in browser'), findsOneWidget);
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
