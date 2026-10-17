import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

/// D031 — delivery/job failed outcome UI (mock reasons; no invented fees).
class DriverJobFailedPage extends StatefulWidget {
  const DriverJobFailedPage({required this.jobId, super.key});

  final String jobId;

  @override
  State<DriverJobFailedPage> createState() => _DriverJobFailedPageState();
}

class _DriverJobFailedPageState extends State<DriverJobFailedPage> {
  var _outcome = 'customer_absent';
  var _submitted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DriverPageFrame(
      title: l10n.driverJobFailedTitle,
      onBack: () => driverBack(context),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        child: DealGoPrimaryButton(
          key: const Key('driver-job-failed-submit'),
          label: _submitted
              ? l10n.actionBack
              : l10n.driverJobFailedSubmit,
          onPressed: () {
            if (_submitted) {
              context.go('/driver/jobs');
              return;
            }
            setState(() => _submitted = true);
          },
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
                        '${l10n.driverJobIdLabel} ${widget.jobId}',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    DealGoChip(
                      label: l10n.driverJobFailedChip,
                      tone: DealGoChipTone.danger,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.driverJobFailedBody,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Text(l10n.driverJobFailedPick, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoSegmentedControl(
            items: [
              DealGoSegmentItem(
                id: 'customer_absent',
                label: l10n.driverFailAbsent,
              ),
              DealGoSegmentItem(
                id: 'wrong_address',
                label: l10n.driverFailAddress,
              ),
              DealGoSegmentItem(
                id: 'refused',
                label: l10n.driverFailRefused,
              ),
              DealGoSegmentItem(
                id: 'other',
                label: l10n.driverFailOther,
              ),
            ],
            value: _outcome,
            onChanged: _submitted
                ? (_) {}
                : (value) => setState(() => _outcome = value),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DealGoBanner(
            tone: DealGoBannerTone.warning,
            message: l10n.driverJobFailedPolicyHint,
          ),
          if (_submitted) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DealGoBanner(
              tone: DealGoBannerTone.info,
              message: l10n.driverJobFailedSoftFail,
            ),
          ],
          const SizedBox(height: DealGoSpacing.s12),
          TextButton(
            key: const Key('driver-open-completed-sample'),
            onPressed: () => context.push(
              DriverRoutes.completed(widget.jobId),
            ),
            child: Text(l10n.driverOpenCompletedSample),
          ),
        ],
      ),
    );
  }
}
