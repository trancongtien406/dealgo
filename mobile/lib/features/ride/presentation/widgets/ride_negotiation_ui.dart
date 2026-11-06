import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/negotiation/ride_negotiation_client.dart';
import '../../domain/ride_fare_presets.dart';

/// Negotiation actions are optional on a screen: when no [RideNegotiationClient] is
/// provided (older widget tests, previews) the buttons are simply hidden.
RideNegotiationClient? maybeRideNegotiation(BuildContext context) {
  try {
    return context.read<RideNegotiationClient>();
  } catch (_) {
    return null;
  }
}

/// User-facing text for a failed negotiation command.
String negotiationErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  return error is ApiException
      ? apiErrorText(l10n, error)
      : l10n.errorLoadFailed;
}

void showNegotiationSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}

/// Bottom sheet listing reasons; returns the chosen value or null.
Future<T?> showReasonSheet<T>({
  required BuildContext context,
  required String title,
  required List<(T, String, String)> reasons,
  String? hint,
}) {
  return showDealGoSheet<T>(
    context: context,
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s20,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            Text(title, style: textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: DealGoSpacing.s8),
              Text(hint, style: textTheme.bodySmall),
            ],
            const SizedBox(height: DealGoSpacing.s8),
            for (final (value, key, label) in reasons)
              ListTile(
                key: Key('reason-$key'),
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      );
    },
  );
}

List<(DriverCancelReason, String, String)> driverCancelReasons(
  AppLocalizations l10n,
) => [
  for (final reason in DriverCancelReason.values)
    (
      reason,
      reason.wire,
      switch (reason) {
        DriverCancelReason.customerUnreachable =>
          l10n.driverCancelReasonCustomerUnreachable,
        DriverCancelReason.pickupTooFar => l10n.driverCancelReasonPickupTooFar,
        DriverCancelReason.vehicleProblem =>
          l10n.driverCancelReasonVehicleProblem,
        DriverCancelReason.safetyConcern =>
          l10n.driverCancelReasonSafetyConcern,
        DriverCancelReason.customerAsked =>
          l10n.driverCancelReasonCustomerAsked,
        DriverCancelReason.other => l10n.driverCancelReasonOther,
      },
    ),
];

List<(FoodReleaseReason, String, String)> foodReleaseReasons(
  AppLocalizations l10n,
) => [
  for (final reason in FoodReleaseReason.values)
    (
      reason,
      reason.wire,
      switch (reason) {
        FoodReleaseReason.storeTooSlow => l10n.driverFoodReleaseStoreTooSlow,
        FoodReleaseReason.storeClosed => l10n.driverFoodReleaseStoreClosed,
        FoodReleaseReason.vehicleProblem =>
          l10n.driverFoodReleaseVehicleProblem,
        FoodReleaseReason.safetyConcern => l10n.driverFoodReleaseSafetyConcern,
        FoodReleaseReason.other => l10n.driverFoodReleaseOther,
      },
    ),
];

String customerRatingTagLabel(AppLocalizations l10n, String tag) {
  return switch (tag) {
    'ON_TIME' => l10n.driverRateTagOnTime,
    'POLITE' => l10n.driverRateTagPolite,
    'CLEAR_PICKUP' => l10n.driverRateTagClearPickup,
    'LATE' => l10n.driverRateTagLate,
    'RUDE' => l10n.driverRateTagRude,
    'WRONG_PICKUP' => l10n.driverRateTagWrongPickup,
    _ => tag,
  };
}

/// "4.6★ (12 ratings)" or "New customer" for the driver's open-ride card.
String customerRatingText(
  AppLocalizations l10n,
  CustomerRatingSummary? rating,
) {
  final average = rating?.average;
  if (rating == null || average == null || rating.count == 0) {
    return l10n.driverCustomerRatingNone;
  }
  return l10n.driverCustomerRatingValue(
    average.toStringAsFixed(1),
    rating.count,
  );
}

/// Raises of the current fare. [maxFareVnd] is the server cap; chips are sliced from
/// [referenceFareVnd], matching the opening suggestions.
List<({int percent, int amountVnd})> rideRaiseFareOptions(
  int currentFareVnd, {
  int? maxFareVnd,
  int? referenceFareVnd,
}) {
  // Same ladder as the opening suggestions: sliced from the reference fare,
  // then only the steps above what is already offered.
  final base = (referenceFareVnd ?? 0) > 0 ? referenceFareVnd! : currentFareVnd;
  return [
    for (final preset in rideFareRaisePresets(
      suggestedVnd: base,
      maxBidVnd: maxFareVnd ?? base * 3,
    ))
      if (preset.amountVnd > currentFareVnd)
        (percent: preset.percent, amountVnd: preset.amountVnd),
  ];
}

/// Asks for a fare step; returns the new total fare or null.
Future<int?> showRaiseFareSheet({
  required BuildContext context,
  required int currentFareVnd,
  required String Function(int amountVnd) formatVnd,
  int? maxFareVnd,
  int? referenceFareVnd,
}) {
  final l10n = AppLocalizations.of(context);
  return showReasonSheet<int>(
    context: context,
    title: l10n.rideRaiseFareTitle,
    hint: l10n.rideRaiseFareBody(formatVnd(currentFareVnd)),
    reasons: [
      for (final o in rideRaiseFareOptions(
        currentFareVnd,
        maxFareVnd: maxFareVnd,
        referenceFareVnd: referenceFareVnd,
      ))
        (o.amountVnd, 'raise-${o.percent}', formatVnd(o.amountVnd)),
    ],
  );
}

/// The driver rates the customer after a completed ride.
class RateCustomerPanel extends StatefulWidget {
  const RateCustomerPanel({
    required this.client,
    required this.rideId,
    required this.accessToken,
    super.key,
  });

  final RideNegotiationClient client;
  final String rideId;
  final String Function() accessToken;

  @override
  State<RateCustomerPanel> createState() => _RateCustomerPanelState();
}

class _RateCustomerPanelState extends State<RateCustomerPanel> {
  var _stars = 0;
  final _tags = <String>{};
  var _busy = false;
  CustomerRatingEntry? _existing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await widget.client.customerRating(
        accessToken: widget.accessToken(),
        rideId: widget.rideId,
      );
      if (mounted && existing != null) {
        setState(() => _existing = existing);
      }
    } catch (_) {
      // Rating is optional; the form stays available.
    }
  }

  Future<void> _submit() async {
    if (_busy || _stars == 0) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.rateCustomer(
        accessToken: widget.accessToken(),
        rideId: widget.rideId,
        stars: _stars,
        tags: _tags.toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _existing = CustomerRatingEntry(stars: _stars, tags: _tags.toList());
      });
      showNegotiationSnack(
        context,
        AppLocalizations.of(context).driverRateCustomerDone,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = negotiationErrorText(context, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final existing = _existing;
    return Column(
      key: const Key('driver-rate-customer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.driverRateCustomerTitle, style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s8),
        if (existing != null)
          Text(
            l10n.driverRateCustomerYours(existing.stars),
            key: const Key('driver-rate-customer-done'),
          )
        else ...[
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  key: Key('driver-rate-star-$star'),
                  onPressed: () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars ? Icons.star : Icons.star_border,
                    color: DealGoColors.primary,
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: DealGoSpacing.s8,
            children: [
              for (final tag in customerRatingTags)
                FilterChip(
                  key: Key('driver-rate-tag-$tag'),
                  label: Text(customerRatingTagLabel(l10n, tag)),
                  selected: _tags.contains(tag),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _tags.add(tag);
                    } else {
                      _tags.remove(tag);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
          DealGoPrimaryButton(
            key: const Key('driver-rate-submit'),
            label: l10n.driverRateCustomerSubmit,
            isLoading: _busy,
            enabled: !_busy && _stars > 0,
            onPressed: _submit,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(_error!, style: TextStyle(color: DealGoColors.danger)),
        ],
      ],
    );
  }
}
