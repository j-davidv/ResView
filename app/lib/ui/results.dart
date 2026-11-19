import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../storage/bookmark_library.dart';
import 'design.dart';
import 'shared.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.version,
    this.publications = const [],
    this.bookmarks,
    this.examId,
    this.examName,
    this.sittingLabel,
    this.loading = false,
    this.onRetry,
    super.key,
  });
  final ResultVersion? version;
  final VoidCallback? onRetry;
  final bool loading;
  final List<Publication> publications;
  final BookmarkLibrary? bookmarks;
  final String? examId, examName, sittingLabel;

  @override
  Widget build(BuildContext context) {
    final current = version;
    final released =
        publications.isNotEmpty ||
        (current != null && current.state != PublicationState.notReleased);
    final title = loading
        ? 'Loading official information'
        : current == null && !released
        ? 'Publication status unavailable'
        : released
        ? current?.state == PublicationState.superseded
              ? 'Updated publication'
              : 'Results released'
        : 'Not released';
    final message = loading
        ? 'Retrieving official announcements and result links.'
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
              : onRetry != null
              ? OutlinedButton(onPressed: onRetry, child: const Text('Retry'))
              : null,
        ),
        SourceLinks(
          current,
          publications: publications,
          bookmarks: bookmarks,
          examId: examId,
          examName: examName,
          sittingLabel: sittingLabel,
        ),
      ],
    );
  }
}
