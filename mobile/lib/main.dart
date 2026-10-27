import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/dealgo_app.dart';
import 'core/design_system/components/dealgo_nav_insets.dart';
import 'core/auth/secure_token_store.dart';
import 'core/auth/token_store.dart';
import 'core/config/app_env.dart';
import 'core/mock/mock_seed.dart';
import 'core/observability/crash_reporting.dart';
import 'core/push/fcm_push.dart';
import 'core/storage/customer_booking_prefs.dart';
import 'firebase_options.dart';

Future<void> main() => runWithCrashReporting(_start);

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  enableAndroidEdgeToEdge();
  await CustomerBookingPrefs.warmUp();
  await _initFirebaseSafely();
  await _maybeSeedSmokeSession();

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

/// Local smoke only: inject seed session via `--dart-define=SMOKE_ACCESS_TOKEN=` /
/// `SMOKE_REFRESH_TOKEN=` (ignored in release; never invent production secrets).
Future<void> _maybeSeedSmokeSession() async {
  if (kReleaseMode) {
    return;
  }
  const access = String.fromEnvironment('SMOKE_ACCESS_TOKEN');
  const refresh = String.fromEnvironment('SMOKE_REFRESH_TOKEN');
  if (access.isEmpty || refresh.isEmpty) {
    return;
  }
  await SecureTokenStore().write(
    StoredTokens(accessToken: access, refreshToken: refresh),
  );
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
