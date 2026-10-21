import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../identity/domain/auth_redirect.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

String? merchantAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is! AuthSignedIn) {
    return null;
  }
  return auth.tokens.accessToken;
}

void merchantBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final auth = context.read<AuthCubit>().state;
  if (auth is AuthSignedIn && auth.profile.activeAppRoles.length > 1) {
    context.push(AuthRoutes.roles);
  }
}

String merchantStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'PLACED' => l10n.merchantStatusPlaced,
    'PREPARING' => l10n.merchantStatusPreparing,
    'READY' || 'READY_FOR_PICKUP' => l10n.merchantStatusReady,
    'ASSIGNED' => l10n.merchantStatusAssigned,
    _ => status,
  };
}

MerchantChipTone merchantStatusTone(String status) {
  return switch (status) {
    'PLACED' => MerchantChipTone.warning,
    'PREPARING' || 'READY' => MerchantChipTone.green,
    _ => MerchantChipTone.neutral,
  };
}

String merchantCountLabel(int value) {
  if (value < 0) {
    return '0';
  }
  if (value < 100) {
    return value.toString().padLeft(2, '0');
  }
  return value.toString();
}

String formatSyncClock(AppLocalizations l10n, DateTime? time) {
  if (time == null) {
    return l10n.merchantNotSynced;
  }
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class MerchantQueueTotals {
  const MerchantQueueTotals({
    required this.placed,
    required this.preparing,
    required this.ready,
    required this.subtotalVnd,
    required this.deliveryFareVnd,
    required this.totalVnd,
  });

  final int placed;
  final int preparing;
  final int ready;
  final int subtotalVnd;
  final int deliveryFareVnd;
  final int totalVnd;
}

MerchantQueueTotals merchantQueueTotals(List<MerchantQueueOrder> orders) {
  var placed = 0;
  var preparing = 0;
  var ready = 0;
  var subtotalVnd = 0;
  var deliveryFareVnd = 0;
  var totalVnd = 0;
  for (final order in orders) {
    switch (order.status) {
      case 'PLACED':
        placed += 1;
      case 'PREPARING':
        preparing += 1;
      case 'READY':
        ready += 1;
    }
    subtotalVnd += order.subtotalVnd;
    deliveryFareVnd += order.deliveryFareVnd;
    totalVnd += order.totalVnd;
  }
  return MerchantQueueTotals(
    placed: placed,
    preparing: preparing,
    ready: ready,
    subtotalVnd: subtotalVnd,
    deliveryFareVnd: deliveryFareVnd,
    totalVnd: totalVnd,
  );
}

class MerchantPageFrame extends StatelessWidget {
  const MerchantPageFrame({
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.onBack,
    this.trailing,
    this.insetBottom = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool insetBottom;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: insetBottom,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MerchantHeader(
              title: title,
              subtitle: subtitle,
              onBack: onBack,
              trailing: trailing,
            ),
            Expanded(
              child: Material(type: MaterialType.transparency, child: body),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class MerchantHeader extends StatelessWidget {
  const MerchantHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return DealGoAppHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBack ?? (canPop ? () => merchantBack(context) : null),
      showBack: canPop || onBack != null,
      trailing: trailing,
    );
  }
}

class MerchantPanel extends StatelessWidget {
  const MerchantPanel({
    required this.child,
    this.color = DealGoColors.card,
    this.elevated = false,
    this.borderColor,
    this.padding = const EdgeInsets.all(DealGoSpacing.s16),
    super.key,
  });

  final Widget child;
  final Color color;
  final bool elevated;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DealGoRadius.card);
    final side =
        borderColor ??
        (color == DealGoColors.card ? DealGoColors.border : Colors.transparent);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: side),
        boxShadow: elevated ? DealGoShadows.card : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

enum MerchantNoteTone { warning, green }

class MerchantNote extends StatelessWidget {
  const MerchantNote({
    required this.message,
    this.tone = MerchantNoteTone.warning,
    super.key,
  });

  final String message;
  final MerchantNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      MerchantNoteTone.warning => (
        DealGoColors.warningSurface,
        DealGoColors.warning,
      ),
      MerchantNoteTone.green => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class MerchantHero extends StatelessWidget {
  const MerchantHero({
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
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: DealGoColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class MerchantMoneyRow extends StatelessWidget {
  const MerchantMoneyRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    super.key,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              value,
              textAlign: TextAlign.end,
              style: emphasize
                  ? textTheme.titleMedium?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w800,
                    )
                  : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

enum MerchantChipTone { green, warning, neutral }

/// Thin feature wrapper over [DealGoChip].
class MerchantChip extends StatelessWidget {
  const MerchantChip({required this.label, required this.tone, super.key});

  final String label;
  final MerchantChipTone tone;

  @override
  Widget build(BuildContext context) {
    return DealGoChip(
      label: label,
      tone: switch (tone) {
        MerchantChipTone.green => DealGoChipTone.success,
        MerchantChipTone.warning => DealGoChipTone.warning,
        MerchantChipTone.neutral => DealGoChipTone.neutral,
      },
    );
  }
}

class MerchantFooter extends StatelessWidget {
  const MerchantFooter({
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.primaryKey,
    this.primaryEnabled = true,
    this.primaryLoading = false,
    super.key,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;
  final Key? primaryKey;
  final bool primaryEnabled;
  final bool primaryLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final secondary = DealGoSecondaryButton(
            label: secondaryLabel,
            onPressed: onSecondary,
          );
          final primary = DealGoPrimaryButton(
            key: primaryKey,
            label: primaryLabel,
            enabled: primaryEnabled,
            isLoading: primaryLoading,
            onPressed: onPrimary,
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                secondary,
                const SizedBox(height: DealGoSpacing.s12),
                primary,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: secondary),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(child: primary),
            ],
          );
        },
      ),
    );
  }
}

class MerchantPrimaryBar extends StatelessWidget {
  const MerchantPrimaryBar({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.enabled = true,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
      ),
      child: DealGoPrimaryButton(
        key: buttonKey,
        label: label,
        enabled: enabled,
        isLoading: loading,
        trailingIcon: DealGoIcons.arrowRight,
        onPressed: onPressed,
      ),
    );
  }
}

const merchantPagePadding = EdgeInsets.fromLTRB(
  DealGoDimensions.pageGutter,
  DealGoSpacing.s8,
  DealGoDimensions.pageGutter,
  DealGoSpacing.s16,
);

/// M022/M024 radio card: tinted icon, title, hint, radio mark.
class MerchantOptionTile extends StatelessWidget {
  const MerchantOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          side: BorderSide(
            color: selected ? DealGoColors.primary : DealGoColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(DealGoSpacing.s12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DealGoSpacing.s8),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleSmall),
                      Text(hint, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  selected ? DealGoIcons.radioOn : DealGoIcons.radioOff,
                  color: selected ? DealGoColors.primary : DealGoColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
