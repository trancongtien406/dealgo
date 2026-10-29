import 'package:dealgo/core/network/api_paths.dart';
import 'package:dealgo/core/notifications/push_route_resolver.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/chat/data/datasources/fake_chat_client.dart';
import 'package:dealgo/features/chat/domain/usecases/list_food_order_chat_messages.dart';
import 'package:dealgo/features/chat/domain/usecases/list_ride_chat_messages.dart';
import 'package:dealgo/features/chat/domain/usecases/send_food_order_chat_message.dart';
import 'package:dealgo/features/chat/domain/usecases/send_ride_chat_message.dart';
import 'package:dealgo/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:dealgo/features/chat/presentation/widgets/open_chat_on_arrival.dart';
import 'package:dealgo/features/chat/presentation/widgets/transaction_chat_sheet.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_order_page.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_chat_repository.dart';

ChatCubit _cubit(
  FakeChatRepository repo,
  ChatThreadKind kind, {
  SnapshotRealtime? realtime,
}) => ChatCubit(
  listRideChatMessages: ListRideChatMessages(repo),
  sendRideChatMessage: SendRideChatMessage(repo),
  listFoodOrderChatMessages: ListFoodOrderChatMessages(repo),
  sendFoodOrderChatMessage: SendFoodOrderChatMessage(repo),
  kind: kind,
  resourceId: 'o1',
  currentUserId: 'me',
  realtime: realtime,
);

/// Food orders have two threads: customer ↔ shop and customer ↔ driver.
void main() {
  final t0 = DateTime.utc(2026, 10, 29, 7);

  test('shop and driver threads hit different endpoints', () {
    expect(
      ApiPaths.foodOrderShopMessages('o1'),
      '/v1/food/orders/o1/shop-messages',
    );
    expect(ApiPaths.foodOrderMessages('o1'), '/v1/food/orders/o1/messages');
    expect(ChatThreadKind.foodOrder.aggregateType, 'FoodOrder');
    expect(ChatThreadKind.foodOrderShop.aggregateType, 'FoodOrderShop');
  });

  test('shop cubit loads and sends on the shop thread only', () async {
    final repo = FakeChatRepository();
    final cubit = _cubit(repo, ChatThreadKind.foodOrderShop);
    await cubit.start(accessToken: 'tok');
    await cubit.send(accessToken: 'tok', body: 'còn món không quán?');
    expect(repo.foodShopFlags, [true, true]);
    await cubit.close();
  });

  test('driver cubit loads and sends on the driver thread only', () async {
    final repo = FakeChatRepository();
    final cubit = _cubit(repo, ChatThreadKind.foodOrder);
    await cubit.start(accessToken: 'tok');
    await cubit.send(accessToken: 'tok', body: 'để trước cổng');
    expect(repo.foodShopFlags, [false, false]);
    await cubit.close();
  });

  test('a driver-thread push never lands in the shop sheet', () async {
    final rt = FakeSnapshotRealtime();
    final repo = FakeChatRepository();
    final cubit = _cubit(repo, ChatThreadKind.foodOrderShop, realtime: rt);
    await cubit.start(accessToken: 'tok');
    ChatMessageHint hint(String type, String id) => ChatMessageHint(
      aggregateType: type,
      aggregateId: 'o1',
      id: id,
      threadId: 't',
      senderUserId: 'other',
      body: id,
      createdAt: t0,
    );
    rt.emitChatMessage(hint('FoodOrder', 'from-driver'));
    rt.emitChatMessage(hint('FoodOrderShop', 'from-shop'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.lines.map((l) => l.key), ['from-shop']);
    await cubit.close();
  });

  test('fake client keeps the two threads apart', () async {
    final client = FakeChatClient();
    await client.postFoodOrderMessage(
      accessToken: 't',
      orderId: 'o1',
      body: 'shop',
      shop: true,
    );
    await client.postFoodOrderMessage(
      accessToken: 't',
      orderId: 'o1',
      body: 'driver',
    );
    final shop = await client.listFoodOrderMessages(
      accessToken: 't',
      orderId: 'o1',
      shop: true,
    );
    final driver = await client.listFoodOrderMessages(
      accessToken: 't',
      orderId: 'o1',
    );
    expect(shop.items.map((m) => m.body), ['shop']);
    expect(driver.items.map((m) => m.body), ['driver']);
  });

  test('header role names the right counterpart', () {
    final l10n = AppLocalizationsVi();
    expect(
      chatCounterpartRole(
        l10n,
        ChatViewer.customer,
        ChatThreadKind.foodOrderShop,
      ),
      'Quán',
    );
    expect(
      chatCounterpartRole(l10n, ChatViewer.customer, ChatThreadKind.foodOrder),
      'Tài xế',
    );
    expect(
      chatCounterpartRole(l10n, ChatViewer.customer, ChatThreadKind.ride),
      'Tài xế',
    );
    expect(
      chatCounterpartRole(
        l10n,
        ChatViewer.merchant,
        ChatThreadKind.foodOrderShop,
      ),
      'Khách hàng',
    );
    expect(
      chatCounterpartRole(l10n, ChatViewer.driver, ChatThreadKind.foodOrder),
      'Khách hàng',
    );
  });

  test('merchant chat only while the order is live', () {
    expect(merchantCanChat('PREPARING'), isTrue);
    expect(merchantCanChat('PICKED_UP'), isTrue);
    expect(merchantCanChat('DELIVERED'), isFalse);
    expect(merchantCanChat('CANCELLED'), isFalse);
  });

  test('server chat=shop push path is kept', () {
    expect(
      resolvePushLocation(
        {
          'path': '/customer/food/orders/o1?chat=shop',
          'role': 'CUSTOMER',
          'eventType': 'Chat.message',
        },
        const [AppRole.customer],
      ),
      '/customer/food/orders/o1?chat=shop',
    );
  });

  group('OpenChatOnArrival channel', () {
    Future<List<String>> pumpAt(WidgetTester tester, String location) async {
      final opened = <String>[];
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/order/:id',
            builder: (context, state) => OpenChatOnArrival(
              shop: true,
              onOpen: () => opened.add('shop'),
              child: OpenChatOnArrival(
                onOpen: () => opened.add('driver'),
                child: const Text('order'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('?chat=shop opens only the shop chat', (tester) async {
      expect(await pumpAt(tester, '/order/o1?chat=shop'), ['shop']);
    });

    testWidgets('?chat=1 opens only the driver chat', (tester) async {
      expect(await pumpAt(tester, '/order/o1?chat=1'), ['driver']);
    });
  });
}
