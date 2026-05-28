import 'package:firebase_core/firebase_core.dart';

/// Placeholder until you run FlutterFire CLI (generates real options).
///
/// From project root:
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// Also add **GoogleService-Info.plist** to `ios/Runner/` (Xcode) and
/// **google-services.json** under `android/app/` from the Firebase console.
///
/// After `flutterfire configure`, this file is replaced and
/// [DefaultFirebaseOptions.currentPlatform] stops throwing.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Run `flutterfire configure` to generate Firebase options '
      '(or rely on GoogleService-Info.plist / google-services.json only).',
    );
  }
}
