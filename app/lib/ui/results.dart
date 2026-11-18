import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'design.dart';
import 'shared.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.version,
    this.publications = const [],
    this.loading = false,
    this.onChooseExam,
    this.onRetry,
    super.key,
  });
  final ResultVersion? version;
  final VoidCallback? onChooseExam, onRetry;
  final bool loading;
  final List<Publication> publications;

  @override
  Widget build(BuildContext context) {
    final current = version;
    final released =
        publications.isNotEmpty ||
        (current != null && current.state != PublicationState.notReleased);
    final title = loading
        ? 'Loading official information'
        : onChooseExam != null || (current == null && !released)
        ? 'Publication status unavailable'
        : released
        ? current?.state == PublicationState.superseded
              ? 'Updated publication'
              : 'Results released'
        : 'Not released';
    final message = loading
        ? 'Retrieving official announcements and result links.'
        : onChooseExam != null
        ? 'Choose an exam and sitting to view its results.'
        : released
        ? 'Open the official PRC publication or successful-examinee list below.'
        : current == null
        ? 'The publication status could not be confirmed. Try refreshing.'
        : 'No official result release has been found for this sitting.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Heading('Publication status', top: 0),
        Notice(
          title,
          message,
          glyph: released ? DesignGlyph.results : DesignGlyph.info,
          action: loading
              ? const LinearProgressIndicator(
                  semanticsLabel: 'Loading official information',
                )
              : onChooseExam != null
              ? FilledButton(
                  onPressed: onChooseExam,
                  child: const Text('Choose exam'),
                )
              : onRetry != null
              ? OutlinedButton(onPressed: onRetry, child: const Text('Retry'))
              : null,
        ),
        if (current != null)
          SourceLinks(current, publications: publications)
        else if (publications.firstOrNull case final publication?) ...[
          const Heading('Official sources'),
          OfficialSourceLinks(
            publicationUrl: publication.url,
            documents: publication.documents,
          ),
        ],
      ],
    );
  }
}
