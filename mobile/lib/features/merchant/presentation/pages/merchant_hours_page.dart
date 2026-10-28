import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_date_time_picker.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/update_store_hours.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';

/// Cut-off presets the backend accepts (DEC-PROD-027).
const merchantLastOrderPresets = <int>[0, 15, 30, 45, 60];

/// Suggested hours before the merchant saves any (store is open 24/7 until then).
const _defaultOpens = '07:00';
const _defaultCloses = '22:00';

class _DayDraft {
  _DayDraft({
    required this.weekday,
    required this.open,
    required this.opensAt,
    required this.closesAt,
  });

  final int weekday;
  bool open;
  String opensAt;
  String closesAt;
}

/// M023 — weekly hours, special closed days and the last-order cut-off, saved to the
/// backend and enforced when a customer places an order.
class MerchantHoursPage extends StatefulWidget {
  const MerchantHoursPage({super.key});

  @override
  State<MerchantHoursPage> createState() => _MerchantHoursPageState();
}

class _MerchantHoursPageState extends State<MerchantHoursPage> {
  FoodStoreDetail? _store;
  Object? _loadError;
  List<_DayDraft> _days = const [];
  List<StoreClosureDay> _closures = const [];
  var _lastOrder = 15;
  var _saving = false;
  var _saved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _store = null;
    });
    try {
      final token = merchantAccessToken(context) ?? '';
      final store = await context.read<GetMerchantCatalog>()(token);
      if (!mounted) {
        return;
      }
      _adopt(store);
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

  void _adopt(FoodStoreDetail store) {
    final schedule = store.schedule;
    setState(() {
      _store = store;
      _days = [
        for (var weekday = 1; weekday <= 7; weekday++)
          if (schedule.hoursConfigured)
            _DayDraft(
              weekday: weekday,
              open: schedule.day(weekday) != null,
              opensAt: schedule.day(weekday)?.opensAt ?? _defaultOpens,
              closesAt: schedule.day(weekday)?.closesAt ?? _defaultCloses,
            )
          else
            _DayDraft(
              weekday: weekday,
              open: true,
              opensAt: _defaultOpens,
              closesAt: _defaultCloses,
            ),
      ];
      _closures = [...schedule.closures];
      _lastOrder = schedule.hoursConfigured ? schedule.lastOrderMinutes : 15;
    });
  }

  StoreSchedule _draft() => StoreSchedule(
    hoursConfigured: true,
    lastOrderMinutes: _lastOrder,
    weekly: [
      for (final day in _days)
        if (day.open)
          StoreDayHours(
            weekday: day.weekday,
            opensAt: day.opensAt,
            closesAt: day.closesAt,
          ),
    ],
    closures: _closures,
  );

  String? _invalidDay(AppLocalizations l10n) {
    for (final day in _days) {
      // Closing earlier than opening is an overnight shift (DEC-PROD-029).
      if (day.open && _minutes(day.closesAt) == _minutes(day.opensAt)) {
        return l10n.merchantHoursInvalidRange(_dayLabel(l10n, day.weekday));
      }
    }
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final invalid = _invalidDay(l10n);
    if (invalid != null) {
      setState(() {
        _saveError = invalid;
        _saved = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _saved = false;
    });
    try {
      final token = merchantAccessToken(context) ?? '';
      final store = await context.read<UpdateStoreHours>()(
        accessToken: token,
        schedule: _draft(),
      );
      if (!mounted) {
        return;
      }
      _adopt(store);
      setState(() => _saved = true);
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = apiErrorText(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickTime(_DayDraft day, {required bool opens}) async {
    final current = opens ? day.opensAt : day.closesAt;
    final minutes = _minutes(current).clamp(0, 1439);
    final picked = await showDealGoTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) {
      return;
    }
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (opens) {
        day.opensAt = value;
      } else {
        // 00:00 as a closing time means midnight at the end of the day.
        day.closesAt = value == '00:00' ? '24:00' : value;
      }
      _saved = false;
    });
  }

  Future<void> _addClosure() async {
    final now = DateTime.now();
    final picked = await showDealGoDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null || !mounted) {
      return;
    }
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (_closures.any((closure) => closure.date == date)) {
      return;
    }
    setState(() {
      _closures = [..._closures, StoreClosureDay(date: date)]
        ..sort((a, b) => a.date.compareTo(b.date));
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = _store;
    final Widget body;
    if (_loadError != null) {
      body = DealGoStateView.failure(
        context,
        onRetry: _load,
        cause: _loadError,
        message: apiErrorText(l10n, _loadError),
      );
    } else if (store == null) {
      body = const DealGoSkeletonList(itemCount: 4);
    } else {
      body = Material(
        color: DealGoColors.canvas,
        child: _form(context, l10n, store),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantHoursTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: store == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantHoursSave,
              buttonKey: const Key('merchant-hours-save'),
              loading: _saving,
              enabled: !_saving,
              onPressed: _save,
            ),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    FoodStoreDetail store,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      children: [
        Text(
          l10n.merchantHoursEyebrow,
          style: textTheme.labelSmall?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s4),
        Text(l10n.merchantHoursHeading, style: textTheme.headlineSmall),
        if (!store.schedule.hoursConfigured) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(
            key: const Key('merchant-hours-unset'),
            tone: DealGoBannerTone.info,
            message: l10n.merchantHoursUnset,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        Text(l10n.merchantHoursWeekly, style: textTheme.titleSmall),
        const SizedBox(height: DealGoSpacing.s8),
        MerchantPanel(
          child: Column(
            children: [
              Row(
                children: [
                  for (final day in _days) ...[
                    Expanded(
                      child: _DayToggle(
                        key: Key('merchant-hours-day-${day.weekday}'),
                        label: _dayShort(l10n, day.weekday),
                        open: day.open,
                        openLabel: l10n.merchantHoursOpen,
                        closedLabel: l10n.merchantHoursClosed,
                        onTap: () => setState(() {
                          day.open = !day.open;
                          _saved = false;
                        }),
                      ),
                    ),
                    if (day.weekday < 7)
                      const SizedBox(width: DealGoSpacing.s4),
                  ],
                ],
              ),
              const SizedBox(height: DealGoSpacing.s8),
              for (final day in _days)
                _DayRow(
                  key: Key('merchant-hours-row-${day.weekday}'),
                  label: _dayLabel(l10n, day.weekday),
                  day: day,
                  closedLabel: l10n.merchantHoursClosedShort,
                  onOpens: () => _pickTime(day, opens: true),
                  onCloses: () => _pickTime(day, opens: false),
                ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.merchantHoursClosures,
                style: textTheme.titleSmall,
              ),
            ),
            TextButton(
              key: const Key('merchant-hours-add-closure'),
              onPressed: _closures.length >= 60 ? null : _addClosure,
              child: Text(l10n.merchantHoursAddClosure),
            ),
          ],
        ),
        if (_closures.isEmpty)
          Text(l10n.merchantHoursNoClosures, style: textTheme.bodySmall)
        else
          for (final closure in _closures) ...[
            MerchantPanel(
              key: Key('merchant-hours-closure-${closure.date}'),
              child: Row(
                children: [
                  const Icon(DealGoIcons.calendar, color: DealGoColors.primary),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(closure.date),
                          style: textTheme.titleSmall,
                        ),
                        if (closure.note case final note?)
                          Text(note, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _closures = [
                        for (final entry in _closures)
                          if (entry.date != closure.date) entry,
                      ];
                      _saved = false;
                    }),
                    child: Text(l10n.merchantHoursRemoveClosure),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s8),
          ],
        const SizedBox(height: DealGoSpacing.s8),
        MerchantPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.merchantHoursCutoffTitle, style: textTheme.titleSmall),
              Wrap(
                spacing: DealGoSpacing.s8,
                runSpacing: DealGoSpacing.s8,
                children: [
                  for (final minutes in merchantLastOrderPresets)
                    DealGoChip(
                      key: Key('merchant-hours-cutoff-$minutes'),
                      label: minutes == 0
                          ? l10n.merchantHoursCutoffNone
                          : l10n.merchantBusyResumeMinutes(minutes),
                      selected: _lastOrder == minutes,
                      onTap: () => setState(() {
                        _lastOrder = minutes;
                        _saved = false;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_saveError case final error?) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Text(
            error,
            key: const Key('merchant-hours-error'),
            style: textTheme.bodySmall?.copyWith(color: DealGoColors.danger),
          ),
        ],
        if (_saved) ...[
          const SizedBox(height: DealGoSpacing.s12),
          MerchantNote(
            key: const Key('merchant-hours-saved'),
            tone: MerchantNoteTone.green,
            message: l10n.merchantHoursSaved,
          ),
        ],
      ],
    );
  }
}

int _minutes(String clock) {
  final parts = clock.split(':');
  if (parts.length != 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

String _formatDate(String iso) {
  final parts = iso.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : iso;
}

String _dayLabel(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.dayMon,
  2 => l10n.dayTue,
  3 => l10n.dayWed,
  4 => l10n.dayThu,
  5 => l10n.dayFri,
  6 => l10n.daySat,
  _ => l10n.daySun,
};

String _dayShort(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.dayShortMon,
  2 => l10n.dayShortTue,
  3 => l10n.dayShortWed,
  4 => l10n.dayShortThu,
  5 => l10n.dayShortFri,
  6 => l10n.dayShortSat,
  _ => l10n.dayShortSun,
};

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.open,
    required this.openLabel,
    required this.closedLabel,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool open;
  final String openLabel;
  final String closedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      toggled: open,
      child: Material(
        color: open ? DealGoColors.card : DealGoColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: DealGoColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
            child: Column(
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  open ? openLabel : closedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: open ? DealGoColors.brandGreen : DealGoColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.day,
    required this.closedLabel,
    required this.onOpens,
    required this.onCloses,
    super.key,
  });

  final String label;
  final _DayDraft day;
  final String closedLabel;
  final VoidCallback onOpens;
  final VoidCallback onCloses;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        children: [
          Icon(
            DealGoIcons.clock,
            size: 18,
            color: day.open ? DealGoColors.primary : DealGoColors.border,
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Expanded(child: Text(label, style: textTheme.titleSmall)),
          if (day.open) ...[
            _TimeChip(label: day.opensAt, onTap: onOpens),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: DealGoSpacing.s4),
              child: Text('–'),
            ),
            _TimeChip(label: day.closesAt, onTap: onCloses),
            if (_minutes(day.closesAt) < _minutes(day.opensAt))
              Padding(
                padding: const EdgeInsets.only(left: DealGoSpacing.s4),
                child: Text(
                  AppLocalizations.of(context).merchantHoursNextDay,
                  key: Key('merchant-hours-overnight-${day.weekday}'),
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ] else
            Text(closedLabel, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.subtlePurple,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
