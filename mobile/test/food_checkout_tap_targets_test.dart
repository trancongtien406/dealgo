import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_checkout_page.dart';
import 'package:dealgo/features/food/presentation/widgets/food_checkout_widgets.dart';
import 'package:dealgo/features/payment/domain/payment_models.dart';
import 'package:dealgo/features/payment/presentation/payment_method_sheet.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';

const _id = 'store-x';

void main() {
  testWidgets(
    'checkout: payment tile scrolls above the bottom bar so taps reach it',
    (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpSignedIn(
        tester,
        profile: customerProfile,
        foodClient: FakeFoodClient(
          stores: const [
            FoodStoreSummary(id: _id, name: 'Quán', category: 'rice'),
          ],
        ),
      );
      final ctx = tester.element(find.byType(Scaffold).first);
      ctx.read<FoodCartCubit>().addItem(
        storeId: _id,
        storeName: 'Quán',
        item: const FoodMenuItem(
          id: 'i1',
          name: 'Bánh mì',
          priceVnd: 20000,
          available: true,
        ),
        minOrderVnd: 0,
      );
      GoRouter.of(ctx).push('/customer/food/checkout');
      await tester.pumpAndSettle();
      expect(find.byType(FoodCheckoutPage), findsOneWidget);

      final tile = find.byType(PaymentMethodTile);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('food-checkout-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 12 && tile.evaluate().isEmpty; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(tile, findsOneWidget);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();

      final bar = find.byType(CheckoutActions);
      expect(
        tester.getRect(tile).bottom,
        lessThanOrEqualTo(tester.getRect(bar).top + 0.5),
        reason: 'the sticky bar painted over the payment tile',
      );
      // The hit test at the tile centre must land on the tile, not the bar.
      final hit = tester.hitTestOnBinding(tester.getCenter(tile));
      final tileBox = tester.renderObject(tile);
      expect(
        hit.path.any(
          (e) => e.target == tileBox || _isDescendant(e.target, tileBox),
        ),
        isTrue,
      );
    },
  );

  testWidgets('payment sheet has no status-bar gap above the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        theme: DealGoTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPaymentMethodSheet(
                context,
                selected: cashMethodCode,
                options: [PaymentMethodOption.cash],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Sheet surface starts at the drag handle; title should follow it
    // directly (no status-bar inset, no doubled top padding).
    final handleTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
    final titleTop = tester.getTopLeft(find.text('Phương thức thanh toán')).dy;
    expect(titleTop - handleTop, lessThan(64));
  });
}

bool _isDescendant(Object? target, RenderObject ancestor) {
  if (target is! RenderObject) return false;
  RenderObject? node = target;
  while (node != null) {
    if (identical(node, ancestor)) return true;
    node = node.parent;
  }
  return false;
}
