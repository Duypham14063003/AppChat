import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isSupportedPlatform {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static bool get isConfiguredForCurrentPlatform {
    if (!isSupportedPlatform) return false;

    final options = currentPlatform;
    return options.apiKey.isNotEmpty &&
        options.appId.isNotEmpty &&
        options.projectId.isNotEmpty;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyDvONTHHetrhRz9ZKvfJf2U4aI754gBQ',
    appId: '1:521088896111:web:bab8e37c62dccf8fbd919a',
    messagingSenderId: '521088896111',
    projectId: 'tdigital-56396',
    authDomain: 'tdigital-56396.firebaseapp.com',
    storageBucket: 'tdigital-56396.firebasestorage.app',
    measurementId: 'G-ZS1MRSP9XK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCC4ZSF7MSNNbgKgQE1s02VLTwp0mLT0Io',
    appId: '1:502236887100:android:d25e1a6df863a88b77eb39',
    messagingSenderId: '502236887100',
    projectId: 't-mobile-9b640',
    storageBucket: 't-mobile-9b640.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDkctwSLsR34mw3u8QLEmYKjXagwYo8bWI',
    appId: '1:502236887100:ios:189192ccef3ab4fe77eb39',
    messagingSenderId: '502236887100',
    projectId: 't-mobile-9b640',
    storageBucket: 't-mobile-9b640.firebasestorage.app',
    iosBundleId: 'vn.19t.nineteenTechApp',
  );
}