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

final _vnMobile = RegExp(r'^\+84[35789]\d{8}$');

/// Vietnamese mobile number as E.164 (`+84` + 9 digits, prefix 3/5/7/8/9),
/// or null. Mirrors the backend's `normalizeVnMobile`.
String? vnMobileFromInput(String raw) {
  final e164 = e164FromNationalInput(raw);
  return e164 != null && _vnMobile.hasMatch(e164) ? e164 : null;
}
