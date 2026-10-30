import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import 'source_viewer.dart';

const privacyDisclosure = '''Your name stays on this device and is used here to check a validated PRC list. We do not send your entered name or personal matching result to our servers. Public result lists may contain names already published by PRC.

Manual source viewing connects to PRC and Google Drive. Document search is handled by Google Drive; ResView does not save the search text or copy your saved name into it. This is separate from validated on-device checking.

If you enable push alerts, Firebase processes an anonymous account identifier, your exam preferences, and a device notification token. No password is required, but this does not mean no information leaves the device.

If you subscribe to emails, Brevo stores your email address and selected exam preferences to confirm your subscription and send updates. You can unsubscribe from an email. Uninstalling the app does not unsubscribe you from email updates.

Downloaded lists are temporary unless you choose to save them offline. You can delete your saved name and offline files in Settings. A matching published name does not confirm your identity, and an absent name does not mean you failed the exam.''';

String publicationLabel(PublicationState state) => switch (state) {
  PublicationState.notReleased => 'Not released',
  PublicationState.validationPending => 'Released; validation pending',
  PublicationState.checkingAvailable => 'Checking available',
  PublicationState.checkingUnavailable => 'Checking unavailable',
  PublicationState.superseded => 'Superseded',
};

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
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
    super.key,
  });
  final String title, message;
  final Widget? action;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: warning ? colors.tertiaryContainer : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
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
      if (version.freshness != SourceFreshness.fresh)
        Notice(
          version.freshness == SourceFreshness.stale
              ? 'Source information may be outdated'
              : 'Source freshness unknown',
          'Previously retrieved information is retained. Refreshing this app does not trigger a new PRC source check.',
          warning: true,
        ),
      Text(
        'Last successful source check: ${sourceTime(version.lastSuccessfulCheckUtc)}',
      ),
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
        const Heading('Official sources'),
        OfficialSourceLinks(
          publicationUrl: version.publicationUrl,
          documents: links,
        ),
        if (version.documentVersion.isNotEmpty)
          SelectableText('Document version: ${version.documentVersion}'),
        if (version.validatedAtUtc != null)
          Text('Validation time: ${sourceTime(version.validatedAtUtc)}'),
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
      icon: const Icon(Icons.open_in_new),
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
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: uri.toString()));
              if (dialog.mounted) Navigator.pop(dialog);
            },
            child: const Text('Copy link'),
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
