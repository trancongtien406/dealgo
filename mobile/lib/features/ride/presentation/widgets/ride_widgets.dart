import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';

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

class RideScreenHeader extends StatelessWidget {
  const RideScreenHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DealGoSpacing.s8,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
      ),
      child: Row(
        children: [
          AuthBackButton(onPressed: onBack),
          const SizedBox(width: DealGoSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: textTheme.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class RidePanel extends StatelessWidget {
  const RidePanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: child,
      ),
    );
  }
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
    return Column(
      children: [
        RideStopRow(
          color: DealGoColors.brandGreen,
          label: 'Điểm đón',
          value: pickup,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        const RideStopRow(
          color: DealGoColors.border,
          label: '',
          value: '',
          connector: true,
        ),
        RideStopRow(
          color: DealGoColors.danger,
          label: 'Điểm đến',
          value: dropoff,
        ),
      ],
    );
  }
}

class RideStopRow extends StatelessWidget {
  const RideStopRow({
    required this.color,
    required this.label,
    required this.value,
    this.connector = false,
    super.key,
  });

  final Color color;
  final String label;
  final String value;
  final bool connector;

  @override
  Widget build(BuildContext context) {
    if (connector) {
      return const SizedBox(height: 4);
    }
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
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
  const RideStatusChip({required this.label, required this.tone, super.key});

  final String label;
  final RideChipTone tone;

  @override
  Widget build(BuildContext context) {
    return DealGoChip(
      label: label,
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
    required this.message,
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
            borderRadius: BorderRadius.circular(16),
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
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: DealGoColors.textSecondary,
          ),
        ),
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
    super.key,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;
  final Key? primaryKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DealGoSecondaryButton(
            label: secondaryLabel,
            enabled: enabled,
            onPressed: onSecondary,
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: DealGoPrimaryButton(
            key: primaryKey,
            label: primaryLabel,
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
          'Bạn đang ngoại tuyến',
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
    super.key,
  });

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FA),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RideStatusChip(
              label: rideVehicleLabel,
              tone: RideChipTone.purple,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            RideStopList(pickup: pickup, dropoff: dropoff),
          ],
        ),
      ),
    );
  }
}

String rideOfferKindLabel(RideOfferKind kind) {
  return switch (kind) {
    RideOfferKind.accept => 'Bằng giá bạn đề xuất',
    RideOfferKind.counter => 'Đề nghị khác',
  };
}
