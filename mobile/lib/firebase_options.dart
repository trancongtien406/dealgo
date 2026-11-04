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
    apiKey: 'AIzaSyAca-_96hvF7wW8z2V7GECqsd9KLBkSS8g',
    appId: '1:218651434467:ios:3995564aa13482628594d6',
    messagingSenderId: '218651434467',
    projectId: 'dealgo-fd862',
    storageBucket: 'dealgo-fd862.firebasestorage.app',
    iosBundleId: 'com.nguyenngoctien.dealgo',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAHSrqKadeXYKJsUWDTi0DdELEnzG2__Ug',
    appId: '1:218651434467:android:45404496e9d2b49a8594d6',
    messagingSenderId: '218651434467',
    projectId: 'dealgo-fd862',
    storageBucket: 'dealgo-fd862.firebasestorage.app',
  );
}
