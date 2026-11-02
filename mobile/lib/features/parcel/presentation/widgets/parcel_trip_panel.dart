import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../onboarding/presentation/document_image_source.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../domain/parcel_client.dart';
import '../../domain/parcel_models.dart';
import '../cubit/parcel_trip_cubit.dart';
import 'parcel_labels.dart';

/// Package card on a parcel ride. Customer: what was sent + the recipient code.
/// Driver ([driver] true): the same card plus pickup / deliver / fail / returned proof.
class ParcelTripPanel extends StatelessWidget {
  const ParcelTripPanel({
    required this.rideId,
    required this.accessToken,
    this.driver = false,
    this.onPickedUp,
    this.onFinished,
    super.key,
  });

  final String rideId;
  final String? Function() accessToken;
  final bool driver;

  /// Driver: the package is on board (ride is IN_TRIP).
  final VoidCallback? onPickedUp;

  /// Driver: delivered or returned (ride is COMPLETED).
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelTripCubit(
        client: context.read<ParcelClient>(),
        accessToken: accessToken,
        rideId: rideId,
      )..load(),
      child: _ParcelTripBody(
        driver: driver,
        onPickedUp: onPickedUp,
        onFinished: onFinished,
      ),
    );
  }
}

class _ParcelTripBody extends StatelessWidget {
  const _ParcelTripBody({
    required this.driver,
    this.onPickedUp,
    this.onFinished,
  });

  final bool driver;
  final VoidCallback? onPickedUp;
  final VoidCallback? onFinished;

  Future<ParcelPhoto?> _photo(BuildContext context) async {
    final picked = await context.read<DocumentImageSource>().pick(camera: true);
    if (picked == null) return null;
    return ParcelPhoto(bytes: picked.bytes, contentType: picked.contentType);
  }

  Future<void> _pickup(BuildContext context) async {
    final cubit = context.read<ParcelTripCubit>();
    final photo = await _photo(context);
    if (photo == null) return;
    if (await cubit.pickup(photo)) onPickedUp?.call();
  }

  Future<void> _deliver(BuildContext context, String code) async {
    final cubit = context.read<ParcelTripCubit>();
    final photo = await _photo(context);
    if (photo == null) return;
    if (await cubit.deliver(photo, recipientCode: code)) onFinished?.call();
  }

  Future<void> _returned(BuildContext context) async {
    final cubit = context.read<ParcelTripCubit>();
    final photo = await _photo(context);
    if (photo == null) return;
    if (await cubit.returned(photo)) onFinished?.call();
  }

  Future<void> _fail(BuildContext context) async {
    final cubit = context.read<ParcelTripCubit>();
    final reason = await showModalBottomSheet<ParcelFailReason>(
      context: context,
      builder: (sheet) {
        final l10n = AppLocalizations.of(sheet);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s12),
                child: Text(
                  l10n.parcelFailTitle,
                  style: Theme.of(sheet).textTheme.titleMedium,
                ),
              ),
              for (final r in ParcelFailReason.values)
                ListTile(
                  key: Key('parcel-fail-${r.wire}'),
                  title: Text(parcelFailReasonLabel(l10n, r)),
                  onTap: () => Navigator.of(sheet).pop(r),
                ),
            ],
          ),
        );
      },
    );
    if (reason != null) await cubit.fail(reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final state = context.watch<ParcelTripCubit>().state;
    final data = state.parcel;
    if (data == null) {
      if (state.errorCode != null) {
        return TextButton(
          key: const Key('parcel-panel-retry'),
          onPressed: () => context.read<ParcelTripCubit>().load(),
          child: Text(l10n.parcelRetry),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(DealGoSpacing.s12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final p = data.parcel;
    final status = data.ride.status;
    final weight = p.weightKg == null
        ? ''
        : ' · ${p.weightKg!.toStringAsFixed(1)} kg';
    return Card(
      key: const Key('parcel-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: Text(
                    '${parcelSizeLabel(l10n, p.sizeClass)}$weight',
                    style: text.titleMedium,
                  ),
                ),
                Text(
                  parcelOutcomeLabel(l10n, p),
                  key: const Key('parcel-outcome'),
                ),
              ],
            ),
            if (p.note != null) ...[
              const SizedBox(height: DealGoSpacing.s4),
              Text(p.note!, style: text.bodyMedium),
            ],
            if (p.sender != null)
              Text(l10n.parcelSenderLine(p.sender!.name, p.sender!.phone)),
            if (p.recipient != null)
              Text(
                l10n.parcelRecipientLine(p.recipient!.name, p.recipient!.phone),
              ),
            Text(
              p.payer == ParcelPayer.recipient
                  ? l10n.parcelPayerRecipient
                  : l10n.parcelPayerSender,
            ),
            if (p.serviceFeeVnd > 0)
              Text(
                l10n.parcelServiceFeeLine(formatRideVnd(p.serviceFeeVnd)),
                key: const Key('parcel-service-fee'),
              ),
            if (p.returnFeeApplies)
              Text(
                l10n.parcelReturnFeeCharged(formatRideVnd(p.returnFeeVnd)),
                key: const Key('parcel-return-fee'),
              )
            else if (p.returnFeeVnd > 0 && p.outcome == ParcelOutcome.pending)
              Text(
                l10n.parcelReturnFeeLine(formatRideVnd(p.returnFeeVnd)),
                key: const Key('parcel-return-fee-hint'),
                style: text.bodySmall,
              ),
            if (!driver &&
                p.recipientCode != null &&
                p.outcome == ParcelOutcome.pending) ...[
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                l10n.parcelRecipientCode(p.recipientCode!),
                key: const Key('parcel-recipient-code'),
                style: text.titleMedium,
              ),
              Text(l10n.parcelRecipientCodeHint, style: text.bodySmall),
            ],
            if (state.errorCode != null) ...[
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                parcelErrorLabel(l10n, state.errorCode),
                key: const Key('parcel-error'),
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (driver) ..._driverActions(context, l10n, p, status, state.busy),
          ],
        ),
      ),
    );
  }

  List<Widget> _driverActions(
    BuildContext context,
    AppLocalizations l10n,
    ParcelInfo p,
    RideStatus status,
    bool busy,
  ) {
    const gap = SizedBox(height: DealGoSpacing.s12);
    if (!p.pickedUp &&
        (status == RideStatus.driverArrived ||
            status == RideStatus.driverEnRoute ||
            status == RideStatus.assigned)) {
      return [
        gap,
        DealGoPrimaryButton(
          key: const Key('parcel-pickup'),
          label: l10n.parcelPickupCta,
          isLoading: busy,
          enabled: !busy,
          onPressed: () => _pickup(context),
        ),
      ];
    }
    if (p.pickedUp && p.outcome == ParcelOutcome.pending) {
      return [
        gap,
        _DeliverForm(
          busy: busy,
          onDeliver: (c) => _deliver(context, c),
          onFail: () => _fail(context),
        ),
      ];
    }
    if (p.outcome == ParcelOutcome.returning) {
      return [
        gap,
        Text(l10n.parcelReturningHint),
        gap,
        DealGoPrimaryButton(
          key: const Key('parcel-returned'),
          label: l10n.parcelReturnedCta,
          isLoading: busy,
          enabled: !busy,
          onPressed: () => _returned(context),
        ),
      ];
    }
    return const [];
  }
}

class _DeliverForm extends StatefulWidget {
  const _DeliverForm({
    required this.busy,
    required this.onDeliver,
    required this.onFail,
  });

  final bool busy;
  final ValueChanged<String> onDeliver;
  final VoidCallback onFail;

  @override
  State<_DeliverForm> createState() => _DeliverFormState();
}

class _DeliverFormState extends State<_DeliverForm> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('parcel-recipient-code-input'),
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: l10n.parcelRecipientCodeInput,
            counterText: '',
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        DealGoPrimaryButton(
          key: const Key('parcel-deliver'),
          label: l10n.parcelDeliverCta,
          isLoading: widget.busy,
          enabled: !widget.busy,
          onPressed: () => widget.onDeliver(_code.text.trim()),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        DealGoSecondaryButton(
          key: const Key('parcel-fail'),
          label: l10n.parcelFailCta,
          tone: DealGoSecondaryTone.danger,
          enabled: !widget.busy,
          onPressed: widget.onFail,
        ),
      ],
    );
  }
}
