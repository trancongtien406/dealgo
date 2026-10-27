import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = UserProfile(
  id: 'u1',
  phone: '+84901234567',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [],
  displayName: 'Lê Thu Hà',
);

void main() {
  test('driver KYC starts empty and only prefills the real profile name', () {
    final cubit = DriverKycCubit(useMock: true);
    expect(cubit.state.fullName, isEmpty);
    expect(cubit.state.vehiclePlate, isEmpty);
    expect(cubit.state.issues, isEmpty);
    expect(cubit.state.canContinuePersonal, isFalse);

    cubit.seedFromProfile(_profile);
    expect(cubit.state.fullName, 'Lê Thu Hà');
    cubit
      ..setBirthDate('02/03/1990')
      ..setAddress('12 Lê Lợi, Đà Nẵng')
      ..setVehiclePlate('43b1-567.89');
    expect(cubit.state.canContinuePersonal, isTrue);
    expect(cubit.state.vehiclePlate, '43B1-567.89');
    expect(cubit.state.canContinueVehicle, isTrue);
  });

  test('merchant KYB starts empty and requires shop + representative', () {
    final cubit = MerchantKybCubit(useMock: true);
    expect(cubit.state.shopName, isEmpty);
    expect(cubit.state.canContinueShopInfo, isFalse);
    cubit.seedFromProfile(_profile);
    expect(cubit.state.representativeName, 'Lê Thu Hà');
    expect(cubit.state.bankAccountHolder, 'LÊ THU HÀ');
    expect(cubit.state.canContinueRepresentative, isFalse);
    cubit
      ..setBankName('Vietcombank')
      ..setBankAccountNumber('0123456789');
    expect(cubit.state.canContinueRepresentative, isTrue);
    cubit
      ..setShopName('Quán Hà')
      ..setShopAddress('Hải Châu');
    // The map pin is required too.
    expect(cubit.state.canContinueShopInfo, isFalse);
    cubit.setShopPin(lat: 16.06, lng: 108.22, label: 'Hải Châu');
    expect(cubit.state.canContinueShopInfo, isTrue);
  });
}
