import 'dart:async';

import '../../features/identity/data/datasources/identity_remote_datasource.dart';
import '../../features/identity/data/models/phone_challenge_model.dart';
import '../../features/identity/data/models/user_profile_model.dart';
import '../../features/identity/data/models/verified_session_model.dart';
import '../../features/identity/domain/entities/user_profile.dart';
import '../network/api_exception.dart';

class FakeIdentityClient implements IdentityClient {
  FakeIdentityClient({UserProfile? profile, this.verifyError})
    : profile = profile ?? customerProfile;

  UserProfile profile;
  ApiException? verifyError;
  Completer<void>? challengeGate;
  final List<String> challengedPhones = [];
  final List<({String challengeId, String code})> verifyCalls = [];
  final List<String> refreshCalls = [];

  @override
  Future<PhoneChallengeModel> createPhoneChallenge(String phone) async {
    challengedPhones.add(phone);
    final gate = challengeGate;
    if (gate != null) {
      await gate.future;
    }
    return const PhoneChallengeModel(
      challengeId: 'challenge-1',
      expiresAt: '2026-10-13T16:05:00.000Z',
    );
  }

  @override
  Future<VerifiedSessionModel> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  }) async {
    verifyCalls.add((challengeId: challengeId, code: code));
    final error = verifyError;
    if (error != null) {
      throw error;
    }
    return const VerifiedSessionModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }

  @override
  Future<VerifiedSessionModel> refreshSession(String refreshToken) async {
    refreshCalls.add(refreshToken);
    return VerifiedSessionModel(
      accessToken: 'access-token-refreshed',
      refreshToken: '$refreshToken-rotated',
      expiresIn: 900,
    );
  }

  @override
  Future<UserProfileModel> fetchMe(String accessToken) async {
    return UserProfileModel.fromEntity(profile);
  }
}

const customerProfile = UserProfile(
  id: 'user-1',
  phone: '+84911111111',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'CUSTOMER', status: 'ACTIVE')],
);

const sandboxProfile = UserProfile(
  id: 'user-2',
  phone: '+84922222222',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [],
);

const multiRoleProfile = UserProfile(
  id: 'user-3',
  phone: '+84987654321',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [
    RoleGrant(role: 'DRIVER', status: 'ACTIVE'),
    RoleGrant(role: 'MERCHANT', status: 'ACTIVE'),
    RoleGrant(role: 'CUSTOMER', status: 'ACTIVE'),
    RoleGrant(role: 'OPS', status: 'ACTIVE'),
    RoleGrant(role: 'CUSTOMER', status: 'PENDING'),
  ],
);

const demoMultiRoleProfile = UserProfile(
  id: 'demo-user',
  phone: '+84900000000',
  email: 'demo@dealgo.local',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: '2026-10-13T16:00:00.000Z',
  grants: [
    RoleGrant(role: 'CUSTOMER', status: 'ACTIVE'),
    RoleGrant(role: 'DRIVER', status: 'ACTIVE'),
    RoleGrant(role: 'MERCHANT', status: 'ACTIVE'),
  ],
);

const pendingPartnerProfile = UserProfile(
  id: 'pending-partner',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [
    RoleGrant(role: 'CUSTOMER', status: 'ACTIVE'),
    RoleGrant(role: 'DRIVER', status: 'PENDING'),
    RoleGrant(role: 'MERCHANT', status: 'PENDING'),
  ],
);
