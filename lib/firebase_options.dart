import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCMAgGAsSdHD0EtS8_oyelTKkKZ9cXqsEU',
    appId: '1:858001624614:web:1913a87cc8f23a5316e0e7',
    messagingSenderId: '858001624614',
    projectId: 'flutter-spoken-english-app',
    authDomain: 'flutter-spoken-english-app.firebaseapp.com',
    storageBucket: 'flutter-spoken-english-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyAndroid1234567890',
    appId: '1:1234567890:android:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'spoken-english-app-dummy',
    storageBucket: 'spoken-english-app-dummy.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyIOS1234567890',
    appId: '1:1234567890:ios:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'spoken-english-app-dummy',
    storageBucket: 'spoken-english-app-dummy.appspot.com',
    iosBundleId: 'com.speakeasy.english',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyMac1234567890',
    appId: '1:1234567890:ios:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'spoken-english-app-dummy',
    storageBucket: 'spoken-english-app-dummy.appspot.com',
    iosBundleId: 'com.speakeasy.english.RunnerTests',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyWindows1234567890',
    appId: '1:1234567890:windows:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'spoken-english-app-dummy',
    authDomain: 'spoken-english-app-dummy.firebaseapp.com',
    storageBucket: 'spoken-english-app-dummy.appspot.com',
  );
}
