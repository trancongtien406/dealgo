import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../identity/domain/entities/app_role.dart';
import '../../identity/domain/auth_redirect.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/entities/user_profile.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../onboarding/domain/entities/partner_onboarding.dart';
import '../../onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../../onboarding/presentation/utils/driver_kyc_routes.dart';
import '../../onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import '../../onboarding/presentation/utils/merchant_kyb_routes.dart';
import '../../merchant/presentation/utils/merchant_routes.dart';
import 'account_routes.dart';
import 'address_draft_cubit.dart';

String accountShellRoleLabel(String shellPath) {
  if (shellPath.startsWith('/merchant')) {
    return 'Shop';
  }
  if (shellPath.startsWith('/driver')) {
    return 'Tài xế';
  }
  return 'Khách hàng';
}

class AccountPage extends StatelessWidget {
  const AccountPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final signedIn = auth is AuthSignedIn ? auth : null;
    final phone = signedIn?.profile.phone;
    final canSwitchRole =
        signedIn != null && signedIn.profile.activeAppRoles.length > 1;
    final roleLabel = accountShellRoleLabel(shellPath);
    final textTheme = Theme.of(context).textTheme;
    final partnerRows = _partnerOnboardingRows(
      context,
      shellPath,
      signedIn?.profile,
    );

    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: DealGoColors.card,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Tài khoản', style: textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Thông báo',
                      onPressed: () =>
                          context.push(AccountRoutes.notifications(shellPath)),
                      icon: const Icon(Icons.notifications_none_outlined),
                      color: DealGoColors.text,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(phone: phone, roleLabel: roleLabel),
                    const SizedBox(height: DealGoSpacing.s12),
                    const _MenuRow(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Ưu đãi của tôi',
                      subtitle: 'Các mã giảm giá đang có',
                      trailing: _LinkLabel('Xem tất cả →'),
                      showChevron: false,
                    ),
                    const SizedBox(height: DealGoSpacing.s20),
                    Text('Tài khoản và dịch vụ', style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s12),
                    const _MenuRow(
                      icon: Icons.format_list_bulleted,
                      title: 'Hoạt động của tôi',
                      subtitle: 'Chuyến đi và đơn hàng',
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MenuRow(
                      icon: Icons.place_outlined,
                      title: 'Địa chỉ đã lưu',
                      subtitle: 'Nhà riêng, công ty và địa chỉ khác',
                      onTap: () =>
                          context.push(AccountRoutes.addresses(shellPath)),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MenuRow(
                      icon: Icons.credit_card_outlined,
                      title: 'Lịch sử thanh toán',
                      subtitle: 'Biên nhận và hoàn tiền (fixture)',
                      onTap: () =>
                          context.push(AccountRoutes.payments(shellPath)),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MenuRow(
                      icon: Icons.person_outline,
                      title: 'Trung tâm vai trò',
                      subtitle: roleLabel,
                      trailing: canSwitchRole
                          ? const _LinkLabel('Đổi vai trò')
                          : null,
                      onTap: canSwitchRole
                          ? () => context.push(AuthRoutes.roles)
                          : null,
                    ),
                    for (final row in partnerRows) ...[
                      const SizedBox(height: DealGoSpacing.s12),
                      row,
                    ],
                    if (shellPath.startsWith('/merchant')) ...[
                      const SizedBox(height: DealGoSpacing.s12),
                      _MenuRow(
                        icon: Icons.tune,
                        title: 'Nhận đơn auto/manual',
                        subtitle: 'Cấu hình trên thiết bị (mock)',
                        onTap: () =>
                            context.push(MerchantRoutes.acceptSettings),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _MenuRow(
                        icon: Icons.schedule,
                        title: 'Giờ hoạt động',
                        subtitle: 'Lịch mở cửa / nghỉ',
                        onTap: () => context.push(MerchantRoutes.hours),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _MenuRow(
                        icon: Icons.pause_circle_outline,
                        title: 'Chế độ bận',
                        subtitle: 'Tạm ngưng nhận đơn',
                        onTap: () => context.push(MerchantRoutes.busy),
                      ),
                    ],
                    const SizedBox(height: DealGoSpacing.s20),
                    Text('Trợ giúp và cài đặt', style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MenuRow(
                      icon: Icons.help_outline,
                      title: 'Trung tâm hỗ trợ',
                      subtitle: 'Câu hỏi thường gặp và khiếu nại',
                      onTap: () => context.push(AccountRoutes.help(shellPath)),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    const _LogoutRow(),
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

List<Widget> _partnerOnboardingRows(
  BuildContext context,
  String shellPath,
  UserProfile? profile,
) {
  if (shellPath.startsWith('/driver')) {
    return [_driverOnboardingRow(context, profile)];
  }
  if (shellPath.startsWith('/merchant')) {
    return [_merchantOnboardingRow(context, profile)];
  }
  if (shellPath.startsWith('/customer') && profile != null) {
    return [
      if (profile.needsPartnerOnboarding(AppRole.driver))
        _driverOnboardingRow(context, profile),
      if (profile.needsPartnerOnboarding(AppRole.merchant))
        _merchantOnboardingRow(context, profile),
    ];
  }
  return const [];
}

Widget _driverOnboardingRow(BuildContext context, UserProfile? profile) {
  final cubit = context.watch<DriverKycCubit>();
  final status = cubit.state.seeded
      ? cubit.state.status
      : _statusFromGrant(profile?.grantStatus(AppRole.driver));
  return _MenuRow(
    icon: Icons.badge_outlined,
    title: 'Hồ sơ đối tác tài xế',
    subtitle: _partnerStatusLabel(status),
    trailing: _LinkLabel(_partnerActionLabel(status)),
    onTap: () {
      if (profile != null) {
        cubit.seedFromProfile(profile);
      }
      context.push(DriverKycRoutes.root);
    },
  );
}

Widget _merchantOnboardingRow(BuildContext context, UserProfile? profile) {
  final cubit = context.watch<MerchantKybCubit>();
  final status = cubit.state.seeded
      ? cubit.state.status
      : _statusFromGrant(profile?.grantStatus(AppRole.merchant));
  return _MenuRow(
    icon: Icons.storefront_outlined,
    title: 'Hồ sơ đối tác Shop',
    subtitle: _partnerStatusLabel(status),
    trailing: _LinkLabel(_partnerActionLabel(status)),
    onTap: () {
      if (profile != null) {
        cubit.seedFromProfile(profile);
      }
      context.push(MerchantKybRoutes.root);
    },
  );
}

PartnerApplicationStatus _statusFromGrant(String? grant) {
  return switch (grant) {
    'ACTIVE' => PartnerApplicationStatus.active,
    'PENDING' => PartnerApplicationStatus.pending,
    'REJECTED' => PartnerApplicationStatus.rejected,
    _ => PartnerApplicationStatus.draft,
  };
}

String _partnerStatusLabel(PartnerApplicationStatus status) {
  return switch (status) {
    PartnerApplicationStatus.draft => 'Chưa gửi xét duyệt',
    PartnerApplicationStatus.pending => 'Đang thẩm định',
    PartnerApplicationStatus.rejected => 'Cần bổ sung hồ sơ',
    PartnerApplicationStatus.active => 'Đã kích hoạt',
  };
}

String _partnerActionLabel(PartnerApplicationStatus status) {
  return switch (status) {
    PartnerApplicationStatus.draft => 'Đăng ký',
    PartnerApplicationStatus.pending => 'Theo dõi',
    PartnerApplicationStatus.rejected => 'Bổ sung',
    PartnerApplicationStatus.active => 'Xem',
  };
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.phone, required this.roleLabel});

  final String? phone;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shownPhone = phone;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        gradient: const LinearGradient(
          colors: [DealGoColors.subtlePurple, Color(0xFFEFFAF3)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DealGoColors.card,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: DealGoColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shownPhone != null && shownPhone.isNotEmpty) ...[
                    Text(shownPhone, style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.greenSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s12,
                        vertical: DealGoSpacing.s4,
                      ),
                      child: Text(
                        roleLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.brandGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkLabel extends StatelessWidget {
  const _LinkLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: DealGoColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      onTap: onTap,
      child: Row(
        children: [
          _IconBadge(icon: icon),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DealGoSpacing.s8),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: DealGoSpacing.s4),
            const Icon(Icons.chevron_right, color: DealGoColors.textSecondary),
          ],
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: DealGoColors.subtlePurple,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: DealGoColors.primary, size: 22),
    );
  }
}

class _LogoutRow extends StatefulWidget {
  const _LogoutRow();

  @override
  State<_LogoutRow> createState() => _LogoutRowState();
}

class _LogoutRowState extends State<_LogoutRow> {
  var _signingOut = false;

  Future<void> _logout() async {
    if (_signingOut) {
      return;
    }
    setState(() => _signingOut = true);
    context.read<AddressDraftCubit>().clear();
    final auth = context.read<AuthCubit>();
    await auth.signOut();
    if (!mounted) {
      return;
    }
    context.go(AuthRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      onTap: _signingOut ? null : _logout,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DealGoColors.dangerSurface,
              shape: BoxShape.circle,
            ),
            child: _signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DealGoColors.danger,
                    ),
                  )
                : const Icon(
                    Icons.logout,
                    color: DealGoColors.danger,
                    size: 22,
                  ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Text(
              'Đăng xuất',
              style: textTheme.titleMedium?.copyWith(
                fontSize: 16,
                color: DealGoColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
