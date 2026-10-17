import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/food_money.dart';

String? currentAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is! AuthSignedIn) {
    return null;
  }
  return auth.tokens.accessToken;
}

class FoodScreenHeader extends StatelessWidget {
  const FoodScreenHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

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
          AuthBackButton(
            onPressed:
                onBack ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
          ),
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

class FoodPanel extends StatelessWidget {
  const FoodPanel({
    required this.child,
    this.color = DealGoColors.card,
    this.padding = const EdgeInsets.all(DealGoSpacing.s16),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(
          color: color == DealGoColors.card
              ? DealGoColors.border
              : Colors.transparent,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class FoodMoneyRow extends StatelessWidget {
  const FoodMoneyRow({
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
        : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
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
          Text(amount, style: valueStyle),
        ],
      ),
    );
  }
}

class FoodNote extends StatelessWidget {
  const FoodNote({required this.message, required this.tone, super.key});

  final String message;
  final FoodNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      FoodNoteTone.green => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      FoodNoteTone.amber => (DealGoColors.warningSurface, DealGoColors.warning),
      FoodNoteTone.danger => (DealGoColors.dangerSurface, DealGoColors.danger),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

enum FoodNoteTone { green, amber, danger }

enum FoodChipTone { neutral, green, warning, purple, danger }

class FoodStatusChip extends StatelessWidget {
  const FoodStatusChip({required this.label, required this.tone, super.key});

  final String label;
  final FoodChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      FoodChipTone.neutral => (DealGoColors.canvas, DealGoColors.textSecondary),
      FoodChipTone.green => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      FoodChipTone.warning => (DealGoColors.amberSurface, DealGoColors.amber),
      FoodChipTone.purple => (DealGoColors.subtlePurple, DealGoColors.primary),
      FoodChipTone.danger => (DealGoColors.dangerSurface, DealGoColors.danger),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s4,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class FoodThumb extends StatelessWidget {
  const FoodThumb({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.ramen_dining,
          color: const Color(0xFFEA580C),
          size: size * 0.46,
        ),
      ),
    );
  }
}

class FoodLineSummary extends StatelessWidget {
  const FoodLineSummary({
    required this.name,
    required this.quantity,
    required this.unitPriceVnd,
    required this.lineTotalVnd,
    super.key,
  });

  final String name;
  final int quantity;
  final int unitPriceVnd;
  final int lineTotalVnd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FoodThumb(size: 44),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DealGoColors.text,
                  ),
                ),
                Text(
                  'x$quantity · ${formatVnd(unitPriceVnd)} / món',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatVnd(lineTotalVnd),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class FoodStateIcon extends StatelessWidget {
  const FoodStateIcon({
    required this.icon,
    required this.background,
    required this.foreground,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Icon(icon, color: foreground, size: 28),
      ),
    );
  }
}
