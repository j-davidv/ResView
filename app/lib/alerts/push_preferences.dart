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
  String status = 'Off';
  StreamSubscription<String>? _rotation;
  bool get configured => Firebase.apps.isNotEmpty;
  Future<void> enable(ExamSelection selection) async {
    if (!configured) {
      throw const PushFailure(
        'Push alerts unavailable. The service is not connected.',
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
    status = 'Registered for this selection. Delivery is not guaranteed.';
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
        status = 'Token update not confirmed. Retry registration.';
      }
    });
  }

  Future<void> restore() async {
    if (await store.pendingPushDeletion()) {
      status = 'Server deletion pending. Alerts may continue until confirmed.';
      if (configured) await deleteServerPreferences();
      return;
    }
    if (!configured) {
      status = 'Push alerts unavailable. The service is not connected.';
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    status = 'Push registration not confirmed. Previously enabled alerts may still arrive.';
    final doc = await FirebaseFirestore.instance
        .doc('pushPreferences/${user.uid}')
        .get(const GetOptions(source: Source.server));
    enabled = doc.data()?['enabled'] == true;
    status = enabled
        ? 'Previously registered. Review the selection before re-enabling alerts.'
        : 'Off';
  }

  Future<void> disable() => deleteServerPreferences();
  Future<void> deleteServerPreferences() async {
    await store.setPendingPushDeletion(true);
    enabled = false;
    status = 'Server deletion pending. Alerts may continue until confirmed.';
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
    status = 'Off. Server preferences deleted.';
  }

  Future<void> dispose() async => _rotation?.cancel();
}
