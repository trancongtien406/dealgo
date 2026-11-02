import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/core/network/request_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('t90u: car-docs 403 is recognised, other 403s are not', () {
    expect(
      isCarDocsRequired(
        const ApiException(
          statusCode: 403,
          message: 'Car KYC documents required: VEHICLE_INSURANCE',
          errorCode: 'PARTNER_KYC_REQUIRED',
          details: {'reason': 'CAR_DOCS_REQUIRED'},
        ),
      ),
      isTrue,
    );
    expect(
      isCarDocsRequired(
        const ApiException(
          statusCode: 403,
          message: 'Forbidden',
          errorCode: 'PARTNER_KYC_REQUIRED',
        ),
      ),
      isFalse,
    );
    expect(isCarDocsRequired(Exception('x')), isFalse);
  });
}
