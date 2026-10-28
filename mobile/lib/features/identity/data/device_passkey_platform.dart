import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../domain/passkey_platform.dart';

/// Production WebAuthn authenticator backed by the `passkeys` plugin.
class DevicePasskeyPlatform implements PasskeyPlatform {
  DevicePasskeyPlatform({PasskeyAuthenticator? authenticator})
    : _authenticator = authenticator ?? PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  @override
  Future<Map<String, Object?>> authenticate(Map<String, Object?> options) =>
      _guard(() async {
        final request = AuthenticateRequestType.fromJson(
          _asStringKeyedMap(options),
          mediation: MediationType.Optional,
          preferImmediatelyAvailableCredentials: false,
        );
        final response = await _authenticator.authenticate(request);
        return _asObjectMap(response.toJson());
      });

  @override
  Future<Map<String, Object?>> register(Map<String, Object?> options) => _guard(
    () async {
      final request = RegisterRequestType.fromJson(_asStringKeyedMap(options));
      final response = await _authenticator.register(request);
      return _asObjectMap(response.toJson());
    },
  );

  /// Maps plugin errors to [PasskeyPlatformException] so callers can stay calm on cancel.
  Future<Map<String, Object?>> _guard(
    Future<Map<String, Object?>> Function() ceremony,
  ) async {
    try {
      return await ceremony();
    } on PasskeyAuthCancelledException {
      throw const PasskeyPlatformException(PasskeyFailureKind.cancelled);
    } on ExcludeCredentialsCanNotBeRegisteredException {
      throw const PasskeyPlatformException(
        PasskeyFailureKind.alreadyRegistered,
      );
    } on DeviceNotSupportedException {
      throw const PasskeyPlatformException(PasskeyFailureKind.unsupported);
    } on PasskeyUnsupportedException catch (error) {
      throw PasskeyPlatformException(PasskeyFailureKind.unsupported, '$error');
    } on MissingGoogleSignInException {
      throw const PasskeyPlatformException(
        PasskeyFailureKind.unsupported,
        'google-sign-in',
      );
    } on SyncAccountNotAvailableException {
      throw const PasskeyPlatformException(
        PasskeyFailureKind.unsupported,
        'sync-account',
      );
    } on NoCreateOptionException catch (error) {
      throw PasskeyPlatformException(PasskeyFailureKind.unsupported, '$error');
    } on DomainNotAssociatedException catch (error) {
      // App ↔ domain association (assetlinks / apple-app-site-association) is missing.
      throw PasskeyPlatformException(PasskeyFailureKind.unsupported, '$error');
    } on MissingPluginException {
      throw const PasskeyPlatformException(
        PasskeyFailureKind.unsupported,
        'no-plugin',
      );
    } on AuthenticatorException catch (error) {
      throw PasskeyPlatformException(PasskeyFailureKind.failed, '$error');
    } on PlatformException catch (error) {
      throw PasskeyPlatformException(PasskeyFailureKind.failed, error.code);
    } on FormatException catch (error) {
      throw PasskeyPlatformException(PasskeyFailureKind.failed, error.message);
    }
  }

  Map<String, dynamic> _asStringKeyedMap(Map<String, Object?> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  Map<String, Object?> _asObjectMap(Map<String, dynamic> source) {
    return Map<String, Object?>.from(
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>,
    );
  }
}
