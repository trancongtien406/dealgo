import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_dialog.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../identity/domain/entities/app_role.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/entities/user_profile.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../onboarding/presentation/utils/driver_kyc_routes.dart';
import '../../onboarding/presentation/utils/merchant_kyb_routes.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../l10n/app_localizations.dart';

class RolePickerPage extends StatefulWidget {
  const RolePickerPage({required this.roles, super.key});

  final List<AppRole> roles;

  @override
  State<RolePickerPage> createState() => _RolePickerPageState();
}

class _RolePickerPageState extends State<RolePickerPage> {
  late AppRole _selected = _defaultRole(widget.roles);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final profile = auth is AuthSignedIn ? auth.profile : null;
    final onboardingRoles = _onboardingRoles(profile, widget.roles);
    final modes = _roleModesFor(AppLocalizations.of(context))
        .where((mode) => widget.roles.contains(mode.role))
        .toList();
    final canPop = context.canPop();

    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DealGoColors.card,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DealGoColors.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DealGoColors.brandGreen.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DealGoAppHeader(
                  title: l10n.accountRoles,
                  showBack: canPop,
                  onBack: canPop ? () => context.pop() : null,
                  applySafeArea: false,
                  backgroundColor: Colors.transparent,
                  actions: IconButton(
                    tooltip: l10n.authHelp,
                    onPressed: () => _showHelp(context),
                    icon: const Icon(
                      DealGoIcons.help,
                      color: DealGoColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s16,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s8,
                    ),
                    children: [
                      Text.rich(
                        TextSpan(
                          style: textTheme.headlineMedium,
                          children: [
                            TextSpan(text: l10n.rolePickerPrefix),
                            TextSpan(
                              text: 'Deal',
                              style: textTheme.headlineMedium?.copyWith(
                                color: DealGoColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: 'Go',
                              style: textTheme.headlineMedium?.copyWith(
                                color: DealGoColors.brandGreen,
                              ),
                            ),
                            TextSpan(text: l10n.rolePickerSuffix),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DealGoSpacing.s24),
                      for (final mode in modes) ...[
                        _RoleCard(
                          mode: mode,
                          selected: mode.role == _selected,
                          onTap: () => setState(() => _selected = mode.role),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                      ],
                      if (onboardingRoles.isNotEmpty) ...[
                        const SizedBox(height: DealGoSpacing.s16),
                        Divider(height: 1, color: DealGoColors.border),
                        const SizedBox(height: DealGoSpacing.s16),
                        Text(
                          l10n.rolePickerPartnerSection,
                          style: textTheme.labelLarge?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        for (final role in onboardingRoles) ...[
                          _OnboardingCard(
                            role: role,
                            grantStatus: profile?.grantStatus(role),
                            onTap: () => context.push(_onboardingPath(role)),
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                        ],
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s16,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DealGoSecondaryButton(
                            label: l10n.rolePickerLearnMore,
                            onPressed: () => _showLearnMore(context),
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: DealGoPrimaryButton(
                            label: l10n.actionContinue,
                            trailingIcon: DealGoIcons.arrowRight,
                            onPressed: () => context.go(_selected.homePath),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDealGoDialog<void>(
      context: context,
      title: l10n.authHelp,
      primaryLabel: l10n.actionGotIt,
    );
  }

  void _showLearnMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).rolePickerInfoTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DealGoColors.text,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: DealGoPrimaryButton(
                  label: AppLocalizations.of(context).actionGotIt,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<AppRole> _onboardingRoles(UserProfile? profile, List<AppRole> active) {
  if (profile == null) {
    return const [];
  }
  final roles = <AppRole>[];
  for (final role in const [AppRole.driver, AppRole.merchant]) {
    if (active.contains(role)) {
      continue;
    }
    if (profile.needsPartnerOnboarding(role) ||
        profile.grantStatus(role) == null) {
      roles.add(role);
    }
  }
  return roles;
}

String _onboardingPath(AppRole role) {
  return switch (role) {
    AppRole.driver => DriverKycRoutes.root,
    AppRole.merchant => MerchantKybRoutes.root,
    AppRole.customer => '/roles',
  };
}

AppRole _defaultRole(List<AppRole> roles) {
  if (roles.isEmpty || roles.contains(AppRole.customer)) {
    return AppRole.customer;
  }
  return roles.first;
}

class _RoleMode {
  const _RoleMode({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.imageAsset,
  });

  final AppRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String imageAsset;
}

List<_RoleMode> _roleModesFor(AppLocalizations l10n) => <_RoleMode>[
  _RoleMode(
    role: AppRole.customer,
    title: l10n.roleCustomer,
    subtitle: l10n.roleCustomerBody,
    icon: DealGoIcons.user,
    iconColor: DealGoColors.primary,
    imageAsset: 'assets/images/role_customer_3d.png',
  ),
  _RoleMode(
    role: AppRole.merchant,
    title: l10n.roleMerchant,
    subtitle: l10n.roleMerchantBody,
    icon: DealGoIcons.store,
    iconColor: DealGoColors.brandGreen,
    imageAsset: 'assets/images/role_merchant_3d.png',
  ),
  _RoleMode(
    role: AppRole.driver,
    title: l10n.roleDriver,
    subtitle: l10n.roleDriverBody,
    icon: DealGoIcons.helmet,
    iconColor: DealGoColors.info,
    imageAsset: 'assets/images/role_driver_3d.png',
  ),
];

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final _RoleMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DealGoRadius.card);
    final inner = Material(
      color: DealGoColors.card,
      borderRadius: BorderRadius.circular(
        DealGoRadius.card - (selected ? 2 : 0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s12,
            DealGoSpacing.s12,
            DealGoSpacing.s8,
            DealGoSpacing.s12,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: mode.iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(mode.icon, color: DealGoColors.card, size: 24),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DealGoColors.text,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      mode.subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DealGoSpacing.s4),
              SizedBox(
                width: 88,
                height: 72,
                child: Image.asset(
                  mode.imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    mode.icon,
                    color: mode.iconColor.withValues(alpha: 0.45),
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? DealGoColors.primary : DealGoColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: DealGoColors.primary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : DealGoShadows.card,
          ),
          child: inner,
        ),
        if (selected)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: DealGoColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: DealGoColors.card, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: DealGoColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                DealGoIcons.check,
                size: 16,
                color: DealGoColors.card,
              ),
            ),
          ),
      ],
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.role,
    required this.grantStatus,
    required this.onTap,
  });

  final AppRole role;
  final String? grantStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDriver = role == AppRole.driver;
    final title = isDriver
        ? AppLocalizations.of(context).rolePartnerDriver
        : AppLocalizations.of(context).rolePartnerShop;
    final detail = switch (grantStatus) {
      'PENDING' => AppLocalizations.of(context).rolePartnerPending,
      'REJECTED' => AppLocalizations.of(context).rolePartnerRejected,
      _ => AppLocalizations.of(context).rolePartnerStart,
    };
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.lavender,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        side: BorderSide(color: DealGoColors.border.withValues(alpha: 0.9)),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isDriver
                      ? DealGoColors.amberSurface
                      : DealGoColors.greenSurface,
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    isDriver ? DealGoIcons.helmet : DealGoIcons.store,
                    size: 20,
                    color: isDriver
                        ? DealGoColors.amber
                        : DealGoColors.brandGreen,
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: DealGoColors.text,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      detail,
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                DealGoIcons.chevronRight,
                size: 20,
                color: DealGoColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
