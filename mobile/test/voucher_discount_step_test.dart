import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/store_meta.dart';
import 'package:dealgo/features/promotion/data/datasources/promotion_remote_datasource.dart';
import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_discount.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_quote.dart';
import 'package:dealgo/features/promotion/presentation/widgets/food_voucher_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('percentage voucher discount rounds down to 1.000đ', () {
    test('matches the server rule', () {
      expect(percentVoucherDiscountVnd(58036, 10, null), 5000);
      expect(percentVoucherDiscountVnd(59000, 15, null), 8000);
      expect(percentVoucherDiscountVnd(300000, 10, 15500), 15000);
      expect(percentVoucherDiscountVnd(300000, 20, 40000), 40000);
      expect(percentVoucherDiscountVnd(9999, 10, null), 0);
      expect(percentVoucherDiscountVnd(0, 10, null), 0);
    });

    test('store offer and checkout picker estimates agree', () {
      final offer = StoreOffer(
        id: 'o',
        code: 'DEMODN10',
        name: '10%',
        kind: StoreOfferKind.percentage,
        discountValue: 10,
        maxDiscountVnd: 20000,
        minOrderVnd: 25000,
        endsAt: DateTime(2030),
      );
      final voucher = AvailableVoucher(
        code: 'DEMODN10',
        name: '10%',
        description: '',
        service: null,
        kind: VoucherDiscountKind.percentage,
        discountValue: 10,
        maxDiscountVnd: 20000,
        minOrderVnd: 25000,
        endsAt: DateTime(2030),
        usesLeft: 1,
      );
      for (final subtotal in [58036, 87500, 123456, 400000]) {
        final a = storeOfferSaving(offer, subtotal);
        final b = voucherEstimatedSaving(
          voucher,
          orderAmountVnd: subtotal,
          deliveryFeeVnd: 15000,
        );
        expect(a, b);
        expect(a % voucherDiscountStepVnd, 0);
      }
      expect(storeOfferSaving(offer, 58036), 5000);
      expect(storeOfferSaving(offer, 400000), 20000);
      expect(storeOfferSaving(offer, 20000), 0);
    });

    test('the offline voucher check keeps a round fare round', () async {
      final VoucherQuote q = await FakePromotionRemoteDataSource()
          .validateVoucher(
            accessToken: 't',
            code: 'dealgo10',
            service: VoucherService.ride,
            orderAmountVnd: 59000,
          );
      expect(q.discountVnd, 5000);
      expect(q.finalAmountVnd, 54000);
    });
  });
}
