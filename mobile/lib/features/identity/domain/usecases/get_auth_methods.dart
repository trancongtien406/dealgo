import '../entities/auth_method_policy.dart';
import '../repositories/identity_repository.dart';

class GetAuthMethods {
  const GetAuthMethods(this._repository);

  final IdentityRepository _repository;

  Future<List<AuthMethodPolicy>> call() => _repository.getAuthMethods();
}
