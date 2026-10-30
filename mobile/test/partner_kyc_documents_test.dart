import 'dart:typed_data';

import 'package:dealgo/core/network/api_exception.dart';

import 'package:dealgo/features/onboarding/data/datasources/fake_partner_applications_client.dart';
import 'package:dealgo/features/onboarding/data/models/partner_application_body.dart';
import 'package:dealgo/features/onboarding/data/repositories/partner_applications_repository_impl.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_application.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_onboarding.dart';
import 'package:dealgo/features/onboarding/domain/usecases/get_my_partner_application.dart';
import 'package:dealgo/features/onboarding/domain/usecases/submit_partner_application.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/onboarding/presentation/pages/driver_kyc_pages.dart';
import 'package:dealgo/features/onboarding/presentation/widgets/partner_kyc_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_l10n.dart';

final _jpeg = PickedDocumentImage(
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]),
  contentType: 'image/jpeg',
);

PartnerDocumentSummary _stored(int index, String kind) =>
    PartnerDocumentSummary(
      index: index,
      kind: kind,
      contentType: 'image/jpeg',
      sizeBytes: 1000,
      hasFile: true,
    );

DriverKycCubit _driver(FakePartnerApplicationsClient partners) {
  final repo = PartnerApplicationsRepositoryImpl(partners);
  return DriverKycCubit(
      submitPartnerApplication: SubmitPartnerApplication(repo),
      getMyPartnerApplication: GetMyPartnerApplication(repo),
      accessToken: () => 'token',
      useMock: false,
    )
    // Services are no longer preselected; tick both explicitly.
    ..toggleRide()
    ..toggleFood();
}

void main() {
  test('parses documents and review issues from the server view', () {
    final view = parsePartnerApplication({
      'id': 'a1',
      'role': 'DRIVER',
      'status': 'REJECTED',
      'metadata': {'fullName': 'Trần Công Tiến'},
      'reason': 'Ảnh mờ',
      'documents': [
        {
          'index': 0,
          'kind': 'ID_FRONT',
          'contentType': 'image/jpeg',
          'sizeBytes': 2048,
          'hasFile': true,
        },
        {
          'index': 1,
          'kind': 'SELFIE',
          'contentType': 'image/jpeg',
          'sizeBytes': 0,
          'hasFile': false,
        },
      ],
      'issues': [
        {'section': 'SELFIE', 'note': 'Chụp lại không đeo kính'},
        {'section': 3},
      ],
    })!;
    expect(view.storedKinds, {'ID_FRONT'});
    expect(view.issues.single.section, 'SELFIE');
    expect(view.reason, 'Ảnh mờ');
  });

  test('submit body sends kind codes with base64 content', () {
    final body = partnerApplicationBodyJson(
      SubmitPartnerApplicationRequest(
        accessToken: 't',
        role: 'DRIVER',
        metadata: const {},
        documents: [
          PartnerDocumentInput(
            kind: 'ID_FRONT',
            contentType: 'image/jpeg',
            contentBase64: _jpeg.contentBase64,
          ),
        ],
      ),
    );
    expect(body['documents'], [
      {
        'kind': 'ID_FRONT',
        'contentType': 'image/jpeg',
        'contentBase64': _jpeg.contentBase64,
      },
    ]);
  });

  test(
    'driver submit uploads every picked document and bank metadata',
    () async {
      final partners = FakePartnerApplicationsClient();
      final cubit = _driver(partners);
      for (final kind in PartnerDocumentKind.driverRequired) {
        cubit.attachDocument(kind, _jpeg);
      }
      cubit
        ..setFullName('Trần Công Tiến')
        ..setBirthDate('01/01/1995')
        ..setAddress('Đà Nẵng')
        ..setIdNumber('0480 9500 1234')
        ..setLicenseNumber('480123456')
        ..setVehiclePlate('43b1-123.45')
        // Fail closed: submit requires an explicit vehicle class (DG-DEC-VEH-001).
        ..setVehicleClass(code: 'MOTORBIKE', name: 'Xe máy')
        ..setBankName('Vietcombank')
        ..setBankAccountNumber('0123 456 789')
        ..setBankAccountHolder('Tran Cong Tien');
      expect(cubit.state.canSubmit, isTrue);

      await cubit.submit();

      final call = partners.submitCalls.single;
      expect(
        call.documents.map((d) => d.kind),
        PartnerDocumentKind.driverRequired,
      );
      expect(call.metadata['bankAccountNumber'], '0123456789');
      expect(call.metadata['bankAccountHolder'], 'TRAN CONG TIEN');
      expect(call.metadata['idNumber'], '048095001234');
      expect(call.metadata.containsKey('idAttached'), isFalse);
      expect(cubit.state.status, PartnerApplicationStatus.pending);
      expect(cubit.state.documents.picked, isEmpty);
      expect(
        cubit.state.documents.stored,
        PartnerDocumentKind.driverRequired.toSet(),
      );
    },
  );

  test('rejected application: refresh shows issues and resubmit re-sends only flagged files', () async {
    final partners = FakePartnerApplicationsClient(
      applications: [
        PartnerApplicationView(
          id: 'app-driver',
          role: 'DRIVER',
          status: 'REJECTED',
          metadata: const {
            'fullName': 'Trần Công Tiến',
            'birthDate': '01/01/1995',
            'address': 'Đà Nẵng',
            'idNumber': '048095001234',
            'licenseNumber': '480123456',
            'vehiclePlate': '43B1-123.45',
            // DG-DEC-VEH-001: a stored application carries its vehicle class.
            'vehicleClassCode': 'MOTORBIKE',
            'bankName': 'Vietcombank',
            'bankAccountNumber': '0123456789',
            'bankAccountHolder': 'TRAN CONG TIEN',
          },
          reason: 'Bổ sung giấy tờ',
          documents: [
            for (final (i, kind) in PartnerDocumentKind.driverRequired.indexed)
              _stored(i, kind),
          ],
          issues: const [
            PartnerReviewIssue(section: 'ID_CARD', note: 'Mặt sau bị lóa'),
          ],
        ),
      ],
    );
    final cubit = _driver(partners);
    await cubit.refresh();
    expect(cubit.state.status, PartnerApplicationStatus.rejected);
    expect(cubit.state.reason, 'Bổ sung giấy tờ');
    expect(cubit.state.issues.single.note, 'Mặt sau bị lóa');
    expect(cubit.state.fullName, 'Trần Công Tiến');
    expect(cubit.state.canSubmit, isTrue);

    cubit.beginResubmit();
    expect(cubit.state.step, DriverKycStep.identity);
    expect(cubit.state.canContinueIdentity, isFalse);
    expect(cubit.state.canContinueSelfie, isTrue);
    expect(cubit.state.documents.isFlagged(PartnerDocumentKind.idBack), isTrue);

    cubit
      ..attachDocument(PartnerDocumentKind.idFront, _jpeg)
      ..attachDocument(PartnerDocumentKind.idBack, _jpeg);
    expect(cubit.state.canSubmit, isTrue);
    await cubit.resubmit();

    expect(partners.submitCalls.single.documents.map((d) => d.kind), [
      PartnerDocumentKind.idFront,
      PartnerDocumentKind.idBack,
    ]);
    expect(cubit.state.status, PartnerApplicationStatus.pending);
    expect(cubit.state.issues, isEmpty);
    expect(
      cubit.state.documents.stored,
      PartnerDocumentKind.driverRequired.toSet(),
    );
  });

  test(
    'missing application keeps the profile status; API errors keep their code',
    () async {
      final partners = FakePartnerApplicationsClient();
      final cubit = _driver(partners);
      await cubit.refresh();
      expect(cubit.state.status, PartnerApplicationStatus.draft);

      final merchantPartners = FakePartnerApplicationsClient(
        submitError: const ApiException(
          statusCode: 413,
          message: 'too large',
          errorCode: 'UPLOAD_TOO_LARGE',
        ),
      );
      final repo = PartnerApplicationsRepositoryImpl(merchantPartners);
      final merchant = MerchantKybCubit(
        submitPartnerApplication: SubmitPartnerApplication(repo),
        accessToken: () => 'token',
        useMock: false,
      )..attachDocument(PartnerDocumentKind.businessLicense, _jpeg);
      await merchant.submit();
      expect(merchant.state.submitError, 'UPLOAD_TOO_LARGE');
      expect(
        merchantPartners.submitCalls.single.metadata['businessType'],
        MerchantBusinessType.restaurant,
      );
      expect(
        merchantPartners.submitCalls.single.documents.single.kind,
        PartnerDocumentKind.businessLicense,
      );
    },
  );

  test('merchant storefront photo is optional unless flagged', () {
    final merchant = MerchantKybCubit(useMock: true);
    for (final kind in PartnerDocumentKind.merchantRequired) {
      merchant.attachDocument(kind, _jpeg);
    }
    expect(merchant.state.canContinueDocuments, isTrue);
    expect(
      MerchantKybCubit.stepForSection('STOREFRONT'),
      MerchantKybStep.documents,
    );
  });

  testWidgets('identity step captures photos through the document source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = FakeDocumentImageSource(nextImage: _jpeg);
    final cubit = DriverKycCubit(useMock: true)
      ..goToStep(DriverKycStep.identity);
    await tester.pumpWidget(
      RepositoryProvider<DocumentImageSource>.value(
        value: source,
        child: BlocProvider.value(
          value: cubit,
          child: const MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: [testLocale],
            locale: testLocale,
            home: DriverKycStepsPage(),
          ),
        ),
      ),
    );
    expect(find.text('CCCD — mặt trước'), findsOneWidget);
    expect(find.text('Chưa có ảnh'), findsNWidgets(2));

    await tester.ensureVisible(find.byKey(const Key('doc-camera-ID_FRONT')));
    await tester.tap(find.byKey(const Key('doc-camera-ID_FRONT')));
    await tester.pumpAndSettle();
    expect(source.calls.single.camera, isTrue);
    expect(cubit.state.documents.picked.keys, [PartnerDocumentKind.idFront]);
    expect(find.text('Ảnh mới — sẽ gửi khi nộp hồ sơ'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('doc-gallery-ID_BACK')));
    await tester.tap(find.byKey(const Key('doc-gallery-ID_BACK')));
    await tester.pumpAndSettle();
    expect(source.calls.last.camera, isFalse);
    expect(cubit.state.canContinueIdentity, isTrue);
  });

  testWidgets('review issues card lists sections with notes and fix actions', (
    tester,
  ) async {
    String? fixed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: const [testLocale],
        locale: testLocale,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerReviewIssuesCard(
              reason: 'Hồ sơ cần bổ sung',
              issues: const [
                PartnerReviewIssue(section: 'LICENSE', note: 'GPLX hết hạn'),
              ],
              onFix: (section) => fixed = section,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Hồ sơ cần bổ sung'), findsOneWidget);
    expect(find.text('Giấy phép lái xe'), findsOneWidget);
    expect(find.text('GPLX hết hạn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fix-LICENSE')));
    expect(fixed, 'LICENSE');
  });

  test('t54u: the liveness clip is required and re-taken with the selfie', () {
    expect(
      PartnerDocumentKind.driverRequired,
      contains(PartnerDocumentKind.selfieVideo),
    );
    expect(flaggedDocumentKinds(['SELFIE']), {
      PartnerDocumentKind.selfie,
      PartnerDocumentKind.selfieVideo,
    });
  });
}
