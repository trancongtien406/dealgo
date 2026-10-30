import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/features/onboarding/domain/ocr/ocr_prefill.dart';

void main() {
  test('fills empty fields only and never overwrites typing', () {
    final r = const OcrPrefill().merge(
      {'fullName': 'AN', 'idNumber': '079203001234'},
      {'fullName': 'Typed', 'idNumber': ''},
    );
    expect(r.apply, {'idNumber': '079203001234'});
    expect(r.prefill.prefilled, {'idNumber'});
  });

  test('re-scan updates an untouched OCR value; edits are tracked', () {
    var p = const OcrPrefill().merge({'idNumber': '1'}, {}).prefill;
    final again = p.merge({'idNumber': '2'}, {'idNumber': '1'});
    expect(again.apply, {'idNumber': '2'});
    p = again.prefill.onEdit('idNumber', '3');
    expect(p.edited, {'idNumber'});
    expect(p.merge({'idNumber': '4'}, {'idNumber': '3'}).apply, isEmpty);
    expect(p.onEdit('idNumber', '2').edited, isEmpty);
    expect(p.onEdit('other', 'x').edited, {'idNumber'});
  });

  test('metadata', () {
    expect(const OcrPrefill().toMetadata(), isEmpty);
    final p = const OcrPrefill().merge({
      'gender': 'MALE',
      'idNumber': '1',
    }, {}).prefill;
    expect(p.toMetadata(extraKeys: ['gender', 'hometown']), {
      'gender': 'MALE',
      'ocrPrefilled': 'gender,idNumber',
      'ocrEdited': '',
    });
  });
}
