import 'package:dealgo/features/onboarding/domain/entities/partner_onboarding.dart';

import 'dart:typed_data';

import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/shell/presentation/customer_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

final _image = PickedDocumentImage(
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
  contentType: 'image/jpeg',
);

void main() {
  test('driver kyc cubit advances steps then submits to pending', () async {
    final cubit = DriverKycCubit();
    expect(cubit.state.status, PartnerApplicationStatus.draft);
    expect(cubit.state.step, DriverKycStep.services);

    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.personal);
    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.identity);
    expect(cubit.state.canContinueIdentity, isFalse);
    cubit
      ..attachDocument(PartnerDocumentKind.idFront, _image)
      ..attachDocument(PartnerDocumentKind.idBack, _image);
    expect(cubit.state.canContinueIdentity, isTrue);
    cubit.nextStep();
    expect(cubit.state.step, DriverKycStep.ocrConfirm);

    // Fail closed: draft must pick a catalog class before submit (DG-DEC-VEH-001).
    expect(cubit.state.hasSelectedVehicleClass, isFalse);
    cubit.setVehicleClass(code: 'MOTORBIKE', name: 'Xe máy');
    expect(cubit.state.hasSelectedVehicleClass, isTrue);

    await cubit.submit();
    expect(cubit.state.status, PartnerApplicationStatus.pending);
    expect(cubit.state.documents.stored, {
      PartnerDocumentKind.idFront,
      PartnerDocumentKind.idBack,
    });
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

    // No role picker at entry: customer home first, switch from the profile.
    expect(find.byType(CustomerTabBar), findsOneWidget);
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đổi vai trò'));
    await tester.tap(find.text('Đổi vai trò'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn muốn dùng DealGo theo vai trò nào?', findRichText: true),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Tài xế'));
    await tester.tap(find.text('Tài xế'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);
    expect(find.text('Đã kích hoạt'), findsOneWidget);

    await tester.ensureVisible(find.text('Hồ sơ đối tác tài xế'));
    await tester.tap(find.text('Hồ sơ đối tác tài xế'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả xét duyệt KYC'), findsOneWidget);
    expect(find.text('Đã kích hoạt'), findsOneWidget);
  });

  testWidgets('pending partner opens KYC status from customer account', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: pendingPartnerProfile);
    expect(find.byType(CustomerTabBar), findsOneWidget);

    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);

    await tester.ensureVisible(find.text('Hồ sơ đối tác tài xế'));
    await tester.tap(find.text('Hồ sơ đối tác tài xế'));
    await tester.pumpAndSettle();

    // Title and status chip.
    expect(find.text('Đang thẩm định'), findsNWidgets(2));
  });

  testWidgets('customer account shows partner signup when grants missing', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: customerProfile);
    expect(find.byType(CustomerTabBar), findsOneWidget);

    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ đối tác tài xế'), findsOneWidget);
    expect(find.text('Hồ sơ đối tác Shop'), findsOneWidget);
  });
}
