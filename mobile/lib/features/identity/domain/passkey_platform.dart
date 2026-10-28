/// Why a passkey ceremony did not complete (S025 enrolment shows a calm message for each).
enum PasskeyFailureKind { cancelled, unsupported, alreadyRegistered, failed }

class PasskeyPlatformException implements Exception {
  const PasskeyPlatformException(this.kind, [this.detail]);

  final PasskeyFailureKind kind;
  final String? detail;

  @override
  String toString() =>
      'PasskeyPlatformException($kind${detail == null ? '' : ': $detail'})';
}

/// Platform WebAuthn / passkey authenticator boundary.
///
/// Production builds use a device adapter; tests and mock mode use
/// [FakePasskeyPlatform] so flows complete without real WebAuthn.
abstract interface class PasskeyPlatform {
  /// Completes an authentication ceremony from server public-key options.
  ///
  /// [options] is the JSON object from
  /// `POST /v1/auth/passkeys/authentication/options` (`data` payload).
  /// Returns an AuthenticationResponseJSON-compatible map for verify.
  Future<Map<String, Object?>> authenticate(Map<String, Object?> options);

  /// Creates a passkey from `POST /v1/auth/passkeys/registration/options` and returns a
  /// RegistrationResponseJSON-compatible map for verify. Throws [PasskeyPlatformException].
  Future<Map<String, Object?>> register(Map<String, Object?> options);
}

/// Deterministic assertion for widget/unit tests and mock identity clients.
class FakePasskeyPlatform implements PasskeyPlatform {
  FakePasskeyPlatform({this.credentialId = 'fake-passkey-credential'});

  final String credentialId;
  final List<Map<String, Object?>> authenticateCalls = [];
  final List<Map<String, Object?>> registerCalls = [];

  /// Set to simulate a device that cannot (or will not) create the passkey.
  PasskeyFailureKind? registerFailure;

  /// Set to simulate a cancelled or failed system prompt on the next assertions.
  PasskeyFailureKind? authenticateFailure;

  @override
  Future<Map<String, Object?>> register(Map<String, Object?> options) async {
    registerCalls.add(Map<String, Object?>.from(options));
    final failure = registerFailure;
    if (failure != null) {
      throw PasskeyPlatformException(failure);
    }
    return {
      'id': credentialId,
      'rawId': credentialId,
      'type': 'public-key',
      'response': <String, Object?>{
        'clientDataJSON': 'fake-client-data',
        'attestationObject': 'fake-attestation',
        'transports': <String>['internal'],
      },
      'clientExtensionResults': <String, Object?>{},
    };
  }

  @override
  Future<Map<String, Object?>> authenticate(
    Map<String, Object?> options,
  ) async {
    authenticateCalls.add(Map<String, Object?>.from(options));
    final failure = authenticateFailure;
    if (failure != null) {
      throw PasskeyPlatformException(failure);
    }
    return {
      'id': credentialId,
      'rawId': credentialId,
      'type': 'public-key',
      'response': <String, Object?>{
        'clientDataJSON': 'fake-client-data',
        'authenticatorData': 'fake-authenticator-data',
        'signature': 'fake-signature',
        'userHandle': 'fake-user-handle',
      },
      'clientExtensionResults': <String, Object?>{},
    };
  }
}

/// Explicit unavailable adapter for environments that cannot host WebAuthn.
class UnsupportedPasskeyPlatform implements PasskeyPlatform {
  const UnsupportedPasskeyPlatform();

  @override
  Future<Map<String, Object?>> authenticate(Map<String, Object?> options) {
    throw StateError(
      'Passkey authentication is not available on this platform',
    );
  }

  @override
  Future<Map<String, Object?>> register(Map<String, Object?> options) {
    throw const PasskeyPlatformException(PasskeyFailureKind.unsupported);
  }
}
