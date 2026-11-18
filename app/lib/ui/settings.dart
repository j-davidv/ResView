import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../alerts/push_preferences.dart';
import '../domain/models.dart';
import '../storage/private_store.dart';
import '../storage/list_store.dart';
import 'design.dart';
import 'shared.dart';
import 'shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.store,
    required this.lists,
    required this.push,
    required this.selection,
    required this.onChange,
    required this.onLocalDeleted,
    this.examTitle,
    this.examDetails,
    this.restoringPush = false,
    super.key,
  });
  final PrivateStore store;
  final ListStore lists;
  final PushPreferences push;
  final ExamSelection? selection;
  final String? examTitle, examDetails;
  final bool restoringPush;
  final VoidCallback onChange, onLocalDeleted;
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  static const _emailUrl = String.fromEnvironment('BREVO_SIGNUP_URL');
  static const _policyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const _contactUrl = String.fromEnvironment('MAINTAINER_CONTACT_URL');
  final _detailRevision = ValueNotifier(0);
  bool _busy = false;
  String? _error;
  Future<void> Function()? _retryAction;
  String? _retrySuccess;
  @override
  void dispose() {
    _detailRevision.dispose();
    super.dispose();
  }

  void _update(VoidCallback update) {
    if (!mounted) return;
    setState(update);
    _detailRevision.value++;
  }

  Future<void> _operation(
    Future<void> Function() action,
    String success,
  ) async {
    if (_busy || !mounted) return;
    _update(() {
      _busy = true;
      _error = null;
      _retryAction = null;
    });
    try {
      await action();
      if (mounted) feedback(context, success);
    } catch (error) {
      if (mounted) {
        _retryAction = action;
        _retrySuccess = success;
        _update(
          () => _error = error is PushFailure
              ? error.message
              : 'The operation could not be completed. Try again.',
        );
      }
    } finally {
      _update(() => _busy = false);
    }
  }

  Future<void> _push(bool enabled) async {
    if (enabled) {
      if (widget.selection == null) {
        feedback(context, 'Choose an exam and sitting before enabling alerts.');
        return;
      }
      final consent = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: const Text('Enable push alerts?'),
          content: const Text(
            'Firebase will process an anonymous account identifier, your exam preference, and a device notification token. Alerts announce official PRC publications for your selected exam.',
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

  void _openDetails(String title, List<Widget> Function() contents) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: const DesignBackButton(),
            toolbarHeight: math.max(
              56,
              MediaQuery.textScalerOf(context).scale(28) + 16,
            ),
            title: Text(title),
          ),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: _detailRevision,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(screenGutter),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...contents(), ..._operationStatus()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailDetails() => [
    const Text(
      'Email preferences are independent of this device. Confirm your subscription through the email provider. Uninstalling does not unsubscribe you.',
    ),
    const SizedBox(height: 12),
    if (_emailUrl.isEmpty)
      const Notice(
        'Email signup unavailable',
        'The email signup service is not currently connected.',
        glyph: DesignGlyph.email,
      )
    else
      OutlinedButton.icon(
        onPressed: _subscribeToEmail,
        icon: const DesignIcon(DesignGlyph.externalLink),
        label: const Text('Subscribe to emails'),
      ),
    const SizedBox(height: 8),
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
  ];

  Future<void> _subscribeToEmail() async {
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
    if (consent == true && mounted) {
      await openSource(context, Uri.parse(_emailUrl));
    }
  }

  List<Widget> _privacyDetails() => [
    const SelectableText(privacyDisclosure),
    const SizedBox(height: 16),
    if (_policyUrl.isNotEmpty)
      SourceButton('Privacy policy', Uri.parse(_policyUrl)),
    if (_contactUrl.isNotEmpty)
      SourceButton('Maintainer contact', Uri.parse(_contactUrl)),
    TextButton(
      onPressed: _openNotificationSettings,
      child: const Text('Android notification settings'),
    ),
    OutlinedButton.icon(
      onPressed: _busy || widget.restoringPush ? null : _deletePushPreferences,
      icon: const DesignIcon(DesignGlyph.delete),
      label: const Text('Delete server-side push preferences'),
    ),
  ];

  Future<void> _deletePushPreferences() async {
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
  }

  Future<void> _deleteLocalData() async {
    if (await confirmDelete(
      context,
      'Delete local data?',
      'Delete your saved exam selection and any files from earlier app versions. Email subscriptions and server push preferences are managed separately.',
    )) {
      await _operation(() async {
        await widget.lists.clearAll();
        await widget.store.clearLocalValues();
        widget.onLocalDeleted();
      }, 'Local data deleted.');
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await const MethodChannel('org.resview/private')
          .invokeMethod<void>('notificationSettings');
    } catch (_) {
      if (mounted) {
        feedback(
          context,
          'Open this app’s notification settings in Android Settings.',
        );
      }
    }
  }

  List<Widget> _operationStatus() => [
    if (_busy)
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: LinearProgressIndicator(semanticsLabel: 'Updating preference'),
      ),
    if (_error != null) ...[
      const SizedBox(height: 12),
      Notice(
        'Action not completed',
        _error!,
        warning: true,
        action: Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _operation(_retryAction!, _retrySuccess!),
              child: const Text('Retry'),
            ),
            if (_error!.startsWith('Notification permission denied'))
              TextButton(
                onPressed: _openNotificationSettings,
                child: const Text('Android notification settings'),
              ),
          ],
        ),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Heading('Your exam', top: 0),
      ExamContextCard(
        title: widget.examTitle,
        details: widget.examDetails,
        onChoose: _busy ? null : widget.onChange,
        settings: true,
      ),
      const Heading('Alerts'),
      DesignCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile(
              secondary: const DesignIcon(DesignGlyph.pushAlerts),
              title: const Text('Push alerts'),
              subtitle: Metadata(
                widget.restoringPush
                    ? 'Restoring alert preferences…'
                    : widget.push.status,
              ),
              value: widget.push.enabled,
              onChanged: _busy || widget.restoringPush ? null : _push,
            ),
            const Divider(height: 1, indent: 8, endIndent: 8),
            _SettingsRow(
              DesignGlyph.email,
              'Email updates',
              subtitle: 'Managed separately',
              onTap: () => _openDetails('Email updates', _emailDetails),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Metadata('Uninstalling does not unsubscribe you from email.'),
      ),
      const SizedBox(height: 16),
      DesignCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _SettingsRow(
              DesignGlyph.privacy,
              'Privacy and data',
              onTap: () => _openDetails('Privacy and data', _privacyDetails),
            ),
            const Divider(height: 1, indent: 8, endIndent: 8),
            _SettingsRow(
              DesignGlyph.delete,
              'Delete local data',
              destructive: true,
              onTap: _busy ? null : _deleteLocalData,
            ),
          ],
        ),
      ),
      ..._operationStatus(),
    ],
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
    this.glyph,
    this.title, {
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final DesignGlyph glyph;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = destructive ? colors.error : colors.onSurface;
    return ListTile(
      minTileHeight: 56,
      minVerticalPadding: 12,
      leading: DesignIcon(
        glyph,
        color: destructive ? colors.error : colors.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(color: foreground),
      ),
      subtitle: subtitle == null ? null : Metadata(subtitle!),
      trailing: const DesignIcon(DesignGlyph.next, size: 20),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}
