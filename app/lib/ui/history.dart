import 'package:flutter/material.dart';

import '../domain/history.dart';
import '../domain/models.dart';
import '../storage/history_library.dart';
import 'design.dart';
import 'shared.dart';

enum _HistoryFilter { all, announcements, results }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.library, super.key});
  final HistoryLibrary library;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('Clear viewing history?'),
        content: const Text(
          'This removes all recently viewed announcements and results from this device. '
          'Your bookmarks will not be affected.',
        ),
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
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.library.clearAll();
      if (mounted) feedback(context, 'Viewing history cleared.');
    } catch (_) {
      if (mounted) {
        feedback(context, 'History could not be cleared. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.library,
    builder: (context, _) {
      final all = widget.library.items;
      final visible = all.where((item) {
        return switch (_filter) {
          _HistoryFilter.all => true,
          _HistoryFilter.announcements =>
            item.kind == HistoryKind.announcement,
          _HistoryFilter.results => item.kind == HistoryKind.result,
        };
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Heading('Recently Viewed', top: 0),
                    Text(
                      "Quickly return to announcements and results you've opened.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (all.isNotEmpty)
                IconButton(
                  tooltip: 'Clear viewing history',
                  icon: const DesignIcon(DesignGlyph.delete),
                  onPressed: _clearAll,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final filter in _HistoryFilter.values)
                ChoiceChip(
                  label: Text(switch (filter) {
                    _HistoryFilter.all => 'All',
                    _HistoryFilter.announcements => 'Announcements',
                    _HistoryFilter.results => 'Results',
                  }),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.library.loading && all.isEmpty)
            const Notice(
              'Loading history',
              'Reading recently viewed items from this device.',
              action: LinearProgressIndicator(
                semanticsLabel: 'Loading history',
              ),
            )
          else if (widget.library.error != null)
            Notice(
              'History may be incomplete',
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
              'Nothing viewed yet',
              'Announcements and results you open will appear here so you can easily return to them.',
              glyph: DesignGlyph.freshness,
              centered: true,
            )
          else if (!widget.library.loading &&
              widget.library.error == null &&
              visible.isEmpty)
            Notice(
              _filter == _HistoryFilter.announcements
                  ? 'No announcements viewed'
                  : 'No results viewed',
              'Items of this type will appear here.',
              glyph: DesignGlyph.freshness,
            )
          else
            ..._buildGroupedItems(context, visible),
        ],
      );
    },
  );

  List<Widget> _buildGroupedItems(
    BuildContext context,
    List<HistoryEntry> items,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = DateTime(now.year, now.month, now.day - 1);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - now.weekday + 1,
    );

    final today = <HistoryEntry>[];
    final yesterday = <HistoryEntry>[];
    final thisWeek = <HistoryEntry>[];
    final older = <HistoryEntry>[];

    for (final item in items) {
      final localViewed = item.viewedAtUtc.toLocal();
      if (!localViewed.isBefore(todayStart)) {
        today.add(item);
      } else if (!localViewed.isBefore(yesterdayStart)) {
        yesterday.add(item);
      } else if (!localViewed.isBefore(weekStart)) {
        thisWeek.add(item);
      } else {
        older.add(item);
      }
    }

    final widgets = <Widget>[];

    void addGroup(String label, List<HistoryEntry> group) {
      if (group.isEmpty) return;
      widgets.add(Heading(label, top: widgets.isEmpty ? 0 : 20));
      for (final item in group) {
        widgets.add(_HistoryCard(item: item, library: widget.library));
      }
    }

    addGroup('Today', today);
    addGroup('Yesterday', yesterday);
    addGroup('Earlier this week', thisWeek);
    addGroup('Older', older);
    return widgets;
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.library});

  final HistoryEntry item;
  final HistoryLibrary library;

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
                tooltip: 'Remove from history',
                onPressed: () async {
                  try {
                    await library.remove(item.sourceId);
                    if (context.mounted) {
                      feedback(context, 'Removed from history.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      feedback(
                        context,
                        'Could not remove from history. Try again.',
                      );
                    }
                  }
                },
                icon: const DesignIcon(DesignGlyph.close),
              ),
            ],
          ),
          Text(item.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Metadata(item.examName),
          if (item.sittingLabel case final sitting?)
            Metadata(sitting),
          if (item.publishedAtUtc case final published?)
            Metadata(
              'Published ${dateLabel(published.toUtc().add(const Duration(hours: 8)))}',
            ),
          Metadata('Viewed ${_viewedLabel(item.viewedAtUtc)}'),
          const SizedBox(height: 8),
          SourceButton(
            'Open official source',
            item.url,
            historyLibrary: library,
            historyEntry: item,
          ),
        ],
      ),
    ),
  );

  String _viewedLabel(DateTime viewedAtUtc) {
    final local = viewedAtUtc.toLocal();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = DateTime(now.year, now.month, now.day - 1);
    final localDate = DateTime(local.year, local.month, local.day);

    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (!localDate.isBefore(todayStart)) return 'today at $timeStr';
    if (!localDate.isBefore(yesterdayStart)) return 'yesterday at $timeStr';
    return '${dateLabel(local)} at $timeStr';
  }
}
