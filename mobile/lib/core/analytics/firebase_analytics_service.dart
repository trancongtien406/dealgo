import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'analytics_port.dart';

/// Firebase Analytics implementation of [AnalyticsPort].
/// Soft-fails when Firebase is not initialized so tests or mock runs never throw.
class FirebaseAnalyticsService implements AnalyticsPort {
  FirebaseAnalyticsService._();

  static final FirebaseAnalyticsService instance = FirebaseAnalyticsService._();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  bool get isReady => Firebase.apps.isNotEmpty;

  FirebaseAnalytics get analytics {
    return _analytics ??= FirebaseAnalytics.instance;
  }

  /// GoRouter / Navigator observer that automatically logs page views.
  FirebaseAnalyticsObserver get navigationObserver {
    return _observer ??= FirebaseAnalyticsObserver(analytics: analytics);
  }

  /// Initialize and configure analytics collection.
  Future<void> init() async {
    if (!isReady) return;
    try {
      await analytics.setAnalyticsCollectionEnabled(true);
      if (kDebugMode) {
        debugPrint('[Analytics] Firebase Analytics initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] Firebase Analytics init error: $e');
      }
    }
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (kDebugMode) {
      debugPrint('[Analytics:event] $name $parameters');
    }
    if (!isReady) return;

    try {
      final sanitized = <String, Object>{};
      for (final entry in parameters.entries) {
        final val = entry.value;
        if (val == null) continue;
        if (val is String || val is num) {
          sanitized[entry.key] = val;
        } else {
          sanitized[entry.key] = val.toString();
        }
      }

      await analytics.logEvent(
        name: name,
        parameters: sanitized.isEmpty ? null : sanitized,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] Failed to logEvent $name: $e');
      }
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    if (kDebugMode) {
      debugPrint('[Analytics:userId] $userId');
    }
    if (!isReady) return;
    try {
      await analytics.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] Failed to setUserId: $e');
      }
    }
  }

  /// Set user role property ('customer', 'merchant', 'driver').
  Future<void> setUserRole(String? role) async {
    if (kDebugMode) {
      debugPrint('[Analytics:userRole] $role');
    }
    if (!isReady || role == null) return;
    try {
      await analytics.setUserProperty(name: 'user_role', value: role);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] Failed to setUserRole: $e');
      }
    }
  }

  /// Log user authentication method (phone, email, apple, google, passkey).
  Future<void> logLogin({required String method}) async {
    await logEvent('login', parameters: {'method': method});
  }

  /// Log user registration.
  Future<void> logSignUp({required String method}) async {
    await logEvent('sign_up', parameters: {'method': method});
  }

  /// Log ride requested.
  Future<void> logRideRequested({
    required String vehicleClass,
    required int fareVnd,
    double? distanceKm,
  }) async {
    await logEvent(
      'ride_requested',
      parameters: {
        'vehicle_class': vehicleClass,
        'fare_vnd': fareVnd,
        'distance_km': ?distanceKm,
      },
    );
  }

  /// Log food order placed.
  Future<void> logFoodOrderPlaced({
    required String orderId,
    required int totalVnd,
    int? itemCount,
  }) async {
    await logEvent(
      'food_order_placed',
      parameters: {
        'order_id': orderId,
        'value': totalVnd,
        'currency': 'VND',
        'item_count': ?itemCount,
      },
    );
  }
}
