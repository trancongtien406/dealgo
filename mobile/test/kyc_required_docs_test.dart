import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

// KYB needs the food-safety certificate; licence class must cover the vehicle.
void main() {
  test('merchant checklist requires the food-safety certificate', () {
    expect(
      PartnerDocumentKind.merchantRequired,
      contains(PartnerDocumentKind.foodSafetyCert),
    );
    expect(
      partnerIssueSectionKinds['BUSINESS_DOCS'],
      contains(PartnerDocumentKind.foodSafetyCert),
    );
  });

  test('licence class covers vehicle class', () {
    expect(PartnerDocumentKind.licenseCoversVehicle('A1', 'MOTORBIKE'), isTrue);
    expect(PartnerDocumentKind.licenseCoversVehicle('A1', 'CAR_4'), isFalse);
    expect(PartnerDocumentKind.licenseCoversVehicle('B', 'CAR_4'), isTrue);
    expect(PartnerDocumentKind.licenseCoversVehicle('b2', 'CAR_7'), isTrue);
    expect(PartnerDocumentKind.licenseCoversVehicle('B', 'MOTORBIKE'), isFalse);
    expect(PartnerDocumentKind.licenseClasses, containsAll(['A1', 'A', 'B']));
  });

  test('vehicle step is blocked when the licence does not cover CAR_4', () {
    final cubit = DriverKycCubit(useMock: true);
    cubit
      ..setLicenseClass('A1')
      ..setVehicleClass(code: 'CAR_4', name: 'Car');
    expect(cubit.state.licenseMatchesVehicle, isFalse);
    cubit.setLicenseClass('B');
    expect(cubit.state.licenseMatchesVehicle, isTrue);
  });

  test('quick mode does not judge the never-asked default licence', () {
    final cubit = DriverKycCubit(useMock: true);
    cubit.emit(cubit.state.copyWith(documentsRequired: false));
    cubit.setVehicleClass(code: 'CAR_4', name: 'Car');
    expect(cubit.state.licenseClass, 'A1');
    expect(cubit.state.licenseMatchesVehicle, isTrue);
  });
}
