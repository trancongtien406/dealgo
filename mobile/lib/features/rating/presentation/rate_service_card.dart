import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/service_rating.dart';

String? _token(BuildContext context) {
  final state = context.read<AuthCubit>().state;
  return state is AuthSignedIn ? state.tokens.accessToken : null;
}

/// Shows "rate this trip/order" for finished subjects, or the submitted rating.
/// Renders nothing while loading, on errors, or when rating is not possible.
class RateServiceCard extends StatefulWidget {
  const RateServiceCard({
    required this.type,
    required this.subjectId,
    this.hasDriver = true,
    super.key,
  });

  final RatingSubjectType type;
  final String subjectId;
  final bool hasDriver;

  @override
  State<RateServiceCard> createState() => _RateServiceCardState();
}

class _RateServiceCardState extends State<RateServiceCard> {
  RatingStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = _token(context);
    if (token == null) {
      return;
    }
    try {
      final status = await context.read<RatingRepository>().status(
        accessToken: token,
        type: widget.type,
        subjectId: widget.subjectId,
      );
      if (mounted) {
        setState(() => _status = status);
      }
    } catch (_) {
      // Rating is optional: hide the card when the lookup fails.
    }
  }

  Future<void> _rate() async {
    final rating = await showModalBottomSheet<ServiceRating>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DealGoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DealGoRadius.card),
        ),
      ),
      builder: (_) => RatingSheet(
        type: widget.type,
        subjectId: widget.subjectId,
        hasDriver: widget.hasDriver,
      ),
    );
    if (rating != null && mounted) {
      setState(() => _status = RatingStatus(rating: rating, canRate: false));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).rateThanks)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final rating = status?.rating;
    if (status == null || (rating == null && !status.canRate)) {
      return const SizedBox.shrink();
    }
    final isRide = widget.type == RatingSubjectType.ride;
    return Padding(
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s12),
      child: DealGoCard(
        key: const Key('rate-service-card'),
        child: rating == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isRide ? l10n.rateRidePrompt : l10n.rateOrderPrompt,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(l10n.rateWhy, style: textTheme.bodySmall),
                  if (status.rateableUntil != null)
                    Padding(
                      padding: const EdgeInsets.only(top: DealGoSpacing.s4),
                      child: Text(
                        l10n.rateDeadline(
                          DateFormat(
                            'HH:mm dd/MM/yyyy',
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(status.rateableUntil!),
                        ),
                        key: const Key('rate-deadline'),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoPrimaryButton(
                    key: const Key('rate-open'),
                    label: isRide ? l10n.rateRideAction : l10n.rateOrderAction,
                    leadingIcon: DealGoIcons.star,
                    onPressed: _rate,
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(DealGoIcons.star, color: DealGoColors.amber),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      l10n.rateDone(
                        rating.driverStars ?? rating.storeStars ?? 0,
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class RatingSheet extends StatefulWidget {
  const RatingSheet({
    required this.type,
    required this.subjectId,
    required this.hasDriver,
    super.key,
  });

  final RatingSubjectType type;
  final String subjectId;
  final bool hasDriver;

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  final _comment = TextEditingController();
  final _tags = <RatingTag>{};
  int? _driverStars;
  int? _storeStars;
  var _saving = false;
  String? _error;

  bool get _isFood => widget.type == RatingSubjectType.foodOrder;

  bool get _complete =>
      (!widget.hasDriver || _driverStars != null) &&
      (!_isFood || _storeStars != null);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final token = _token(context);
    if (token == null || !_complete) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final rating = await context.read<RatingRepository>().submit(
        accessToken: token,
        submission: RatingSubmission(
          type: widget.type,
          subjectId: widget.subjectId,
          driverStars: widget.hasDriver ? _driverStars : null,
          storeStars: _isFood ? _storeStars : null,
          tags: _tags.toList(),
          comment: _comment.text,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(rating);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final code = error is ApiException ? error.errorCode : '';
      setState(() {
        _saving = false;
        _error = switch (code) {
          'RATING_ALREADY_SUBMITTED' => l10n.rateErrAlready,
          'RATING_NOT_ALLOWED' => l10n.rateErrNotAllowed,
          'RATING_WINDOW_EXPIRED' => l10n.rateErrExpired,
          'NETWORK_ERROR' => l10n.rateErrOffline,
          _ => l10n.rateErrGeneric,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tags = [
      for (final tag in RatingTag.values)
        if (tag.appliesTo(widget.type)) tag,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isFood ? l10n.rateOrderTitle : l10n.rateRideTitle,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: DealGoSpacing.s16),
            if (widget.hasDriver)
              _StarRow(
                key: const Key('rate-driver-stars'),
                label: l10n.rateDriverLabel,
                value: _driverStars,
                onChanged: (value) => setState(() => _driverStars = value),
              ),
            if (_isFood)
              _StarRow(
                key: const Key('rate-store-stars'),
                label: l10n.rateStoreLabel,
                value: _storeStars,
                onChanged: (value) => setState(() => _storeStars = value),
              ),
            const SizedBox(height: DealGoSpacing.s12),
            Text(l10n.rateTagsLabel, style: textTheme.labelLarge),
            const SizedBox(height: DealGoSpacing.s8),
            Wrap(
              spacing: DealGoSpacing.s8,
              runSpacing: DealGoSpacing.s8,
              children: [
                for (final tag in tags)
                  DealGoChip(
                    key: Key('rate-tag-${tag.wire}'),
                    label: ratingTagLabel(l10n, tag),
                    selected: _tags.contains(tag),
                    onTap: () => setState(() {
                      if (!_tags.remove(tag)) {
                        _tags.add(tag);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.rateCommentLabel,
              hint: l10n.rateCommentHint,
              controller: _comment,
              fieldKey: const Key('rate-comment'),
              maxLength: 500,
              maxLines: 3,
            ),
            if (_error case final error?) ...[
              Text(
                error,
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.danger,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
            ],
            const SizedBox(height: DealGoSpacing.s8),
            DealGoPrimaryButton(
              key: const Key('rate-submit'),
              label: l10n.rateSubmit,
              enabled: _complete,
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          for (var star = 1; star <= 5; star++)
            IconButton(
              key: Key('${(key as ValueKey<String>?)?.value ?? 'stars'}-$star'),
              tooltip: l10n.rateStarTooltip(star),
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(star),
              icon: Icon(
                DealGoIcons.star,
                color: (value ?? 0) >= star
                    ? DealGoColors.amber
                    : DealGoColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

String ratingTagLabel(AppLocalizations l10n, RatingTag tag) => switch (tag) {
  RatingTag.onTime => l10n.rateTagOnTime,
  RatingTag.friendly => l10n.rateTagFriendly,
  RatingTag.safeDriving => l10n.rateTagSafeDriving,
  RatingTag.cleanVehicle => l10n.rateTagCleanVehicle,
  RatingTag.tastyFood => l10n.rateTagTastyFood,
  RatingTag.wellPacked => l10n.rateTagWellPacked,
  RatingTag.late => l10n.rateTagLate,
  RatingTag.rude => l10n.rateTagRude,
  RatingTag.unsafeDriving => l10n.rateTagUnsafeDriving,
  RatingTag.wrongItems => l10n.rateTagWrongItems,
  RatingTag.coldFood => l10n.rateTagColdFood,
};
