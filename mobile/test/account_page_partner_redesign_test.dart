import 'package:dealgo/features/shell/presentation/customer_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  testWidgets(
    'customer account shows Partner Hub at the top and removes duplicate role items from services',
    (tester) async {
      await pumpSignedIn(tester, profile: customerProfile);
      expect(find.byType(CustomerTabBar), findsOneWidget);

      await tester.tap(navLabel('Tôi'));
      await tester.pumpAndSettle();

      // 1. Partner Hub is displayed at the top with attractive header
      expect(find.text('Cơ hội gia tăng thu nhập'), findsOneWidget);
      expect(
        find.text('Trở thành đối tác Tài xế hoặc mở Quán ăn cùng DealGo'),
        findsOneWidget,
      );

      // 2. Both partner options are visible with clear CTAs
      expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);
      expect(find.text('Hồ sơ đối tác Shop'), findsOneWidget);
      expect(find.text('Đăng ký'), findsNWidgets(2));

      // 3. Single-role customer does not have the bottom "Đổi vai trò" bar in profile
      expect(find.text('Đổi vai trò'), findsNothing);

      // 4. Duplicate "Trung tâm vai trò" row is removed from services section
      expect(find.text('Trung tâm vai trò'), findsNothing);

      // 5. Normal services remain clean
      expect(find.text('Hoạt động của tôi'), findsOneWidget);
      expect(find.text('Địa chỉ đã lưu'), findsOneWidget);
      expect(find.text('Lịch sử thanh toán'), findsOneWidget);
    },
  );

  testWidgets(
    'multi-role user shows integrated role switch bar right at bottom of profile card',
    (tester) async {
      await pumpSignedIn(tester, profile: demoMultiRoleProfile);
      expect(find.byType(CustomerTabBar), findsOneWidget);

      await tester.tap(navLabel('Tôi'));
      await tester.pumpAndSettle();

      // Multi-role user has the "Đổi vai trò" button at bottom of profile card
      expect(find.text('Đổi vai trò'), findsOneWidget);

      // Tapping it opens the role picker page (/roles)
      await tester.tap(find.text('Đổi vai trò'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bạn muốn dùng DealGo theo vai trò nào?', findRichText: true),
        findsOneWidget,
      );
    },
  );
}
