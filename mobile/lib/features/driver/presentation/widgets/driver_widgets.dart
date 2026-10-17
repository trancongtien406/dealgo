import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/auth_redirect.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';

String? driverAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  if (auth is! AuthSignedIn) {
    return null;
  }
  return auth.tokens.accessToken;
}

void driverBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final auth = context.read<AuthCubit>().state;
  if (auth is AuthSignedIn && auth.profile.activeAppRoles.length > 1) {
    context.push(AuthRoutes.roles);
  }
}

class DriverPageFrame extends StatelessWidget {
  const DriverPageFrame({
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.onBack,
    this.insetBottom = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onBack;
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
            DriverHeader(title: title, subtitle: subtitle, onBack: onBack),
            Expanded(child: body),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class DriverHeader extends StatelessWidget {
  const DriverHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
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
          AuthBackButton(onPressed: onBack ?? () => driverBack(context)),
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
        ],
      ),
    );
  }
}

class DriverPanel extends StatelessWidget {
  const DriverPanel({
    required this.child,
    this.color = DealGoColors.card,
    super.key,
  });

  final Widget child;
  final Color color;

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
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: child,
      ),
    );
  }
}

class DriverNote extends StatelessWidget {
  const DriverNote({
    required this.message,
    this.tone = DriverNoteTone.warning,
    super.key,
  });

  final String message;
  final DriverNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      DriverNoteTone.warning => (
        DealGoColors.warningSurface,
        DealGoColors.warning,
      ),
      DriverNoteTone.green => (
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

enum DriverNoteTone { warning, green }

class DriverHero extends StatelessWidget {
  const DriverHero({
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
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 72,
            height: 72,
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

class DriverMoneyRow extends StatelessWidget {
  const DriverMoneyRow({
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

enum DriverChipTone { green, danger, warning, neutral }

/// Thin feature wrapper over [DealGoChip] so driver call sites keep tone names.
class DriverChip extends StatelessWidget {
  const DriverChip({required this.label, required this.tone, super.key});

  final String label;
  final DriverChipTone tone;

  @override
  Widget build(BuildContext context) {
    return DealGoChip(
      label: label,
      tone: switch (tone) {
        DriverChipTone.green => DealGoChipTone.success,
        DriverChipTone.danger => DealGoChipTone.danger,
        DriverChipTone.warning => DealGoChipTone.warning,
        DriverChipTone.neutral => DealGoChipTone.neutral,
      },
    );
  }
}

class DriverFooter extends StatelessWidget {
  const DriverFooter({
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
      child: Row(
        children: [
          Expanded(
            child: DealGoSecondaryButton(
              label: secondaryLabel,
              onPressed: onSecondary,
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: DealGoPrimaryButton(
              key: primaryKey,
              label: primaryLabel,
              enabled: primaryEnabled,
              isLoading: primaryLoading,
              onPressed: onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverStop extends StatelessWidget {
  const DriverStop({
    required this.color,
    required this.label,
    required this.value,
    super.key,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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

class DriverMissingJobPage extends StatelessWidget {
  const DriverMissingJobPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DriverPageFrame(
        title: 'Yêu cầu',
        insetBottom: true,
        body: Center(child: Text('Không tìm thấy yêu cầu')),
      ),
    );
  }
}

const driverStateSubtitle = 'DealGo · Biến thể trạng thái';
const driverAreaLabel = 'Hải Châu, Đà Nẵng';
const driverVehicleLabel = 'Xe máy';
