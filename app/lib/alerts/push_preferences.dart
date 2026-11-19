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

class PushPreferences {
  PushPreferences({required this.store});
  final PrivateStore store;
  bool enabled = false;
  String status = 'Off · Get alerts for your selected exam.';
  StreamSubscription<String>? _rotation;
  bool get configured => Firebase.apps.isNotEmpty;
  Future<void> enable(ExamSelection selection) async {
    if (!configured) {
      throw const PushFailure(
        'Alerts are unavailable right now. Try again later.',
      );
    }
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      throw const PushFailure(
        'Notification permission denied. Enable it in Android notification settings.',
      );
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      throw const PushFailure('Could not register this device. Try again.');
    }
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) {
      throw const PushFailure('Could not register alerts. Try again.');
    }
    final ref = FirebaseFirestore.instance.doc('pushPreferences/${user.uid}');
    await ref
        .set({
          'enabled': true,
          'selection': selection.toJson(),
          'token': token,
          'lastActiveAtUtc': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
    await store.setPendingPushDeletion(false);
    enabled = true;
    status = 'On · Alerts for your selected exam.';
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
  }

  Future<void> disable() => deleteServerPreferences();
  Future<void> deleteServerPreferences() async {
    await store.setPendingPushDeletion(true);
    enabled = false;
    status = 'Turning alerts off. You may still receive alerts until this finishes.';
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
