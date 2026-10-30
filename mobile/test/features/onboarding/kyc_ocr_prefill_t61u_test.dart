import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/domain/ocr/document_text_reader.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';

class _Reader implements DocumentTextReader {
  _Reader(this.text);
  final String text;
  @override
  Future<String?> read(Uint8List imageBytes) async => text;
}

PickedDocumentImage _img() => PickedDocumentImage(
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'image/jpeg',
);

const _front = '''
Số / No.: 079203001234
Họ và tên / Full name:
NGUYỄN VĂN AN
Ngày sinh / Date of birth: 15/04/1995
Giới tính / Sex: Nam
Quê quán / Place of origin: Long An
Nơi thường trú / Place of residence: 12 Lê Lợi, Quận 1
''';

void main() {
  test('driver: ID front photo prefills the form; edits are tracked', () async {
    final cubit = DriverKycCubit(useMock: true, textReader: _Reader(_front));
    cubit.setFullName('Typed Name');
    await cubit.readDocumentText(PartnerDocumentKind.idFront, _img());
    final s = cubit.state;
    expect(s.idNumber, '079203001234');
    expect(s.birthDate, '15/04/1995');
    expect(s.address, '12 Lê Lợi, Quận 1');
    expect(s.fullName, 'Typed Name', reason: 'never overwrite typing');
    cubit.setIdNumber('079203001235');
    final m = cubit.state.ocr.toMetadata(
      extraKeys: DriverKycCubit.ocrExtraKeys,
    );
    expect(m['gender'], 'MALE');
    expect(m['hometown'], 'Long An');
    expect(
      (m['ocrPrefilled']! as String).split(','),
      containsAll(['idNumber', 'birthDate', 'address']),
    );
    expect(m['ocrEdited'], 'idNumber');
    await cubit.close();
  });

  test('driver: unsupported licence class is not applied', () {
    final cubit = DriverKycCubit(useMock: true);
    cubit.applyOcr({'licenseClass': 'FE', 'licenseNumber': '790123456789'});
    expect(cubit.state.licenseClass, 'A1');
    expect(cubit.state.licenseNumber, '790123456789');
  });

  test('merchant: household may use the ATTP commitment', () {
    final cubit = MerchantKybCubit(useMock: true);
    expect(
      cubit.state.requiredDocumentKinds,
      contains(PartnerDocumentKind.foodSafetyCert),
    );
    cubit.setFoodSafetyCommitment(true);
    expect(
      cubit.state.requiredDocumentKinds,
      contains(PartnerDocumentKind.foodSafetyCommitment),
    );
    expect(
      cubit.state.requiredDocumentKinds,
      isNot(contains(PartnerDocumentKind.foodSafetyCert)),
    );
    cubit.selectRegistrationSubject(MerchantRegistrationSubject.company);
    expect(
      cubit.state.requiredDocumentKinds,
      contains(PartnerDocumentKind.foodSafetyCert),
    );
  });

  test('merchant: business licence + representative ID prefill', () async {
    final cubit = MerchantKybCubit(
      useMock: true,
      textReader: _Reader(
        'Số: 41M8012345\nTên hộ kinh doanh: QUÁN CƠM TẤM BA GHIỀN',
      ),
    );
    await cubit.readDocumentText(PartnerDocumentKind.businessLicense, _img());
    final rep = MerchantKybCubit(useMock: true, textReader: _Reader(_front));
    await rep.readDocumentText(PartnerDocumentKind.repIdFront, _img());
    expect(rep.state.representativeName, 'NGUYỄN VĂN AN');
    final m = cubit.state.ocr.toMetadata(
      extraKeys: MerchantKybCubit.ocrExtraKeys,
    );
    expect(m['businessLicenseNumber'], '41M8012345');
    expect(m['businessName'], 'QUÁN CƠM TẤM BA GHIỀN');
  });

  test('partnerStatus push carries reject reason and sections', () {
    final hint = parsePartnerStatusHint({
      'applicationId': 'a',
      'role': 'DRIVER',
      'status': 'REJECTED',
      'reason': 'Ảnh mờ',
      'sections': ['ID_CARD', 3],
    })!;
    expect(hint.reason, 'Ảnh mờ');
    expect(hint.sections, ['ID_CARD']);
    expect(
      parsePartnerStatusHint({
        'applicationId': 'a',
        'role': 'R',
        'status': 'APPROVED',
      })!.reason,
      isNull,
    );
  });
}
