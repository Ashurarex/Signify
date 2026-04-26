import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD0B-tpKmCOogYfa2OkSZ8oOYibkhIDg_Y',
    appId: '1:62367810101:web:f7a7f35bea6a197cf9e77c',
    messagingSenderId: '62367810101',
    projectId: 'signify-eb72a',
    authDomain: 'signify-eb72a.firebaseapp.com',
    storageBucket: 'signify-eb72a.firebasestorage.app',
    measurementId: 'G-JTV5WNQ1S7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYXRUgaV6yx8v_8h06uW_KklmC_OzfMdg',
    appId: '1:62367810101:android:0d42fe376bfbeafff9e77c',
    messagingSenderId: '62367810101',
    projectId: 'signify-eb72a',
    storageBucket: 'signify-eb72a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosBundleId: 'com.example.signify',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosBundleId: 'com.example.signify',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD0B-tpKmCOogYfa2OkSZ8oOYibkhIDg_Y',
    appId: '1:62367810101:web:38d80007234c2f01f9e77c',
    messagingSenderId: '62367810101',
    projectId: 'signify-eb72a',
    authDomain: 'signify-eb72a.firebaseapp.com',
    storageBucket: 'signify-eb72a.firebasestorage.app',
    measurementId: 'G-RT8QFVYLGE',
  );

}