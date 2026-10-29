import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin permission_handler wrapper. Call sites own UX copy for rationale/denial.
///
/// Notification prompts prefer [FirebaseMessaging.requestPermission] when
/// Firebase is ready so the OS dialog matches the FCM registration path.
@lazySingleton
class AppPermissionService {
  Future<PermissionStatus> status(Permission permission) async {
    if (permission == Permission.notification) {
      return _notificationStatus();
    }
    return permission.status;
  }

  Future<PermissionStatus> request(Permission permission) async {
    if (permission == Permission.notification) {
      return _requestNotification();
    }
    return permission.request();
  }

  Future<Map<Permission, PermissionStatus>> requestMany(
    List<Permission> permissions,
  ) async {
    final result = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      result[permission] = await request(permission);
    }
    return result;
  }

  Future<bool> ensureLocationWhenInUse() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> ensureMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// One OS photo prompt at a time: a second tap while the first prompt is
  /// open shares its answer instead of throwing "a request is already running"
  /// (permission_handler; Sentry).
  Future<bool> ensurePhotos() => _photosFlight ??= _ensurePhotos().whenComplete(
    () => _photosFlight = null,
  );

  Future<bool>? _photosFlight;

  @visibleForTesting
  Future<PermissionStatus> Function() requestPhotos = () =>
      Permission.photos.request();

  Future<bool> _ensurePhotos() async {
    final status = await requestPhotos();
    return status.isGranted || status.isLimited;
  }

  Future<bool> ensureNotifications() async {
    final status = await _requestNotification();
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  /// OS dialogs only (location + notifications). Mic is requested when calling.
  Future<void> promptLaunchPermissions() async {
    await request(Permission.locationWhenInUse);
    await request(Permission.notification);
  }

  Future<bool> openAppSettingsPage() => openAppSettings();

  Future<PermissionStatus> _notificationStatus() async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        return _mapAuthorization(settings.authorizationStatus);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('FCM getNotificationSettings failed: $error');
        }
      }
    }
    return Permission.notification.status;
  }

  Future<PermissionStatus> _requestNotification() async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (kDebugMode) {
          debugPrint(
            'Notification permission: ${settings.authorizationStatus}',
          );
        }
        return _mapAuthorization(settings.authorizationStatus);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('FCM requestPermission failed: $error');
        }
      }
    }
    return Permission.notification.request();
  }

  PermissionStatus _mapAuthorization(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return PermissionStatus.granted;
      case AuthorizationStatus.provisional:
        return PermissionStatus.provisional;
      case AuthorizationStatus.denied:
        return PermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return PermissionStatus.denied;
      case AuthorizationStatus.deniedPermanently:
        return PermissionStatus.permanentlyDenied;
    }
  }
}
