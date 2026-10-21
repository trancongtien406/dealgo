enum AppRole {
  customer('/customer', 'CUSTOMER'),
  merchant('/merchant', 'MERCHANT'),
  driver('/driver', 'DRIVER');

  const AppRole(this.homePath, this.grantName);

  final String homePath;
  final String grantName;

  static AppRole? fromGrant(String role) {
    for (final value in AppRole.values) {
      if (value.grantName == role) {
        return value;
      }
    }
    return null;
  }
}

String entryPathFor(List<AppRole> roles) {
  if (roles.length > 1) {
    return '/roles';
  }
  if (roles.length == 1) {
    return roles.single.homePath;
  }
  return AppRole.customer.homePath;
}

bool shellAllows(String path, List<AppRole> roles) {
  // Partner onboarding is available before DRIVER/MERCHANT grants become ACTIVE.
  if (path.startsWith('/driver/kyc') || path.startsWith('/merchant/kyb')) {
    return true;
  }
  final allowed = roles.isEmpty ? const [AppRole.customer] : roles;
  for (final role in allowed) {
    if (path == role.homePath || path.startsWith('${role.homePath}/')) {
      return true;
    }
  }
  return false;
}
