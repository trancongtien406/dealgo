import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';

ThemeData _dealGoPickerTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: DealGoColors.primary,
      onPrimary: Colors.white,
      surface: DealGoColors.card,
      onSurface: DealGoColors.text,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: DealGoColors.card,
      headerBackgroundColor: DealGoColors.primary,
      headerForegroundColor: Colors.white,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) {
          return DealGoColors.textTertiary;
        }
        return DealGoColors.text;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return DealGoColors.primary;
        }
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return DealGoColors.primary;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return DealGoColors.primary;
        }
        return Colors.transparent;
      }),
      todayBorder: const BorderSide(color: DealGoColors.primary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: DealGoColors.card,
      dialHandColor: DealGoColors.primary,
      dialBackgroundColor: DealGoColors.lavender,
      hourMinuteColor: DealGoColors.subtlePurple,
      hourMinuteTextColor: DealGoColors.primary,
      dayPeriodColor: DealGoColors.subtlePurple,
      dayPeriodTextColor: DealGoColors.primary,
      entryModeIconColor: DealGoColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
    ),
  );
}

Future<DateTime?> showDealGoDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(1920);
  final last = lastDate ?? now;
  var initial = initialDate ?? (last.isBefore(now) ? last : first);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    builder: (context, child) =>
        Theme(data: _dealGoPickerTheme(context), child: child!),
  );
}

Future<TimeOfDay?> showDealGoTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  bool use24HourFormat = true,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      final themed = Theme(data: _dealGoPickerTheme(context), child: child!);
      if (!use24HourFormat) return themed;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: themed,
      );
    },
  );
}

/// Tappable field styled like [DealGoTextField] that opens a date picker.
class DealGoDateField extends StatelessWidget {
  const DealGoDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.includeTime = false,
    this.dateFormat,
    this.enabled = true,
    this.requiredMark = false,
    this.showLabel = true,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool includeTime;
  final DateFormat? dateFormat;
  final bool enabled;
  final bool requiredMark;
  final bool showLabel;

  Future<void> _pick(BuildContext context) async {
    if (!enabled) return;
    final date = await showDealGoDatePicker(
      context: context,
      initialDate: value,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !context.mounted) return;

    if (!includeTime) {
      onChanged(date);
      return;
    }

    final time = await showDealGoTimePicker(
      context: context,
      initialTime: value != null
          ? TimeOfDay.fromDateTime(value!)
          : TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final format =
        dateFormat ??
        DateFormat(includeTime ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy');
    final display = value == null ? null : format.format(value!);
    final placeholder = hint ?? label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (requiredMark)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: DealGoColors.danger),
                    ),
                ],
              ),
              style: textTheme.labelMedium,
            ),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: InputDecorator(
              isEmpty: display == null,
              decoration: InputDecoration(
                hintText: showLabel ? placeholder : label,
                prefixIcon: const Icon(DealGoIcons.calendar, size: 20),
                suffixIcon: const Icon(DealGoIcons.calendarMonth, size: 18),
                enabled: enabled,
              ),
              child: Text(
                display ?? '',
                style: textTheme.bodyLarge?.copyWith(
                  color: enabled
                      ? DealGoColors.text
                      : DealGoColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
