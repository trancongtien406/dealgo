/// t61u: pure-Dart parsers for text read on the phone (ML Kit, Latin script).
///
/// Input is the raw recognized text of one Vietnamese document photo; output is a
/// flat map of metadata keys the KYC/KYB form uses. Nothing here talks to a
/// server or an AI service — the applicant always confirms/edits the values.
library;

/// Metadata keys produced by the parsers.
abstract final class OcrKeys {
  static const idNumber = 'idNumber';
  static const fullName = 'fullName';
  static const birthDate = 'birthDate';
  static const gender = 'gender';
  static const hometown = 'hometown';
  static const address = 'address';
  static const idIssueDate = 'idIssueDate';
  static const licenseNumber = 'licenseNumber';
  static const licenseClass = 'licenseClass';
  static const licenseExpiry = 'licenseExpiry';
  static const vehiclePlate = 'vehiclePlate';
  static const businessLicenseNumber = 'businessLicenseNumber';
  static const businessName = 'businessName';
}

/// Which parser to run for a document kind (backend PARTNER_DOCUMENT_KINDS).
Map<String, String> parseDocumentText(String kind, String text) {
  switch (kind) {
    case 'ID_FRONT':
    case 'REP_ID_FRONT':
      return parseCccdFront(text);
    case 'ID_BACK':
    case 'REP_ID_BACK':
      return parseCccdBack(text);
    case 'LICENSE':
      return parseDriverLicense(text);
    case 'VEHICLE_REG':
      return parseVehicleRegistration(text);
    case 'BUSINESS_LICENSE':
      return parseBusinessLicense(text);
    default:
      return const {};
  }
}

List<String> _lines(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

/// Lowercase without Vietnamese diacritics, for label matching only.
String foldVietnamese(String input) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}

final _date = RegExp(r'(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{4})');

/// Normalizes to dd/MM/yyyy (the form's format); null when not a valid date.
String? normalizeDate(String raw) {
  final m = _date.firstMatch(raw);
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  if (d < 1 || d > 31 || mo < 1 || mo > 12 || y < 1900 || y > 2100) {
    return null;
  }
  return '${d.toString().padLeft(2, '0')}/${mo.toString().padLeft(2, '0')}/$y';
}

/// Value on the same line after ':' or on the next line.
String? _valueAfter(List<String> lines, bool Function(String folded) isLabel) {
  for (var i = 0; i < lines.length; i++) {
    final folded = foldVietnamese(lines[i]);
    if (!isLabel(folded)) continue;
    final colon = lines[i].indexOf(':');
    if (colon >= 0) {
      final rest = lines[i].substring(colon + 1).trim();
      if (rest.isNotEmpty) return rest;
    }
    if (i + 1 < lines.length) return lines[i + 1].trim();
  }
  return null;
}

String _clean(String value) => value
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'^[:\-\s]+'), '')
    .trim();

/// CCCD (chip) front: 12-digit number, name, DOB, sex, hometown, residence.
Map<String, String> parseCccdFront(String text) {
  final lines = _lines(text);
  final out = <String, String>{};
  final id = RegExp(r'(?<!\d)(\d{12})(?!\d)')
      .firstMatch(text.replaceAll(' ', ''));
  if (id != null) out[OcrKeys.idNumber] = id.group(1)!;

  final name = _valueAfter(
    lines,
    (f) =>
        f.contains('ho va ten') ||
        f.contains('ho, chu dem') ||
        f.contains('full name'),
  );
  if (name != null) {
    final cleaned = _clean(
      name.replaceAll(RegExp(r'full name', caseSensitive: false), ''),
    );
    if (cleaned.isNotEmpty && !RegExp(r'\d').hasMatch(cleaned)) {
      out[OcrKeys.fullName] = cleaned.toUpperCase();
    }
  }
  final dobLine = _valueAfter(
    lines,
    (f) => f.contains('ngay sinh') || f.contains('date of birth'),
  );
  final dob = dobLine == null ? null : normalizeDate(dobLine);
  if (dob != null) out[OcrKeys.birthDate] = dob;

  for (final line in lines) {
    final f = foldVietnamese(line);
    if (f.contains('gioi tinh') || f.contains('sex')) {
      final value = f.split(':').last;
      if (RegExp(r'\bnu\b').hasMatch(value) || value.contains('female')) {
        out[OcrKeys.gender] = 'FEMALE';
      } else if (value.contains('nam') || value.contains('male')) {
        out[OcrKeys.gender] = 'MALE';
      }
      break;
    }
  }
  final home = _valueAfter(
    lines,
    (f) => f.contains('que quan') || f.contains('place of origin'),
  );
  if (home != null && _clean(home).isNotEmpty) {
    out[OcrKeys.hometown] = _clean(home);
  }
  final residence = _valueAfter(
    lines,
    (f) =>
        f.contains('noi thuong tru') ||
        f.contains('place of residence') ||
        f.contains('noi cu tru'),
  );
  if (residence != null && _clean(residence).isNotEmpty) {
    out[OcrKeys.address] = _clean(residence);
  }
  return out;
}

/// CCCD back: issue date and the ICAO TD1 MRZ (3 × 30 chars).
Map<String, String> parseCccdBack(String text) {
  final out = <String, String>{};
  final lines = _lines(text);
  final issue = _valueAfter(
    lines,
    (f) =>
        f.contains('ngay, thang, nam') ||
        f.contains('date, month, year') ||
        f.contains('ngay cap'),
  );
  final issueDate = issue == null ? null : normalizeDate(issue);
  if (issueDate != null) {
    out[OcrKeys.idIssueDate] = issueDate;
  } else {
    // The issue date is the only full date printed on the back.
    for (final line in lines) {
      if (line.contains('<')) continue;
      final d = normalizeDate(line);
      if (d != null) {
        out[OcrKeys.idIssueDate] = d;
        break;
      }
    }
  }
  out.addAll(parseMrzTd1(text));
  return out;
}

/// ICAO 9303 TD1 (Vietnamese CCCD): line 1 `IDVNM<doc9><cd><12-digit id>…`,
/// line 2 `YYMMDD<cd><sex>YYMMDD<cd>VNM…`, line 3 `SURNAME<<GIVEN<NAMES`.
Map<String, String> parseMrzTd1(String text) {
  final mrz = _lines(text)
      .map((l) => l.replaceAll(' ', '').toUpperCase())
      .where(
        (l) =>
            l.length >= 25 &&
            RegExp(r'^[A-Z0-9<]+$').hasMatch(l) &&
            l.contains('<'),
      )
      .toList();
  final out = <String, String>{};
  final l1 = mrz.where((l) => l.startsWith('ID')).firstOrNull;
  if (l1 != null) {
    // 5..13 = 9-digit document no., 14 = check digit, 15.. = 12-digit CCCD.
    final id = l1.length >= 27
        ? RegExp(r'^(\d{12})').firstMatch(l1.substring(15))
        : null;
    if (id != null) out[OcrKeys.idNumber] = id.group(1)!;
  }
  final l2 = mrz
      .where((l) => RegExp(r'^\d{7}[MF<]\d{7}').hasMatch(l))
      .firstOrNull;
  if (l2 != null) {
    final dob = _mrzDate(l2.substring(0, 6), past: true);
    if (dob != null && _mrzCheck(l2.substring(0, 6)) == int.tryParse(l2[6])) {
      out[OcrKeys.birthDate] = dob;
    }
    final sex = l2[7];
    if (sex == 'M') out[OcrKeys.gender] = 'MALE';
    if (sex == 'F') out[OcrKeys.gender] = 'FEMALE';
  }
  final l3 = mrz
      .where((l) => RegExp(r'^[A-Z]+<<[A-Z<]+$').hasMatch(l))
      .firstOrNull;
  if (l3 != null) {
    final parts = l3.split('<<');
    final surname = parts.first.replaceAll('<', ' ').trim();
    final given = parts
        .skip(1)
        .join(' ')
        .replaceAll('<', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final name = '$surname $given'.trim();
    if (name.isNotEmpty) out['mrzName'] = name;
  }
  return out;
}

String? _mrzDate(String yymmdd, {required bool past}) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  final yy = int.parse(yymmdd.substring(0, 2));
  final now = DateTime.now().year % 100;
  final century = past ? (yy > now ? 1900 : 2000) : 2000;
  return normalizeDate(
    '${yymmdd.substring(4, 6)}/${yymmdd.substring(2, 4)}/${century + yy}',
  );
}

/// ICAO 7-3-1 check digit.
int _mrzCheck(String field) {
  const weights = [7, 3, 1];
  var sum = 0;
  for (var i = 0; i < field.length; i++) {
    final c = field.codeUnitAt(i);
    final v = c >= 48 && c <= 57
        ? c - 48
        : c >= 65 && c <= 90
        ? c - 55
        : 0;
    sum += v * weights[i % 3];
  }
  return sum % 10;
}

const _licenseClasses = [
  'A1',
  'A2',
  'A3',
  'A4',
  'A',
  'B1',
  'B2',
  'B',
  'C1',
  'C',
  'D1',
  'D2',
  'D',
  'BE',
  'C1E',
  'CE',
  'D1E',
  'D2E',
  'DE',
  'FB2',
  'FC',
  'FD',
  'FE',
];

/// GPLX (PET card): 12-digit number, class, expiry ("Không thời hạn" = none).
Map<String, String> parseDriverLicense(String text) {
  final lines = _lines(text);
  final out = <String, String>{};
  final numberLine = _valueAfter(
    lines,
    (f) =>
        f.contains('so/no') ||
        f.startsWith('so:') ||
        f.startsWith('no:') ||
        f.contains('so / no'),
  );
  final number =
      RegExp(r'(\d{12})')
          .firstMatch((numberLine ?? text).replaceAll(' ', '')) ??
      RegExp(r'(\d{12})').firstMatch(text.replaceAll(' ', ''));
  if (number != null) out[OcrKeys.licenseNumber] = number.group(1)!;

  final classLine = _valueAfter(
    lines,
    (f) => f.contains('hang') && f.contains('class'),
  );
  final classText = (classLine ?? '').toUpperCase().replaceAll(' ', '');
  final cls = _licenseClasses
      .where((c) => RegExp('(^|[^A-Z0-9])$c(\$|[^A-Z0-9])').hasMatch(classText))
      .fold<String?>(
        null,
        (best, c) => best == null || c.length > best.length ? c : best,
      );
  if (cls != null) out[OcrKeys.licenseClass] = mapLicenseClass(cls);

  final expiry = _valueAfter(
    lines,
    (f) => f.contains('co gia tri den') || f.contains('expires'),
  );
  if (expiry != null) {
    final folded = foldVietnamese(expiry);
    if (folded.contains('khong thoi han') || folded.contains('unlimited')) {
      out[OcrKeys.licenseExpiry] = 'UNLIMITED';
    } else {
      final d = normalizeDate(expiry);
      if (d != null) out[OcrKeys.licenseExpiry] = d;
    }
  }
  final name = _valueAfter(
    lines,
    (f) => f.contains('ho ten') || f.contains('full name'),
  );
  if (name != null &&
      _clean(name).isNotEmpty &&
      !RegExp(r'\d').hasMatch(name)) {
    out[OcrKeys.fullName] = _clean(name).toUpperCase();
  }
  return out;
}

/// Vietnamese plate: `59X1-123.45`, `51G-123.45`, `30A-12345`, `29B1 12345`.
final _plate = RegExp(
  r'(\d{2})\s*[- ]?\s*([A-Z]{1,2}\d?)\s*[- ]?\s*(\d{3})\.?(\d{2})',
);

String? normalizePlate(String raw) {
  final m = _plate.firstMatch(raw.toUpperCase());
  if (m == null) return null;
  return '${m.group(1)}${m.group(2)}-${m.group(3)}.${m.group(4)}';
}

/// Cà vẹt (vehicle registration): the plate number ("Biển số đăng ký").
Map<String, String> parseVehicleRegistration(String text) {
  final lines = _lines(text);
  final labelled = _valueAfter(
    lines,
    (f) => f.contains('bien so') || f.contains('plate'),
  );
  final plate =
      (labelled == null ? null : normalizePlate(labelled)) ??
      normalizePlate(text);
  return plate == null ? const {} : {OcrKeys.vehiclePlate: plate};
}

/// GCN đăng ký hộ kinh doanh / doanh nghiệp: number (mã số) and registered name.
Map<String, String> parseBusinessLicense(String text) {
  final lines = _lines(text);
  final out = <String, String>{};
  final numberLine = _valueAfter(
    lines,
    (f) =>
        f.contains('ma so doanh nghiep') ||
        f.contains('ma so ho kinh doanh') ||
        f.contains('so dang ky') ||
        f.contains('ma so:') ||
        f.startsWith('so:') ||
        f.startsWith('so :'),
  );
  final number = numberLine == null
      ? null
      : RegExp(r'([0-9A-Z][0-9A-Z.\-/]{5,})')
            .firstMatch(numberLine.toUpperCase().replaceAll(' ', ''));
  if (number != null) out[OcrKeys.businessLicenseNumber] = number.group(1)!;
  final name = _valueAfter(
    lines,
    (f) =>
        f.contains('ten ho kinh doanh') ||
        f.contains('ten doanh nghiep viet bang tieng viet') ||
        f.contains('ten doanh nghiep') ||
        f.contains('ten cua hang'),
  );
  if (name != null && _clean(name).isNotEmpty) {
    out[OcrKeys.businessName] = _clean(name);
  }
  return out;
}

/// Pre-2025 classes printed on older cards → classes under Luật TTATGT 2024
/// (A2→A, B1/B2→B); others pass through unchanged.
String mapLicenseClass(String printed) => switch (printed) {
  'A2' => 'A',
  'B1' || 'B2' => 'B',
  _ => printed,
};
