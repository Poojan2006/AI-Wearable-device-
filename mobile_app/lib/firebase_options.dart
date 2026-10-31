// File generated for worker-safety-system-9798a.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '1:909125349437:android:9f5bb2400b58bb79cd7a54',
    messagingSenderId: '909125349437',
    projectId: 'worker-safety-system-9798a',
    databaseURL: 'https://worker-safety-system-9798a-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'worker-safety-system-9798a.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '1:909125349437:web:9f5bb2400b58bb79cd7a54',
    messagingSenderId: '909125349437',
    projectId: 'worker-safety-system-9798a',
    databaseURL: 'https://worker-safety-system-9798a-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'worker-safety-system-9798a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '1:909125349437:ios:9f5bb2400b58bb79cd7a54',
    messagingSenderId: '909125349437',
    projectId: 'worker-safety-system-9798a',
    databaseURL: 'https://worker-safety-system-9798a-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'worker-safety-system-9798a.firebasestorage.app',
    iosBundleId: 'com.workersafety.workerSafetyApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '',
    appId: '1:909125349437:ios:9f5bb2400b58bb79cd7a54',
    messagingSenderId: '909125349437',
    projectId: 'worker-safety-system-9798a',
    databaseURL: 'https://worker-safety-system-9798a-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'worker-safety-system-9798a.firebasestorage.app',
    iosBundleId: 'com.workersafety.workerSafetyApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '',
    appId: '1:909125349437:web:9f5bb2400b58bb79cd7a54',
    messagingSenderId: '909125349437',
    projectId: 'worker-safety-system-9798a',
    databaseURL: 'https://worker-safety-system-9798a-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'worker-safety-system-9798a.firebasestorage.app',
  );
}
