import 'package:dealgo/core/mock/fake_identity_client.dart';
import 'package:dealgo/features/onboarding/data/datasources/partner_requirements_client.dart';
import 'package:dealgo/features/onboarding/presentation/utils/driver_kyc_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';

// Regression: with KYC switched off (DEC-PROD-048) the driver
// status page still said "Kết quả xét duyệt KYC" / "Xét duyệt giấy tờ".
void main() {
  for (final required in [false, true]) {
    testWidgets('driver status copy follows KYC switch (required=$required)', (
      tester,
    ) async {
      await pumpSignedIn(
        tester,
        profile: pendingPartnerProfile,
        partnerRequirements: FixedPartnerRequirements(required: required),
      );
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(DriverKycRoutes.status);
      await tester.pumpAndSettle();
      if (required) {
        expect(find.text('Kết quả xét duyệt KYC'), findsWidgets);
        expect(find.text('Xét duyệt giấy tờ'), findsOneWidget);
      } else {
        expect(find.text('Trạng thái đăng ký tài xế'), findsWidgets);
        expect(find.text('Admin duyệt hồ sơ'), findsOneWidget);
        expect(find.text('Kết quả xét duyệt KYC'), findsNothing);
        expect(find.text('Xét duyệt giấy tờ'), findsNothing);
      }
    });
  }
}
