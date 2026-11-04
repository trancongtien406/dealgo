// DEC-PROD-093 — driver prepaid credit: top-up lifecycle, error mapping and
// the page the driver uses to pay fees.
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/driver_credit/data/driver_credit_remote_datasource.dart';
import 'package:dealgo/features/driver_credit/domain/driver_credit.dart';
import 'package:dealgo/features/driver_credit/presentation/driver_credit_cubit.dart';
import 'package:dealgo/features/driver_credit/presentation/pages/driver_credit_page.dart';
import 'package:dealgo/features/driver_credit/presentation/widgets/driver_credit_payment_sheet.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RejectingRepository extends FakeDriverCreditRemoteDataSource {
  _RejectingRepository(this.errorCode);

  final String errorCode;
  var createAttempts = 0;

  @override
  Future<DriverTopUp> createTopUp({
    required String accessToken,
    required int amountVnd,
    String? idempotencyKey,
  }) async {
    createAttempts += 1;
    throw ApiException(
      statusCode: 400,
      message: errorCode,
      errorCode: errorCode,
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required DriverCreditRepository repository,
  required DriverCreditUrlLauncher launcher,
  bool vi = false,
  String? initialTopUpId,
  FakeSnapshotRealtime? realtime,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(vi ? 'vi' : 'en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DriverCreditPage(
        repository: repository,
        accessToken: 'token',
        launcher: launcher,
        initialTopUpId: initialTopUpId,
        realtime: realtime,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('DriverCreditCubit', () {
    test('loads the prepaid balance and clamps the picked amount', () async {
      final repo = FakeDriverCreditRemoteDataSource(creditVnd: 120_000);
      final cubit = DriverCreditCubit(
        repository: repo,
        accessToken: () => 'token',
      );
      await cubit.load();
      expect(cubit.state.status, DriverCreditStatus.loaded);
      expect(cubit.state.credit?.creditVnd, 120_000);
      expect(cubit.state.amountVnd, 100_000);

      cubit.selectAmount(1);
      expect(cubit.state.amountVnd, FakeDriverCreditRemoteDataSource.minVnd);
      cubit.selectAmount(99_000_000);
      expect(cubit.state.amountVnd, FakeDriverCreditRemoteDataSource.maxVnd);
    });

    test('creates one pending link, then cancels it', () async {
      final repo = FakeDriverCreditRemoteDataSource();
      final cubit = DriverCreditCubit(
        repository: repo,
        accessToken: () => 'token',
      );
      await cubit.load();
      final created = await cubit.createTopUp(idempotencyKey: 'k1');
      expect(created?.status, DriverTopUpStatus.pending);
      expect(cubit.state.pending?.id, created!.id);

      final again = await cubit.createTopUp(idempotencyKey: 'k2');
      expect(again?.id, created.id);

      await cubit.cancelPending();
      expect(cubit.state.pending, isNull);
      expect(cubit.state.credit?.recentTopUps.first.status,
          DriverTopUpStatus.cancelled);
    });

    test('surfaces the server error code of a rejected top-up', () async {
      final repo = _RejectingRepository('DRIVER_TOP_UP_DAILY_LIMIT');
      final cubit = DriverCreditCubit(
        repository: repo,
        accessToken: () => 'token',
      );
      await cubit.load();
      final created = await cubit.createTopUp();
      expect(created, isNull);
      expect(repo.createAttempts, 1);
      expect(cubit.state.actionError, 'DRIVER_TOP_UP_DAILY_LIMIT');
      expect(cubit.state.submitting, isFalse);
    });

    test('a missing session fails without calling the server', () async {
      final repo = FakeDriverCreditRemoteDataSource();
      final cubit = DriverCreditCubit(repository: repo, accessToken: () => null);
      await cubit.load();
      expect(cubit.state.status, DriverCreditStatus.failed);
      expect(cubit.state.credit, isNull);
    });
  });

  group('DriverCreditPage', () {
    testWidgets('shows the balance, debt and quick amounts', (tester) async {
      await _pumpPage(
        tester,
        repository: FakeDriverCreditRemoteDataSource(
          creditVnd: 120_000,
          owesVnd: 30_000,
        ),
        launcher: (_) async => true,
      );
      expect(find.byKey(const Key('driver-credit-balance')), findsOneWidget);
      expect(find.text('120.000đ'), findsWidgets);
      expect(find.byKey(const Key('driver-credit-owes')), findsOneWidget);
      expect(find.byKey(const Key('driver-credit-amount-100000')), findsOneWidget);
      expect(find.byKey(const Key('driver-credit-top-up')), findsOneWidget);
    });

    testWidgets('shows the QR sheet, then opens the provider page on demand',
        (tester) async {
      final opened = <Uri>[];
      final repo = FakeDriverCreditRemoteDataSource(creditVnd: 0);
      await _pumpPage(
        tester,
        repository: repo,
        launcher: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('driver-credit-top-up')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('driver-credit-qr')), findsOneWidget);
      expect(find.byKey(const Key('driver-credit-order-code')), findsOneWidget);
      expect(find.byKey(const Key('driver-credit-countdown')), findsOneWidget);
      expect(opened, isEmpty);

      await tester.tap(find.byKey(const Key('driver-credit-sheet-open')));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(opened.single.toString(), 'https://pay.payos.vn/web/mock');
    });

    testWidgets('pending card is cancelled back to no pending top-up',
        (tester) async {
      final repo = FakeDriverCreditRemoteDataSource(creditVnd: 0);
      await _pumpPage(
        tester,
        repository: repo,
        launcher: (_) async => true,
      );
      await tester.tap(find.byKey(const Key('driver-credit-top-up')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('driver-credit-sheet-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('driver-credit-pending')), findsNothing);
      expect(find.byKey(const Key('driver-credit-sheet-amount')), findsNothing);
    });

    testWidgets('a realtime hint flips the sheet to the paid state',
        (tester) async {
      final repo = FakeDriverCreditRemoteDataSource(creditVnd: 0);
      final realtime = FakeSnapshotRealtime();
      await _pumpPage(
        tester,
        repository: repo,
        launcher: (_) async => true,
        realtime: realtime,
      );
      await tester.tap(find.byKey(const Key('driver-credit-top-up')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pending = (await repo.summary(accessToken: 'token')).pendingTopUp!;
      repo.markPaid(pending.id);
      realtime.emitDriverCreditStatus(
        DriverCreditStatusHint(topUpId: pending.id, status: 'PAID'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('driver-credit-sheet-paid')), findsOneWidget);
    });

    testWidgets('a driver-credit return deeplink reopens the top-up sheet',
        (tester) async {
      final repo = FakeDriverCreditRemoteDataSource(
        topUps: [
          DriverTopUp(
            id: '11111111-1111-4111-8111-111111111111',
            amountVnd: 200_000,
            status: DriverTopUpStatus.pending,
            createdAt: DateTime.now(),
            orderCode: 1000000001,
            qrCode: 'MOCK-VIETQR-1000000001',
            checkoutUrl: 'https://pay.payos.vn/web/mock',
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          ),
        ],
      );
      await _pumpPage(
        tester,
        repository: repo,
        launcher: (_) async => true,
        initialTopUpId: '11111111-1111-4111-8111-111111111111',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('driver-credit-sheet-amount')), findsOneWidget);
      expect(find.text('200.000đ'), findsWidgets);
    });

    testWidgets('shows the disabled notice until Ops enables top-up',
        (tester) async {
      await _pumpPage(
        tester,
        repository: FakeDriverCreditRemoteDataSource(enabled: false),
        launcher: (_) async => true,
      );
      expect(find.byKey(const Key('driver-credit-top-up')), findsNothing);
      expect(find.textContaining('not open yet'), findsOneWidget);
    });

    testWidgets('maps a daily-limit rejection to a readable message',
        (tester) async {
      await _pumpPage(
        tester,
        repository: _RejectingRepository('DRIVER_TOP_UP_DAILY_LIMIT'),
        launcher: (_) async => true,
      );
      await tester.tap(find.byKey(const Key('driver-credit-top-up')));
      await tester.pumpAndSettle();
      expect(find.text("Today's top-up limit has been reached."), findsOneWidget);
    });

    testWidgets('keeps wording in Vietnamese', (tester) async {
      await _pumpPage(
        tester,
        repository: FakeDriverCreditRemoteDataSource(),
        launcher: (_) async => true,
        vi: true,
      );
      expect(find.text('Số dư tạm ứng'), findsWidgets);
      expect(find.textContaining('Công nợ phí'), findsOneWidget);
    });
  });
}
