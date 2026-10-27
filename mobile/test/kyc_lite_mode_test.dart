import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver: KYC off -> lite steps, fail-closed default', () async {
    final on = DriverKycCubit(useMock: false);
    expect(on.state.documentsRequired, isTrue);
    final off = DriverKycCubit(
      useMock: false,
      accessToken: () => 't',
      loadDocumentsRequired: ({required accessToken, required role}) async =>
          false,
    );
    await off.loadRequirements();
    expect(off.state.documentsRequired, isFalse);
    expect(off.state.totalSteps, lessThan(on.state.totalSteps));
    expect(off.state.steps, isNot(contains(DriverKycStep.selfie)));
  });

  test('merchant: KYB off -> 3 steps, submit needs only shop info', () async {
    final c = MerchantKybCubit(
      useMock: false,
      accessToken: () => 't',
      loadDocumentsRequired: ({required accessToken, required role}) async =>
          false,
    );
    await c.loadRequirements();
    expect(c.state.totalSteps, 3);
    expect(c.state.canSubmit, isFalse);
  });
}
