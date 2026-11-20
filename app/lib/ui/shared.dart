import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/bookmark.dart';
import '../domain/history.dart';
import '../domain/models.dart';
import '../storage/bookmark_library.dart';
import '../storage/history_library.dart';
import 'design.dart';
import 'source_viewer.dart';

final Map<BookmarkLibrary, Set<String>> _pendingBookmarks = {};
final ValueNotifier<int> _bookmarkPendingRevision = ValueNotifier(0);

void _notifyBookmarkPendingChanged() => _bookmarkPendingRevision.value++;

Future<void> _recordOpenedSource(
  HistoryLibrary library,
  HistoryEntry entry,
) async {
  try {
    await library.record(entry);
  } catch (_) {
    // HistoryLibrary exposes persistence failures through its error state.
  }
}

const privacyDisclosure = '''ResView saves your selected exam, bookmarks, and viewing history on this device so you can return to official announcements and result lists.

Opening an official source connects to PRC or Google Drive and requires internet access. Google Drive handles searches made in its document viewer. ResView does not save that search text.

If you enable push alerts, Firebase processes an anonymous account identifier, your exam preferences, and a device notification token.

If you subscribe to emails, Brevo stores your email address and selected exam preferences to confirm your subscription and send updates. You can unsubscribe from an email.

Delete local data in Settings to remove your exam selection, bookmarks, viewing history, and any files from earlier app versions. Email subscriptions and server push preferences have separate controls.''';

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
  const SourceLinks(
    this.version, {
    this.publications = const [],
    this.bookmarks,
    this.historyLibrary,
    this.examId,
    this.examName,
    this.sittingLabel,
    super.key,
  });
  final ResultVersion? version;
  final List<Publication> publications;
  final BookmarkLibrary? bookmarks;
  final HistoryLibrary? historyLibrary;
  final String? examId, examName, sittingLabel;

  @override
  Widget build(BuildContext context) {
    final grouped = <Uri, List<Publication>>{};
    for (final article in publications) {
      (grouped[_articleIdentity(article.url)] ??= []).add(article);
    }
    final url = version?.publicationUrl;
    final featured = grouped.remove(
      url == null ? grouped.keys.firstOrNull : _articleIdentity(url),
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
            version: version,
            url: url,
            fallback: url != null ? document : null,
          ),
        ],
        if (separateList) ...[
          Heading(
            featured == null ? 'Official sources' : 'Additional official list',
          ),
          if (bookmarks != null && examId != null && examName != null)
            Align(
              alignment: Alignment.centerRight,
              child: BookmarkToggleButton(
                library: bookmarks!,
                item: _bookmarkItem(
                  document,
                  version: version,
                  fallbackTitle: 'Official successful-examinee list',
                )!,
              ),
            ),
          OfficialSourceLinks(
            documents: {document: 'successful-examinee list'},
            historyLibrary: historyLibrary,
            documentsHistoryEntry: _historyItem(
              document,
              version: version,
              fallbackTitle: 'Official successful-examinee list',
            ),
          ),
        ],
        if (grouped.isNotEmpty) ...[
          const Heading('Other result publications'),
          for (final article in grouped.values)
            _article(context, article, version: version),
        ],
      ],
    );
  }

  BookmarkItem? _bookmarkItem(
    Uri uri, {
    Publication? article,
    ResultVersion? version,
    String? fallbackTitle,
  }) {
    final id = article == null && version != null
        ? '${version.selection.examId}:${version.selection.sittingId}:${version.selection.categoryId}:${version.documentVersion}'
        : _articleIdentity(uri).toString();
    if (bookmarks == null || examId == null || examName == null) return null;
    return BookmarkItem(
      id: id,
      kind: BookmarkKind.result,
      examId: examId!,
      examName: examName!,
      title: article?.title.trim().isNotEmpty == true
          ? article!.title
          : fallbackTitle ?? 'Official result publication',
      url: uri,
      publishedAtUtc: article?.publishedAtUtc,
      savedAtUtc: DateTime.now().toUtc(),
      sittingLabel: sittingLabel,
    );
  }

  HistoryEntry? _historyItem(
    Uri uri, {
    Publication? article,
    ResultVersion? version,
    String? fallbackTitle,
  }) {
    if (historyLibrary == null || examId == null || examName == null) {
      return null;
    }
    final sourceId = article?.id ??
        (version == null
            ? uri.toString()
            : '${version.selection.examId}:${version.selection.sittingId}:${version.selection.categoryId}:${version.documentVersion}');
    return HistoryEntry(
      sourceId: sourceId,
      kind: HistoryKind.result,
      examId: examId!,
      examName: examName!,
      title: article?.title.trim().isNotEmpty == true
          ? article!.title
          : fallbackTitle ?? 'Official result publication',
      url: uri,
      publishedAtUtc: article?.publishedAtUtc,
      viewedAtUtc: DateTime.now().toUtc(),
      sittingLabel: sittingLabel,
    );
  }

  Widget _article(
    BuildContext context,
    List<Publication> records, {
    ResultVersion? version,
    Uri? url,
    Uri? fallback,
  }) {
    final article = records.firstOrNull;
    final bookmarkUrl = article?.url ?? url ?? fallback;
    final bookmark = bookmarkUrl == null
        ? null
        : _bookmarkItem(
            bookmarkUrl,
            article: article,
            version: version,
            fallbackTitle: 'Official result publication',
          );
    final documents = <Uri, String>{};
    for (final record in records) {
      for (final link in record.documents.entries) {
        documents.putIfAbsent(link.key, () => link.value);
      }
    }
    final effectiveDocs = documents.isEmpty && fallback != null
        ? {fallback: 'successful-examinee list'}
        : documents;
    final effectiveUrl = bookmarkUrl ?? url ?? article?.url;
    final articleHistoryEntry = effectiveUrl == null
        ? null
        : _historyItem(
            effectiveUrl,
            article: article,
            version: version,
            fallbackTitle: 'Official result publication',
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DesignCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (bookmark != null)
                    BookmarkToggleButton(
                      library: bookmarks!,
                      item: bookmark,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Metadata('Published: ${sourceTime(article.publishedAtUtc)}'),
              const SizedBox(height: 8),
            ] else if (bookmark != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Official result publication',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  BookmarkToggleButton(
                    library: bookmarks!,
                    item: bookmark,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            OfficialSourceLinks(
              publicationUrl: url ?? article?.url,
              documents: effectiveDocs,
              historyLibrary: historyLibrary,
              publicationHistoryEntry: url != null || article != null
                  ? _historyItem(
                      url ?? article!.url,
                      article: article,
                      version: version,
                      fallbackTitle: 'Official result publication',
                    )
                  : null,
              documentsHistoryEntry: articleHistoryEntry,
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
    this.historyLibrary,
    this.publicationHistoryEntry,
    this.documentsHistoryEntry,
    super.key,
  });
  final Map<Uri, String> documents;
  final Uri? publicationUrl;
  final HistoryLibrary? historyLibrary;
  // History entry for the PRC publication announcement link.
  final HistoryEntry? publicationHistoryEntry;
  // History entry shared for document links (passers list / result docs).
  final HistoryEntry? documentsHistoryEntry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, entry) in documents.entries.indexed)
        SourceButton(
          '${entry.value == 'successful-examinee list' ? 'View list of passers' : 'Open ${entry.value}'}${entry.value == 'successful-examinee list' && documents.length > 1 ? ' ${index + 1}' : ''}',
          entry.key,
          filled: true,
          historyLibrary: historyLibrary,
          historyEntry: documentsHistoryEntry?.withUrl(entry.key),
        ),
      if (publicationUrl != null)
        SourceButton(
          'PRC announcement',
          publicationUrl!,
          historyLibrary: historyLibrary,
          historyEntry: publicationHistoryEntry,
        ),
    ],
  );
}

class SourceButton extends StatelessWidget {
  const SourceButton(
    this.label,
    this.uri, {
    this.filled = false,
    this.historyLibrary,
    this.historyEntry,
    super.key,
  });
  final String label;
  final Uri uri;
  final bool filled;
  final HistoryLibrary? historyLibrary;
  final HistoryEntry? historyEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final outlinedStyle = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.onSurfaceVariant
            : colors.primary,
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: colors.primary, width: 2);
        }
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: colors.outlineVariant);
        }
        return BorderSide(color: colors.primary.withValues(alpha: 0.4));
      }),
    );
    final content = Row(
      children: [
        DesignIcon(
          filled ? DesignGlyph.listChecks : DesignGlyph.document,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        const DesignIcon(DesignGlyph.externalLink, size: 20),
      ],
    );
    void open() {
      openSource(
        context,
        uri,
        onOpened: historyLibrary != null && historyEntry != null
            ? () => unawaited(
                _recordOpenedSource(historyLibrary!, historyEntry!),
              )
            : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: filled
          ? FilledButton(onPressed: open, child: content)
          : OutlinedButton(
              onPressed: open,
              style: outlinedStyle.copyWith(
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

class BookmarkToggleButton extends StatelessWidget {
  const BookmarkToggleButton({
    required this.library,
    required this.item,
    super.key,
  });

  final BookmarkLibrary library;
  final BookmarkItem item;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([library, _bookmarkPendingRevision]),
    builder: (context, _) {
      final saved = library.contains(item);
      final pending = _pendingBookmarks[library]?.contains(item.key) ?? false;
      final type = item.kind == BookmarkKind.announcement
          ? 'announcement'
          : 'result publication';
      return IconButton(
        tooltip: saved
            ? 'Remove $type from bookmarks'
            : 'Bookmark $type',
        onPressed: library.loaded && !pending
            ? () async {
                final pendingItems = _pendingBookmarks.putIfAbsent(
                  library,
                  () => <String>{},
                );
                if (!library.loaded || !pendingItems.add(item.key)) return;
                _notifyBookmarkPendingChanged();
                try {
                  final appliedSaved = await library.toggle(item);
                  if (context.mounted) {
                    feedback(
                      context,
                      appliedSaved ? 'Saved to bookmarks.' : 'Bookmark removed.',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    feedback(
                      context,
                      'Bookmark could not be updated. Try again.',
                    );
                  }
                } finally {
                  pendingItems.remove(item.key);
                  if (pendingItems.isEmpty) _pendingBookmarks.remove(library);
                  _notifyBookmarkPendingChanged();
                }
              }
            : null,
        icon: DesignIcon(
          saved ? DesignGlyph.bookmarked : DesignGlyph.bookmark,
          color: saved ? Theme.of(context).colorScheme.primary : null,
        ),
      );
    },
  );
}

Future<void> openSource(
  BuildContext context,
  Uri uri, {
  bool external = false,
  VoidCallback? onOpened,
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
          openExternal: (value) => openSource(
            context,
            value,
            external: true,
            onOpened: onOpened,
          ),
          onSourceLoaded: onOpened,
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
  if (opened) onOpened?.call();
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
