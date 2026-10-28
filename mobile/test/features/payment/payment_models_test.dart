import 'package:dealgo/features/payment/data/payment_api.dart';
import 'package:dealgo/features/payment/domain/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentMethodOption opt(String code, String group, {bool available = true, int order = 0}) =>
    PaymentMethodOption.fromJson({
      'code': code,
      'label': code,
      'group': group,
      'available': available,
      'sortOrder': order,
      'reason': available ? null : 'Sắp ra mắt',
    });

void main() {
  test('groups in fixed section order and always keeps CASH', () {
    final groups = groupPaymentMethods([
      opt('ZALOPAY', 'ADD_MORE'),
      opt('MOMO', 'WALLET', order: 2),
      opt('APPLE_PAY', 'WALLET', available: false, order: 1),
    ]);
    expect(groups.keys.toList(), [
      PaymentGroup.wallet,
      PaymentGroup.recommended,
      PaymentGroup.addMore,
    ]);
    expect(groups[PaymentGroup.wallet]!.map((o) => o.code), ['APPLE_PAY', 'MOMO']);
    expect(groups[PaymentGroup.recommended]!.single.code, cashMethodCode);
  });

  test('selection falls back to CASH when method becomes unavailable', () {
    final list = [opt('MOMO', 'WALLET', available: false)];
    expect(effectivePaymentSelection(list, 'MOMO'), cashMethodCode);
    expect(effectivePaymentSelection([opt('MOMO', 'WALLET')], 'MOMO'), 'MOMO');
    expect(effectivePaymentSelection(list, null), cashMethodCode);
  });

  test('vehicle class maps to service', () {
    expect(paymentServiceForVehicleClass('MOTORBIKE'), 'BIKE');
    expect(paymentServiceForVehicleClass('CAR_4'), 'CAR');
    expect(paymentServiceForVehicleClass(null), 'CAR');
  });

  test('status parsing and terminal states', () {
    expect(paymentStatusFrom('PAID'), PaymentCheckoutStatus.paid);
    expect(paymentStatusFrom('weird'), PaymentCheckoutStatus.notStarted);
    expect(isTerminalPaymentStatus(PaymentCheckoutStatus.pending), isFalse);
    expect(isTerminalPaymentStatus(PaymentCheckoutStatus.failed), isTrue);
  });

  test('payment paths per entity', () {
    expect(paymentPathFor('RIDE', 'r1'), '/v1/rides/r1/payment');
    expect(paymentPathFor('FOOD_ORDER', 'o1'), '/v1/food/orders/o1/payment');
  });
}
