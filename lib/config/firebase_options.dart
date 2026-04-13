import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Placeholder Firebase configuration.
///
/// Replace these values with your real Firebase project config by running:
///   flutterfire configure
///
/// Or manually update from the Firebase console → Project Settings → Your apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
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

  /// Placeholder Android config — replace with real values from Firebase console.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'pawgo-placeholder',
    storageBucket: 'pawgo-placeholder.appspot.com',
  );

  /// Placeholder iOS config — replace with real values from Firebase console.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'pawgo-placeholder',
    storageBucket: 'pawgo-placeholder.appspot.com',
    iosBundleId: 'com.pawgo.pawgo',
  );
}
