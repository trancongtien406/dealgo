import 'package:dealgo/features/food/data/food_fare_negotiation.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/widgets/food_fare_widgets.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/pricing/domain/pricing.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _quote = FoodDeliveryQuote(
  suggestedVnd: 15400,
  minOfferVnd: 11000,
  maxOfferVnd: 18000,
  fareStepVnd: 1000,
);

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('decodeFoodDeliveryQuote', () {
    test('reads bounds', () {
      final q = decodeFoodDeliveryQuote({
        'deliveryFareVnd': 15000,
        'suggestedDeliveryFareVnd': 15000,
        'minOfferVnd': 11000,
        'maxOfferVnd': 60000,
        'fareStepVnd': 500,
      });
      expect(q.suggestedVnd, 15000);
      expect(q.fareStepVnd, 500);
      expect(q.negotiable, isTrue);
    });

    test('old server → fixed fee, not negotiable', () {
      final q = decodeFoodDeliveryQuote({'deliveryFareVnd': 15000});
      expect(q, const FoodDeliveryQuote.fixed(15000));
      expect(q.negotiable, isFalse);
    });
  });

  group('cart offer', () {
    test('stepper snaps to the step grid and stays in bounds', () {
      final cart = FoodCartCubit()..setDeliveryQuote(_quote);
      expect(cart.state.offeredDeliveryFareVnd, 15400);
      cart.stepDeliveryOffer(1);
      expect(cart.state.offeredDeliveryFareVnd, 16000);
      cart.stepDeliveryOffer(1);
      cart.stepDeliveryOffer(1);
      expect(cart.stepDeliveryOffer(1), isFalse);
      expect(cart.state.offeredDeliveryFareVnd, 18000);
      for (var i = 0; i < 10; i++) {
        cart.stepDeliveryOffer(-1);
      }
      expect(cart.state.offeredDeliveryFareVnd, 11000);
      expect(cart.state.previewTotalVnd, isNotNull);
      cart.resetDeliveryOffer();
      expect(cart.state.offeredDeliveryFareVnd, 15400);
      expect(cart.state.deliveryFareVnd, 15400);
    });

    test('a new quote resets the offer', () {
      final cart = FoodCartCubit()..setDeliveryQuote(_quote);
      cart.stepDeliveryOffer(2);
      cart.setDeliveryQuote(
        const FoodDeliveryQuote(
          suggestedVnd: 20000,
          minOfferVnd: 14000,
          maxOfferVnd: 60000,
          fareStepVnd: 1000,
        ),
      );
      expect(cart.state.deliveryOfferVnd, isNull);
      expect(cart.state.offeredDeliveryFareVnd, 20000);
    });
  });

  group('FoodFareCubit', () {
    test('select fixes the fee; others lost', () async {
      final client = FakeFoodFareClient(
        offers: [
          const FoodDeliveryOffer(
            id: 'a',
            driverId: 'd1',
            amountVnd: 18000,
            status: FoodDeliveryOfferStatus.pending,
          ),
          const FoodDeliveryOffer(
            id: 'b',
            driverId: 'd2',
            amountVnd: 20000,
            status: FoodDeliveryOfferStatus.pending,
          ),
        ],
      );
      final cubit = FoodFareCubit(
        client: client,
        orderId: 'o1',
        accessToken: () => 't',
      );
      await cubit.refresh();
      expect(cubit.state.offers!.pendingOffers, hasLength(2));
      expect(await cubit.select('a'), isTrue);
      expect(cubit.state.offers!.agreed, isTrue);
      expect(cubit.state.offers!.deliveryFareVnd, 18000);
      expect(
        client.offers.firstWhere((o) => o.id == 'b').status,
        FoodDeliveryOfferStatus.lost,
      );
      await cubit.close();
    });

    test('raise adds one step until the limit', () async {
      final client = FakeFoodFareClient();
      final cubit = FoodFareCubit(
        client: client,
        orderId: 'o1',
        accessToken: () => 't',
      );
      await cubit.refresh();
      for (var i = 0; i < 3; i++) {
        expect(await cubit.raise(), isTrue);
      }
      expect(client.fareVnd, 18000);
      expect(cubit.state.offers!.nextRaiseVnd, isNull);
      expect(await cubit.raise(), isFalse);
      await cubit.close();
    });
  });

  testWidgets('checkout panel steps the offer', (tester) async {
    final cart = FoodCartCubit()..setDeliveryQuote(_quote);
    await tester.pumpWidget(
      BlocProvider.value(value: cart, child: _host(const FoodFareOfferPanel())),
    );
    expect(find.text('Phí giao gợi ý'), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-fare-increase')));
    await tester.pump();
    expect(cart.state.offeredDeliveryFareVnd, 16000);
    expect(find.byKey(const Key('food-fare-reset')), findsOneWidget);
  });

  testWidgets('negotiation card lists offers and selects one', (tester) async {
    final client = FakeFoodFareClient(
      offers: [
        const FoodDeliveryOffer(
          id: 'a',
          driverId: 'd1',
          amountVnd: 19000,
          status: FoodDeliveryOfferStatus.pending,
        ),
      ],
    );
    var agreed = 0;
    await tester.pumpWidget(
      _host(
        FoodFareNegotiationCard(
          orderId: 'o1',
          accessToken: () => 't',
          client: client,
          onAgreed: () => agreed++,
          pollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('food-fare-offer-a')), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-fare-select-a')));
    await tester.pump();
    await tester.pump();
    expect(client.calls, contains('select:a'));
    expect(find.byKey(const Key('food-fare-agreed')), findsOneWidget);
    expect(agreed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  group('fee mode (FOOD_DELIVERY_FEE_MODE)', () {
    test('quote and offers decode FIXED; unknown keeps negotiate', () {
      final q = decodeFoodDeliveryQuote({
        'suggestedDeliveryFareVnd': 15000,
        'minOfferVnd': 11000,
        'maxOfferVnd': 60000,
        'fareStepVnd': 1000,
        'feeMode': 'FIXED',
      });
      expect(q.feeMode, FoodDeliveryFeeMode.fixed);
      expect(q.driversCanCounter, isFalse);
      expect(q.negotiable, isTrue);
      final o = decodeFoodDeliveryOffers({
        'deliveryFareVnd': 15000,
        'feeMode': 'FIXED',
      });
      expect(o.driversCanCounter, isFalse);
      expect(
        decodeFoodDeliveryOffers({'deliveryFareVnd': 1}).driversCanCounter,
        isTrue,
      );
    });

    testWidgets('FIXED shows the fixed fee and no stepper', (tester) async {
      final cart = FoodCartCubit()
        ..setDeliveryQuote(
          const FoodDeliveryQuote(
            suggestedVnd: 15000,
            minOfferVnd: 11000,
            maxOfferVnd: 18000,
            fareStepVnd: 1000,
            feeMode: FoodDeliveryFeeMode.fixed,
          ),
        );
      await tester.pumpWidget(
        BlocProvider.value(
          value: cart,
          child: _host(const FoodFareOfferPanel()),
        ),
      );
      expect(find.byKey(const Key('food-fare-fixed-panel')), findsOneWidget);
      expect(find.text('Phí giao cố định'), findsOneWidget);
      expect(find.byKey(const Key('food-fare-increase')), findsNothing);
      expect(find.byKey(const Key('food-fare-decrease')), findsNothing);
    });

    testWidgets('FIXED tracking card hides counters but keeps raise', (
      tester,
    ) async {
      final client = FakeFoodFareClient(
        feeMode: FoodDeliveryFeeMode.fixed,
        offers: [
          const FoodDeliveryOffer(
            id: 'a',
            driverId: 'd1',
            amountVnd: 19000,
            status: FoodDeliveryOfferStatus.pending,
          ),
        ],
      );
      await tester.pumpWidget(
        _host(
          FoodFareNegotiationCard(
            orderId: 'o1',
            accessToken: () => 't',
            client: client,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('food-fare-offer-a')), findsNothing);
      expect(find.byKey(const Key('food-fare-fixed-note')), findsOneWidget);
      expect(find.byKey(const Key('food-fare-raise')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('driver counter button hidden in FIXED, shown in NEGOTIATE', (
      tester,
    ) async {
      Widget button(FakeFoodFareClient c) => _host(
        DriverFareCounterButton(
          orderId: 'o1',
          customerOfferVnd: 15000,
          accessToken: 't',
          client: c,
        ),
      );
      await tester.pumpWidget(button(FakeFoodFareClient()));
      await tester.pump();
      expect(find.byKey(const Key('driver-fare-counter')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        button(FakeFoodFareClient(feeMode: FoodDeliveryFeeMode.fixed)),
      );
      await tester.pump();
      expect(find.byKey(const Key('driver-fare-counter')), findsNothing);
    });
  });
}
