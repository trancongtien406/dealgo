import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/ride_models.dart';
import '../utils/ride_vehicle_label.dart';
import '../../../../l10n/app_localizations.dart';

String? rideAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is! AuthSignedIn) {
    return null;
  }
  return auth.tokens.accessToken;
}

bool rideFailureIsOffline(Object error) {
  if (error is! ApiException) {
    return true;
  }
  return error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR';
}

/// Drag handle used on ride bottom sheets (C002 / C003).
class RideSheetHandle extends StatelessWidget {
  const RideSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: DealGoColors.border,
          borderRadius: BorderRadius.circular(DealGoRadius.pill),
        ),
      ),
    );
  }
}

class RidePanel extends StatelessWidget {
  const RidePanel({
    required this.child,
    this.color = DealGoColors.card,
    this.padding = const EdgeInsets.all(DealGoSpacing.s16),
    this.elevated = false,
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DealGoRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color: color == DealGoColors.card
              ? DealGoColors.border
              : Colors.transparent,
        ),
        boxShadow: elevated ? DealGoShadows.card : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Rounded top sheet surface for map-backed ride steps.
class RideBottomSheet extends StatelessWidget {
  const RideBottomSheet({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DealGoRadius.sheet),
        ),
        border: Border(top: BorderSide(color: DealGoColors.border)),
        boxShadow: DealGoShadows.floating,
      ),
      child: child,
    );
  }
}

/// inDrive-like persistent sheet: drag + snap sizes over a full-bleed map.
/// Prefer this over [showModalBottomSheet] for book / fare / waiting (map stays
/// interactive; sheet is not a dismissible modal).
class RideDraggableSheet extends StatelessWidget {
  const RideDraggableSheet({
    required this.builder,
    this.initialChildSize = 0.46,
    this.minChildSize = 0.28,
    this.maxChildSize = 0.88,
    this.snapSizes = const [0.28, 0.46, 0.72],
    super.key,
  });

  final Widget Function(BuildContext context, ScrollController controller)
  builder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double> snapSizes;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: true,
      snapSizes: snapSizes,
      builder: (context, controller) {
        return RideBottomSheet(child: builder(context, controller));
      },
    );
  }
}

/// Optional helper: present a one-shot picker sheet (not used on map hot path).
Future<T?> showRideModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return RideBottomSheet(child: builder(context));
    },
  );
}

class RideSectionTitle extends StatelessWidget {
  const RideSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class RideStopList extends StatelessWidget {
  const RideStopList({required this.pickup, required this.dropoff, super.key});

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const _StopDot(color: DealGoColors.brandGreen),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: DealGoSpacing.s4,
                  ),
                  color: DealGoColors.border,
                ),
              ),
              const _StopDot(color: DealGoColors.danger),
            ],
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RideStopRow(
                  color: DealGoColors.brandGreen,
                  label: AppLocalizations.of(context).ridePickup,
                  value: pickup,
                  showDot: false,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                RideStopRow(
                  color: DealGoColors.danger,
                  label: AppLocalizations.of(context).rideDropoff,
                  value: dropoff,
                  showDot: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox(width: 10, height: 10),
      ),
    );
  }
}

class RideStopRow extends StatelessWidget {
  const RideStopRow({
    required this.color,
    required this.label,
    required this.value,
    this.connector = false,
    this.showDot = true,
    super.key,
  });

  final Color color;
  final String label;
  final String value;
  final bool connector;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    if (connector) {
      return const SizedBox(height: 4);
    }
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDot) ...[
          _StopDot(color: color),
          const SizedBox(width: DealGoSpacing.s8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodySmall),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bordered pickup/dropoff field used on the map booking sheet (C002).
class RideStopField extends StatelessWidget {
  const RideStopField({
    required this.icon,
    required this.tone,
    required this.caption,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final Color tone;
  final String caption;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chosen = value;
    return Semantics(
      button: true,
      label: '$caption: ${chosen ?? placeholder}',
      excludeSemantics: true,
      child: Material(
        color: DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          side: const BorderSide(color: DealGoColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s12,
              vertical: DealGoSpacing.s12,
            ),
            child: Row(
              children: [
                Icon(icon, color: tone, size: 20),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caption, style: textTheme.labelSmall),
                      Text(
                        chosen ?? placeholder,
                        // Full address wraps; never cut the house number off.
                        softWrap: true,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: chosen == null
                              ? FontWeight.w400
                              : FontWeight.w700,
                          color: chosen == null
                              ? DealGoColors.textSecondary
                              : DealGoColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: DealGoSpacing.s8),
                  trailing!,
                ] else
                  Icon(
                    chosen == null
                        ? DealGoIcons.chevronRight
                        : DealGoIcons.edit,
                    color: DealGoColors.textSecondary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RideNote extends StatelessWidget {
  const RideNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.warningSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DealGoColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class RideInfoBanner extends StatelessWidget {
  const RideInfoBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.greenSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              DealGoIcons.info,
              color: DealGoColors.brandGreen,
              size: 18,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DealGoColors.brandGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RideMoneyLine extends StatelessWidget {
  const RideMoneyLine({
    required this.label,
    required this.amount,
    this.emphasize = false,
    super.key,
  });

  final String label;
  final String amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = emphasize
        ? textTheme.titleMedium?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w800,
          )
        : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize ? textTheme.titleMedium : textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Flexible(
            child: Text(
              amount,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

enum RideChipTone { neutral, danger, warning, green, purple }

/// Thin feature wrapper over [DealGoChip].
class RideStatusChip extends StatelessWidget {
  const RideStatusChip({
    required this.label,
    required this.tone,
    this.leading,
    super.key,
  });

  final String label;
  final RideChipTone tone;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return DealGoChip(
      label: label,
      leading: leading,
      tone: switch (tone) {
        RideChipTone.neutral => DealGoChipTone.neutral,
        RideChipTone.danger => DealGoChipTone.danger,
        RideChipTone.warning => DealGoChipTone.warning,
        RideChipTone.green => DealGoChipTone.success,
        RideChipTone.purple => DealGoChipTone.brand,
      },
    );
  }
}

class RideStateHero extends StatelessWidget {
  const RideStateHero({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    this.message = '',
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
          ),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, color: iconColor, size: 32),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(fontSize: 22),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class RideDualActions extends StatelessWidget {
  const RideDualActions({
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.primaryKey,
    this.enabled = true,
    this.compact = true,
    super.key,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;
  final Key? primaryKey;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DealGoSecondaryButton(
            label: secondaryLabel,
            compact: compact,
            enabled: enabled,
            onPressed: onSecondary,
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: DealGoPrimaryButton(
            key: primaryKey,
            label: primaryLabel,
            compact: compact,
            enabled: enabled,
            onPressed: onPrimary,
          ),
        ),
      ],
    );
  }
}

class RideOfflineNotice extends StatelessWidget {
  const RideOfflineNotice({required this.detail, super.key});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context).rideYouAreOffline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class RideRoutePanel extends StatelessWidget {
  const RideRoutePanel({
    required this.pickup,
    required this.dropoff,
    this.vehicleClassCode,
    this.imageUrl,
    super.key,
  });

  final String pickup;
  final String dropoff;
  final String? vehicleClassCode;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = resolveMediaUrl(imageUrl);
    return RidePanel(
      color: DealGoColors.lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RideStatusChip(
            label: rideVehicleClassLabel(l10n, vehicleClassCode),
            tone: RideChipTone.purple,
            leading: photo == null
                ? Icon(
                    rideVehicleClassIcon(vehicleClassCode),
                    size: 14,
                    color: DealGoColors.primary,
                  )
                : RideVehicleClassPhoto(
                    imageUrl: imageUrl,
                    code: vehicleClassCode,
                    size: 18,
                  ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          RideStopList(pickup: pickup, dropoff: dropoff),
        ],
      ),
    );
  }
}

String rideOfferKindLabel(AppLocalizations l10n, RideOfferKind kind) {
  return switch (kind) {
    RideOfferKind.accept => l10n.rideOfferKindAccept,
    RideOfferKind.counter => l10n.rideOfferKindCounter,
  };
}
