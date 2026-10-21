import 'package:intl/intl.dart';

/// "19/10/2026 14:45" in the device time zone; null for a missing/bad value.
String? formatLocalDateTime(String? iso) {
  if (iso == null) {
    return null;
  }
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return null;
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}
