import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'shared.dart';

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({
    required this.publications,
    required this.version,
    super.key,
  });
  final List<Publication> publications;
  final ResultVersion? version;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (version != null) FreshnessSection(version!),
      if (publications.isEmpty)
        const Notice(
          'No announcements found for this selection',
          'Try another sitting or refresh the available announcements.',
        ),
      for (final p in publications) ...[
        const Divider(height: 24),
        Text(p.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '${p.type}\nPublished: ${sourceTime(p.publishedAtUtc)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OfficialSourceLinks(publicationUrl: p.url, documents: p.documents),
      ],
    ],
  );
}
