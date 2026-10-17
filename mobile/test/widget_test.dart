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

    expect(find.text('Trung tâm vai trò'), findsOneWidget);
    expect(find.text('Chế độ Khách hàng'), findsOneWidget);
    expect(find.text('Chế độ Shop'), findsOneWidget);
    expect(find.text('Chế độ Tài xế'), findsOneWidget);
  });

  testWidgets('tapping Khách hàng shows customer nav label Trang chủ', (
    tester,
  ) async {
    await pumpSignedIn(
      tester,
      profile: multiRoleProfile,
      initialLocation: AuthRoutes.roles,
    );

    await tester.tap(find.text('Tiếp tục với Khách hàng'));
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

    await tester.tap(find.text('Tiếp tục với Khách hàng'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerTabBar), findsOneWidget);
    expect(navLabel('Đặt'), findsOneWidget);

    await _switchRole(tester, 'Chế độ Shop', 'Tiếp tục với Shop');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(navLabel('Tổng quan'), findsOneWidget);
    expect(navLabel('Sản phẩm'), findsOneWidget);
    expect(navLabel('Đặt'), findsNothing);
    expect(navLabel('Công việc'), findsNothing);

    await _switchRole(tester, 'Chế độ Tài xế', 'Tiếp tục với Tài xế');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(navLabel('Công việc'), findsOneWidget);
    expect(navLabel('Thu nhập'), findsOneWidget);
    expect(navLabel('Đặt'), findsNothing);
    expect(navLabel('Sản phẩm'), findsNothing);
  });

  testWidgets(
    'multi-role user automatically enters customer shell and skips role picker',
    (tester) async {
      await pumpSignedIn(tester, profile: multiRoleProfile);

      // Skips role picker, lands directly in Customer shell
      expect(find.byType(CustomerTabBar), findsOneWidget);
      expect(navLabel('Trang chủ'), findsOneWidget);
      expect(find.text('Trung tâm vai trò'), findsNothing);

      // User can switch role from Account page
      await tester.tap(navLabel('Tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi vai trò'), findsOneWidget);
    },
  );
}

Future<void> _switchRole(
  WidgetTester tester,
  String mode,
  String continueLabel,
) async {
  await tester.tap(navLabel('Tài khoản'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Đổi vai trò'));
  await tester.tap(find.text('Đổi vai trò'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(mode));
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(continueLabel));
  await tester.tap(find.text(continueLabel));
  await tester.pumpAndSettle();
}
