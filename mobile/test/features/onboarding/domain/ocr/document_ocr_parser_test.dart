import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/features/onboarding/domain/ocr/document_ocr_parser.dart';

const cccdFront = '''
CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM
Độc lập - Tự do - Hạnh phúc
CĂN CƯỚC CÔNG DÂN
Citizen Identity Card
Số / No.: 079 203 001234
Họ và tên / Full name:
NGUYỄN VĂN AN
Ngày sinh / Date of birth: 15/04/1995
Giới tính / Sex: Nam Quốc tịch / Nationality: Việt Nam
Quê quán / Place of origin:
Xã Tân Phú, Huyện Đức Hòa, Long An
Nơi thường trú / Place of residence: 12 Lê Lợi, Phường Bến Nghé, Quận 1, TP Hồ Chí Minh
''';

const cccdBack = '''
Đặc điểm nhân dạng / Personal identification: Nốt ruồi
Ngày, tháng, năm / Date, month, year: 20/06/2021
CỤC TRƯỞNG CỤC CẢNH SÁT
IDVNM2030012349079203001234<<8
9504154M3504152VNM<<<<<<<<<<<6
NGUYEN<<VAN<AN<<<<<<<<<<<<<<<<
''';

const gplx = '''
GIẤY PHÉP LÁI XE / DRIVER'S LICENSE
Số/No: 790123456789
Họ tên/Full name: TRẦN THỊ BÌNH
Ngày sinh/Date of Birth: 01/02/1990
Hạng / Class: A1
Có giá trị đến/Expires: Không thời hạn
''';

void main() {
  test('CCCD front', () {
    final r = parseCccdFront(cccdFront);
    expect(r[OcrKeys.idNumber], '079203001234');
    expect(r[OcrKeys.fullName], 'NGUYỄN VĂN AN');
    expect(r[OcrKeys.birthDate], '15/04/1995');
    expect(r[OcrKeys.gender], 'MALE');
    expect(r[OcrKeys.hometown], 'Xã Tân Phú, Huyện Đức Hòa, Long An');
    expect(r[OcrKeys.address], startsWith('12 Lê Lợi'));
  });

  test('CCCD front female, noisy text yields only what is certain', () {
    final r = parseCccdFront('Giới tính / Sex: Nữ\nrandom 12345');
    expect(r[OcrKeys.gender], 'FEMALE');
    expect(r.containsKey(OcrKeys.idNumber), isFalse);
  });

  test('CCCD back: issue date + MRZ', () {
    final r = parseCccdBack(cccdBack);
    expect(r[OcrKeys.idIssueDate], '20/06/2021');
    expect(r[OcrKeys.idNumber], '079203001234');
    expect(r[OcrKeys.birthDate], '15/04/1995');
    expect(r[OcrKeys.gender], 'MALE');
    expect(r['mrzName'], 'NGUYEN VAN AN');
    // A misread check digit drops the MRZ birth date instead of guessing.
    final bad = parseMrzTd1(cccdBack.replaceAll('9504154M', '9504153M'));
    expect(bad.containsKey(OcrKeys.birthDate), isFalse);
  });

  test('GPLX', () {
    final r = parseDriverLicense(gplx);
    expect(r[OcrKeys.licenseNumber], '790123456789');
    expect(r[OcrKeys.licenseClass], 'A1');
    expect(r[OcrKeys.licenseExpiry], 'UNLIMITED');
    expect(r[OcrKeys.fullName], 'TRẦN THỊ BÌNH');
    final b2 = parseDriverLicense(
      'Hạng / Class: B2\nCó giá trị đến/Expires: 03/08/2032',
    );
    expect(b2[OcrKeys.licenseClass], 'B'); // legacy B2 → B
    expect(b2[OcrKeys.licenseExpiry], '03/08/2032');
  });

  test('vehicle registration plate', () {
    expect(
      parseVehicleRegistration(
        'Biển số đăng ký: 59X1-123.45',
      )[OcrKeys.vehiclePlate],
      '59X1-123.45',
    );
    expect(
      parseVehicleRegistration(
        'BIỂN SỐ ĐĂNG KÝ\n51G 12345',
      )[OcrKeys.vehiclePlate],
      '51G-123.45',
    );
    expect(parseVehicleRegistration('no plate here'), isEmpty);
  });

  test('business licence', () {
    final r = parseBusinessLicense('''
GIẤY CHỨNG NHẬN ĐĂNG KÝ HỘ KINH DOANH
Số: 41M8012345
Tên hộ kinh doanh: QUÁN CƠM TẤM BA GHIỀN
''');
    expect(r[OcrKeys.businessLicenseNumber], '41M8012345');
    expect(r[OcrKeys.businessName], 'QUÁN CƠM TẤM BA GHIỀN');
    final dn = parseBusinessLicense(
      'Mã số doanh nghiệp: 0312345678\nTên doanh nghiệp viết bằng tiếng Việt: CÔNG TY TNHH ABC',
    );
    expect(dn[OcrKeys.businessLicenseNumber], '0312345678');
    expect(dn[OcrKeys.businessName], 'CÔNG TY TNHH ABC');
  });

  test('dispatch by kind and helpers', () {
    expect(parseDocumentText('SELFIE', 'x'), isEmpty);
    expect(parseDocumentText('LICENSE', gplx)[OcrKeys.licenseClass], 'A1');
    expect(normalizeDate('31/02/20'), isNull);
    expect(foldVietnamese('Họ và tên'), 'ho va ten');
  });
}
