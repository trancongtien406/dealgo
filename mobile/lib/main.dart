import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/dealgo_app.dart';
import 'core/auth/token_store.dart';
import 'core/config/app_env.dart';
import 'core/mock/mock_seed.dart';
import 'core/push/fcm_push.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebaseSafely();

  if (useMockData) {
    if (kReleaseMode) {
      throw StateError('USE_MOCK_DATA is not allowed in release builds');
    }
    final mocks = createSeededMockClients();
    runApp(
      DealGoApp(
        identityClient: mocks.identity,
        foodClient: mocks.food,
        rideClient: mocks.ride,
        tokenStore: MemoryTokenStore(),
      ),
    );
    return;
  }
  runApp(const DealGoApp());
}

/// Soft-fail Firebase + FCM bootstrap so missing keys never crash cold start.
Future<void> _initFirebaseSafely() async {
  if (useMockData) {
    return;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await configureFcmMessaging();
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Firebase init skipped: $error');
      debugPrint('$stack');
    }
  }
}
