import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Initializes Firebase without making the rest of the app depend on project
/// credentials. The generated FlutterFire options are used by default, while
/// FIREBASE_* dart-defines can override them for alternate environments.
abstract final class FirebaseBootstrap {
  static String? lastError;

  static bool get isReady => Firebase.apps.isNotEmpty;

  static Future<bool> initialize() async {
    if (isReady) return true;
    try {
      const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
      if (apiKey.isNotEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: apiKey,
            appId: String.fromEnvironment('FIREBASE_APP_ID'),
            messagingSenderId:
                String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
            projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
            databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL'),
            authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
            storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
          ),
        );
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      lastError = null;
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    }
  }
}
