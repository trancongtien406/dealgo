import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/merchant_widgets.dart';

/// M023 — hours / closed schedule (mock local state).
class MerchantHoursPage extends StatefulWidget {
  const MerchantHoursPage({super.key});

  @override
  State<MerchantHoursPage> createState() => _MerchantHoursPageState();
}

class _MerchantHoursPageState extends State<MerchantHoursPage> {
  final _days = <_DayHours>[
    const _DayHours(id: 'mon', open: true, range: '08:00 – 22:00'),
    const _DayHours(id: 'tue', open: true, range: '08:00 – 22:00'),
    const _DayHours(id: 'wed', open: true, range: '08:00 – 22:00'),
    const _DayHours(id: 'thu', open: true, range: '08:00 – 22:00'),
    const _DayHours(id: 'fri', open: true, range: '08:00 – 23:00'),
    const _DayHours(id: 'sat', open: true, range: '09:00 – 23:00'),
    const _DayHours(id: 'sun', open: false, range: '—'),
  ];

  String _dayLabel(AppLocalizations l10n, String id) {
    return switch (id) {
      'mon' => l10n.dayMon,
      'tue' => l10n.dayTue,
      'wed' => l10n.dayWed,
      'thu' => l10n.dayThu,
      'fri' => l10n.dayFri,
      'sat' => l10n.daySat,
      'sun' => l10n.daySun,
      _ => id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return MerchantPageFrame(
      title: l10n.merchantHoursTitle,
      onBack: () => merchantBack(context),
      body: Material(
        color: DealGoColors.canvas,
        child: ListView(
          padding: merchantPagePadding,
          children: [
            DealGoBanner(
              tone: DealGoBannerTone.info,
              message: l10n.merchantSettingsMockHint,
            ),
            const SizedBox(height: DealGoSpacing.s16),
            for (var i = 0; i < _days.length; i++) ...[
              MerchantPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dayLabel(l10n, _days[i].id),
                            style: textTheme.titleSmall,
                          ),
                          Text(
                            _days[i].open
                                ? _days[i].range
                                : l10n.merchantHoursClosed,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    DealGoChip(
                      label: _days[i].open
                          ? l10n.merchantHoursOpen
                          : l10n.merchantHoursClosed,
                      tone: _days[i].open
                          ? DealGoChipTone.success
                          : DealGoChipTone.neutral,
                    ),
                    Switch(
                      key: Key('merchant-hours-${_days[i].id}'),
                      value: _days[i].open,
                      onChanged: (value) {
                        setState(() {
                          _days[i] = _DayHours(
                            id: _days[i].id,
                            open: value,
                            range: value ? _days[i].range : '—',
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayHours {
  const _DayHours({
    required this.id,
    required this.open,
    required this.range,
  });

  final String id;
  final bool open;
  final String range;
}
