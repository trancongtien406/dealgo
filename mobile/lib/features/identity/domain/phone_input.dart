final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

String? e164FromNationalInput(String raw) {
  final compact = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (compact.isEmpty) {
    return null;
  }
  if (compact.startsWith('+')) {
    return _e164.hasMatch(compact) ? compact : null;
  }

  final digits = compact.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('84') && digits.length >= 11) {
    final international = '+$digits';
    return _e164.hasMatch(international) ? international : null;
  }

  final national = digits.startsWith('0') ? digits.substring(1) : digits;
  if (national.length < 8 || national.length > 12) {
    return null;
  }
  final e164 = '+84$national';
  return _e164.hasMatch(e164) ? e164 : null;
}

String formatDisplayPhone(String e164) {
  if (!e164.startsWith('+84') || e164.length <= 3) {
    return e164;
  }
  final national = e164.substring(3);
  final groups = <String>[];
  for (var index = 0; index < national.length; index += 3) {
    final end = index + 3 > national.length ? national.length : index + 3;
    groups.add(national.substring(index, end));
  }
  return '+84 ${groups.join(' ')}';
}

/// `+84901234567` → `0901 234 567`.
String displayVnPhone(String? e164) {
  if (e164 == null || e164.isEmpty) return '';
  var digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('84')) digits = '0${digits.substring(2)}';
  if (digits.length != 10) return digits;
  return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
}

/// Two digits after `+84` (the national prefix without the leading 0) that
/// Bộ TT&TT has assigned to a mobile network. Landlines and unused blocks
/// such as 030, 071, 080 and 095 are rejected.
const vnMobilePrefixes = {
  '32',
  '33',
  '34',
  '35',
  '36',
  '37',
  '38',
  '39',
  '52',
  '55',
  '56',
  '58',
  '59',
  '70',
  '76',
  '77',
  '78',
  '79',
  '81',
  '82',
  '83',
  '84',
  '85',
  '86',
  '87',
  '88',
  '89',
  '90',
  '91',
  '92',
  '93',
  '94',
  '96',
  '97',
  '98',
  '99',
};

/// Vietnamese mobile as E.164, or null.
///
/// Accepts `0901 234 567`, `901234567`, `84901234567` and `+84 901 234 567`.
/// Mirrors the backend's `normalizeVnMobile`.
String? vnMobileFromInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final String national;
  if (digits.startsWith('84') && digits.length == 11) {
    national = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 10) {
    national = digits.substring(1);
  } else if (digits.length == 9) {
    national = digits;
  } else {
    return null;
  }
  if (!vnMobilePrefixes.contains(national.substring(0, 2))) {
    return null;
  }
  return '+84$national';
}
