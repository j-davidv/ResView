import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/firestore_repository.dart';
import 'main.dart' show ExamApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(
    options: const FirebaseOptions(
      projectId: 'demo-resview-advisories',
      apiKey: 'demo-only',
      appId: '1:123:android:demo',
      messagingSenderId: '123',
    ),
  );
  final db = FirebaseFirestore.instanceFor(app: app);
  const usb = bool.fromEnvironment('RESVIEW_USB');
  db.useFirestoreEmulator(
    usb ? '127.0.0.1' : '10.0.2.2',
    8185,
    automaticHostMapping: false,
  );
  runApp(ExamApp(repository: FirestoreExamRepository(db), advisoryPilot: true));
}
