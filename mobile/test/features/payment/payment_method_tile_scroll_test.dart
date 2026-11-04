import 'package:dealgo/features/payment/data/payment_api.dart';
import 'package:dealgo/features/payment/domain/payment_models.dart';
import 'package:dealgo/features/payment/presentation/payment_method_sheet.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingPaymentApi implements PaymentApi {
  var listCalls = 0;

  @override
  Future<List<PaymentMethodOption>> listMethods({
    required String accessToken,
    required String service,
  }) async {
    listCalls += 1;
    return const [
      PaymentMethodOption(
        code: 'CASH',
        label: '',
        group: PaymentGroup.recommended,
        available: true,
      ),
      PaymentMethodOption(
        code: 'MOMO',
        label: 'MoMo',
        group: PaymentGroup.wallet,
        available: true,
      ),
    ];
  }

  @override
  Future<PaymentCheckoutView> start({
    required String accessToken,
    required String entityType,
    required String entityId,
    required String methodCode,
  }) => throw UnimplementedError();

  @override
  Future<PaymentCheckoutView> status({
    required String accessToken,
    required String entityType,
    required String entityId,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('scrolling the tile out of view does not refetch methods', (
    tester,
  ) async {
    final api = _CountingPaymentApi();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              PaymentMethodTile(
                service: 'FOOD',
                selected: 'CASH',
                accessToken: 't',
                api: api,
                onChanged: (_) {},
              ),
              const SizedBox(height: 2400),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.listCalls, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(api.listCalls, 1);
  });
}
