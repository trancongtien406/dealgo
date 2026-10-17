import 'package:dealgo/features/onboarding/presentation/pages/permissions_page.dart';
import 'package:dealgo/features/onboarding/presentation/pages/profile_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileSetupPage (S005)', () {
    testWidgets('renders all form components and validates required name', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupPage(),
        ),
      );

      expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(find.text('Họ và tên *'), findsOneWidget);
      expect(find.byKey(const Key('name-field')), findsOneWidget);
      expect(find.text('Email (tuỳ chọn)'), findsOneWidget);
      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.text('Ngày sinh (tuỳ chọn)'), findsOneWidget);
      expect(find.text('Giới tính'), findsOneWidget);
      expect(find.text('Nam'), findsOneWidget);
      expect(find.text('Nữ'), findsOneWidget);
      expect(find.text('Khác'), findsOneWidget);
      expect(find.text('Bổ sung sau'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);

      // Initially, "Hoàn tất" button is disabled because name is empty
      final completeButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Hoàn tất'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(completeButton.enabled, isFalse);

      // Enter name
      await tester.enterText(find.byKey(const Key('name-field')), 'Trần Văn DealGo');
      await tester.pumpAndSettle();

      // Now "Hoàn tất" button is enabled
      final completeButtonEnabled = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Hoàn tất'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(completeButtonEnabled.enabled, isTrue);

      // Select female gender
      await tester.ensureVisible(find.text('Nữ'));
      await tester.tap(find.text('Nữ'));
      await tester.pumpAndSettle();
    });
  });

  group('PermissionsPage (S006)', () {
    testWidgets('renders permission cards and toggles permission status', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PermissionsPage(),
        ),
      );

      expect(find.text('Cho phép truy cập'), findsOneWidget);
      expect(find.text('Vị trí'), findsOneWidget);
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Micro & Cuộc gọi'), findsOneWidget);
      expect(find.text('Cho phép tất cả'), findsOneWidget);
      expect(find.text('Thiết lập sau'), findsOneWidget);

      // Initially shows 3 "Cho phép" buttons
      expect(find.text('Cho phép'), findsNWidgets(3));
      expect(find.text('Đã bật'), findsNothing);

      // Toggle first permission (Vị trí)
      await tester.tap(find.text('Cho phép').first);
      await tester.pumpAndSettle();

      expect(find.text('Đã bật'), findsOneWidget);
      expect(find.text('Cho phép'), findsNWidgets(2));
    });
  });
}
