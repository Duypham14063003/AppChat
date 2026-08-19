import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nineteen_tech_app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DefaultFirebaseOptions.isConfiguredForCurrentPlatform) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'firebase initialization',
          context: ErrorDescription('while bootstrapping the app'),
        ),
      );
    }
  } else {
    debugPrint(
      'Skipping Firebase initialization because the current platform is not configured.',
    );
  }

  runApp(const ProviderScope(child: App()));
}
