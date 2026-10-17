import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZsjxlx56QeHoRhBr3ocxM7uUeQDN6Xd0',
    appId: '1:1077959967029:ios:998942c876fbfb8f164c7c',
    messagingSenderId: '1077959967029',
    projectId: 'dealgo-81a0d',
    storageBucket: 'dealgo-81a0d.firebasestorage.app',
    iosBundleId: 'com.trancongtien.dealgo',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJTa4RLZYfLxvRyvbu06qyPhYpcE6DXSM',
    appId: '1:1077959967029:android:251a8a164a56fef2164c7c',
    messagingSenderId: '1077959967029',
    projectId: 'dealgo-81a0d',
    storageBucket: 'dealgo-81a0d.firebasestorage.app',
  );
}
