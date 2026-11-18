import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'design.dart';
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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (publications.isEmpty)
        const Notice(
          'No announcements found for this selection',
          'Try another sitting or refresh the available announcements.',
        ),
      for (final p in publications) ...[
        const SizedBox(height: 16),
        DesignCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DesignIcon(DesignGlyph.updates),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Metadata('${p.type}\nPublished: ${sourceTime(p.publishedAtUtc)}'),
              const SizedBox(height: 12),
              OfficialSourceLinks(
                publicationUrl: p.url,
                documents: p.documents,
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
