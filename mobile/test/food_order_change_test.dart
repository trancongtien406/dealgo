import 'package:dealgo/core/l10n/api_error_text.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/data/datasources/food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_order_change_card.dart';
import 'package:dealgo/features/food/presentation/widgets/food_reject_reason.dart';
import 'package:dealgo/features/merchant/presentation/utils/merchant_kitchen_lines.dart';
import 'package:dealgo/features/merchant/presentation/widgets/merchant_order_change_sheet.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_food_client.dart';
import 'support/test_l10n.dart';

Map<String, Object?> _orderJson({Object? pendingChange}) => {
  'success': true,
  'data': {
    'id': 'order-1',
    'status': 'PREPARING',
    'subtotalVnd': 100000,
    'deliveryFareVnd': 15000,
    'totalVnd': 115000,
    'dropoff': {'lat': 16.06, 'lng': 108.21, 'label': 'Hải Châu'},
    'lines': [
      {
        'id': 'line-1',
        'itemId': 'item-1',
        'name': 'Bún bò',
        'unitPriceVnd': 50000,
        'quantity': 2,
      },
    ],
    'pendingChange': pendingChange,
  },
};

const _changeJson = {
  'id': 'change-1',
  'orderId': 'order-1',
  'status': 'PENDING',
  'reasonCode': 'OUT_OF_STOCK',
  'note': ' Hết bò ',
  'lines': [
    {
      'lineId': 'line-1',
      'itemId': 'item-1',
      'name': 'Bún bò',
      'unitPriceVnd': 50000,
      'fromQuantity': 2,
      'toQuantity': 1,
    },
  ],
  'oldSubtotalVnd': 100000,
  'newSubtotalVnd': 50000,
  'newDiscountVnd': 0,
  'newTotalVnd': 65000,
  'expiresAt': '2030-01-01T00:05:00.000Z',
  'respondedAt': null,
  'createdAt': '2030-01-01T00:00:00.000Z',
};

FoodOrderChange _change() => decodeFoodOrderChange(_changeJson)!;

void main() {
  group('decode', () {
    test('order detail carries line ids and the pending change', () {
      final detail = decodeFoodOrderDetail(
        _orderJson(pendingChange: _changeJson),
      );
      expect(detail.lines.single.id, 'line-1');
      final change = detail.pendingChange!;
      expect(change.pending, isTrue);
      expect(change.reason, FoodOrderChangeReason.outOfStock);
      expect(change.note, 'Hết bò');
      expect(change.lines.single.toQuantity, 1);
      expect(change.newTotalVnd, 65000);
    });

    test('no pending change → null; malformed → null', () {
      expect(decodeFoodOrderDetail(_orderJson()).pendingChange, isNull);
      expect(decodeFoodOrderChange({'id': 'x'}), isNull);
    });

    test('change cancel reasons decode and have copy', () {
      final l10n = AppLocalizationsVi();
      for (final code in ['CHANGE_REJECTED', 'CHANGE_EXPIRED']) {
        final reason = FoodRejectReason.fromWire(code);
        expect(reason.wire, code);
        expect(foodRejectReasonLabel(l10n, reason), isNotEmpty);
      }
      expect(
        FoodRejectReason.storeChoices,
        isNot(contains(FoodRejectReason.changeRejected)),
      );
    });

    test('new API error codes have specific copy', () {
      final l10n = AppLocalizationsVi();
      for (final code in [
        'FOOD_CHANGE_PENDING',
        'FOOD_CHANGE_INVALID',
        'FOOD_CHANGE_NOT_FOUND',
        'FOOD_FAIL_TOO_EARLY',
        'FOOD_FAIL_NOTE_REQUIRED',
        'FOOD_STORE_LOCATION_REQUIRED',
        'RIDE_LIVE_OFFERS_FULL',
        'RIDE_CANCEL_COOLDOWN',
      ]) {
        final text = apiErrorText(
          l10n,
          ApiException(statusCode: 409, message: 'x', errorCode: code),
        );
        expect(text, isNot(l10n.apiErrGeneric), reason: code);
      }
    });
  });

  Widget host(Widget child, FoodClient client) =>
      RepositoryProvider<FoodClient>.value(
        value: client,
        child: MaterialApp(
          locale: testLocale,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('customer accepts the store change', (tester) async {
    final client = FakeFoodClient(
      orderDetail: decodeFoodOrderDetail(_orderJson()),
    );
    var answered = 0;
    await tester.pumpWidget(
      host(
        FoodOrderChangeCard(
          orderId: 'order-1',
          change: _change(),
          accessToken: 'token',
          onAnswered: () => answered++,
        ),
        client,
      ),
    );
    expect(find.text('1 → 2'), findsNothing);
    expect(find.text('2 → 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-change-accept')));
    await tester.pumpAndSettle();
    expect(client.changeAnswers.single, (changeId: 'change-1', accept: true));
    expect(answered, 1);
  });

  testWidgets('customer reject asks for confirmation first', (tester) async {
    final client = FakeFoodClient(
      orderDetail: decodeFoodOrderDetail(_orderJson()),
    );
    await tester.pumpWidget(
      host(
        FoodOrderChangeCard(
          orderId: 'order-1',
          change: _change(),
          accessToken: 'token',
          onAnswered: () {},
        ),
        client,
      ),
    );
    await tester.tap(find.byKey(const Key('food-change-reject')));
    await tester.pumpAndSettle();
    expect(client.changeAnswers, isEmpty);
    await tester.tap(find.byKey(const Key('food-change-reject-confirm')));
    await tester.pumpAndSettle();
    expect(client.changeAnswers.single.accept, isFalse);
  });

  testWidgets('merchant lowers a quantity and sends the change', (
    tester,
  ) async {
    final client = FakeFoodClient(
      orderDetail: decodeFoodOrderDetail(_orderJson()),
    );
    await tester.pumpWidget(
      host(
        MerchantOrderChangeSheet(
          orderId: 'order-1',
          lines: const [
            MerchantKitchenLine(
              id: 'line-1',
              name: 'Bún bò',
              qty: 2,
              unitPriceVnd: 50000,
            ),
          ],
          client: client,
          accessToken: 'token',
        ),
        client,
      ),
    );
    final submit = find.byKey(const Key('merchant-change-submit'));
    await tester.tap(submit);
    await tester.pump();
    expect(client.proposedChanges, isEmpty, reason: 'nothing edited yet');
    await tester.tap(find.byKey(const Key('merchant-change-minus-line-1')));
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(client.proposedChanges.single.quantities, {'line-1': 1});
  });
}
