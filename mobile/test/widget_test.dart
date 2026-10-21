import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/shell/presentation/customer_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  testWidgets('role picker shows active customer merchant and driver roles', (
    tester,
  ) async {
    await pumpSignedIn(
      tester,
      profile: multiRoleProfile,
      initialLocation: AuthRoutes.roles,
    );

    expect(
      find.text('Bạn muốn dùng DealGo theo vai trò nào?', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Khách hàng'), findsOneWidget);
    expect(find.text('Cửa hàng'), findsOneWidget);
    expect(find.text('Tài xế'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Tìm hiểu thêm'), findsOneWidget);
  });

  testWidgets('tapping Khách hàng shows customer nav label Trang chủ', (
    tester,
  ) async {
    await pumpSignedIn(
      tester,
      profile: multiRoleProfile,
      initialLocation: AuthRoutes.roles,
    );

    await tester.tap(find.text('Khách hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerTabBar), findsOneWidget);
    expect(navLabel('Trang chủ'), findsOneWidget);
    expect(navLabel('Chuyến đi'), findsOneWidget);
    expect(navLabel('Đặt'), findsOneWidget);
    expect(navLabel('Mua hàng'), findsOneWidget);
    expect(navLabel('Tài khoản'), findsOneWidget);
    expect(find.text('DealGo'), findsWidgets);
    expect(find.text('Đặt xe'), findsWidgets);
    expect(find.text('Đồ ăn'), findsWidgets);
  });

  testWidgets('switching role replaces the previous shell nav', (tester) async {
    await pumpSignedIn(
      tester,
      profile: multiRoleProfile,
      initialLocation: AuthRoutes.roles,
    );

    await tester.tap(find.text('Khách hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerTabBar), findsOneWidget);
    expect(navLabel('Đặt'), findsOneWidget);

    await _switchRole(tester, 'Cửa hàng');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(navLabel('Tổng quan'), findsOneWidget);
    expect(navLabel('Thực đơn'), findsOneWidget);
    expect(navLabel('Đặt'), findsNothing);
    expect(navLabel('Việc nhận'), findsNothing);

    await _switchRole(tester, 'Tài xế');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(navLabel('Việc nhận'), findsOneWidget);
    expect(navLabel('Thu nhập'), findsOneWidget);
    expect(navLabel('Đặt'), findsNothing);
    expect(navLabel('Thực đơn'), findsNothing);
  });

  testWidgets(
    'multi-role user lands on role picker then can open customer shell',
    (tester) async {
      await pumpSignedIn(tester, profile: multiRoleProfile);

      expect(
        find.text('Bạn muốn dùng DealGo theo vai trò nào?', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(CustomerTabBar), findsNothing);

      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerTabBar), findsOneWidget);
      expect(navLabel('Trang chủ'), findsOneWidget);

      await tester.tap(navLabel('Tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi vai trò'), findsOneWidget);
    },
  );
}

Future<void> _switchRole(WidgetTester tester, String roleTitle) async {
  await tester.tap(navLabel('Tài khoản'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Đổi vai trò'));
  await tester.tap(find.text('Đổi vai trò'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(roleTitle));
  await tester.tap(find.text(roleTitle));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Tiếp tục'));
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
}
