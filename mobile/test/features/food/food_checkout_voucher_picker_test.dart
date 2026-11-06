import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_checkout_page.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/pricing/domain/pricing.dart';
import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_quote.dart';
import 'package:dealgo/features/promotion/domain/repositories/promotion_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-voucher';
const _dish = FoodMenuItem(
  id: 'dish',
  name: 'Bún bò',
  priceVnd: 45000,
  available: true,
);
const _code = 'FOOD20';

class _Promotions implements PromotionRepository {
  @override
  Future<List<AvailableVoucher>> listAvailable({
    required String accessToken,
    VoucherService? service,
    String? storeId,
  }) async => [
    AvailableVoucher(
      code: _code,
      name: 'Giảm 20% món ăn',
      description: '',
      service: VoucherService.food,
      kind: VoucherDiscountKind.percentage,
      discountValue: 20,
      maxDiscountVnd: 30000,
      minOrderVnd: 0,
      endsAt: DateTime.now().add(const Duration(days: 7)),
      usesLeft: 3,
    ),
  ];

  @override
  Future<VoucherQuote> validateVoucher({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  }) async => VoucherQuote(
    valid: code == _code,
    code: code,
    discountVnd: 5000,
    finalAmountVnd: orderAmountVnd - 5000,
  );
}

Future<void> _openCheckout(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: FakeFoodClient(
      stores: const [FoodStoreSummary(id: _storeId, name: 'Quán Bún')],
    ),
    promotions: _Promotions(),
    pricing: FakePricingRemoteDataSource(deliveryFareVnd: 15000),
  );
  final context = tester.element(find.byType(Scaffold).first);
  context.read<FoodCartCubit>()
    ..addItem(storeId: _storeId, storeName: 'Quán Bún', item: _dish)
    ..setDropoff(label: '123 Nguyễn Văn Linh', lat: 10.77, lng: 106.7)
    ..setDeliveryQuote(
      const FoodDeliveryQuote(
        suggestedVnd: 15000,
        minOfferVnd: 12000,
        maxOfferVnd: 45000,
        fareStepVnd: 1000,
      ),
    );
  GoRouter.of(context).push('/customer/food/checkout');
  await tester.pumpAndSettle();
}

Finder get _scrollable => find.byType(Scrollable).first;

Future<void> _openPicker(WidgetTester tester) async {
  final open = find.byKey(const Key('checkout-voucher-picker'));
  await tester.scrollUntilVisible(open, 200, scrollable: _scrollable);
  await tester.tap(open);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a voucher cleared in the field is offered again in the sheet', (
    tester,
  ) async {
    await _openCheckout(tester);

    await _openPicker(tester);
    expect(find.byKey(const Key('checkout-voucher-use-$_code')), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout-voucher-use-$_code')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voucher-applied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('voucher-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-applied')), findsNothing);

    await _openPicker(tester);
    expect(
      find.byKey(const Key('checkout-voucher-use-$_code')),
      findsOneWidget,
      reason: 'clearing the code must not leave the sheet claiming it is used',
    );
    expect(
      find.byKey(const Key('checkout-voucher-used-$_code')),
      findsNothing,
    );
    expect(find.byType(FoodCheckoutPage), findsOneWidget);
  });
}
