import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../alerts/push_preferences.dart';
import '../domain/models.dart';
import '../storage/private_store.dart';
import '../storage/list_store.dart';
import 'shared.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.store,
    required this.lists,
    required this.push,
    required this.selection,
    required this.onChange,
    required this.onEditName,
    required this.onLocalDeleted,
    this.onNameDeleted,
    required this.onUseSaved,
    super.key,
  });
  final PrivateStore store;
  final ListStore lists;
  final PushPreferences push;
  final ExamSelection? selection;
  final VoidCallback onChange, onEditName, onLocalDeleted;
  final VoidCallback? onNameDeleted;
  final ValueChanged<SavedList> onUseSaved;
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  List<SavedList> _saved = [];
  bool _hasName = false, _busy = false;
  String? _error;
  Future<void> Function()? _retryAction;
  String? _retrySuccess;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.lists.listSaved();
      final name = await widget.store.readName();
      if (mounted) {
        setState(() {
          _saved = saved;
          _hasName = name != null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Device data could not be read. Retry without deleting your saved files.',
        );
      }
    }
  }

  Future<void> _operation(
    Future<void> Function() action,
    String success,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _retryAction = null;
    });
    try {
      await action();
      await _load();
      if (mounted) feedback(context, success);
    } catch (error) {
      if (mounted) {
        _retryAction = action;
        _retrySuccess = success;
        setState(
          () => _error = error is PushFailure
              ? error.message
              : 'The operation could not be completed. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _push(bool enabled) async {
    if (enabled) {
      if (widget.selection == null) {
        setState(
          () => _error = 'Choose an exam and sitting before enabling alerts.',
        );
        return;
      }
      final consent = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: const Text('Enable push alerts?'),
          content: const Text(
            'Firebase will process an anonymous account identifier, your exam preference, and a device notification token. Alerts announce official publications, never your entered name or personal outcome.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (consent != true) return;
    }
    await _operation(
      () => enabled
          ? widget.push.enable(widget.selection!)
          : widget.push.disable(),
      enabled
          ? 'Push preference registered. Delivery is not guaranteed.'
          : 'Push preferences deleted.',
    );
  }

  @override
  Widget build(BuildContext context) {
    const emailUrl = String.fromEnvironment('BREVO_SIGNUP_URL');
    const policyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
    const contactUrl = String.fromEnvironment('MAINTAINER_CONTACT_URL');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading('Exam selection'),
        OutlinedButton(
          onPressed: _busy ? null : widget.onChange,
          child: const Text('Change exam selection'),
        ),
        const Heading('Name on this device'),
        Text(_hasName ? 'A name is saved on this device.' : 'No saved name.'),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _busy ? null : widget.onEditName,
              child: Text(_hasName ? 'Edit saved name' : 'Enter a name'),
            ),
            TextButton(
              onPressed: !_hasName || _busy
                  ? null
                  : () async {
                      if (await confirmDelete(
                        context,
                        'Delete saved name?',
                        'Remove your name from this device. Exam selection and offline lists stay saved.',
                      )) {
                        await _operation(() async {
                          await widget.store.deleteName();
                          widget.onNameDeleted?.call();
                        }, 'Saved name deleted.');
                      }
                    },
              child: const Text('Delete saved name'),
            ),
          ],
        ),
        const Heading('Alerts'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Push alerts'),
          subtitle: Text(widget.push.status),
          value: widget.push.enabled,
          onChanged: _busy ? null : _push,
        ),
        TextButton(
          onPressed: () async {
            try {
              await const MethodChannel('org.resview/private')
                  .invokeMethod<void>('notificationSettings');
            } catch (_) {
              if (context.mounted) {
                feedback(
                  context,
                  'Open this app’s notification settings in Android Settings.',
                );
              }
            }
          },
          child: const Text('Android notification settings'),
        ),
        const Heading('Email updates'),
        const Text(
          'Email preferences are independent of this device. Confirm your subscription through the email provider. Uninstalling does not unsubscribe you.',
        ),
        if (emailUrl.isEmpty)
          const Notice(
            'Email signup unavailable',
            'The email signup service is not currently connected.',
          )
        else
          OutlinedButton(
            onPressed: () async {
              final consent = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  scrollable: true,
                  title: const Text('Subscribe to email updates?'),
                  content: const Text(
                    'Brevo stores your email address and selected exam preferences. Complete its form and confirmation email. Returning to this app does not confirm subscription.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Open signup form'),
                    ),
                  ],
                ),
              );
              if (consent == true && context.mounted) {
                await openSource(context, Uri.parse(emailUrl));
              }
            },
            child: const Text('Subscribe to emails'),
          ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              scrollable: true,
              title: const Text('Unsubscribe from emails'),
              content: const Text(
                'Use the unsubscribe link in an email from this service. Deleting local data or uninstalling this app does not cancel email updates. The email provider manages confirmation and suppression.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: const Text('Unsubscribe instructions'),
        ),
        const Heading('Saved offline lists'),
        Text(
          '${(_saved.fold<int>(0, (sum, s) => sum + s.bytes) / (1024 * 1024)).toStringAsFixed(2)} MiB / 50 MiB',
        ),
        if (_saved.isEmpty)
          const Text('No lists saved. Saving is always your choice.'),
        for (final item in _saved) ...[
          const Divider(),
          Text(
            item.contextDescription ?? 'Saved exam context unavailable. Open its official publication to confirm the sitting.',
          ),
          SelectableText('Version: ${item.version.documentVersion}'),
          Text(
            '${(item.bytes / (1024 * 1024)).toStringAsFixed(2)} MiB · Last source check: ${sourceTime(item.version.lastSuccessfulCheckUtc)}',
          ),
          if (item.outdated)
            const Notice(
              'Outdated offline list',
              'A newer official version is known. Use the latest publication.',
              warning: true,
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: item.outdated || _busy
                    ? null
                    : () => widget.onUseSaved(item),
                child: const Text('Use saved list'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirmDelete(
                          context,
                          'Delete offline list?',
                          'Remove version ${item.version.documentVersion} from this device?',
                        )) {
                          await _operation(
                            () => widget.lists.deleteSaved(item.id),
                            'Offline list deleted.',
                          );
                        }
                      },
                child: const Text('Delete list'),
              ),
            ],
          ),
        ],
        const Heading('Privacy and data'),
        const SelectableText(privacyDisclosure),
        const SizedBox(height: 16),
        if (policyUrl.isNotEmpty)
          SourceButton('Privacy policy', Uri.parse(policyUrl)),
        if (contactUrl.isNotEmpty)
          SourceButton('Maintainer contact', Uri.parse(contactUrl)),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  if (await confirmDelete(
                    context,
                    'Delete server-side push preferences?',
                    'Stop this installation’s push subscription. If offline, deletion remains pending and alerts may continue until confirmed. Email subscriptions are separate.',
                  )) {
                    await _operation(
                      widget.push.deleteServerPreferences,
                      'Server push preferences deleted.',
                    );
                  }
                },
          child: const Text('Delete server-side push preferences'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  if (await confirmDelete(
                    context,
                    'Delete local data?',
                    'Delete your saved name, exam selection, and downloaded lists on this device. This does not unsubscribe email or delete server push preferences. Pending server deletion will be retained.',
                  )) {
                    await _operation(() async {
                      await widget.lists.clearAll();
                      await widget.store.clearLocalValues();
                      widget.onLocalDeleted();
                    }, 'Local data deleted.');
                  }
                },
          child: const Text('Delete local data'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(
              semanticsLabel: 'Updating preference',
            ),
          ),
        if (_error != null)
          Notice(
            'Action not completed',
            _error!,
            warning: true,
            action: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _operation(
                      _retryAction ?? _load,
                      _retrySuccess ?? 'Device data refreshed.',
                    ),
              child: const Text('Retry'),
            ),
          ),
      ],
    );
  }
}
