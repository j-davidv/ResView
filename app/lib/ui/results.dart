import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'shared.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.version,
    required this.onCheck,
    this.publications = const [],
    super.key,
  });
  final ResultVersion? version;
  final VoidCallback onCheck;
  final List<Publication> publications;
  @override
  Widget build(BuildContext context) {
    final v = version;
    if (v == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Notice(
            publications.isEmpty
                ? 'Publication status unavailable'
                : 'Checking status unavailable',
            publications.isEmpty
                ? 'A successful source check is needed to establish whether results have been released.'
                : 'An official announcement is available. Checking status could not be retrieved; you can open the source below.',
          ),
          for (final publication in publications.take(1))
            OfficialSourceLinks(
              publicationUrl: publication.url,
              documents: publication.documents,
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
        const Heading('Publication status'),
        Notice(
          publicationLabel(v.state),
          explanation,
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
