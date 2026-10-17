import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/merchant_widgets.dart';

/// M024 — busy / pause mode (mock local state).
class MerchantBusyPage extends StatefulWidget {
  const MerchantBusyPage({super.key});

  @override
  State<MerchantBusyPage> createState() => _MerchantBusyPageState();
}

class _MerchantBusyPageState extends State<MerchantBusyPage> {
  var _mode = 'open';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chipTone = switch (_mode) {
      'busy' => DealGoChipTone.warning,
      'paused' => DealGoChipTone.danger,
      _ => DealGoChipTone.success,
    };
    final chipLabel = switch (_mode) {
      'busy' => l10n.merchantBusyBusy,
      'paused' => l10n.merchantBusyPaused,
      _ => l10n.merchantBusyOpen,
    };

    return MerchantPageFrame(
      title: l10n.merchantBusyTitle,
      onBack: () => merchantBack(context),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          DealGoBanner(
            tone: DealGoBannerTone.info,
            message: l10n.merchantSettingsMockHint,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.merchantBusyModeLabel,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    DealGoChip(label: chipLabel, tone: chipTone),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DealGoSegmentedControl(
                  items: [
                    DealGoSegmentItem(
                      id: 'open',
                      label: l10n.merchantBusyOpen,
                    ),
                    DealGoSegmentItem(
                      id: 'busy',
                      label: l10n.merchantBusyBusy,
                    ),
                    DealGoSegmentItem(
                      id: 'paused',
                      label: l10n.merchantBusyPaused,
                    ),
                  ],
                  value: _mode,
                  onChanged: (value) => setState(() => _mode = value),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  switch (_mode) {
                    'busy' => l10n.merchantBusyBusyHint,
                    'paused' => l10n.merchantBusyPausedHint,
                    _ => l10n.merchantBusyOpenHint,
                  },
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
