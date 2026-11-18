import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import 'design.dart';
import 'source_viewer.dart';

const privacyDisclosure = '''ResView saves your selected exam on this device so you can return to its official announcements and result lists.

Opening an official source connects to PRC or Google Drive and requires internet access. Google Drive handles searches made in its document viewer. ResView does not save that search text.

If you enable push alerts, Firebase processes an anonymous account identifier, your exam preferences, and a device notification token.

If you subscribe to emails, Brevo stores your email address and selected exam preferences to confirm your subscription and send updates. You can unsubscribe from an email.

Delete local data in Settings to remove your exam selection and any files from earlier app versions. Email subscriptions and server push preferences have separate controls.''';

String publicationLabel(PublicationState state) => switch (state) {
  PublicationState.notReleased => 'Not released',
  PublicationState.superseded => 'Updated publication',
  _ => 'Results released',
};

class Heading extends StatelessWidget {
  const Heading(this.text, {this.top = 24, super.key});
  final String text;
  final double top;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.title,
    this.message, {
    this.action,
    this.warning = false,
    this.glyph,
    this.highlighted = false,
    this.centered = false,
    this.announce = true,
    super.key,
  });
  final String title, message;
  final Widget? action;
  final DesignGlyph? glyph;
  final bool warning, highlighted, centered, announce;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = DesignIconWell(
      glyph ?? (warning ? DesignGlyph.warning : DesignGlyph.info),
      color: warning ? colors.tertiary : null,
      background: warning ? colors.tertiaryContainer : null,
      size: centered ? 64 : 44,
      glyphSize: centered ? 32 : 24,
    );
    final copy = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: warning ? colors.tertiary : colors.onSurfaceVariant,
          ),
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
    return Semantics(
      liveRegion: announce,
      child: DesignCard(
        color: warning
            ? colors.tertiaryContainer
            : highlighted
            ? colors.primaryContainer
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (centered) ...[
              Center(child: icon),
              const SizedBox(height: 12),
              copy,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: copy),
                ],
              ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class Metadata extends StatelessWidget {
  const Metadata(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class FreshnessSection extends StatelessWidget {
  const FreshnessSection(this.version, {super.key});
  final ResultVersion version;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Heading('Source freshness'),
      Notice(
        switch (version.freshness) {
          SourceFreshness.fresh => 'Fresh',
          SourceFreshness.stale => 'Stale',
          SourceFreshness.unknown => 'Unknown',
        },
        switch (version.freshness) {
          SourceFreshness.fresh =>
            'The latest recorded source check is current.',
          SourceFreshness.stale => 'Source information may be outdated',
          SourceFreshness.unknown =>
            version.lastSuccessfulCheckUtc == null
                ? 'No source-check time is available for this selection.'
                : 'The freshness of this source has not been confirmed.',
        },
        glyph: version.freshness == SourceFreshness.stale
            ? DesignGlyph.warning
            : DesignGlyph.freshness,
        warning: version.freshness == SourceFreshness.stale,
      ),
      if (version.lastSuccessfulCheckUtc != null) ...[
        const SizedBox(height: 8),
        Metadata(
          'Last successful source check: ${sourceTime(version.lastSuccessfulCheckUtc)}',
        ),
      ],
    ],
  );
}

class SourceLinks extends StatelessWidget {
  const SourceLinks(this.version, {this.publications = const [], super.key});
  final ResultVersion version;
  final List<Publication> publications;
  @override
  Widget build(BuildContext context) {
    Uri identity(Uri uri) {
      if (uri.host != 'prc.gov.ph' && uri.host != 'www.prc.gov.ph') return uri;
      return uri.replace(
        host: 'www.prc.gov.ph',
        path: uri.path.startsWith('/index.php/article/')
            ? uri.path.replaceFirst('/index.php', '')
            : uri.path,
      );
    }

    final publication = publications
        .where(
          (p) =>
              version.publicationUrl != null &&
              identity(p.url) == identity(version.publicationUrl!),
        )
        .firstOrNull;
    final links = <Uri, String>{...?publication?.documents};
    if (links.isEmpty && version.documentUrl != null) {
      links[version.documentUrl!] = 'successful-examinee list';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (links.isNotEmpty || version.publicationUrl != null)
          const Heading('Official sources'),
        OfficialSourceLinks(
          publicationUrl: version.publicationUrl,
          documents: links,
        ),
      ],
    );
  }
}

class OfficialSourceLinks extends StatelessWidget {
  const OfficialSourceLinks({
    required this.documents,
    this.publicationUrl,
    super.key,
  });
  final Map<Uri, String> documents;
  final Uri? publicationUrl;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, entry) in documents.entries.indexed)
        SourceButton(
          'Open ${entry.value}${entry.value == 'successful-examinee list' && documents.length > 1 ? ' ${index + 1}' : ''}',
          entry.key,
        ),
      if (publicationUrl != null)
        SourceButton('Open PRC publication', publicationUrl!),
    ],
  );
}

class SourceButton extends StatelessWidget {
  const SourceButton(this.label, this.uri, {super.key});
  final String label;
  final Uri uri;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      onPressed: () => openSource(context, uri),
      icon: const DesignIcon(DesignGlyph.externalLink),
      label: Text(label),
    ),
  );
}

Future<void> openSource(
  BuildContext context,
  Uri uri, {
  bool external = false,
}) async {
  final embedded = sourceViewerUrl(uri);
  if (!external &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      embedded != null) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SourceViewer(
          uri: embedded,
          openExternal: (value) => openSource(context, value, external: true),
        ),
      ),
    );
    return;
  }
  bool opened = false;
  try {
    publicUrl(uri.toString());
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Could not open this link'),
        content: SingleChildScrollView(child: SelectableText(uri.toString())),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(dialog),
            icon: const DesignIcon(DesignGlyph.close),
            label: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: uri.toString()));
              if (dialog.mounted) Navigator.pop(dialog);
            },
            icon: const DesignIcon(DesignGlyph.copyLink),
            label: const Text('Copy link'),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String explanation,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialog).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
void feedback(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
