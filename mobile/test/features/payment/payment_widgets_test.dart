import 'package:dealgo/features/payment/data/payment_api.dart';
import 'package:dealgo/features/payment/domain/payment_models.dart';
import 'package:dealgo/features/payment/presentation/payment_method_sheet.dart';
import 'package:dealgo/features/payment/presentation/payment_status_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePaymentApi implements PaymentApi {
  FakePaymentApi({this.methods = const [], this.statuses = const []});

  final List<PaymentMethodOption> methods;
  final List<String> statuses;
  var statusCalls = 0;
  final started = <String>[];

  PaymentCheckoutView _view(String status, String method) =>
      PaymentCheckoutView.fromJson({
        'entityType': 'RIDE',
        'entityId': 'r1',
        'methodCode': method,
        'status': status,
        'paymentUrl': 'https://pay.example.test/x',
      });

  @override
  Future<List<PaymentMethodOption>> listMethods({
    required String accessToken,
    required String service,
  }) async => methods;

  @override
  Future<PaymentCheckoutView> start({
    required String accessToken,
    required String entityType,
    required String entityId,
    required String methodCode,
  }) async {
    started.add(methodCode);
    return _view(methodCode == cashMethodCode ? 'CASH' : 'PENDING', methodCode);
  }

  @override
  Future<PaymentCheckoutView> status({
    required String accessToken,
    required String entityType,
    required String entityId,
  }) async {
    final s = statuses.isEmpty
        ? 'PENDING'
        : statuses[statusCalls.clamp(0, statuses.length - 1)];
    statusCalls++;
    return _view(s, 'MOMO');
  }
}

PaymentMethodOption opt(String code, String group, {bool available = true}) =>
    PaymentMethodOption.fromJson({
      'code': code,
      'label': 'L-$code',
      'group': group,
      'available': available,
      'reason': available ? null : 'Đang chờ giấy phép',
    });

void main() {
  testWidgets(
    'sheet shows four sections, disabled reason, and returns choice',
    (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showPaymentMethodSheet(
                  context,
                  selected: cashMethodCode,
                  options: [
                    opt('MOMO', 'WALLET'),
                    opt('VNPAY_ATM', 'CARD'),
                    opt('CASH', 'RECOMMENDED'),
                    opt('ZALOPAY', 'ADD_MORE', available: false),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final t in [
        'Ví điện tử',
        'Thẻ tín dụng/ghi nợ',
        'Phương thức đề xuất',
        'Thêm phương thức',
      ]) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Đang chờ giấy phép'), findsOneWidget);

      await tester.tap(find.byKey(const Key('payment-method-ZALOPAY')));
      await tester.pumpAndSettle();
      expect(
        find.text('Ví điện tử'),
        findsOneWidget,
        reason: 'disabled row ignores taps',
      );

      await tester.tap(find.byKey(const Key('payment-method-MOMO')));
      await tester.pumpAndSettle();
      expect(picked, 'MOMO');
    },
  );

  testWidgets('tile falls back to CASH when selected method is unavailable', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaymentMethodTile(
            service: 'FOOD',
            selected: 'MOMO',
            accessToken: 't',
            api: FakePaymentApi(
              methods: [
                opt('MOMO', 'WALLET', available: false),
                opt('CASH', 'RECOMMENDED'),
              ],
            ),
            onChanged: (m) => changed = m.code,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(changed, cashMethodCode);
  });

  testWidgets('status page starts payment, launches URL and polls to PAID', (
    tester,
  ) async {
    final api = FakePaymentApi(statuses: ['PENDING', 'PAID']);
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaymentStatusPage(
          entityType: 'RIDE',
          entityId: 'r1',
          startMethod: 'MOMO',
          accessToken: 't',
          api: api,
          pollInterval: const Duration(milliseconds: 10),
          launcher: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(api.started, ['MOMO']);
    expect(launched.single.host, 'pay.example.test');
    expect(find.text('Đang chờ xác nhận thanh toán'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.text('Thanh toán thành công'), findsOneWidget);
  });

  testWidgets('failed payment offers retry and switch to cash', (tester) async {
    final api = FakePaymentApi(statuses: ['FAILED']);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaymentStatusPage(
          entityType: 'RIDE',
          entityId: 'r1',
          accessToken: 't',
          api: api,
          launcher: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán thất bại'), findsOneWidget);
    await tester.tap(find.text('Chuyển sang tiền mặt'));
    await tester.pumpAndSettle();
    expect(api.started, [cashMethodCode]);
    expect(find.text('Thanh toán tiền mặt'), findsOneWidget);
  });
}
