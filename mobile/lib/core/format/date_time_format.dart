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

/// Vietnam has no DST: Asia/Ho_Chi_Minh is always UTC+7.
const _vnOffset = Duration(hours: 7);

/// Short Vietnam-time stamp for activity rows: "Hôm nay · 20:22",
/// "Hôm qua · 20:22", "26/10 · 20:22" (year added when not this year).
/// Null when [iso] is not a timestamp.
String? formatRecentTime(
  String? iso, {
  required String today,
  required String yesterday,
  DateTime? now,
}) {
  final parsed = iso == null ? null : DateTime.tryParse(iso);
  if (parsed == null) return null;
  final at = parsed.toUtc().add(_vnOffset);
  final ref = (now ?? DateTime.now()).toUtc().add(_vnOffset);
  final day = DateTime.utc(at.year, at.month, at.day);
  final refDay = DateTime.utc(ref.year, ref.month, ref.day);
  final diff = refDay.difference(day).inDays;
  final time = DateFormat('HH:mm').format(at);
  if (diff == 0) return '$today · $time';
  if (diff == 1) return '$yesterday · $time';
  final date = DateFormat(at.year == ref.year ? 'dd/MM' : 'dd/MM/yyyy')
      .format(at);
  return '$date · $time';
}
