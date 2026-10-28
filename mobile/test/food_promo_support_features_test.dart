import 'package:dealgo/core/config/api_base_url.dart';

import 'support/visual_shot.dart';

import 'package:dealgo/core/mock/fake_food_client.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/promotion/data/datasources/promotion_remote_datasource.dart';
import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/ride/data/ride_share_remote_datasource.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:dealgo/features/shell/presentation/help_center_page.dart';
import 'package:dealgo/features/support/data/help_faq_remote_datasource.dart';
import 'package:dealgo/features/support/data/support_remote_datasource.dart';
import 'package:dealgo/features/support/domain/help_faq.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
]);

void main() {
  group('decoders', () {
    test('cancel reason maps unknown codes to OTHER and trims notes', () {
      final reason = decodeFoodCancelReason({
        'code': 'NEW_CODE',
        'note': ' x ',
      });
      expect(reason?.reason, FoodRejectReason.other);
      expect(reason?.note, 'x');
      expect(decodeFoodCancelReason(null), isNull);
      expect(
        decodeFoodCancelReason({'code': 'OUT_OF_STOCK', 'note': null})?.reason,
        FoodRejectReason.outOfStock,
      );
    });

    test('available vouchers skip malformed rows', () {
      final items = decodeAvailableVouchers([
        {
          'code': 'FOOD15',
          'name': 'Giảm 15k',
          'description': '',
          'serviceType': 'FOOD',
          'discountType': 'FIXED_AMOUNT',
          'discountValue': 15000,
          'maxDiscountVnd': null,
          'minOrderVnd': 60000,
          'endsAt': '2026-11-01T00:00:00.000Z',
          'usesLeft': 2,
        },
        {'code': 'BROKEN'},
      ]);
      expect(items, hasLength(1));
      expect(items.single.kind, VoucherDiscountKind.fixedAmount);
      expect(items.single.minOrderVnd, 60000);
      expect(items.single.usesLeft, 2);
    });

    test('help FAQ decoder keeps only complete rows', () {
      expect(
        decodeHelpFaqs([
          {'id': 'a', 'question': 'Q', 'answer': 'A'},
          {'id': 'b', 'question': 'Q'},
        ]).map((f) => f.id),
        ['a'],
      );
    });

    test('help audience follows the shell', () {
      expect(helpAudienceFor('/driver/account'), 'DRIVER');
      expect(helpAudienceFor('/merchant/account'), 'MERCHANT');
      expect(helpAudienceFor('/customer/account'), 'CUSTOMER');
    });

    test('media URLs resolve against the API base', () {
      expect(
        resolveMediaUrl('/v1/public/avatars/u/a.png', base: 'https://api.x/'),
        'https://api.x/v1/public/avatars/u/a.png',
      );
      expect(resolveMediaUrl('https://cdn/x.png'), 'https://cdn/x.png');
      expect(resolveMediaUrl('mock://avatar'), isNull);
      expect(resolveMediaUrl(null), isNull);
    });
  });

  testWidgets('help center shows the server FAQ and filters it', (
    tester,
  ) async {
    _tallPhone(tester);
    final faqs = FakeHelpFaqRepository(
      items: const [
        HelpFaq(
          id: 'f1',
          question: 'Hủy đơn đồ ăn?',
          answer: 'Trước khi quán nhận.',
        ),
        HelpFaq(
          id: 'f2',
          question: 'Mã ưu đãi ở đâu?',
          answer: 'Trong mục Ưu đãi.',
        ),
      ],
    );
    await pumpSignedIn(tester, profile: customerProfile, helpFaqs: faqs);
    await _go(tester, '/customer/account/help');

    expect(faqs.calls, ['CUSTOMER']);
    expect(find.text('Hủy đơn đồ ăn?'), findsOneWidget);
    expect(find.text('Khi nào nhận được tiền hoàn?'), findsNothing);
    await tester.tap(find.text('Hủy đơn đồ ăn?'));
    await tester.pumpAndSettle();
    expect(find.text('Trước khi quán nhận.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'ưu đãi');
    await tester.pumpAndSettle();
    expect(find.text('Hủy đơn đồ ăn?'), findsNothing);
    expect(find.text('Mã ưu đãi ở đâu?'), findsOneWidget);
  });

  testWidgets('help center shows a retry when the FAQ fails', (tester) async {
    _tallPhone(tester);
    final faqs = FakeHelpFaqRepository(
      error: const ApiException(
        statusCode: 0,
        message: 'x',
        errorCode: 'NETWORK_ERROR',
      ),
    );
    await pumpSignedIn(tester, profile: customerProfile, helpFaqs: faqs);
    await _go(tester, '/customer/account/help');
    expect(faqs.calls, ['CUSTOMER']);
    expect(find.byKey(const Key('help-faq-error')), findsOneWidget);

    faqs
      ..error = null
      ..items = const [HelpFaq(id: 'd', question: 'Rút tiền?', answer: 'A')];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Rút tiền?'), findsOneWidget);
  });

  testWidgets('support ticket sends picked photos and shows attachment chips', (
    tester,
  ) async {
    _tallPhone(tester);
    final support = FakeSupportRepository()..attachmentBytes = _png;
    final images = FakeDocumentImageSource(
      nextImage: PickedDocumentImage(bytes: _png, contentType: 'image/png'),
    );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      support: support,
      documentImageSource: images,
    );
    await _go(tester, '/customer/account/help/tickets/new');
    await tester.enterText(
      find.byKey(const Key('support-subject')),
      'Thu sai tiền',
    );
    await tester.enterText(
      find.byKey(const Key('support-description')),
      'Tài xế thu thêm tiền mặt so với giá trên ứng dụng.',
    );
    await tester.tap(find.byKey(const Key('support-attach-gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support-attach-camera')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-attach-thumb-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('support-attach-remove-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-attach-thumb-1')), findsNothing);
    expect(images.calls.map((c) => c.camera), [false, true]);

    await tester.ensureVisible(find.byKey(const Key('support-submit')));
    await tester.tap(find.byKey(const Key('support-submit')));
    await tester.pumpAndSettle();

    final sent = support.created.single.attachments;
    expect(sent, hasLength(1));
    expect(sent.single.contentType, 'image/png');
    expect(sent.single.contentBase64, 'iVBORw0KGgo=');
  });

  testWidgets('storage outage on a reply shows the attachment copy', (
    tester,
  ) async {
    _tallPhone(tester);
    final support = FakeSupportRepository();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      support: support,
      documentImageSource: FakeDocumentImageSource(
        nextImage: PickedDocumentImage(bytes: _png, contentType: 'image/png'),
      ),
    );
    await _go(tester, '/customer/account/help/tickets/new');
    await tester.enterText(find.byKey(const Key('support-subject')), 'Thu sai');
    await tester.enterText(
      find.byKey(const Key('support-description')),
      'Tài xế thu thêm tiền mặt so với giá trên ứng dụng.',
    );
    support.failNext = const ApiException(
      statusCode: 503,
      message: 'x',
      errorCode: 'STORAGE_UNAVAILABLE',
    );
    await tester.tap(find.byKey(const Key('support-attach-gallery')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('support-submit')));
    await tester.tap(find.byKey(const Key('support-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa gửi được tệp đính kèm'), findsOneWidget);
  });

  testWidgets('customer sees why the store declined the order', (tester) async {
    _tallPhone(tester);
    final food = FakeFoodClient()
      ..orderDetail = const FoodOrderDetail(
        id: 'order-1',
        status: 'CANCELLED',
        subtotalVnd: 125000,
        deliveryFareVnd: 25000,
        totalVnd: 150000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        lines: [],
        cancelReason: FoodCancelReason(
          reason: FoodRejectReason.outOfStock,
          note: 'Hết bún bò',
        ),
      );
    await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
    await _go(tester, FoodRoutes.order('order-1'));
    expect(
      find.byKey(const Key('food-tracking-reject-reason')),
      findsOneWidget,
    );
    expect(find.text('Lý do: Hết món — Hết bún bò'), findsOneWidget);
    // Nothing to pay or chat about on a declined order.
    expect(find.byKey(const Key('food-open-chat')), findsNothing);
    expect(find.text('Cần thanh toán khi nhận hàng'), findsNothing);
    expect(find.byKey(const Key('food-cancelled-browse')), findsOneWidget);
  });

  testWidgets('vouchers page attaches a code to the cart', (tester) async {
    _tallPhone(tester);
    await pumpSignedIn(tester, profile: customerProfile);
    await _go(tester, '/customer/account/vouchers');
    expect(find.text('DEALGO10'), findsOneWidget);
    await tester.tap(find.byKey(const Key('voucher-use-DEALGO10')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã gắn mã DEALGO10'), findsOneWidget);
  });

  group('trip share', () {
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    late List<Map<Object?, Object?>> shared;
    late String shareReply;
    String? copied;

    setUp(() {
      shared = [];
      shareReply = 'com.zing.zalo';
      copied = null;
    });

    Future<FakeRideShareRepository> open(WidgetTester tester) async {
      _tallPhone(tester);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        shared.add(call.arguments as Map<Object?, Object?>);
        return shareReply;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(shareChannel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final share = FakeRideShareRepository();
      await pumpSignedIn(tester, profile: customerProfile, rideShare: share);
      await _go(tester, RideRoutes.safety('ride-9'));
      return share;
    }

    testWidgets('opens the system share sheet with the server link', (
      tester,
    ) async {
      await loadShotFonts(tester);
      final share = await open(tester);
      await saveShot(tester, 'G-safety-before-share');
      await tester.tap(find.byKey(const Key('ride-safety-share')));
      await tester.pumpAndSettle();
      await saveShot(tester, 'G-safety-after-share');
      expect(share.calls, ['ride-9']);
      expect(shared, hasLength(1));
      expect(
        shared.single['text'],
        'Theo dõi chuyến đi DealGo của mình: '
        'http://localhost:3000/chia-se-chuyen/demo-1',
      );
      expect(shared.single['subject'], 'Chuyến đi DealGo của mình');
      expect(shared.single.containsKey('originX'), isTrue);
      expect(copied, isNull);
      expect(find.text('Đã chia sẻ'), findsOneWidget);

      // Sharing again reuses the link instead of minting another.
      await tester.tap(find.byKey(const Key('ride-safety-share')));
      await tester.pumpAndSettle();
      expect(share.calls, ['ride-9']);
      expect(shared, hasLength(2));
    });

    testWidgets('a dismissed sheet changes nothing', (tester) async {
      shareReply = '';
      await open(tester);
      await tester.tap(find.byKey(const Key('ride-safety-share')));
      await tester.pumpAndSettle();
      expect(shared, hasLength(1));
      expect(find.byKey(const Key('ride-safety-share-outcome')), findsNothing);
      expect(copied, isNull);
    });

    testWidgets('no share sheet falls back to copying the link', (
      tester,
    ) async {
      shareReply = 'dev.fluttercommunity.plus/share/unavailable';
      await open(tester);
      await tester.tap(find.byKey(const Key('ride-safety-share')));
      await tester.pumpAndSettle();
      expect(copied, 'http://localhost:3000/chia-se-chuyen/demo-1');
      expect(find.text('Đã sao chép'), findsOneWidget);
    });

    testWidgets('copy link copies without the sheet', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('ride-safety-copy')));
      await tester.pumpAndSettle();
      expect(shared, isEmpty);
      expect(copied, 'http://localhost:3000/chia-se-chuyen/demo-1');
    });

    testWidgets('a trip without a driver maps the 409', (tester) async {
      final share = await open(tester);
      share.error = const ApiException(
        statusCode: 409,
        message: 'x',
        errorCode: 'RIDE_SHARE_NOT_ACTIVE',
      );
      await tester.tap(find.byKey(const Key('ride-safety-share')));
      await tester.pumpAndSettle();
      expect(
        find.text('Chỉ chia sẻ được khi đã có tài xế nhận chuyến.'),
        findsOneWidget,
      );
      expect(shared, isEmpty);
    });
  });

  test('fake voucher list filters by service', () async {
    final fake = FakePromotionRemoteDataSource(
      available: [
        AvailableVoucher(
          code: 'R',
          name: 'R',
          description: '',
          service: null,
          kind: VoucherDiscountKind.percentage,
          discountValue: 5,
          minOrderVnd: 0,
          endsAt: DateTime(2030),
          usesLeft: 1,
        ),
      ],
    );
    expect(await fake.listAvailable(accessToken: 't'), hasLength(1));
  });
}
