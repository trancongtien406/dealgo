import 'package:dealgo/features/onboarding/data/datasources/fake_partner_applications_client.dart';
import 'package:dealgo/features/onboarding/data/models/partner_application_body.dart';
import 'package:dealgo/features/onboarding/data/repositories/partner_applications_repository_impl.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_application.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_onboarding.dart';
import 'package:dealgo/features/onboarding/domain/usecases/submit_partner_application.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver kyc submit calls partner API when not mock', () async {
    final partners = FakePartnerApplicationsClient();
    final cubit =
        DriverKycCubit(
            submitPartnerApplication: SubmitPartnerApplication(
              PartnerApplicationsRepositoryImpl(partners),
            ),
            accessToken: () => 'access-token',
            useMock: false,
          )
          // Fail closed: submit requires an explicit vehicle class (DG-DEC-VEH-001).
          ..setVehicleClass(code: 'MOTORBIKE', name: 'Xe máy')
          ..goToStep(DriverKycStep.review);

    await cubit.submit();

    expect(partners.submitCalls, hasLength(1));
    expect(partners.submitCalls.single.role, 'DRIVER');
    expect(cubit.state.status, PartnerApplicationStatus.pending);
    expect(cubit.state.submitting, isFalse);
  });

  test('merchant kyb mock path skips partner API', () async {
    final partners = FakePartnerApplicationsClient();
    final cubit = MerchantKybCubit(
      submitPartnerApplication: SubmitPartnerApplication(
        PartnerApplicationsRepositoryImpl(partners),
      ),
      accessToken: () => 'access-token',
      useMock: true,
    )..goToStep(MerchantKybStep.review);

    await cubit.submit();

    expect(partners.submitCalls, isEmpty);
    expect(cubit.state.status, PartnerApplicationStatus.pending);
  });

  test('submit request serializes role and metadata', () {
    const request = SubmitPartnerApplicationRequest(
      accessToken: 't',
      role: 'MERCHANT',
      metadata: {'shopName': 'Demo'},
    );
    expect(partnerApplicationBodyJson(request), {
      'role': 'MERCHANT',
      'metadata': {'shopName': 'Demo'},
    });
  });
}
