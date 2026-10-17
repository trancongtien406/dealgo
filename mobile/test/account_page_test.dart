import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  testWidgets('customer account tab shows the signed-in phone', (tester) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('+84911111111'), findsOneWidget);
    expect(find.text('Khách hàng'), findsWidgets);
    expect(find.text('Ưu đãi của tôi'), findsOneWidget);
    expect(find.text('Trung tâm vai trò'), findsOneWidget);
    expect(find.text('Trần Minh Anh'), findsNothing);
    expect(find.text('Sửa →'), findsNothing);
    expect(find.text('Chuyến đã đi'), findsNothing);
    expect(find.text('Đơn đã đặt'), findsNothing);
    // Customer without DRIVER/MERCHANT grants can start partner onboarding.
    expect(find.textContaining('Đăng ký'), findsWidgets);
    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);
    expect(find.text('Hồ sơ đối tác Shop'), findsOneWidget);
    expect(find.text('Đổi vai trò'), findsNothing);

    await tester.tap(find.text('Ưu đãi của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('+84911111111'), findsOneWidget);
    expect(navLabel('Tài khoản'), findsOneWidget);
  });

  testWidgets('merchant account tab shows the shop role', (tester) async {
    await pumpSignedIn(tester, profile: _merchantProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('+84933333333'), findsOneWidget);
    expect(find.text('Shop'), findsWidgets);
    expect(find.text('Khách hàng'), findsNothing);
  });

  testWidgets('driver account tab shows the driver role', (tester) async {
    await pumpSignedIn(tester, profile: _driverProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('+84944444444'), findsWidgets);
    expect(find.text('Tài xế'), findsWidgets);
    expect(find.text('Khách hàng'), findsNothing);
  });

  testWidgets('opening addresses shows the saved-address title', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Địa chỉ đã lưu'));
    await tester.tap(find.text('Địa chỉ đã lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Địa chỉ của tôi'), findsOneWidget);
    expect(find.text('Địa chỉ đã lưu'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('address-label-field')),
      'Nhà riêng',
    );
    await tester.tap(find.byKey(const Key('address-label-add')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('address-label-field')),
      'Công ty',
    );
    await tester.tap(find.byKey(const Key('address-label-add')));
    await tester.pump();

    expect(find.byKey(const Key('saved-label-0')), findsOneWidget);
    expect(find.byKey(const Key('saved-label-1')), findsOneWidget);
    expect(find.text('Nhà riêng'), findsOneWidget);
    expect(find.text('Công ty'), findsOneWidget);
    expect(find.byKey(const Key('address-label-field')), findsNothing);
    expect(find.text('Đã lưu'), findsNothing);
  });

  testWidgets('an empty place search shows the empty copy', (tester) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Địa chỉ đã lưu'));
    await tester.tap(find.text('Địa chỉ đã lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm địa chỉ mới'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm kiếm địa điểm'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'Đà Nẵng, đường không tồn tại 9999',
    );
    await tester.pump();

    expect(find.text('Không tìm thấy địa điểm'), findsOneWidget);
    expect(find.text('Đà Nẵng, đường không tồn tại 9999'), findsOneWidget);
    expect(find.text('Sân bay Quốc tế Đà Nẵng'), findsNothing);
  });

  testWidgets('help center shows the support title', (tester) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trung tâm hỗ trợ'));
    await tester.tap(find.text('Trung tâm hỗ trợ'));
    await tester.pumpAndSettle();

    expect(find.text('Trung tâm hỗ trợ'), findsWidgets);
    expect(find.text('Chúng mình có thể giúp gì cho bạn?'), findsOneWidget);
  });

  testWidgets('the account bell opens the notification inbox', (tester) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tài xế đã đến gần bạn'), findsOneWidget);
    expect(find.text('Đã đánh dấu đã đọc'), findsNothing);
  });
}

const _merchantProfile = UserProfile(
  id: 'user-merchant',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

const _driverProfile = UserProfile(
  id: 'user-driver',
  phone: '+84944444444',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);
