import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_logo.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/app_role.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/entities/user_profile.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';
import '../../onboarding/presentation/utils/driver_kyc_routes.dart';
import '../../onboarding/presentation/utils/merchant_kyb_routes.dart';

class RolePickerPage extends StatefulWidget {
  const RolePickerPage({required this.roles, super.key});

  final List<AppRole> roles;

  @override
  State<RolePickerPage> createState() => _RolePickerPageState();
}

class _RolePickerPageState extends State<RolePickerPage> {
  late final AppRole _initial = _defaultRole(widget.roles);
  late AppRole _selected = _initial;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final modes =
        _roleModes(l10n).where((mode) => widget.roles.contains(mode.role));
    final auth = context.watch<AuthCubit>().state;
    final profile = auth is AuthSignedIn ? auth.profile : null;
    final onboardingRoles = _onboardingRoles(profile, widget.roles);

    return Scaffold(
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
                  if (context.canPop())
                    AuthBackButton(onPressed: () => context.pop())
                  else
                    const SizedBox(width: DealGoSpacing.s8),
                  const SizedBox(width: DealGoSpacing.s8),
                  Text(l10n.roleHubTitle, style: textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                children: [
                  const Center(child: DealGoLogo(variant: DealGoLogoVariant.horizontal, size: 36)),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    l10n.roleHubSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  for (final mode in modes) ...[
                    _ModeCard(
                      mode: mode,
                      selected: mode.role == _selected,
                      onTap: () => setState(() => _selected = mode.role),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                  ],
                  if (onboardingRoles.isNotEmpty) ...[
                    Text(
                      l10n.roleOnboardingTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    for (final role in onboardingRoles) ...[
                      _OnboardingCard(
                        role: role,
                        grantStatus: profile?.grantStatus(role),
                        onTap: () => context.push(_onboardingPath(role)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                  ],
                  const _SwitchNote(),
                  const SizedBox(height: DealGoSpacing.s12),
                  const _CrossRoleNotice(),
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
              child: DealGoPrimaryButton(
                label: _continueLabel(l10n, _selected),
                trailingIcon: Icons.arrow_forward,
                onPressed: () => context.go(_selected.homePath),
              ),
            ),
          ],
        ),
      ),
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

String _continueLabel(AppLocalizations l10n, AppRole role) {
  return switch (role) {
    AppRole.customer => l10n.roleContinueCustomer,
    AppRole.merchant => l10n.roleContinueMerchant,
    AppRole.driver => l10n.roleContinueDriver,
  };
}

class _RoleMode {
  const _RoleMode({
    required this.role,
    required this.title,
    required this.headline,
    required this.detail,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.imageAsset,
  });

  final AppRole role;
  final String title;
  final String headline;
  final String detail;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String imageAsset;
}

List<_RoleMode> _roleModes(AppLocalizations l10n) => [
  _RoleMode(
    role: AppRole.customer,
    title: l10n.roleCustomerTitle,
    headline: l10n.roleCustomerHeadline,
    detail: l10n.roleCustomerDetail,
    icon: Icons.person_outline,
    tint: DealGoColors.subtlePurple,
    iconColor: DealGoColors.primary,
    imageAsset: 'assets/images/role_customer_3d.png',
  ),
  _RoleMode(
    role: AppRole.merchant,
    title: l10n.roleMerchantTitle,
    headline: l10n.roleMerchantHeadline,
    detail: l10n.roleMerchantDetail,
    icon: Icons.storefront_outlined,
    tint: DealGoColors.greenSurface,
    iconColor: DealGoColors.brandGreen,
    imageAsset: 'assets/images/role_merchant_3d.png',
  ),
  _RoleMode(
    role: AppRole.driver,
    title: l10n.roleDriverTitle,
    headline: l10n.roleDriverHeadline,
    detail: l10n.roleDriverDetail,
    icon: Icons.two_wheeler,
    tint: DealGoColors.amberSurface,
    iconColor: DealGoColors.amber,
    imageAsset: 'assets/images/role_driver_3d.png',
  ),
];

class _ModeCard extends StatelessWidget {
  const _ModeCard({
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
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 2.0 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.title,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? DealGoColors.primary : DealGoColors.textSecondary,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: mode.tint,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        mode.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(mode.icon, color: mode.iconColor, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.headline,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s4),
                        Text(
                          mode.detail,
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  _ModeBadge(selected: selected),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (selected) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: DealGoColors.greenSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          child: Text(
            'Đang xem',
            style: textTheme.labelSmall?.copyWith(
              color: DealGoColors.brandGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DealGoColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chuyển',
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 14,
              color: DealGoColors.primary,
            ),
          ],
        ),
      ),
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
    final textTheme = Theme.of(context).textTheme;
    final isDriver = role == AppRole.driver;
    final title = isDriver ? 'Đăng ký đối tác tài xế' : 'Đăng ký đối tác Shop';
    final detail = switch (grantStatus) {
      'PENDING' => 'Hồ sơ đang thẩm định — tiếp tục theo dõi',
      'REJECTED' => 'Hồ sơ cần bổ sung trước khi hoạt động',
      _ => 'Hoàn tất KYC/KYB mock để kích hoạt vai trò',
    };
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: const BorderSide(color: DealGoColors.border),
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
                  color: isDriver
                      ? DealGoColors.amberSurface
                      : DealGoColors.greenSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      isDriver
                          ? 'assets/images/role_driver.png'
                          : 'assets/images/role_shop.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isDriver ? Icons.two_wheeler : Icons.storefront_outlined,
                        color: isDriver
                            ? DealGoColors.amber
                            : DealGoColors.brandGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(detail, style: textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: DealGoColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchNote extends StatelessWidget {
  const _SwitchNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.greenSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Text(
          'Đổi chế độ chỉ thay đổi giao diện và quyền thao tác. Đơn Shop hoặc công việc Tài xế đang chạy vẫn giữ nguyên trạng thái trên hệ thống.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: DealGoColors.brandGreen, height: 1.4),
        ),
      ),
    );
  }
}

class _CrossRoleNotice extends StatelessWidget {
  const _CrossRoleNotice();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông báo xuyên vai trò', style: textTheme.labelLarge),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.amberSurface,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: DealGoColors.amber,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Có 2 công việc cần theo dõi',
                        style: textTheme.titleMedium?.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        'Thông báo đưa bạn về đúng vai trò khi mở',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
