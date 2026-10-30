import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/merchant/domain/repositories/merchant_orders_repository.dart';
import 'package:dealgo/features/merchant/domain/usecases/list_merchant_order_queue.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_order_resume_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements MerchantOrdersRepository {
  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'unmounted MerchantOrderResumePage tokenSource does not throw on refresh',
    (tester) async {
      final cubit = MerchantQueueCubit(
        listMerchantOrderQueue: ListMerchantOrderQueue(_FakeRepo()),
        realtime: FakeSnapshotRealtime(),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const MerchantOrderResumePage(
              orderId: 'test-order-1',
              accessToken: _fakeToken,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Replace the widget so MerchantOrderResumePage is unmounted/disposed.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(value: cubit, child: const SizedBox()),
        ),
      );
      await tester.pumpAndSettle();

      // Refreshing the cubit after unmount should not throw TypeError or FlutterError.
      await expectLater(cubit.refresh(), completes);

      await cubit.close();
    },
  );
}

String? _fakeToken(BuildContext context) => 'fake-token';
