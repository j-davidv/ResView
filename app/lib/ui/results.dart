import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'design.dart';
import 'shared.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.version,
    required this.onCheck,
    this.publications = const [],
    this.loading = false,
    this.onChooseExam,
    this.onRetry,
    super.key,
  });
  final ResultVersion? version;
  final VoidCallback onCheck;
  final VoidCallback? onChooseExam, onRetry;
  final bool loading;
  final List<Publication> publications;
  @override
  Widget build(BuildContext context) {
    final v = version;
    if (v == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Heading('Publication status', top: 0),
          Notice(
            loading
                ? 'Loading official information'
                : onChooseExam != null
                ? 'Status unavailable'
                : publications.isEmpty
                ? 'Publication status unavailable'
                : 'Checking status unavailable',
            loading
                ? 'Retrieving available publications and validation metadata.'
                : onChooseExam != null
                ? 'Choose an exam and sitting to view its publication status.'
                : publications.isEmpty
                ? 'A successful source check is needed to establish whether results have been released.'
                : 'An official announcement is available. Checking status could not be retrieved; you can open the source below.',
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
          const SizedBox(height: 16),
          const Divider(height: 1),
          const Heading('Source freshness'),
          const Notice(
            'Unknown',
            'No source-check time is available for this selection.',
            glyph: DesignGlyph.freshness,
            announce: false,
          ),
          if (publications.firstOrNull case final publication?) ...[
            const Heading('Official sources'),
            OfficialSourceLinks(
              publicationUrl: publication.url,
              documents: publication.documents,
            ),
          ],
          const SizedBox(height: 12),
          const Notice(
            'A published result and a name match are different.',
            'A matching name does not confirm your identity.',
            highlighted: true,
            announce: false,
          ),
        ],
      );
    }
    final explanation = switch (v.state) {
      PublicationState.notReleased => 'No official release has been found for this sitting. This is not a personal exam outcome.',
      PublicationState.validationPending => 'PRC has published a release. Automatic checking awaits document validation.',
      PublicationState.checkingAvailable => 'This list version passed validation. Name checking takes place on your device.',
      PublicationState.checkingUnavailable =>
        'Automatic name checking unavailable.',
      PublicationState.superseded => 'This version is outdated. Select the latest publication before checking.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading('Publication status', top: 0),
        Notice(
          publicationLabel(v.state),
          explanation,
          glyph: v.state == PublicationState.validationPending
              ? DesignGlyph.freshness
              : null,
          warning: v.state == PublicationState.superseded,
          action: v.state == PublicationState.checkingAvailable
              ? FilledButton(
                  onPressed: onCheck,
                  child: const Text('Check name'),
                )
              : null,
        ),
        if (v.reason != null) Text(v.reason!),
        FreshnessSection(v),
        SourceLinks(v, publications: publications),
      ],
    );
  }
}
