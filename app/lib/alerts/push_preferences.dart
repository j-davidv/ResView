import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models.dart';
import '../storage/private_store.dart';

class PushFailure implements Exception {
  const PushFailure(this.message);
  final String message;
}

PushFailure explainPushFailure(Object error, String step) {
  if (error is PushFailure) return error;
  if (error is TimeoutException) {
    return PushFailure(
      step == 'save-preferences'
          ? 'The server did not confirm alert registration. You may still receive alerts. Retry to check. ($step/timeout)'
          : 'Phone alert registration timed out. Check your connection and retry. ($step/timeout)',
    );
  }
  if (error is FirebaseException) {
    // Provider messages can contain device identifiers. Show only a bounded
    // diagnostic code, together with an actionable explanation.
    final safeCode = error.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final code = safeCode.length > 64 ? safeCode.substring(0, 64) : safeCode;
    final suffix = '($step/$code)';
    if (step == 'sign-in' &&
        {
          'operation-not-allowed',
          'configuration-not-found',
          'admin-restricted-operation',
        }.contains(code)) {
      return PushFailure(
        'Phone registration is disabled on the server. The ResView team needs to enable Anonymous sign-in in Firebase Authentication. $suffix',
      );
    }
    if (step == 'save-preferences' && code == 'permission-denied') {
      return PushFailure(
        'The server rejected your alert registration. The ResView team needs to deploy the updated notification rules. $suffix',
      );
    }
    if ({
      'invalid-api-key',
      'app-not-authorized',
      'invalid-app-credential',
    }.contains(code)) {
      return PushFailure(
        'This app is not authorized for phone alerts. The ResView team needs to check its Firebase configuration and signing certificate. $suffix',
      );
    }
    if ({'network-request-failed', 'unavailable'}.contains(code)) {
      return PushFailure(
        'The alert service could not be reached. Check your internet connection and retry. $suffix',
      );
    }
    if (step == 'device-registration') {
      return PushFailure(
        'This phone could not register for notifications. Check your internet connection and Google Play services, then retry. $suffix',
      );
    }
    return PushFailure(
      'Phone alert registration failed. Share this error code with the ResView team: $suffix',
    );
  }
  return PushFailure(
    'Phone alert registration failed at $step. Retry, or contact the ResView team.',
  );
}

Future<T> _pushStep<T>(String step, Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw explainPushFailure(error, step);
  }
}

class PushPreferences {
  PushPreferences({required this.store});
  final PrivateStore store;
  bool enabled = false;
  String status = 'Off · Get alerts for your selected exam.';
  StreamSubscription<String>? _rotation;
  Future<void> _selectionUpdates = Future.value();
  bool get configured => Firebase.apps.isNotEmpty;
  Future<void> _watchToken(DocumentReference<Map<String, dynamic>> ref) async {
    await _rotation?.cancel();
    _rotation = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        if (enabled) {
          await ref.update({
            'token': token,
            'lastActiveAtUtc': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {
        status = 'Alerts need to reconnect. Turn them off and on again.';
      }
    });
  }

  Future<void> updateSelection(ExamSelection selection) {
    final next = _selectionUpdates.then((_) => _updateSelection(selection));
    _selectionUpdates = next.catchError((Object _) {});
    return next;
  }

  Future<void> _updateSelection(ExamSelection selection) async {
    if (!enabled || !configured) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .doc('pushPreferences/${user.uid}')
          .update({
            'selection': selection.toJson(),
            'lastActiveAtUtc': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      status = 'Alerts need to reconnect for your new exam. Turn them off and on again.';
      rethrow;
    }
  }

  Future<void> enable(ExamSelection selection) async {
    if (!configured) {
      throw const PushFailure(
        'Alerts are unavailable right now. Try again later.',
      );
    }
    final permission = await _pushStep(
      'permission',
      () => FirebaseMessaging.instance.requestPermission(),
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      throw const PushFailure(
        'Notification permission denied. Enable it in Android notification settings.',
      );
    }
    await _pushStep(
      'device-registration',
      () => FirebaseMessaging.instance.setAutoInitEnabled(true),
    );
    final token = await _pushStep(
      'device-registration',
      () => FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 30),
      ),
    );
    if (token == null) {
      throw const PushFailure('Could not register this device. Try again.');
    }
    final auth = FirebaseAuth.instance;
    final user =
        auth.currentUser ??
        (await _pushStep(
          'sign-in',
          () => auth.signInAnonymously().timeout(const Duration(seconds: 20)),
        )).user;
    if (user == null) {
      throw const PushFailure('Could not register alerts. Try again.');
    }
    final ref = FirebaseFirestore.instance.doc('pushPreferences/${user.uid}');
    await _pushStep(
      'save-preferences',
      () => ref
          .set({
            'enabled': true,
            'selection': selection.toJson(),
            'token': token,
            'registrationId': DateTime.now().microsecondsSinceEpoch.toString(),
            'lastActiveAtUtc': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15)),
    );
    await _pushStep(
      'device-preferences',
      () => store.setPendingPushDeletion(false),
    );
    enabled = true;
    status = 'On · Alerts for your selected exam.';
    await _watchToken(ref);
  }

  Future<void> restore() async {
    if (await store.pendingPushDeletion()) {
      status = 'Turning alerts off. You may still receive alerts until this finishes.';
      if (configured) await deleteServerPreferences();
      return;
    }
    if (!configured) {
      status = 'Alerts are unavailable right now. Try again later.';
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    status = 'Could not check alert settings. You may still receive alerts.';
    final doc = await FirebaseFirestore.instance
        .doc('pushPreferences/${user.uid}')
        .get(const GetOptions(source: Source.server));
    enabled = doc.data()?['enabled'] == true;
    status = enabled
        ? 'On · Alerts for your saved exam choice.'
        : 'Off · Get alerts for your selected exam.';
    if (enabled) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        status = 'Notification permission denied. Enable it in Android notification settings.';
        return;
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      final ref = FirebaseFirestore.instance.doc('pushPreferences/${user.uid}');
      await _watchToken(ref);
      final token = await FirebaseMessaging.instance.getToken();
      final selection = await store.readSelection();
      if (token != null) {
        await ref.update({
          'token': token,
          if (selection != null) 'selection': selection.toJson(),
          'lastActiveAtUtc': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> disable() => deleteServerPreferences();
  Future<void> deleteServerPreferences() async {
    await store.setPendingPushDeletion(true);
    enabled = false;
    status =
        'Turning alerts off. You may still receive alerts until this finishes.';
    await _rotation?.cancel();
    if (!configured) throw PushFailure(status);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .doc('pushPreferences/${user.uid}')
          .delete()
          .timeout(const Duration(seconds: 15));
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
    await store.setPendingPushDeletion(false);
    status = 'Off · Get alerts for your selected exam.';
  }

  Future<void> dispose() async => _rotation?.cancel();
}
