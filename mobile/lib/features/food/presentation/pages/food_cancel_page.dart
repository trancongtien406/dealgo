import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/cancel_food_order.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// C035 — cancel food order (`POST /v1/food/orders/:id/cancel`, PLACED only).
/// The reason stays on device; the API takes no body.
class FoodCancelPage extends StatefulWidget {
  const FoodCancelPage({required this.orderId, super.key});

  final String orderId;

  @override
  State<FoodCancelPage> createState() => _FoodCancelPageState();
}

class _FoodCancelPageState extends State<FoodCancelPage> {
  String? _reasonId;
  var _submitted = false;
  var _busy = false;
  String? _error;

  List<_FoodCancelReason> _reasons(AppLocalizations l10n) {
    return [
      _FoodCancelReason(id: 'wrong_items', label: l10n.foodCancelReasonWrong),
      _FoodCancelReason(id: 'too_long', label: l10n.foodCancelReasonWait),
      _FoodCancelReason(id: 'address', label: l10n.foodCancelReasonAddress),
      _FoodCancelReason(id: 'other', label: l10n.foodCancelReasonOther),
    ];
  }

  void _back() {
    if (_submitted) {
      // The order is gone. Pop would reopen its detail, which sits above the
      // shell and has no bottom nav.
      context.go('/customer/shop');
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(FoodRoutes.order(widget.orderId));
  }

  Future<void> _confirm() async {
    if (_reasonId == null || _busy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final token = currentAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => _error = l10n.errorSessionExpired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? failure;
    try {
      await context.read<CancelFoodOrder>()(
        accessToken: token,
        orderId: widget.orderId,
      );
    } on ApiException catch (error) {
      failure = switch (error.statusCode) {
        409 => l10n.foodCancelNotAllowed,
        401 => l10n.errorSessionExpired,
        _ when error.statusCode <= 0 => l10n.errorNetwork,
        _ => l10n.foodCancelFailed,
      };
    } catch (_) {
      failure = l10n.foodCancelFailed;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
      _submitted = failure == null;
    });
    if (failure == null) {
      DealGoHaptics.success();
    } else {
      DealGoHaptics.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final reasons = _reasons(l10n);

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: l10n.foodCancelTitle, onBack: _back),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  DealGoBanner(
                    tone: DealGoBannerTone.warning,
                    message: l10n.foodCancelPolicyHint,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(l10n.foodCancelPickReason, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  for (final reason in reasons) ...[
                    Material(
                      color: DealGoColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DealGoRadius.card),
                        side: BorderSide(
                          color: _reasonId == reason.id
                              ? DealGoColors.primary
                              : DealGoColors.border,
                          width: _reasonId == reason.id ? 1.6 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('food-cancel-reason-${reason.id}'),
                        onTap: _submitted || _busy
                            ? null
                            : () => setState(() => _reasonId = reason.id),
                        child: Padding(
                          padding: const EdgeInsets.all(DealGoSpacing.s16),
                          child: Row(
                            children: [
                              Expanded(child: Text(reason.label)),
                              if (_reasonId == reason.id)
                                const DealGoChip(
                                  label: '✓',
                                  tone: DealGoChipTone.brand,
                                  selected: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    DealGoBanner(
                      tone: DealGoBannerTone.warning,
                      message: _error!,
                    ),
                  ],
                  if (_submitted) ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    DealGoBanner(
                      tone: DealGoBannerTone.info,
                      message: l10n.foodCancelDone,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: _submitted
                  ? DealGoPrimaryButton(
                      key: const Key('food-cancel-done'),
                      label: l10n.actionBack,
                      onPressed: _back,
                    )
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: DealGoSecondaryButton(
                              key: const Key('food-cancel-keep'),
                              label: l10n.foodCancelKeep,
                              enabled: !_busy,
                              onPressed: _back,
                            ),
                          ),
                          const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: DealGoPrimaryButton(
                              key: const Key('food-cancel-confirm'),
                              label: l10n.foodCancelConfirm,
                              enabled: _reasonId != null && !_busy,
                              isLoading: _busy,
                              onPressed: _confirm,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodCancelReason {
  const _FoodCancelReason({required this.id, required this.label});

  final String id;
  final String label;
}
