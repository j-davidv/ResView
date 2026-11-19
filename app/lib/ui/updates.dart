import 'dart:async';

import 'package:flutter/material.dart';

import '../data/exam_repository.dart';
import '../domain/bookmark.dart';
import '../domain/models.dart';
import '../storage/bookmark_library.dart';
import 'design.dart';
import 'shared.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({
    required this.repository,
    required this.selection,
    this.examId,
    this.bookmarks,
    this.examTitle,
    required this.revision,
    super.key,
  });
  final ExamRepository repository;
  final ExamSelection selection;
  final String? examId;
  final BookmarkLibrary? bookmarks;
  final String? examTitle;
  final int revision;

  @override
  State<UpdatesScreen> createState() => _UpdatesState();
}

class _UpdatesState extends State<UpdatesScreen> {
  AdvisoryFeed? _feed;
  bool _loading = true, _failed = false;
  int _generation = 0;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UpdatesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selection.examId != oldWidget.selection.examId ||
        widget.repository != oldWidget.repository) {
      _feed = null;
      _failed = false;
      _expiry?.cancel();
      _load();
    } else if (widget.revision != oldWidget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final feed = await widget.repository.loadAdvisories(
        widget.selection.examId,
      );
      if (!mounted || generation != _generation) return;
      _expiry?.cancel();
      _failed = false;
      _feed = feed;
      final expiry = feed?.lastCheck?.add(AdvisoryFeed.maxAge);
      if (feed?.stale == false &&
          expiry != null &&
          expiry.isAfter(DateTime.now())) {
        _expiry = Timer(
          expiry.difference(DateTime.now()),
          () => setState(() {}),
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) _failed = true;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    if (feed == null && _loading) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Checking exam updates',
      );
    }
    final retry = OutlinedButton(
      onPressed: _loading ? null : _load,
      child: const Text('Retry'),
    );
    if (feed == null || feed.lastCheck == null) {
      final failed = _failed || feed != null;
      return Notice(
        failed
            ? 'Exam updates unavailable'
            : 'Update history unavailable for this exam',
        failed
            ? 'The PRC archive check could not be confirmed.'
            : 'This exam has no verified archive coverage yet.',
        action: failed ? retry : null,
      );
    }
    final last = feed.lastCheck!;
    final now = DateTime.now().toUtc();
    final stale =
        _failed ||
        feed.stale ||
        last.isAfter(now) ||
        !now.isBefore(last.add(AdvisoryFeed.maxAge));
    const philippineOffset = Duration(hours: 8);
    final first = dateLabel(feed.start.add(philippineOffset));
    final through = dateLabel(
      feed.end.subtract(const Duration(microseconds: 1)).add(philippineOffset),
    );
    final window =
        'All sittings · PRC archive checked $first – $through · Last checked: ${sourceTime(last)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Refreshing exam updates',
          ),
        if (stale)
          Notice(
            'Exam updates may be outdated',
            'Last successful check: ${sourceTime(last)}.',
            warning: true,
            action: retry,
          ),
        if (feed.notices.isEmpty)
          Notice(
            stale
                ? 'No verified updates available'
                : 'No verified updates for this exam',
            window,
          )
        else ...[
          const Heading('Latest update', top: 8),
          Metadata(window),
          _UpdateCard(
            item: feed.notices.first,
            examId: widget.examId,
            examName: widget.examTitle ?? widget.examId,
            bookmarks: widget.bookmarks,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    leading: const DesignBackButton(),
                    title: const Text('All updates'),
                  ),
                  body: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(screenGutter),
                          itemCount: feed.notices.length + 1,
                          itemBuilder: (context, index) => index == 0
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.examTitle case final title?)
                                      Heading(title, top: 0),
                                    Metadata(window),
                                    if (stale)
                                      Metadata(
                                        'Last successful check: ${sourceTime(last)}.',
                                      ),
                                  ],
                                )
                              : _UpdateCard(
                                  item: feed.notices[index - 1],
                                  examId: widget.examId,
                                  examName: widget.examTitle ?? widget.examId,
                                  bookmarks: widget.bookmarks,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('View all updates'),
          ),
        ],
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.item,
    this.examId,
    this.examName,
    this.bookmarks,
  });

  final ExamUpdate item;
  final String? examId, examName;
  final BookmarkLibrary? bookmarks;

  @override
  Widget build(BuildContext context) {
    final canonicalUrl = item.url.replace(
      host: item.url.host == 'prc.gov.ph' || item.url.host == 'www.prc.gov.ph'
          ? 'www.prc.gov.ph'
          : item.url.host.toLowerCase(),
    );
    final bookmark = examId == null || examName == null
        ? null
        : BookmarkItem(
            id: canonicalUrl.toString(),
            kind: BookmarkKind.announcement,
            examId: examId!,
            examName: examName!,
            title: item.title,
            url: item.url,
            publishedAtUtc: item.posted,
            savedAtUtc: DateTime.now().toUtc(),
          );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DesignCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Metadata(
              'Posted ${dateLabel(item.posted.add(const Duration(hours: 8)))}',
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (bookmarks != null && bookmark != null)
                  BookmarkToggleButton(library: bookmarks!, item: bookmark),
              ],
            ),
            if (item.audience.isNotEmpty) Metadata(item.audience),
            const SizedBox(height: 8),
            SourceButton('Open PRC notice', item.url),
          ],
        ),
      ),
    );
  }
}
