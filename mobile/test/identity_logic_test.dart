import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_envelope.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/core/network/dio_mapper.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/phone_input.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_identity_client.dart';

void main() {
  test('national phone input becomes E.164', () {
    expect(e164FromNationalInput('987654321'), '+84987654321');
    expect(e164FromNationalInput('0987654321'), '+84987654321');
    expect(e164FromNationalInput('84 987 654 321'), '+84987654321');
    expect(e164FromNationalInput('123'), isNull);
    expect(formatDisplayPhone('+84987654321'), '+84 987 654 321');
  });

  test('active grants map to shells and ignore ops or pending', () {
    expect(multiRoleProfile.activeAppRoles, [
      AppRole.customer,
      AppRole.merchant,
      AppRole.driver,
    ]);
    expect(sandboxProfile.activeAppRoles, isEmpty);
    expect(entryPathFor(sandboxProfile.activeAppRoles), '/customer');
    expect(entryPathFor(customerProfile.activeAppRoles), '/customer');
    expect(entryPathFor(multiRoleProfile.activeAppRoles), '/roles');
  });

  test('redirect sends signed-out users to login and signed-in users home', () {
    const restoring = AuthRestoring();
    const signedOut = AuthSignedOut();
    final customer = AuthSignedIn(tokens: _tokens, profile: customerProfile);
    final many = AuthSignedIn(tokens: _tokens, profile: multiRoleProfile);
    final sandbox = AuthSignedIn(tokens: _tokens, profile: sandboxProfile);

    expect(authRedirect(restoring, Uri.parse('/customer')), '/login');
    expect(authRedirect(restoring, Uri.parse('/login')), isNull);
    expect(authRedirect(signedOut, Uri.parse('/customer')), '/login');
    expect(authRedirect(signedOut, Uri.parse('/login')), isNull);
    expect(
      authRedirect(
        signedOut,
        Uri.parse('/login/otp?challengeId=abc&phone=%2B84987654321'),
      ),
      isNull,
    );
    expect(authRedirect(signedOut, Uri.parse('/login/otp')), '/login');
    expect(authRedirect(customer, Uri.parse('/login')), '/customer');
    expect(authRedirect(sandbox, Uri.parse('/login/otp')), '/customer');
    expect(authRedirect(sandbox, Uri.parse('/merchant')), '/customer');
    expect(authRedirect(many, Uri.parse('/login')), '/roles');
    expect(authRedirect(many, Uri.parse('/roles')), isNull);
    expect(authRedirect(many, Uri.parse('/driver/jobs')), isNull);
    expect(authRedirect(customer, Uri.parse('/roles')), '/customer');
    expect(authRedirect(customer, Uri.parse('/driver')), '/customer');
  });

  test('error envelope keeps the API errorCode', () {
    final data = requireSuccessData({
      'success': true,
      'statusCode': 200,
      'message': 'OK',
      'data': {'challengeId': 'abc', 'expiresAt': '2026-10-13T00:00:00.000Z'},
    });
    expect(data['challengeId'], 'abc');

    final parsed = apiExceptionFromDio(
      DioException(
        requestOptions: RequestOptions(
          path: '/v1/auth/phone/challenges/x/verify',
        ),
        response: Response(
          requestOptions: RequestOptions(
            path: '/v1/auth/phone/challenges/x/verify',
          ),
          statusCode: 401,
          data: {
            'success': false,
            'statusCode': 401,
            'message': 'Verification code is invalid',
            'errorCode': 'AUTH_CODE_INVALID',
            'timestamp': '2026-10-13T00:00:00.000Z',
            'path': '/v1/auth/phone/challenges/x/verify',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(parsed, isA<ApiException>());
    expect(parsed.statusCode, 401);
    expect(parsed.errorCode, 'AUTH_CODE_INVALID');
    expect(parsed.message, 'Verification code is invalid');
  });
}

const _tokens = StoredTokens(accessToken: 'access', refreshToken: 'refresh');
