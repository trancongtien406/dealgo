import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/params/food_delivery_action.dart';
import '../../domain/usecases/advance_food_delivery.dart';
import '../widgets/driver_widgets.dart';

/// Server reason code per on-screen outcome (backend FOOD_FAIL_REASONS).
const driverFoodFailReasonCodes = {
  'customer_absent': 'CUSTOMER_UNREACHABLE',
  'wrong_address': 'WRONG_ADDRESS',
  'refused': 'CUSTOMER_REFUSED',
  'other': 'OTHER',
};

/// D031 — delivery/job failed outcome. For a food order the reason is sent to
/// the server (POST /food/orders/:id/fail), like GrabFood/ShopeeFood "không giao được":
/// "customer unreachable" only after the minimum wait, OTHER needs a note.
class DriverJobFailedPage extends StatefulWidget {
  const DriverJobFailedPage({
    required this.jobId,
    this.food = false,
    super.key,
  });

  final String jobId;

  /// True when [jobId] is a food order the driver has picked up.
  final bool food;

  @override
  State<DriverJobFailedPage> createState() => _DriverJobFailedPageState();
}

class _DriverJobFailedPageState extends State<DriverJobFailedPage> {
  var _outcome = 'customer_absent';
  var _submitted = false;
  var _busy = false;
  String? _error;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.food) {
      setState(() => _submitted = true);
      return;
    }
    final note = _note.text.trim();
    if (_outcome == 'other' && note.isEmpty) {
      setState(() => _error = l10n.driverFailNoteRequired);
      return;
    }
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => _error = l10n.errorSessionExpired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AdvanceFoodDelivery>()(
        accessToken: token,
        orderId: widget.jobId,
        action: FoodDeliveryAction.fail,
        failReason: driverFoodFailReasonCodes[_outcome],
        failNote: note.isEmpty ? null : note,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _submitted = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = apiErrorText(l10n, error);
      });
    }
  }

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
          label: _submitted ? l10n.actionBack : l10n.driverJobFailedSubmit,
          isLoading: _busy,
          enabled: !_busy,
          onPressed: () {
            if (_submitted) {
              context.go('/driver/jobs');
              return;
            }
            _submit();
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
                Text(l10n.driverJobFailedBody, style: textTheme.bodySmall),
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
              DealGoSegmentItem(id: 'refused', label: l10n.driverFailRefused),
              DealGoSegmentItem(id: 'other', label: l10n.driverFailOther),
            ],
            value: _outcome,
            onChanged: _submitted || _busy
                ? (_) {}
                : (value) => setState(() {
                    _outcome = value;
                    _error = null;
                  }),
          ),
          if (widget.food && _outcome == 'other') ...[
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              key: const Key('driver-job-failed-note'),
              label: l10n.driverFailNoteLabel,
              controller: _note,
              enabled: !_submitted && !_busy,
              maxLines: 3,
              maxLength: 300,
            ),
          ],
          if (widget.food && _outcome == 'customer_absent') ...[
            const SizedBox(height: DealGoSpacing.s12),
            DealGoBanner(
              tone: DealGoBannerTone.info,
              message: l10n.driverFailAbsentHint,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DealGoBanner(tone: DealGoBannerTone.warning, message: _error!),
          ],
          const SizedBox(height: DealGoSpacing.s16),
          DealGoBanner(
            tone: DealGoBannerTone.warning,
            message: l10n.driverJobFailedPolicyHint,
          ),
          if (_submitted) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DealGoBanner(
              tone: DealGoBannerTone.info,
              message: widget.food
                  ? l10n.driverFoodFailedDone
                  : l10n.driverJobFailedSoftFail,
            ),
          ],
        ],
      ),
    );
  }
}
