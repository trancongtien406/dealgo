import 'package:dealgo/core/permissions/app_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Deterministic [AppPermissionService] for widget tests (no OS prompts).
class FakeAppPermissionService extends AppPermissionService {
  FakeAppPermissionService({
    Map<Permission, PermissionStatus>? initial,
    this.grantOnRequest = true,
  }) : _statuses = {
         Permission.locationWhenInUse: PermissionStatus.denied,
         Permission.notification: PermissionStatus.denied,
         Permission.microphone: PermissionStatus.denied,
         Permission.camera: PermissionStatus.denied,
         Permission.photos: PermissionStatus.denied,
         ...?initial,
       };

  final Map<Permission, PermissionStatus> _statuses;
  final bool grantOnRequest;
  final List<Permission> requested = <Permission>[];

  @override
  Future<PermissionStatus> status(Permission permission) async {
    return _statuses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> request(Permission permission) async {
    requested.add(permission);
    final next = grantOnRequest
        ? PermissionStatus.granted
        : PermissionStatus.denied;
    _statuses[permission] = next;
    return next;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestMany(
    List<Permission> permissions,
  ) async {
    final result = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      result[permission] = await request(permission);
    }
    return result;
  }

  @override
  Future<bool> ensureLocationWhenInUse() async {
    final status = await request(Permission.locationWhenInUse);
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> ensureCamera() async {
    final status = await request(Permission.camera);
    return status.isGranted;
  }

  @override
  Future<bool> ensureMicrophone() async {
    final status = await request(Permission.microphone);
    return status.isGranted;
  }

  @override
  Future<bool> ensurePhotos() async {
    final status = await request(Permission.photos);
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> ensureNotifications() async {
    final status = await request(Permission.notification);
    return status.isGranted;
  }

  @override
  Future<void> promptLaunchPermissions() async {
    await request(Permission.locationWhenInUse);
    await request(Permission.notification);
  }

  @override
  Future<bool> openAppSettingsPage() async => true;
}
