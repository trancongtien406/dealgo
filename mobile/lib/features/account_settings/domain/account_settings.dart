class NotificationPrefs {
  const NotificationPrefs({
    required this.ride,
    required this.food,
    required this.chat,
    required this.promotion,
    required this.news,
    this.newJobSound = true,
  });

  final bool ride;
  final bool food;
  final bool chat;
  final bool promotion;
  final bool news;

  /// Driver / merchant: spoken "DealGo, có cuốc mới" on new jobs (off = default sound).
  final bool newJobSound;

  NotificationPrefs copyWith({
    bool? ride,
    bool? food,
    bool? chat,
    bool? promotion,
    bool? news,
    bool? newJobSound,
  }) {
    return NotificationPrefs(
      ride: ride ?? this.ride,
      food: food ?? this.food,
      chat: chat ?? this.chat,
      promotion: promotion ?? this.promotion,
      news: news ?? this.news,
      newJobSound: newJobSound ?? this.newJobSound,
    );
  }

  Map<String, bool> toJson() => {
    'ride': ride,
    'food': food,
    'chat': chat,
    'promotion': promotion,
    'news': news,
    'newJobSound': newJobSound,
  };
}

NotificationPrefs decodeNotificationPrefs(Object? raw) {
  final map = raw is Map<String, dynamic>
      ? raw
      : raw is Map
      ? {for (final e in raw.entries) e.key.toString(): e.value}
      : const <String, dynamic>{};
  bool flag(String key, {required bool fallback}) {
    final value = map[key];
    return value is bool ? value : fallback;
  }

  return NotificationPrefs(
    ride: flag('ride', fallback: true),
    food: flag('food', fallback: true),
    chat: flag('chat', fallback: true),
    promotion: flag('promotion', fallback: false),
    news: flag('news', fallback: false),
    newJobSound: flag('newJobSound', fallback: true),
  );
}

class AccountSession {
  const AccountSession({
    required this.id,
    required this.channel,
    required this.current,
    required this.createdAt,
    required this.lastSeenAt,
    this.deviceLabel,
    this.userAgent,
    this.ipAddress,
  });

  final String id;
  final String channel;
  final bool current;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final String? deviceLabel;
  final String? userAgent;
  final String? ipAddress;
}

List<AccountSession> decodeAccountSessions(Object? raw) {
  final list = raw is List ? raw : const [];
  return [
    for (final entry in list)
      if (entry is Map)
        AccountSession(
          id: '${entry['id']}',
          channel: '${entry['channel'] ?? ''}',
          current: entry['current'] == true,
          createdAt:
              DateTime.tryParse('${entry['createdAt'] ?? ''}') ??
              DateTime.now(),
          lastSeenAt:
              DateTime.tryParse('${entry['lastSeenAt'] ?? ''}') ??
              DateTime.now(),
          deviceLabel: entry['deviceLabel'] as String?,
          userAgent: entry['userAgent'] as String?,
          ipAddress: entry['ipAddress'] as String?,
        ),
  ];
}

/// One passkey bound to the account (no key material). [backedUp] means the
/// platform syncs it (iCloud Keychain / Google Password Manager).
class AccountPasskey {
  const AccountPasskey({
    required this.id,
    required this.createdAt,
    required this.backedUp,
    this.deviceType,
  });

  final String id;
  final DateTime createdAt;
  final bool backedUp;
  final String? deviceType;
}

List<AccountPasskey> decodeAccountPasskeys(Object? raw) {
  final list = raw is List ? raw : const [];
  return [
    for (final entry in list)
      if (entry is Map)
        AccountPasskey(
          id: '${entry['id']}',
          createdAt:
              DateTime.tryParse('${entry['createdAt'] ?? ''}') ??
              DateTime.now(),
          backedUp: entry['backedUp'] == true,
          deviceType: entry['deviceType'] as String?,
        ),
  ];
}

abstract class AccountSettingsRepository {
  Future<NotificationPrefs> notificationPrefs({required String accessToken});
  Future<NotificationPrefs> saveNotificationPrefs({
    required String accessToken,
    required NotificationPrefs prefs,
  });
  Future<List<AccountSession>> sessions({required String accessToken});
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  });
  Future<int> revokeOtherSessions({required String accessToken});
  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  });
  Future<void> updateProfile({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
  });
  Future<void> touchCurrentDevice({
    required String accessToken,
    String? deviceLabel,
  });

  /// S025 passkey enrolment (existing `/v1/auth/passkeys/registration/*` endpoints).
  Future<List<AccountPasskey>> passkeys({required String accessToken});
  Future<void> deletePasskey({
    required String accessToken,
    required String passkeyId,
  });
  Future<Map<String, Object?>> passkeyRegistrationOptions({
    required String accessToken,
  });
  Future<void> verifyPasskeyRegistration({
    required String accessToken,
    required Map<String, Object?> response,
  });
}
