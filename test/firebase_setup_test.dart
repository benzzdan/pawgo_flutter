import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying Firebase packages are properly configured.
void main() {
  group('Firebase setup', () {
    test('firebase_options.dart exists with DefaultFirebaseOptions class', () {
      final file = File('lib/config/firebase_options.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/config/firebase_options.dart must exist');
      final content = file.readAsStringSync();
      expect(content, contains('DefaultFirebaseOptions'),
          reason: 'firebase_options.dart must export DefaultFirebaseOptions');
      expect(content, contains('currentPlatform'),
          reason:
              'DefaultFirebaseOptions must have a currentPlatform getter');
    });

    test('main.dart initializes Firebase before runApp', () {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('Firebase.initializeApp'),
          reason: 'main.dart must call Firebase.initializeApp()');
      expect(content, contains("import 'package:firebase_core/firebase_core.dart'"),
          reason: 'main.dart must import firebase_core');

      // Verify Firebase init comes before runApp
      final firebaseInitIndex = content.indexOf('Firebase.initializeApp');
      final runAppIndex = content.indexOf('runApp(');
      expect(firebaseInitIndex, lessThan(runAppIndex),
          reason:
              'Firebase.initializeApp() must be called before runApp()');
    });

    test('pubspec.yaml includes firebase_core and firebase_messaging', () {
      final file = File('pubspec.yaml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('firebase_core:'),
          reason: 'pubspec.yaml must include firebase_core');
      expect(content, contains('firebase_messaging:'),
          reason: 'pubspec.yaml must include firebase_messaging');
    });

    test('google-services.json exists for Android', () {
      final file = File('android/app/google-services.json');
      expect(file.existsSync(), isTrue,
          reason: 'android/app/google-services.json must exist');
    });

    test('GoogleService-Info.plist exists for iOS', () {
      final file = File('ios/Runner/GoogleService-Info.plist');
      expect(file.existsSync(), isTrue,
          reason: 'ios/Runner/GoogleService-Info.plist must exist');
    });
  });
}
