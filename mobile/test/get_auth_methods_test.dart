import 'package:dealgo/features/identity/data/models/auth_method_policy_model.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/auth_method_policy.dart';
import 'package:dealgo/features/identity/domain/usecases/get_auth_methods.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_identity_client.dart';

void main() {
  group('GetAuthMethods', () {
    test('calls repository to retrieve auth method policies', () async {
      final fakeClient = FakeIdentityClient();
      fakeClient.authMethods = const [
        AuthMethodPolicyModel(method: AuthMethodPolicy.passkey, enabled: true),
        AuthMethodPolicyModel(method: AuthMethodPolicy.phoneSms, enabled: true),
        AuthMethodPolicyModel(method: AuthMethodPolicy.email, enabled: false),
      ];
      final repository = IdentityRepositoryImpl(fakeClient);
      final usecase = GetAuthMethods(repository);

      final methods = await usecase();
      expect(methods, hasLength(3));
      expect(methods[0].method, AuthMethodPolicy.passkey);
      expect(methods[0].isPasskey, isTrue);
      expect(methods[0].enabled, isTrue);

      expect(methods[1].method, AuthMethodPolicy.phoneSms);
      expect(methods[1].isPhoneSms, isTrue);
      expect(methods[1].enabled, isTrue);

      expect(methods[2].method, AuthMethodPolicy.email);
      expect(methods[2].isEmail, isTrue);
      expect(methods[2].enabled, isFalse);
    });

    test('AuthMethodPolicyModel handles json mapping correctly', () {
      final json = {'method': 'PASSKEY', 'enabled': true};
      final model = AuthMethodPolicyModel.fromJson(json);

      expect(model.method, 'PASSKEY');
      expect(model.enabled, isTrue);
      expect(model.toJson(), equals(json));
    });
  });
}
