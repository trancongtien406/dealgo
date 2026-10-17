import 'package:dealgo/features/onboarding/domain/entities/partner_onboarding.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/shell/presentation/customer_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  test('driver kyc cubit advances steps then submits to pending', () async {
    final cubit = DriverKycCubit();
    expect(cubit.state.status, PartnerApplicationStatus.draft);
    expect(cubit.state.step, DriverKycStep.services);

    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.personal);
    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.identity);

    cubit.toggleIdAttached();
    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.ocrConfirm);
    cubit.nextStep();
    cubit.toggleSelfieAttached();
    cubit.nextStep();
    cubit.toggleLicenseAttached();
    cubit.nextStep();
    cubit.nextStep();
    cubit.toggleBankAttached();
    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.review);

    await cubit.submit();
    expect(cubit.state.status, PartnerApplicationStatus.pending);

    cubit.simulateReject();
    expect(cubit.state.status, PartnerApplicationStatus.rejected);

    await cubit.resubmit();
    expect(cubit.state.status, PartnerApplicationStatus.pending);
  });

  test('seedFromProfile maps ACTIVE grant without forcing draft', () {
    final cubit = DriverKycCubit()..seedFromProfile(demoMultiRoleProfile);
    expect(cubit.state.status, PartnerApplicationStatus.active);
    expect(cubit.state.seeded, isTrue);
  });

  test('seedFromProfile maps PENDING grant to pending status', () {
    final cubit = DriverKycCubit()..seedFromProfile(pendingPartnerProfile);
    expect(cubit.state.status, PartnerApplicationStatus.pending);
  });

  testWidgets('driver account exposes KYC entry for ACTIVE mock seed', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: demoMultiRoleProfile);

    // Multi-role session opens Customer shell directly; switch role via Account page
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đổi vai trò'));
    await tester.tap(find.text('Đổi vai trò'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Chế độ Tài xế'));
    await tester.tap(find.text('Chế độ Tài xế'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tiếp tục với Tài xế'));
    await tester.tap(find.text('Tiếp tục với Tài xế'));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);
    expect(find.text('Đã kích hoạt'), findsOneWidget);

    await tester.ensureVisible(find.text('Hồ sơ đối tác tài xế'));
    await tester.tap(find.text('Hồ sơ đối tác tài xế'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả xét duyệt KYC'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('pending partner opens KYC status from customer account', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: pendingPartnerProfile);
    expect(find.byType(CustomerTabBar), findsOneWidget);

    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);

    await tester.ensureVisible(find.text('Hồ sơ đối tác tài xế'));
    await tester.tap(find.text('Hồ sơ đối tác tài xế'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING_REVIEW'), findsOneWidget);
    expect(find.text('Đang thẩm định'), findsOneWidget);
  });

  testWidgets('customer account shows partner signup when grants missing', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: customerProfile);
    expect(find.byType(CustomerTabBar), findsOneWidget);

    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);
    expect(find.text('Hồ sơ đối tác Shop'), findsOneWidget);
  });
}
