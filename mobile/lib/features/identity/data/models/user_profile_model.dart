import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_profile.dart';

class RoleGrantModel {
  const RoleGrantModel({required this.role, required this.status});

  final String role;
  final String status;

  factory RoleGrantModel.fromJson(Map<String, Object?> json) {
    final role = json['role'];
    final status = json['status'];
    if (role is! String || status is! String) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return RoleGrantModel(role: role, status: status);
  }

  Map<String, Object?> toJson() => {'role': role, 'status': status};

  RoleGrant toEntity() => RoleGrant(role: role, status: status);
}

class UserProfileModel {
  const UserProfileModel({
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
  final List<RoleGrantModel> grants;

  factory UserProfileModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return UserProfileModel(
      id: id,
      phone: _nullableString(json['phone']),
      email: _nullableString(json['email']),
      displayName: _nullableString(json['displayName']) ?? '',
      dateOfBirth: _nullableString(json['dateOfBirth']),
      gender: _nullableString(json['gender']),
      avatarUrl: _nullableString(json['avatarUrl']),
      phoneVerifiedAt: _nullableString(json['phoneVerifiedAt']),
      emailVerifiedAt: _nullableString(json['emailVerifiedAt']),
      needsProfileSetup: json['needsProfileSetup'] == true,
      grants: _decodeGrants(json['grants']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'displayName': displayName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'avatarUrl': avatarUrl,
      'phoneVerifiedAt': phoneVerifiedAt,
      'emailVerifiedAt': emailVerifiedAt,
      'needsProfileSetup': needsProfileSetup,
      'grants': [for (final grant in grants) grant.toJson()],
    };
  }

  factory UserProfileModel.fromEntity(UserProfile entity) {
    return UserProfileModel(
      id: entity.id,
      phone: entity.phone,
      email: entity.email,
      displayName: entity.displayName,
      dateOfBirth: entity.dateOfBirth,
      gender: entity.gender,
      avatarUrl: entity.avatarUrl,
      phoneVerifiedAt: entity.phoneVerifiedAt,
      emailVerifiedAt: entity.emailVerifiedAt,
      needsProfileSetup: entity.needsProfileSetup,
      grants: [
        for (final grant in entity.grants)
          RoleGrantModel(role: grant.role, status: grant.status),
      ],
    );
  }

  UserProfile toEntity() {
    return UserProfile(
      id: id,
      phone: phone,
      email: email,
      displayName: displayName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      avatarUrl: avatarUrl,
      phoneVerifiedAt: phoneVerifiedAt,
      emailVerifiedAt: emailVerifiedAt,
      needsProfileSetup: needsProfileSetup,
      grants: List.unmodifiable([for (final grant in grants) grant.toEntity()]),
    );
  }

  static List<RoleGrantModel> _decodeGrants(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final grants = <RoleGrantModel>[];
    for (final item in raw) {
      final map = asJsonMap(item);
      if (map == null) {
        continue;
      }
      final role = map['role'];
      final status = map['status'];
      if (role is String && status is String) {
        grants.add(RoleGrantModel(role: role, status: status));
      }
    }
    return List.unmodifiable(grants);
  }
}

String? _nullableString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
