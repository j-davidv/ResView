import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'exam_alert.dart';

class PhoneAlerts {
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  bool _disposed = false;
  Future<void> start({
    required Future<void> Function(ExamAlert) onReceive,
    required Future<void> Function(ExamAlert) onOpen,
  }) async {
    if (Firebase.apps.isEmpty) return;
    Future<void> handle(RemoteMessage message, bool opened) async {
      try {
        final alert = ExamAlert.fromJson(message.data);
        if (_disposed) return;
        await onReceive(alert);
        if (!_disposed && opened) await onOpen(alert);
      } catch (_) {
        // Malformed or unrelated payloads never open untrusted links.
      }
    }

    _foreground = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(handle(message, false)),
    );
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(handle(message, true)),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && !_disposed) await handle(initial, true);
  }

  void dispose() {
    _disposed = true;
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
  }
}
