import 'app_role.dart';

class RoleGrant {
  const RoleGrant({required this.role, required this.status});

  final String role;
  final String status;
}

/// API gender values: `MALE` | `FEMALE` | `OTHER`.
abstract final class UserGender {
  static const male = 'MALE';
  static const female = 'FEMALE';
  static const other = 'OTHER';

  static const values = [male, female, other];

  static bool isValid(String? value) => value != null && values.contains(value);
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.email,
    required this.phoneVerifiedAt,
    required this.emailVerifiedAt,
    required this.grants,
    this.displayName = '',
    this.dateOfBirth,
    this.gender,
    this.avatarUrl,
    this.needsProfileSetup = false,
  });

  final String id;
  final String? phone;
  final String? email;
  final String displayName;
  final String? dateOfBirth;
  final String? gender;
  final String? avatarUrl;
  final String? phoneVerifiedAt;
  final String? emailVerifiedAt;
  final bool needsProfileSetup;
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

  UserProfile copyWith({
    String? id,
    String? phone,
    String? email,
    String? displayName,
    String? dateOfBirth,
    String? gender,
    String? avatarUrl,
    String? phoneVerifiedAt,
    String? emailVerifiedAt,
    bool? needsProfileSetup,
    List<RoleGrant>? grants,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      needsProfileSetup: needsProfileSetup ?? this.needsProfileSetup,
      grants: grants ?? this.grants,
    );
  }

  @override
  String toString() => 'UserProfile($id)';
}
