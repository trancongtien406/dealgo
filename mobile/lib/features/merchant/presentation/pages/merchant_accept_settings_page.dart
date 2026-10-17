import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/merchant_widgets.dart';

/// M022 — auto/manual accept settings (local mock toggle).
class MerchantAcceptSettingsPage extends StatefulWidget {
  const MerchantAcceptSettingsPage({super.key});

  @override
  State<MerchantAcceptSettingsPage> createState() =>
      _MerchantAcceptSettingsPageState();
}

class _MerchantAcceptSettingsPageState
    extends State<MerchantAcceptSettingsPage> {
  var _mode = 'manual';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return MerchantPageFrame(
      title: l10n.merchantAcceptTitle,
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
                        l10n.merchantAcceptModeLabel,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    DealGoChip(
                      label: _mode == 'auto'
                          ? l10n.merchantAcceptAuto
                          : l10n.merchantAcceptManual,
                      tone: _mode == 'auto'
                          ? DealGoChipTone.success
                          : DealGoChipTone.brand,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DealGoSegmentedControl(
                  items: [
                    DealGoSegmentItem(
                      id: 'manual',
                      label: l10n.merchantAcceptManual,
                    ),
                    DealGoSegmentItem(
                      id: 'auto',
                      label: l10n.merchantAcceptAuto,
                    ),
                  ],
                  value: _mode,
                  onChanged: (value) => setState(() => _mode = value),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  _mode == 'auto'
                      ? l10n.merchantAcceptAutoHint
                      : l10n.merchantAcceptManualHint,
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
