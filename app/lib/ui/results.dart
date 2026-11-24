import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../storage/bookmark_library.dart';
import '../storage/history_library.dart';
import 'design.dart';
import 'shared.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.version,
    this.publications = const [],
    this.bookmarks,
    this.historyLibrary,
    this.examId,
    this.examName,
    this.sittingLabel,
    this.loading = false,
    this.failed = false,
    this.sitting,
    this.monitorStatus,
    this.now,
    this.onRetry,
    super.key,
  });
  final ResultVersion? version;
  final VoidCallback? onRetry;
  final bool loading, failed;
  final Sitting? sitting;
  final ResultMonitorStatus? monitorStatus;
  final DateTime? now;
  final List<Publication> publications;
  final BookmarkLibrary? bookmarks;
  final HistoryLibrary? historyLibrary;
  final String? examId, examName, sittingLabel;

  @override
  Widget build(BuildContext context) {
    final current = version;
    final released =
        publications.isNotEmpty ||
        (current != null && current.state != PublicationState.notReleased);
    final clock = (now ?? DateTime.now()).toUtc();
    final philippineTime = clock.add(const Duration(hours: 8));
    final today = DateTime.utc(
      philippineTime.year,
      philippineTime.month,
      philippineTime.day,
    );
    final schedule = sitting;
    final target = schedule?.targetReleaseDate;
    String title, message;
    if (released) {
      title = current?.state == PublicationState.superseded
          ? 'Updated publication'
          : 'Results released';
      message = 'Open the official PRC publication or successful-examinee list below.';
    } else if (loading) {
      title = 'Loading official information';
      message = 'Retrieving official announcements and result links.';
    } else if (failed) {
      title = "Couldn't refresh";
      message = 'Result information could not be loaded. Check your connection and retry.';
    } else {
      if (schedule != null && today.isBefore(schedule.start)) {
        title = 'Upcoming exam';
        message =
            'This examination is scheduled to start on ${dateLabel(schedule.start)}.';
      } else if (schedule != null && !today.isAfter(schedule.end)) {
        title = 'Exam in progress';
        message =
            'This sitting is scheduled through ${dateLabel(schedule.end)}.';
      } else if (target != null && !today.isAfter(target)) {
        title = 'Awaiting results';
        message = 'The examination has ended. Check back for the official PRC release.';
      } else {
        title = 'No verified result announcement found';
        message =
            'No verified PRC result announcement has been found for this sitting.';
        if (target != null) {
          message += ' The target date has passed; this does not confirm whether PRC has released the results.';
        }
      }
      if (target != null) {
        message +=
            '\nPRC target release: ${dateLabel(target)}. Actual release may change.';
      }
    }
    final showCheck = !released && !loading && !failed;
    final freshness = sourceFreshness(
      monitorStatus?.freshness,
      monitorStatus?.lastSuccessfulCheckUtc,
      clock,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Heading('Publication status', top: 0),
        Notice(
          title,
          message,
          glyph: released ? DesignGlyph.results : DesignGlyph.info,
          action: loading && !released
              ? const LinearProgressIndicator(
                  semanticsLabel: 'Loading official information',
                )
              : onRetry != null
              ? OutlinedButton(onPressed: onRetry, child: const Text('Retry'))
              : null,
        ),
        if (showCheck) ...[
          const SizedBox(height: 8),
          Metadata(
            'Last successful PRC results check: ${sourceTime(monitorStatus?.lastSuccessfulCheckUtc)}',
          ),
          if (freshness != SourceFreshness.fresh)
            const Metadata(
              'Result information may be outdated. Check the official PRC source for updates.',
            ),
        ],
        if (!released && !loading && schedule?.catalogUrl != null) ...[
          const SizedBox(height: 12),
          SourceButton('PRC exam schedule', schedule!.catalogUrl!),
        ],
        SourceLinks(
          current,
          publications: publications,
          bookmarks: bookmarks,
          historyLibrary: historyLibrary,
          examId: examId,
          examName: examName,
          sittingLabel: sittingLabel,
        ),
      ],
    );
  }
}
