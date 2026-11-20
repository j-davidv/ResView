import 'package:flutter/material.dart';

import '../domain/bookmark.dart';
import '../domain/history.dart';
import '../domain/models.dart';
import '../storage/bookmark_library.dart';
import '../storage/history_library.dart';
import 'design.dart';
import 'shared.dart';

enum _BookmarkFilter { all, announcements, results }

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({
    required this.library,
    this.historyLibrary,
    super.key,
  });

  final BookmarkLibrary library;
  final HistoryLibrary? historyLibrary;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  _BookmarkFilter _filter = _BookmarkFilter.all;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.library,
    builder: (context, _) {
      final all = widget.library.items;
      final visible = all.where((item) {
        return switch (_filter) {
          _BookmarkFilter.all => true,
          _BookmarkFilter.announcements =>
            item.kind == BookmarkKind.announcement,
          _BookmarkFilter.results => item.kind == BookmarkKind.result,
        };
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Heading('Saved items', top: 0),
          Text(
            'Your saved announcements and results.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final filter in _BookmarkFilter.values)
                ChoiceChip(
                  label: Text(switch (filter) {
                    _BookmarkFilter.all => 'All',
                    _BookmarkFilter.announcements => 'Announcements',
                    _BookmarkFilter.results => 'Results',
                  }),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.library.loading && all.isEmpty)
            const Notice(
              'Loading bookmarks',
              'Reading saved items from this device.',
              action: LinearProgressIndicator(
                semanticsLabel: 'Loading bookmarks',
              ),
            )
          else if (widget.library.error != null)
            Notice(
              'Bookmarks may be incomplete',
              widget.library.error!,
              warning: true,
              action: OutlinedButton(
                onPressed: widget.library.load,
                child: const Text('Retry'),
              ),
            ),
          if (!widget.library.loading &&
              widget.library.error == null &&
              all.isEmpty)
            const Notice(
              'Nothing saved yet',
              'Bookmark announcements and results to access them quickly later.',
              glyph: DesignGlyph.bookmark,
              centered: true,
            )
          else if (!widget.library.loading &&
              widget.library.error == null &&
              visible.isEmpty)
            Notice(
              _filter == _BookmarkFilter.announcements
                  ? 'No announcements saved'
                  : 'No results saved',
              'Bookmarks of this type will appear here.',
              glyph: DesignGlyph.bookmark,
            )
          else
            for (final item in visible)
              _BookmarkCard(
                item: item,
                library: widget.library,
                historyLibrary: widget.historyLibrary,
              ),
        ],
      );
    },
  );
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.item,
    required this.library,
    required this.historyLibrary,
  });

  final BookmarkItem item;
  final BookmarkLibrary library;
  final HistoryLibrary? historyLibrary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.kindLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove bookmark',
                onPressed: () async {
                  try {
                    await library.remove(item.key);
                    if (context.mounted) {
                      feedback(context, 'Bookmark removed.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      feedback(
                        context,
                        'Bookmark could not be removed. Try again.',
                      );
                    }
                  }
                },
                icon: const DesignIcon(DesignGlyph.bookmarked),
              ),
            ],
          ),
          Text(item.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Metadata(item.examName),
          if (item.sittingLabel case final sitting?)
            Metadata(sitting),
          if (item.publishedAtUtc case final published?)
            Metadata('Published ${dateLabel(published.toUtc().add(const Duration(hours: 8)))}'),
          const SizedBox(height: 8),
          SourceButton(
            'Open official source',
            item.url,
            historyLibrary: historyLibrary,
            historyEntry: HistoryEntry(
              sourceId: item.id,
              kind: item.kind == BookmarkKind.announcement
                  ? HistoryKind.announcement
                  : HistoryKind.result,
              examId: item.examId,
              examName: item.examName,
              title: item.title,
              url: item.url,
              publishedAtUtc: item.publishedAtUtc,
              viewedAtUtc: DateTime.now().toUtc(),
              sittingLabel: item.sittingLabel,
            ),
          ),
        ],
      ),
    ),
  );
}
