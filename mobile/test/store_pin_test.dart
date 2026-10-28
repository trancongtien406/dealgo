import 'package:dealgo/features/onboarding/data/datasources/fake_partner_applications_client.dart';
import 'package:dealgo/features/onboarding/data/repositories/partner_applications_repository_impl.dart';
import 'package:dealgo/features/onboarding/domain/usecases/submit_partner_application.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Merchant KYB must pin the store; the backend rejects KYB without it.
void main() {
  test('shop info needs a map pin', () {
    final cubit = MerchantKybCubit(useMock: true)
      ..setShopName('Quán Hà')
      ..setShopAddress('12 Lê Lợi, Đà Nẵng');
    expect(cubit.state.canContinueShopInfo, isFalse);
    cubit.setShopPin(lat: 16.06, lng: 108.22, label: 'Ghim');
    expect(cubit.state.canContinueShopInfo, isTrue);
    // A typed address is kept; the pin label only fills an empty one.
    expect(cubit.state.shopAddress, '12 Lê Lợi, Đà Nẵng');
  });

  test('pin fills an empty address', () {
    final cubit = MerchantKybCubit(useMock: true)
      ..setShopPin(lat: 16.06, lng: 108.22, label: '12 Lê Lợi');
    expect(cubit.state.shopAddress, '12 Lê Lợi');
  });

  test('submit sends shopLat/shopLng', () async {
    final partners = FakePartnerApplicationsClient();
    final cubit = MerchantKybCubit(
      submitPartnerApplication: SubmitPartnerApplication(
        PartnerApplicationsRepositoryImpl(partners),
      ),
      accessToken: () => 'token',
      useMock: false,
    )..setShopPin(lat: 16.06, lng: 108.22, label: 'Ghim');
    await cubit.submit();
    final metadata = partners.submitCalls.single.metadata;
    expect(metadata['shopLat'], 16.06);
    expect(metadata['shopLng'], 108.22);
  });

  test('submit sends the picked shop category only when chosen', () async {
    Future<Map<String, Object?>> submitWith(String? code) async {
      final partners = FakePartnerApplicationsClient();
      final cubit = MerchantKybCubit(
        submitPartnerApplication: SubmitPartnerApplication(
          PartnerApplicationsRepositoryImpl(partners),
        ),
        accessToken: () => 'token',
        useMock: false,
      )..setShopPin(lat: 16.06, lng: 108.22, label: 'Ghim');
      if (code != null) cubit.setShopCategory(code);
      await cubit.submit();
      return partners.submitCalls.single.metadata;
    }

    expect((await submitWith('noodles'))['shopCategory'], 'noodles');
    expect((await submitWith(null)).containsKey('shopCategory'), isFalse);
  });
}
