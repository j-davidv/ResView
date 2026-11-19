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

Uri _articleIdentity(Uri uri) {
  if (uri.host != 'prc.gov.ph' && uri.host != 'www.prc.gov.ph') return uri;
  return uri.replace(
    host: 'www.prc.gov.ph',
    path: uri.path.startsWith('/index.php/article/')
        ? uri.path.replaceFirst('/index.php', '')
        : uri.path,
  );
}

class SourceLinks extends StatelessWidget {
  const SourceLinks(this.version, {this.publications = const [], super.key});
  final ResultVersion? version;
  final List<Publication> publications;

  @override
  Widget build(BuildContext context) {
    final history = <Uri, List<Publication>>{};
    for (final article in publications) {
      (history[_articleIdentity(article.url)] ??= []).add(article);
    }
    final url = version?.publicationUrl;
    final featured = history.remove(
      url == null ? history.keys.firstOrNull : _articleIdentity(url),
    );
    final document = version?.documentUrl;
    final separateList =
        url == null &&
        document != null &&
        !publications.any((article) => article.documents.containsKey(document));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (featured != null || url != null) ...[
          const Heading('Official sources'),
          _article(
            context,
            featured ?? const [],
            url: url,
            fallback: url != null ? document : null,
          ),
        ],
        if (separateList) ...[
          Heading(
            featured == null ? 'Official sources' : 'Additional official list',
          ),
          OfficialSourceLinks(
            documents: {document: 'successful-examinee list'},
          ),
        ],
        if (history.isNotEmpty) ...[
          const Heading('Other result publications'),
          for (final article in history.values) _article(context, article),
        ],
      ],
    );
  }

  Widget _article(
    BuildContext context,
    List<Publication> records, {
    Uri? url,
    Uri? fallback,
  }) {
    final article = records.firstOrNull;
    final documents = <Uri, String>{};
    for (final record in records) {
      for (final link in record.documents.entries) {
        documents.putIfAbsent(link.key, () => link.value);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DesignCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article != null) ...[
              Text(
                article.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Metadata('Published: ${sourceTime(article.publishedAtUtc)}'),
              const SizedBox(height: 8),
            ],
            OfficialSourceLinks(
              publicationUrl: url ?? article?.url,
              documents: documents.isEmpty && fallback != null
                  ? {fallback: 'successful-examinee list'}
                  : documents,
            ),
          ],
        ),
      ),
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
          '${entry.value == 'successful-examinee list' ? 'View list of passers' : 'Open ${entry.value}'}${entry.value == 'successful-examinee list' && documents.length > 1 ? ' ${index + 1}' : ''}',
          entry.key,
          filled: true,
        ),
      if (publicationUrl != null)
        SourceButton('PRC announcement', publicationUrl!),
    ],
  );
}

class SourceButton extends StatelessWidget {
  const SourceButton(this.label, this.uri, {this.filled = false, super.key});
  final String label;
  final Uri uri;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(13)),
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
    );
    final content = Row(
      children: [
        DesignIcon(
          filled ? DesignGlyph.listChecks : DesignGlyph.document,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        const DesignIcon(DesignGlyph.externalLink, size: 22),
      ],
    );
    void open() => openSource(context, uri);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: filled
          ? FilledButton(onPressed: open, style: style, child: content)
          : OutlinedButton(
              onPressed: open,
              style: style.copyWith(
                foregroundColor: WidgetStatePropertyAll(colors.primary),
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.focused)
                        ? colors.primary
                        : colors.primary.withValues(alpha: 0.4),
                    width: states.contains(WidgetState.focused) ? 2 : 1,
                  ),
                ),
              ),
              child: content,
            ),
    );
  }
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
