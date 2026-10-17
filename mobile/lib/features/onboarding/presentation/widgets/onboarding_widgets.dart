import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/partner_onboarding.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.title,
    required this.roleBadge,
    required this.body,
    this.footer,
    this.onBack,
    super.key,
  });

  final String title;
  final String roleBadge;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoSpacing.s8,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                0,
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    AuthBackButton(onPressed: onBack!)
                  else
                    const SizedBox(width: DealGoDimensions.minTapTarget),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  _RolePill(label: roleBadge),
                ],
              ),
            ),
            Expanded(child: body),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    required this.flowLabel,
    required this.stepLabel,
    required this.currentStep,
    required this.totalSteps,
    required this.headline,
    this.subtitle,
    super.key,
  });

  final String flowLabel;
  final String stepLabel;
  final int currentStep;
  final int totalSteps;
  final String headline;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                flowLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.textSecondary,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              stepLabel,
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s8),
        OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps),
        const SizedBox(height: DealGoSpacing.s20),
        Text(headline, style: textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    required this.currentStep,
    required this.totalSteps,
    super.key,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= totalSteps; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: i < currentStep
                    ? DealGoColors.brandGreen
                    : i == currentStep
                    ? DealGoColors.primary
                    : DealGoColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const SizedBox(height: 6),
            ),
          ),
        ],
      ],
    );
  }
}

enum OnboardingBannerTone { success, warning, danger, neutral }

class OnboardingInfoBanner extends StatelessWidget {
  const OnboardingInfoBanner({
    required this.message,
    this.tone = OnboardingBannerTone.success,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String message;
  final OnboardingBannerTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      OnboardingBannerTone.success => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      OnboardingBannerTone.warning => (
        DealGoColors.warningSurface,
        DealGoColors.warning,
      ),
      OnboardingBannerTone.danger => (
        DealGoColors.dangerSurface,
        DealGoColors.danger,
      ),
      OnboardingBannerTone.neutral => (
        DealGoColors.subtlePurple,
        DealGoColors.primary,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: fg, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin feature wrapper over [DealGoChip].
class OnboardingStatusChip extends StatelessWidget {
  const OnboardingStatusChip({
    required this.label,
    required this.tone,
    super.key,
  });

  final String label;
  final OnboardingBannerTone tone;

  @override
  Widget build(BuildContext context) {
    return DealGoChip(
      label: label,
      size: DealGoChipSize.md,
      tone: switch (tone) {
        OnboardingBannerTone.success => DealGoChipTone.success,
        OnboardingBannerTone.warning => DealGoChipTone.warning,
        OnboardingBannerTone.danger => DealGoChipTone.danger,
        OnboardingBannerTone.neutral => DealGoChipTone.brand,
      },
    );
  }
}

class OnboardingSelectCard extends StatelessWidget {
  const OnboardingSelectCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.multiSelect = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, color: iconColor),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(subtitle, style: textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected
                    ? (multiSelect
                          ? Icons.check_circle
                          : Icons.radio_button_checked)
                    : (multiSelect
                          ? Icons.circle_outlined
                          : Icons.radio_button_off),
                color: selected
                    ? DealGoColors.primary
                    : DealGoColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingMockField extends StatelessWidget {
  const OnboardingMockField({
    required this.label,
    required this.value,
    this.required = false,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: textTheme.labelLarge?.copyWith(fontSize: 13),
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: DealGoColors.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.card,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            border: Border.all(color: DealGoColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Expanded(child: Text(value, style: textTheme.bodyLarge)),
                ?trailing,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingMockDocSlot extends StatelessWidget {
  const OnboardingMockDocSlot({
    required this.title,
    required this.hint,
    required this.attached,
    required this.onToggle,
    super.key,
  });

  final String title;
  final String hint;
  final bool attached;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: attached ? DealGoColors.brandGreen : DealGoColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s4),
            Text(hint, style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s12),
            OutlinedButton.icon(
              onPressed: onToggle,
              icon: Icon(
                attached
                    ? Icons.check_circle_outline
                    : Icons.add_a_photo_outlined,
              ),
              label: Text(attached ? 'Đã đính kèm (mock)' : 'Thêm tệp mock'),
              style: OutlinedButton.styleFrom(
                foregroundColor: attached
                    ? DealGoColors.brandGreen
                    : DealGoColors.primary,
                side: BorderSide(
                  color: attached
                      ? DealGoColors.brandGreen
                      : DealGoColors.primary,
                ),
                minimumSize: const Size(
                  DealGoDimensions.minTapTarget,
                  DealGoDimensions.buttonMinHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DealGoRadius.button),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingRejectionList extends StatelessWidget {
  const OnboardingRejectionList({required this.items, super.key});

  final List<OnboardingRejection> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final item in items) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.card,
              borderRadius: BorderRadius.circular(DealGoRadius.card),
              border: Border.all(color: DealGoColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(DealGoSpacing.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error, color: DealGoColors.danger),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: textTheme.titleMedium),
                        const SizedBox(height: DealGoSpacing.s4),
                        Text(item.reason, style: textTheme.bodySmall),
                        const SizedBox(height: DealGoSpacing.s4),
                        Text(
                          item.code,
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }
}

class OnboardingContinueBar extends StatelessWidget {
  const OnboardingContinueBar({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DealGoPrimaryButton(
      label: label,
      enabled: enabled,
      trailingIcon: Icons.arrow_forward,
      onPressed: onPressed,
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
