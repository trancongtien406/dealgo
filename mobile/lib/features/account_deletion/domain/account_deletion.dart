/// S027 account deletion (DEC-PROD-037): request → re-auth → soft-delete → purge after grace.
/// Re-auth the server picked from the sign-in methods that are on (passkey first).
enum AccountDeletionMethod { passkey, phoneOtp, password }

/// Why the server refuses to delete right now (codes from the backend).
class AccountDeletionBlocker {
  const AccountDeletionBlocker({
    required this.code,
    this.count,
    this.amountVnd,
  });

  final String code;
  final int? count;
  final int? amountVnd;

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionBlocker &&
      other.code == code &&
      other.count == count &&
      other.amountVnd == amountVnd;

  @override
  int get hashCode => Object.hash(code, count, amountVnd);
}

class AccountDeletionOverview {
  const AccountDeletionOverview({
    required this.status,
    required this.graceDays,
    required this.method,
    required this.phoneMasked,
    required this.blockers,
  });

  /// NONE | PENDING | SCHEDULED | CANCELLED | PURGED
  final String status;
  final int graceDays;

  /// Null when no enabled sign-in method can re-verify this account.
  final AccountDeletionMethod? method;
  final String? phoneMasked;
  final List<AccountDeletionBlocker> blockers;
}

class AccountDeletionChallenge {
  const AccountDeletionChallenge({
    required this.requestId,
    required this.method,
    required this.phoneMasked,
    required this.graceDays,
    this.passkeyOptions,
  });

  final String requestId;
  final AccountDeletionMethod method;
  final String? phoneMasked;
  final int graceDays;

  /// WebAuthn request options for the native passkey prompt (method = passkey).
  final Map<String, Object?>? passkeyOptions;
}

class AccountDeletionScheduled {
  const AccountDeletionScheduled({
    required this.purgeAfter,
    required this.graceDays,
  });

  final DateTime purgeAfter;
  final int graceDays;
}

abstract interface class AccountDeletionRepository {
  Future<AccountDeletionOverview> overview({required String accessToken});

  /// Throws ApiException `ACCOUNT_DELETION_BLOCKED` (details.blockers) when not allowed.
  Future<AccountDeletionChallenge> start({required String accessToken});

  Future<AccountDeletionScheduled> confirm({
    required String accessToken,
    required String requestId,
    String? code,
    String? password,
    Map<String, Object?>? passkey,
  });
}

/// Parses `details.blockers` / `blockers` arrays from the API.
List<AccountDeletionBlocker> decodeAccountDeletionBlockers(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map && item['code'] is String)
        AccountDeletionBlocker(
          code: item['code'] as String,
          count: item['count'] is num ? (item['count'] as num).toInt() : null,
          amountVnd: item['amountVnd'] is num
              ? (item['amountVnd'] as num).toInt()
              : null,
        ),
  ];
}

AccountDeletionMethod? decodeAccountDeletionMethod(Object? raw) =>
    switch (raw) {
      'PASSKEY' => AccountDeletionMethod.passkey,
      'PHONE_OTP' => AccountDeletionMethod.phoneOtp,
      'PASSWORD' => AccountDeletionMethod.password,
      _ => null,
    };
