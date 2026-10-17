import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/driver_widgets.dart';

/// D034 — completed job detail (fixture amounts for layout only).
class DriverJobCompletedPage extends StatelessWidget {
  const DriverJobCompletedPage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DriverPageFrame(
      title: l10n.driverJobCompletedTitle,
      onBack: () => driverBack(context),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        child: DealGoPrimaryButton(
          key: const Key('driver-completed-back-jobs'),
          label: l10n.driverBackToJobs,
          trailingIcon: Icons.arrow_forward,
          onPressed: () => context.go('/driver/jobs'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.driverJobIdLabel} $jobId',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    DealGoChip(
                      label: l10n.statusCompleted,
                      tone: DealGoChipTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(l10n.driverCompletedRouteSample, style: textTheme.bodyMedium),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.driverCompletedTimeSample,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.driverCompletedEarningsTitle, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                DriverMoneyRow(
                  label: l10n.driverCompletedFareLabel,
                  value: '45.000đ',
                  emphasize: true,
                ),
                DriverMoneyRow(
                  label: l10n.driverCompletedBonusLabel,
                  value: '—',
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.driverCompletedEarningsHint,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(
            tone: DealGoBannerTone.info,
            message: l10n.driverCompletedFixtureHint,
          ),
        ],
      ),
    );
  }
}
