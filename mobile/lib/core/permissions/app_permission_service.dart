import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin permission_handler wrapper. Call sites own UX copy for rationale/denial.
@lazySingleton
class AppPermissionService {
  Future<PermissionStatus> status(Permission permission) {
    return permission.status;
  }

  Future<PermissionStatus> request(Permission permission) {
    return permission.request();
  }

  Future<Map<Permission, PermissionStatus>> requestMany(
    List<Permission> permissions,
  ) {
    return permissions.request();
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

  Future<bool> ensurePhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> ensureNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> openAppSettingsPage() => openAppSettings();
}
