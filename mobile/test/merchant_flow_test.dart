import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/core/l10n/api_error_text.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'dart:typed_data';

import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dealgo/features/identity/presentation/widgets/auth_widgets.dart';

import 'package:dealgo/features/food/presentation/widgets/store_meta.dart';

import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/domain/place.dart';

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void main() {
  test('queue reads the success envelope', () {
    final orders = decodeMerchantQueue({
      'success': true,
      'data': [
        {
          'id': 'order-1',
          'storeId': 'store-1',
          'status': 'PLACED',
          'deliveryFareVnd': 25000,
          'subtotalVnd': 125000,
          'totalVnd': 150000,
          'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': '456 Trần Hưng Đạo'},
          'lineCount': 3,
          'createdAt': '2026-10-14T02:20:00.000Z',
          'customerName': 'Tiến T.',
          'driverName': null,
        },
      ],
    });
    expect(orders.single.status, 'PLACED');
    expect(orders.single.customerName, 'Tiến T.');
    expect(orders.single.driverName, isNull);
    expect(orders.single.subtotalVnd, 125000);
    expect(orders.single.totalVnd, 150000);

    final update = decodeMerchantOrderUpdate({
      'success': true,
      'data': {
        'id': 'order-1',
        'status': 'PREPARING',
        'subtotalVnd': 125000,
        'deliveryFareVnd': 25000,
        'totalVnd': 150000,
        'lines': [
          {
            'itemId': 'bun',
            'name': 'Bún',
            'unitPriceVnd': 125000,
            'quantity': 1,
          },
        ],
      },
    });
    expect(update.status, 'PREPARING');
    expect(update.lineCount, 1);
    expect(update.totalVnd, 150000);
  });

  testWidgets('queue lists one PLACED order', (tester) async {
    final food = FakeFoodClient()..queueOrders = [_placedOrder()];
    await _openOrders(tester, food);

    expect(food.queueCalls, isNotEmpty);
    expect(food.queueCalls, everyElement('access-token'));
    expect(find.textContaining('Chờ Shop xác nhận'), findsWidgets);
    expect(find.text('456 Trần Hưng Đạo'), findsOneWidget);
    expect(find.textContaining('125.000đ'), findsWidgets);
    expect(find.text('150.000đ'), findsWidgets);
    expect(find.text('Chưa có đơn mới'), findsNothing);
  });

  testWidgets('assigned order shows the handover code from the server (DEC-PROD-036)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [
        MerchantQueueOrder(
          id: 'order-placed-1',
          storeId: 'store-1',
          status: 'ASSIGNED',
          deliveryFareVnd: 25000,
          subtotalVnd: 125000,
          totalVnd: 150000,
          dropoff: const FoodDropoff(lat: 16.1, lng: 108.22, label: '456 Trần Hưng Đạo'),
          lineCount: 3,
          createdAt: '2026-10-14T02:20:00.000Z',
          driverName: 'Minh A.',
        ),
      ]
      ..orderDetail = const FoodOrderDetail(
        id: 'order-placed-1',
        status: 'ASSIGNED',
        subtotalVnd: 125000,
        deliveryFareVnd: 25000,
        totalVnd: 150000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.22, label: '456 Trần Hưng Đạo'),
        lines: [],
        handoverCode: '2891',
      );
    await _openOrders(tester, food);
    final card = find.byKey(const Key('merchant-order-order-placed-1'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    final code = find.byKey(const Key('merchant-handover-code'));
    await tester.ensureVisible(code);
    expect(tester.widget<Text>(code).data, '2891');
    expect(find.text('Bàn giao cho tài xế'), findsWidgets);
  });

  testWidgets('a READY order refreshes to ASSIGNED without leaving the screen', (
    tester,
  ) async {
    const dropoff = FoodDropoff(lat: 16.1, lng: 108.22, label: '456 Trần Hưng Đạo');
    FoodOrderDetail detail(String status, {String? code}) => FoodOrderDetail(
      id: 'order-placed-1',
      status: status,
      subtotalVnd: 125000,
      deliveryFareVnd: 25000,
      totalVnd: 150000,
      dropoff: dropoff,
      lines: const [],
      handoverCode: code,
    );
    final food = FakeFoodClient()
      ..queueOrders = [
        MerchantQueueOrder(
          id: 'order-placed-1',
          storeId: 'store-1',
          status: 'READY',
          deliveryFareVnd: 25000,
          subtotalVnd: 125000,
          totalVnd: 150000,
          dropoff: dropoff,
          lineCount: 3,
          createdAt: '2026-10-14T02:20:00.000Z',
        ),
      ]
      ..orderDetail = detail('READY');
    await _openOrders(tester, food);
    final card = find.byKey(const Key('merchant-order-order-placed-1'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã sẵn sàng'), findsOneWidget);
    final readsBefore = food.orderReads.length;

    // Still READY on the next poll: nothing changes.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(food.orderReads.length, readsBefore + 1);
    expect(find.text('Đơn đã sẵn sàng'), findsOneWidget);

    // A driver accepts: the next poll flips the screen to ASSIGNED.
    food.orderDetail = detail('ASSIGNED', code: '4417');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã sẵn sàng'), findsNothing);
    expect(find.text('Đã có tài xế'), findsWidgets);
    final code = find.byKey(const Key('merchant-handover-code'));
    await tester.ensureVisible(code);
    expect(tester.widget<Text>(code).data, '4417');

    // ASSIGNED is terminal for the poll: no more reads.
    final readsAfter = food.orderReads.length;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(food.orderReads.length, readsAfter);
  });


  testWidgets('store socket hint refreshes READY to ASSIGNED without poll', (
    tester,
  ) async {
    const dropoff = FoodDropoff(lat: 16.1, lng: 108.22, label: '456 Trần Hưng Đạo');
    FoodOrderDetail detail(String status, {String? code}) => FoodOrderDetail(
      id: 'order-placed-1',
      status: status,
      subtotalVnd: 125000,
      deliveryFareVnd: 25000,
      totalVnd: 150000,
      dropoff: dropoff,
      lines: const [],
      handoverCode: code,
    );
    final food = FakeFoodClient()
      ..queueOrders = [
        MerchantQueueOrder(
          id: 'order-placed-1',
          storeId: 'store-1',
          status: 'READY',
          deliveryFareVnd: 25000,
          subtotalVnd: 125000,
          totalVnd: 150000,
          dropoff: dropoff,
          lineCount: 3,
          createdAt: '2026-10-14T02:20:00.000Z',
        ),
      ]
      ..orderDetail = detail('READY');
    final realtime = FakeSnapshotRealtime()..connected = true;
    await _openOrders(tester, food, realtime: realtime);
    final card = find.byKey(const Key('merchant-order-order-placed-1'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Đơn đã sẵn sàng'), findsOneWidget);
    final readsBefore = food.orderReads.length;
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(food.orderReads.length, readsBefore);
    food.orderDetail = detail('ASSIGNED', code: '4417');
    realtime.emitHint(
      const SnapshotHint(
        aggregateType: 'FoodOrder',
        aggregateId: 'order-placed-1',
        status: 'ASSIGNED',
        revision: 'r1',
        occurredAt: '2026-10-19T10:00:00.000Z',
        storeId: 'store-1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã có tài xế'), findsWidgets);
    expect(realtime.subscribed, contains('store:store-1'));
  });

  testWidgets('empty list shows the empty state', (tester) async {
    final food = FakeFoodClient();
    await _openOrders(tester, food);

    expect(food.queueCalls, isNotEmpty);
    expect(find.text('Chưa có đơn mới'), findsOneWidget);
    // No made-up store status or counters on the empty state.
    expect(find.text('Đang mở'), findsNothing);
    expect(find.text('Tự động / thủ công'), findsNothing);
    expect(find.text('PLACED'), findsNothing);
    expect(find.text('Không tải được đơn hàng'), findsNothing);
  });

  testWidgets(
    'empty queue still subscribes store room from catalog (DEC-PROD-043)',
    (tester) async {
      final food = FakeFoodClient(
        details: {
          'store-bun-bo': const FoodStoreDetail(
            id: 'store-bun-bo',
            name: 'Bún bò Huế',
            items: [],
          ),
        },
      );
      final realtime = FakeSnapshotRealtime()..connected = true;
      await pumpSignedIn(
        tester,
        profile: _merchantProfile,
        foodClient: food,
        realtime: realtime,
      );
      await tester.pumpAndSettle();
      final home = navLabel('Tổng quan');
      if (home.evaluate().isNotEmpty) {
        await tester.tap(home.first);
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(food.catalogCalls, isNotEmpty);
      expect(realtime.subscribed, contains('store:store-bun-bo'));
    },
  );

  testWidgets('accept sends the order id and shows PREPARING', (tester) async {
    final food = FakeFoodClient()..queueOrders = [_placedOrder()];
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    await tester.tap(find.byKey(const Key('merchant-accept')));
    await tester.pumpAndSettle();

    expect(food.acceptCalls, ['order-placed-1']);
    expect(find.text('Đơn đang chuẩn bị'), findsOneWidget);
    expect(find.text('Đang chuẩn bị'), findsWidgets);
    expect(find.text('Đơn đã được xử lý'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
  });

  testWidgets('404 shows the conflict message and not success', (tester) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..acceptError = const ApiException(
        statusCode: 404,
        message: 'Food order not found',
        errorCode: 'FOOD_ORDER_NOT_FOUND',
      );
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    await tester.tap(find.byKey(const Key('merchant-accept')));
    await tester.pumpAndSettle();

    expect(food.acceptCalls, ['order-placed-1']);
    expect(find.text('Đơn đã được xử lý'), findsOneWidget);
    expect(
      find.text(
        'Đơn đã thay đổi trạng thái (khách hủy, nhân viên khác hoặc hệ thống đã xử lý).',
      ),
      findsOneWidget,
    );
    expect(find.text('PREPARING'), findsNothing);
    expect(find.text('Đang chuẩn bị'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
    expect(find.text('125.000đ'), findsWidgets);
  });

  testWidgets('403 shows ineligible, not an empty queue', (tester) async {
    final food = FakeFoodClient()
      ..queueOrders = [
        _placedOrder(dropoff: 'Không được hiện như hàng đợi trống'),
      ]
      ..queueError = const ApiException(
        statusCode: 403,
        message: 'An active role is required',
        errorCode: 'ROLE_NOT_ACTIVE',
      );
    await _openOrders(tester, food);

    expect(food.queueCalls, isNotEmpty);
    expect(find.text('Cửa hàng chưa được phép nhận đơn'), findsWidgets);
    expect(find.text('Chưa có đơn mới'), findsNothing);
    expect(find.text('Không được hiện như hàng đợi trống'), findsNothing);
    expect(find.text('PLACED'), findsNothing);
  });

  testWidgets(
    'network failure shows the queue error and does not move the order',
    (tester) async {
      final food = FakeFoodClient()
        ..queueOrders = [_placedOrder()]
        ..acceptError = Exception('offline');
      await _openOrders(tester, food);
      await _openPlacedOrder(tester);
      await tester.tap(find.byKey(const Key('merchant-accept')));
      await tester.pumpAndSettle();

      expect(food.acceptCalls, ['order-placed-1']);
      expect(find.text('Không tải được đơn hàng'), findsOneWidget);
      expect(
        find.text(
          'Lỗi kết nối không có nghĩa là không có đơn. Hãy thử lại để xem đơn mới.',
        ),
        findsOneWidget,
      );
      expect(find.text('PREPARING'), findsNothing);
      expect(find.text('Đang chuẩn bị'), findsNothing);
      expect(find.textContaining('thành công'), findsNothing);
      expect(find.text('Chưa có đơn mới'), findsNothing);
    },
  );

  testWidgets('reject calls the server and leaves the order', (tester) async {
    final food = FakeFoodClient()..queueOrders = [_placedOrder()];
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    expect(find.text('Khách hàng DealGo'), findsOneWidget);
    expect(find.text('Trần Thị Mai'), findsNothing);
    expect(find.textContaining('v1 · Dữ liệu'), findsNothing);

    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('merchant-reject-reason-OUT_OF_STOCK')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-reject-confirm')));
    await tester.pumpAndSettle();

    expect(food.rejectCalls, ['order-placed-1']);
    expect(food.rejectReasons.single.reason, FoodRejectReason.outOfStock);
    expect(food.rejectReasons.single.note, isNull);
    expect(
      find.text('Đã từ chối đơn. Khách được thông báo đơn bị hủy.'),
      findsOneWidget,
    );
  });

  testWidgets('reject needs a reason, and a note for "other"', (tester) async {
    final food = FakeFoodClient()..queueOrders = [_placedOrder()];
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    TextButton confirm() => tester.widget<TextButton>(
      find.byKey(const Key('merchant-reject-confirm')),
    );
    expect(confirm().onPressed, isNull);
    await tester.tap(find.byKey(const Key('merchant-reject-reason-OTHER')));
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('merchant-reject-note')),
      '  Bếp hỏng  ',
    );
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('merchant-reject-confirm')));
    await tester.pumpAndSettle();

    expect(food.rejectReasons.single.reason, FoodRejectReason.other);
    expect(food.rejectReasons.single.note, 'Bếp hỏng');
  });

  testWidgets('reject after the customer cancelled shows the conflict', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..rejectError = const ApiException(
        statusCode: 409,
        message: 'conflict',
        errorCode: 'FOOD_STATUS_CONFLICT',
      );
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('merchant-reject-reason-OUT_OF_STOCK')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-reject-confirm')));
    await tester.pumpAndSettle();

    expect(food.rejectCalls, ['order-placed-1']);
    expect(find.text('Đơn đã được xử lý'), findsOneWidget);
    expect(find.textContaining('Đã từ chối'), findsNothing);
  });

  test('store detail decodes the M024 service mode (DEC-PROD-026)', () {
    final store = decodeFoodStoreDetail({
      'success': true,
      'data': {
        'id': 'store-1',
        'name': 'Bún Bò',
        'items': <Object?>[],
        'serviceMode': 'PAUSED',
        'serviceModeUntil': '2026-10-20T03:30:00.000Z',
      },
    });
    expect(store.serviceMode, StoreServiceMode.paused);
    expect(store.isPaused, isTrue);
    expect(store.serviceModeUntil, DateTime.utc(2026, 10, 20, 3, 30));
    final legacy = decodeFoodStoreDetail({
      'success': true,
      'data': {'id': 'store-1', 'name': 'Bún Bò', 'items': <Object?>[]},
    });
    expect(legacy.serviceMode, StoreServiceMode.open);
  });

  testWidgets('M024 saves pause with auto-resume and the home chip follows', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      initialLocation: '/merchant',
    );
    final chip = find.byKey(const Key('merchant-home-mode-chip'));
    await tester.scrollUntilVisible(chip, 200);
    expect(
      find.descendant(of: chip, matching: find.text('Đang mở')),
      findsOneWidget,
    );

    final open = find.byKey(const Key('merchant-open-busy'));
    await tester.scrollUntilVisible(open, 200);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Tình trạng cửa hàng'), findsOneWidget);
    expect(find.text('Đang nhận đơn'), findsOneWidget);
    expect(find.byKey(const Key('merchant-busy-resume-30')), findsNothing);

    final paused = find.byKey(const Key('merchant-busy-paused'));
    await tester.ensureVisible(paused);
    await tester.tap(paused);
    await tester.pumpAndSettle();
    final hour = find.byKey(const Key('merchant-busy-resume-60'));
    await Scrollable.ensureVisible(tester.element(hour), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(hour);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-busy-save')));
    await tester.pumpAndSettle();

    expect(food.storeStatusCalls, [(StoreServiceMode.paused, 60)]);
    final saved = find.byKey(const Key('merchant-busy-saved'));
    await tester.scrollUntilVisible(saved, 200);
    expect(saved, findsOneWidget);
    final resumes = find.byKey(const Key('merchant-busy-resumes'));
    await tester.scrollUntilVisible(resumes, -200);
    expect(resumes, findsOneWidget);
    expect(find.text('Tạm ngưng nhận đơn'), findsWidgets);

    await tester.tap(find.byType(AuthBackButton).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(chip, -200);
    expect(
      find.descendant(of: chip, matching: find.text('Tạm ngưng')),
      findsOneWidget,
    );
  });

  test('store detail and list decode the M023 schedule (DEC-PROD-027)', () {
    final store = decodeFoodStoreDetail({
      'success': true,
      'data': {
        'id': 'store-1',
        'name': 'Bún Bò',
        'items': <Object?>[],
        'openNow': false,
        'closedReason': 'CLOSED',
        'schedule': {
          'hoursConfigured': true,
          'lastOrderMinutes': 15,
          'weekly': [
            {'weekday': 1, 'opensAt': '07:00', 'closesAt': '22:00'},
          ],
          'closures': [
            {'date': '2027-01-01', 'note': 'Tết'},
          ],
        },
      },
    });
    expect(store.openNow, isFalse);
    expect(store.closedReason, StoreClosedReason.closed);
    expect(store.schedule.lastOrderMinutes, 15);
    expect(store.schedule.day(1)?.closesAt, '22:00');
    expect(store.schedule.day(7), isNull);
    expect(store.schedule.closures.single.note, 'Tết');

    final legacy = decodeFoodStoreDetail({
      'success': true,
      'data': {'id': 'store-1', 'name': 'Bún Bò', 'items': <Object?>[]},
    });
    expect(legacy.openNow, isTrue);
    expect(legacy.schedule.hoursConfigured, isFalse);
  });

  testWidgets('M030 store profile: renames the store and manages the logo (DEC-PROD-045)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      documentImageSource: FakeDocumentImageSource(
        nextImage: PickedDocumentImage(
          bytes: Uint8List.fromList(List<int>.filled(64, 1)),
          contentType: 'image/png',
        ),
      ),
      initialLocation: '/merchant',
    );
    await tester.tap(find.text('Tài khoản').last);
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('account-store-profile'));
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-profile-logo-empty')), findsOneWidget);
    final name = find.byKey(const Key('merchant-profile-name'));
    expect(tester.widget<TextField>(name).controller!.text, 'Bún Bò Huế O Cò');

    await tester.enterText(name, 'x');
    await tester.pump();
    expect(find.text('Tên quán cần từ 2 đến 120 ký tự.'), findsOneWidget);
    await tester.enterText(name, '  Bún Bò   Cô Ba  ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('merchant-profile-save')));
    await tester.pumpAndSettle();
    expect(food.storeProfileCalls, ['Bún Bò Cô Ba']);
    expect(find.text('Đã lưu tên quán.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-profile-logo-pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-profile-logo')), findsOneWidget);
    expect(find.text('Đã cập nhật logo.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-profile-logo-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-profile-logo-empty')), findsOneWidget);
    expect(find.byKey(const Key('merchant-profile-logo-remove')), findsNothing);
  });

  test('store detail decodes the M030 logo path', () {
    final store = decodeFoodStoreDetail({
      'success': true,
      'data': {
        'id': 'store-1',
        'name': 'Bún Bò',
        'logoUrl': '/v1/public/store-logos/store-1/a.png',
        'items': <Object?>[],
      },
    });
    expect(store.logoUrl, '/v1/public/store-logos/store-1/a.png');
    expect(store.copyWith(clearLogoUrl: true).logoUrl, isNull);
  });

  testWidgets('M030 store location: warns when unset, picks and saves (DEC-PROD-044)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      places: FakePlacesRemoteDataSource(
        recent: const [
          PlaceOption(
            name: 'Chợ Hàn',
            address: '119 Trần Phú, Hải Châu, Đà Nẵng',
            lat: 16.068,
            lng: 108.2235,
            source: PlaceSource.recent,
          ),
        ],
      ),
      initialLocation: '/merchant',
    );
    final link = find.byKey(const Key('merchant-open-location'));
    await tester.scrollUntilVisible(link, 200);
    await Scrollable.ensureVisible(tester.element(link), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-location-unset')), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-location-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chợ Hàn').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-location-save')));
    await tester.pumpAndSettle();

    final saved = food.storeLocationCalls.single;
    expect(saved.$1, 16.068);
    expect(saved.$2, 108.2235);
    expect(saved.$3, 'Chợ Hàn, 119 Trần Phú, Hải Châu, Đà Nẵng');
    expect(find.byKey(const Key('merchant-location-saved')), findsOneWidget);
    expect(find.byKey(const Key('merchant-location-unset')), findsNothing);
  });

  test('store detail decodes the pickup point (M030)', () {
    final store = decodeFoodStoreDetail({
      'success': true,
      'data': {
        'id': 's1',
        'name': 'Quán',
        'items': <Object>[],
        'lat': 16.05,
        'lng': 108.2,
        'addressLabel': '1 Lê Duẩn',
      },
    });
    expect(store.hasLocation, isTrue);
    expect(store.lat, 16.05);
    expect(store.addressLabel, '1 Lê Duẩn');
    final bare = decodeFoodStoreDetail({
      'success': true,
      'data': {'id': 's2', 'name': 'Quán 2', 'items': <Object>[]},
    });
    expect(bare.hasLocation, isFalse);
  });

  testWidgets('M023 saves weekly hours, a day off and the cut-off', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      initialLocation: '/merchant',
    );
    final link = find.byKey(const Key('merchant-open-hours'));
    await tester.scrollUntilVisible(link, 200);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Lịch hoạt động'), findsOneWidget);
    expect(find.byKey(const Key('merchant-hours-unset')), findsOneWidget);

    // Sunday off.
    await tester.tap(find.byKey(const Key('merchant-hours-day-7')));
    await tester.pumpAndSettle();
    final cutoff = find.byKey(const Key('merchant-hours-cutoff-30'));
    await tester.scrollUntilVisible(cutoff, 200);
    await Scrollable.ensureVisible(tester.element(cutoff), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(cutoff);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-hours-save')));
    await tester.pumpAndSettle();

    final saved = food.storeHoursCalls.single;
    expect(saved.lastOrderMinutes, 30);
    expect(saved.weekly.map((day) => day.weekday), [1, 2, 3, 4, 5, 6]);
    expect(saved.weekly.first.opensAt, '07:00');
    expect(saved.weekly.first.closesAt, '22:00');
    final ok = find.byKey(const Key('merchant-hours-saved'));
    await tester.scrollUntilVisible(ok, 200);
    expect(ok, findsOneWidget);
    expect(find.byKey(const Key('merchant-hours-unset')), findsNothing);
  });

  test(
    'store detail and order decode M022 settings and ETA (DEC-PROD-028)',
    () {
      final store = decodeFoodStoreDetail({
        'success': true,
        'data': {
          'id': 'store-1',
          'name': 'Bún Bò',
          'items': <Object?>[],
          'serviceMode': 'BUSY',
          'estimatedPrepMinutes': 50,
          'acceptSettings': {
            'acceptMode': 'AUTO',
            'maxActiveOrders': 8,
            'defaultPrepMinutes': 20,
            'busyExtraMinutes': 30,
          },
        },
      });
      expect(store.acceptSettings.acceptMode, StoreAcceptMode.auto);
      expect(store.acceptSettings.maxActiveOrders, 8);
      expect(store.acceptSettings.defaultPrepMinutes, 20);
      expect(store.acceptSettings.busyExtraMinutes, 30);
      expect(store.estimatedPrepMinutes, 50);
      final legacy = decodeFoodStoreDetail({
        'success': true,
        'data': {'id': 'store-1', 'name': 'Bún Bò', 'items': <Object?>[]},
      });
      expect(legacy.acceptSettings.acceptMode, StoreAcceptMode.manual);
      expect(legacy.acceptSettings.maxActiveOrders, isNull);
      expect(legacy.estimatedPrepMinutes, isNull);

      final order = decodeFoodOrderDetail({
        'success': true,
        'data': {
          'id': 'order-1',
          'status': 'PREPARING',
          'subtotalVnd': 45000,
          'deliveryFareVnd': 15000,
          'totalVnd': 60000,
          'dropoff': {'lat': 16.05, 'lng': 108.2, 'label': 'Hải Châu'},
          'lines': <Object?>[],
          'prepMinutes': 25,
          'estimatedReadyAt': '2026-10-20T05:25:00.000Z',
        },
      });
      expect(order.prepMinutes, 25);
      expect(order.estimatedReadyAt, DateTime.utc(2026, 10, 20, 5, 25));
    },
  );

  testWidgets('M022 saves auto accept, kitchen cap, prep time and cut-off', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      initialLocation: '/merchant',
    );
    final link = find.byKey(const Key('merchant-open-accept'));
    await tester.scrollUntilVisible(link, 200);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập nhận đơn'), findsOneWidget);
    expect(find.text('Trạng thái hoạt động: đang nhận đơn'), findsOneWidget);
    expect(
      find.text('Cài đặt này hiện chỉ lưu trên thiết bị này.'),
      findsNothing,
    );
    expect(find.text('Không giới hạn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-accept-auto')));
    await tester.pumpAndSettle();
    Future<void> pick(String row, String option) async {
      final target = find.byKey(Key(row));
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(option)));
      await tester.pumpAndSettle();
    }

    await pick('merchant-accept-max', 'merchant-accept-max-option-8');
    await pick('merchant-accept-prep', 'merchant-accept-prep-option-20');
    await pick('merchant-accept-cutoff', 'merchant-accept-cutoff-option-15');
    expect(find.text('8 đơn'), findsOneWidget);
    expect(find.text('20 phút'), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchant-accept-save')));
    await tester.pumpAndSettle();

    final (settings, lastOrder) = food.storeAcceptCalls.single;
    expect(settings.acceptMode, StoreAcceptMode.auto);
    expect(settings.maxActiveOrders, 8);
    expect(settings.defaultPrepMinutes, 20);
    expect(lastOrder, 15);
    final ok = find.byKey(const Key('merchant-accept-saved'));
    await tester.scrollUntilVisible(ok, 200);
    expect(ok, findsOneWidget);

    // Back to "no limit" clears the cap.
    await pick('merchant-accept-max', 'merchant-accept-max-option-none');
    await tester.tap(find.byKey(const Key('merchant-accept-save')));
    await tester.pumpAndSettle();
    expect(food.storeAcceptCalls.last.$1.maxActiveOrders, isNull);
  });

  testWidgets('M024 BUSY sends the extra prep minutes', (tester) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      initialLocation: '/merchant',
    );
    final open = find.byKey(const Key('merchant-open-busy'));
    await tester.scrollUntilVisible(open, 200);
    await Scrollable.ensureVisible(tester.element(open), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Tình trạng cửa hàng'), findsOneWidget);
    expect(find.byKey(const Key('merchant-busy-extra-30')), findsNothing);
    final busy = find.byKey(const Key('merchant-busy-busy'));
    await tester.ensureVisible(busy);
    await tester.tap(busy);
    await tester.pumpAndSettle();
    final extra = find.byKey(const Key('merchant-busy-extra-30'));
    await Scrollable.ensureVisible(tester.element(extra), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(extra);
    await tester.pumpAndSettle();
    expect(
      find.text('Khách sẽ thấy thời gian chuẩn bị khoảng 45 phút.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('merchant-busy-save')));
    await tester.pumpAndSettle();
    expect(food.storeStatusCalls.single.$1, StoreServiceMode.busy);
    expect(food.storeBusyExtraCalls.single, 30);
  });

  testWidgets('M023 keeps an overnight shift and marks it next day (DEC-PROD-029)', (
    tester,
  ) async {
    const night = StoreDayHours(weekday: 5, opensAt: '18:00', closesAt: '02:00');
    expect(night.overnight, isTrue);
    expect(
      const StoreDayHours(weekday: 6, opensAt: '10:00', closesAt: '24:00').overnight,
      isFalse,
    );
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [],
          schedule: StoreSchedule(
            hoursConfigured: true,
            weekly: [night],
          ),
        ),
      };
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      initialLocation: '/merchant',
    );
    final link = find.byKey(const Key('merchant-open-hours'));
    await tester.scrollUntilVisible(link, 200);
    await Scrollable.ensureVisible(tester.element(link), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    final marker = find.byKey(const Key('merchant-hours-overnight-5'));
    await tester.scrollUntilVisible(marker, 100);
    expect(tester.widget<Text>(marker).data, 'hôm sau');
    await tester.tap(find.byKey(const Key('merchant-hours-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-hours-error')), findsNothing);
    final saved = food.storeHoursCalls.single;
    expect(saved.weekly.single.opensAt, '18:00');
    expect(saved.weekly.single.closesAt, '02:00');
  });

  testWidgets('store lists label closed and paused stores', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Column(
            children: [
              StoreMetaLine(
                store: FoodStoreSummary(
                  id: 's1',
                  name: 'A',
                  category: 'pho',
                  closedReason: StoreClosedReason.closed,
                ),
              ),
              StoreMetaLine(
                store: FoodStoreSummary(
                  id: 's2',
                  name: 'B',
                  closedReason: StoreClosedReason.paused,
                ),
              ),
              StoreMetaLine(store: FoodStoreSummary(id: 's3', name: 'C')),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('Đóng cửa'), findsOneWidget);
    expect(find.textContaining('Tạm ngưng'), findsOneWidget);
    expect(find.byKey(const Key('store-meta-s3')), findsNothing);
  });

  test('FOOD_STORE_PAUSED reads as a friendly checkout error', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(
      apiErrorText(
        l10n,
        const ApiException(
          statusCode: 409,
          message: 'The store is not taking new orders right now',
          errorCode: 'FOOD_STORE_PAUSED',
        ),
      ),
      'Quán đang tạm ngưng nhận đơn. Vui lòng thử lại sau.',
    );
  });
}

Future<void> _openOrders(
  WidgetTester tester,
  FakeFoodClient food, {
  SnapshotRealtime? realtime,
}) async {
  await pumpSignedIn(
    tester,
    profile: _merchantProfile,
    foodClient: food,
    realtime: realtime,
  );
  await tester.tap(navLabel('Đơn hàng'));
  await tester.pumpAndSettle();
}

Future<void> _openPlacedOrder(WidgetTester tester) async {
  final card = find.byKey(const Key('merchant-order-order-placed-1'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
  final accept = find.byKey(const Key('merchant-accept'));
  await tester.ensureVisible(accept);
}

MerchantQueueOrder _placedOrder({String dropoff = '456 Trần Hưng Đạo'}) {
  return MerchantQueueOrder(
    id: 'order-placed-1',
    storeId: 'store-1',
    status: 'PLACED',
    deliveryFareVnd: 25000,
    subtotalVnd: 125000,
    totalVnd: 150000,
    dropoff: FoodDropoff(lat: 16.1, lng: 108.22, label: dropoff),
    lineCount: 3,
    createdAt: '2026-10-14T02:20:00.000Z',
  );
}
