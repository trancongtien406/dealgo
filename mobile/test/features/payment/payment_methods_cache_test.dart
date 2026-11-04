import 'package:dealgo/features/payment/data/payment_methods_cache.dart';
import 'package:dealgo/features/payment/domain/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentMethodOption _option(String code) => PaymentMethodOption(
  code: code,
  label: code,
  group: PaymentGroup.recommended,
  available: true,
);

void main() {
  test('reuses the first answer within the ttl', () async {
    final cache = PaymentMethodsCache();
    var calls = 0;
    Future<List<PaymentMethodOption>> fetch() async {
      calls += 1;
      return [_option('CASH')];
    }

    final first = await cache.read('FOOD', fetch);
    final second = await cache.read('FOOD', fetch);

    expect(calls, 1);
    expect(first.single.code, 'CASH');
    expect(second.single.code, 'CASH');
  });

  test('shares one in-flight request between concurrent readers', () async {
    final cache = PaymentMethodsCache();
    var calls = 0;
    Future<List<PaymentMethodOption>> fetch() async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return [_option('CASH')];
    }

    await Future.wait([
      cache.read('FOOD', fetch),
      cache.read('FOOD', fetch),
      cache.read('FOOD', fetch),
    ]);

    expect(calls, 1);
  });

  test('keeps services apart and refetches after invalidation', () async {
    final cache = PaymentMethodsCache();
    var foodCalls = 0;
    var rideCalls = 0;

    await cache.read('FOOD', () async {
      foodCalls += 1;
      return [_option('CASH')];
    });
    await cache.read('BIKE', () async {
      rideCalls += 1;
      return [_option('CASH')];
    });
    cache.invalidate('FOOD');
    await cache.read('FOOD', () async {
      foodCalls += 1;
      return [_option('CASH')];
    });

    expect(foodCalls, 2);
    expect(rideCalls, 1);
  });

  test('does not cache a failed fetch', () async {
    final cache = PaymentMethodsCache();
    var calls = 0;
    Future<List<PaymentMethodOption>> fetch() async {
      calls += 1;
      if (calls == 1) {
        throw StateError('offline');
      }
      return [_option('CASH')];
    }

    await expectLater(cache.read('FOOD', fetch), throwsStateError);
    final retried = await cache.read('FOOD', fetch);

    expect(calls, 2);
    expect(retried.single.code, 'CASH');
  });

  test('expires entries older than the ttl', () async {
    final cache = PaymentMethodsCache(ttl: Duration.zero);
    var calls = 0;
    Future<List<PaymentMethodOption>> fetch() async {
      calls += 1;
      return [_option('CASH')];
    }

    await cache.read('FOOD', fetch);
    await cache.read('FOOD', fetch);

    expect(calls, 2);
  });
}
