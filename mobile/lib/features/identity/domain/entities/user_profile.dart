import 'app_role.dart';

class RoleGrant {
  const RoleGrant({required this.role, required this.status});

  final String role;
  final String status;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.email,
    required this.phoneVerifiedAt,
    required this.emailVerifiedAt,
    required this.grants,
  });

  final String id;
  final String? phone;
  final String? email;
  final String? phoneVerifiedAt;
  final String? emailVerifiedAt;
  final List<RoleGrant> grants;

  List<AppRole> get activeAppRoles {
    final selected = <AppRole>{};
    for (final grant in grants) {
      if (grant.status != 'ACTIVE') {
        continue;
      }
      final role = AppRole.fromGrant(grant.role);
      if (role != null) {
        selected.add(role);
      }
    }
    return AppRole.values.where(selected.contains).toList(growable: false);
  }

  String? grantStatus(AppRole role) {
    String? best;
    for (final grant in grants) {
      if (grant.role != role.grantName) {
        continue;
      }
      if (grant.status == 'ACTIVE') {
        return 'ACTIVE';
      }
      best ??= grant.status;
    }
    return best;
  }

  bool hasActiveGrant(AppRole role) => grantStatus(role) == 'ACTIVE';

  bool needsPartnerOnboarding(AppRole role) {
    if (role == AppRole.customer) {
      return false;
    }
    final status = grantStatus(role);
    return status == null || status == 'PENDING' || status == 'REJECTED';
  }

  @override
  String toString() => 'UserProfile($id)';
}
