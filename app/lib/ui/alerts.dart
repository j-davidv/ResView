import 'package:flutter/material.dart';

import '../alerts/alert_inbox.dart';
import '../alerts/exam_alert.dart';
import '../domain/models.dart';
import 'design.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({
    required this.inbox,
    required this.selection,
    required this.onOpen,
    super.key,
  });
  final AlertInbox inbox;
  final ExamSelection selection;
  final ValueChanged<ExamAlert> onOpen;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alerts')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: inbox,
        builder: (context, _) {
          final items = inbox.forSelection(selection);
          if (items.isEmpty) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(screenGutter),
              child: Text(
                'New results, official exam updates, and verified schedule changes will appear here for your selected exam.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(screenGutter),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  isThreeLine: true,
                  leading: const DesignIcon(DesignGlyph.pushAlerts),
                  title: Text(item.title),
                  subtitle: Text('${item.label}\n${sourceTime(item.posted)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen(item),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
