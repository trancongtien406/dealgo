import '../../domain/entities/auth_method_policy.dart';

class AuthMethodPolicyModel extends AuthMethodPolicy {
  const AuthMethodPolicyModel({required super.method, required super.enabled});

  factory AuthMethodPolicyModel.fromJson(Map<String, dynamic> json) {
    return AuthMethodPolicyModel(
      method: json['method'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {'method': method, 'enabled': enabled};
}
