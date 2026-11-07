import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/appearance/app_appearance.dart';
import '../../../core/appearance/appearance_sheet.dart';
import '../../inbox/presentation/inbox_unread.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/design_system/components/dealgo_dialog.dart';
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
import '../../driver/presentation/utils/driver_routes.dart';
import '../../merchant/presentation/utils/merchant_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../legal/legal_document_page.dart';
import '../../legal/legal_documents.dart';
import '../../support/presentation/support_links.dart';
import 'account_routes.dart';
import 'driver_account_vehicle.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../core/design_system/components/dealgo_network_image.dart';

String accountShellRoleLabel(AppLocalizations l10n, String shellPath) {
  if (shellPath.startsWith('/merchant')) {
    return l10n.accountRoleShop;
  }
  if (shellPath.startsWith('/driver')) {
    return l10n.roleDriver;
  }
  return l10n.roleCustomer;
}

class AccountPage extends StatelessWidget {
  const AccountPage({required this.shellPath, super.key});

  final String shellPath;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final signedIn = auth is AuthSignedIn ? auth : null;
    final headerTitle = accountProfileTitle(
      signedIn?.profile.displayName,
      signedIn?.profile.phone,
    );
    final canSwitchRole =
        signedIn != null && signedIn.profile.activeAppRoles.length > 1;
    final l10n = AppLocalizations.of(context);
    final roleLabel = accountShellRoleLabel(l10n, shellPath);
    final textTheme = Theme.of(context).textTheme;
    final appearance = context.watch<AppAppearance>();
    final isDriver = shellPath.startsWith('/driver');
    final isMerchant = shellPath.startsWith('/merchant');
    final isCustomer = !isDriver && !isMerchant;

    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(
              title: AppLocalizations.of(context).accountTitle,
              showBack: false,
              actions: IconButton(
                tooltip: AppLocalizations.of(context).accountNotifications,
                onPressed: () =>
                    context.push(AccountRoutes.notifications(shellPath)),
                icon: InboxUnreadBadge(
                  child: Icon(
                    DealGoIcons.notifications,
                    color: DealGoColors.text,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: DealGoColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: dealGoScrollPadding(
                  context,
                  const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s16,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(
                      phone: headerTitle,
                      roleLabel: roleLabel,
                      avatarUrl: resolveMediaUrl(signedIn?.profile.avatarUrl),
                      canSwitchRole: canSwitchRole,
                      onTap: signedIn == null
                          ? null
                          : () => context.push(
                              AccountRoutes.editProfile(shellPath),
                            ),
                      onSwitchRole: canSwitchRole
                          ? () => context.push(AuthRoutes.roles)
                          : null,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    if (isDriver) ...[
                      const DriverAccountVehicle(),
                      const SizedBox(height: DealGoSpacing.s12),
                      _MenuGroup(
                        children: [
                          _driverOnboardingRow(context, signedIn?.profile),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ] else if (isMerchant) ...[
                      _MenuGroup(
                        children: [
                          _merchantOnboardingRow(context, signedIn?.profile),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ] else if (signedIn != null) ...[
                      _CustomerPartnerHubCard(profile: signedIn.profile),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                    if (isCustomer) ...[
                      _MenuGroup(
                        children: [
                          _MenuRow(
                            icon: DealGoIcons.gift,
                            iconBackground: DealGoColors.amberSurface,
                            iconColor: DealGoColors.amber,
                            title: l10n.accountVouchers,
                            subtitle: l10n.accountVouchersBody,
                            trailing: _LinkLabel(l10n.actionSeeAll),
                            showChevron: false,
                            onTap: () =>
                                context.push(AccountRoutes.vouchers(shellPath)),
                          ),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s20),
                    ],
                    Text(
                      l10n.accountSectionServices,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    if (isCustomer) ...[
                      _MenuGroup(
                        children: [
                          _MenuRow(
                            icon: DealGoIcons.list,
                            title: l10n.accountActivity,
                            subtitle: l10n.accountActivityBody,
                            onTap: () => context.go(_activityPath(shellPath)),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.pin,
                            title: l10n.accountAddresses,
                            subtitle: l10n.accountAddressesBody,
                            onTap: () => context.push(
                              AccountRoutes.addresses(shellPath),
                            ),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.card,
                            title: l10n.accountPayments,
                            subtitle: l10n.accountPaymentsBody,
                            onTap: () => context.push(
                              AccountRoutes.payments(shellPath),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isDriver) ...[
                      _MenuGroup(
                        children: [
                          _MenuRow(
                            icon: DealGoIcons.cash,
                            iconBackground: DealGoColors.greenSurface,
                            iconColor: DealGoColors.brandGreen,
                            title: l10n.driverCreditTitle,
                            subtitle: l10n.driverCreditCardBody,
                            onTap: () => context.push(DriverRoutes.credit),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.tune,
                            iconBackground: DealGoColors.subtlePurple,
                            iconColor: DealGoColors.primary,
                            title: l10n.driverServicesTitle,
                            subtitle: l10n.driverServicesHeadline,
                            onTap: () => context.push(DriverRoutes.services),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.list,
                            title: l10n.accountActivity,
                            subtitle: l10n.accountActivityBody,
                            onTap: () => context.go(_activityPath(shellPath)),
                          ),
                        ],
                      ),
                    ] else if (isMerchant) ...[
                      _MenuGroup(
                        children: [
                          _MenuRow(
                            icon: DealGoIcons.filter,
                            title: l10n.accountAcceptMode,
                            subtitle: l10n.accountAcceptModeBody,
                            onTap: () =>
                                context.push(MerchantRoutes.acceptSettings),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.clock,
                            title: l10n.accountHours,
                            subtitle: l10n.accountHoursBody,
                            onTap: () => context.push(MerchantRoutes.hours),
                          ),
                          _MenuRow(
                            key: const Key('account-store-profile'),
                            icon: DealGoIcons.restaurant,
                            title: l10n.merchantProfileTitle,
                            subtitle: l10n.accountStoreProfileBody,
                            onTap: () => context.push(MerchantRoutes.profile),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.pin,
                            title: l10n.merchantLocationTitle,
                            subtitle: l10n.accountStoreLocationBody,
                            onTap: () => context.push(MerchantRoutes.location),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.pause,
                            title: l10n.accountBusy,
                            subtitle: l10n.accountBusyBody,
                            onTap: () => context.push(MerchantRoutes.busy),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.voucher,
                            iconBackground: DealGoColors.greenSurface,
                            iconColor: DealGoColors.brandGreen,
                            title: l10n.merchantOffersTitle,
                            subtitle: l10n.accountVouchersBody,
                            onTap: () => context.push(MerchantRoutes.offers),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.star,
                            iconBackground: DealGoColors.amberSurface,
                            iconColor: DealGoColors.amber,
                            title: l10n.merchantReviewsTitle,
                            subtitle: l10n.merchantReviewsEmpty,
                            onTap: () => context.push(MerchantRoutes.reviews),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.layers,
                            title: l10n.merchantCategoriesTitle,
                            subtitle: l10n.merchantCategoriesHeadline,
                            onTap: () =>
                                context.push(MerchantRoutes.categories),
                          ),
                          _MenuRow(
                            icon: DealGoIcons.history,
                            title: l10n.merchantHistoryTitle,
                            subtitle: l10n.accountActivityBody,
                            onTap: () => context.push(MerchantRoutes.history),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: DealGoSpacing.s20),
                    Text(
                      l10n.accountSectionDisplay,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MenuGroup(
                      children: [
                        _MenuRow(
                          key: const Key('account-language'),
                          icon: DealGoIcons.languages,
                          iconBackground: DealGoColors.subtlePurple,
                          iconColor: DealGoColors.primary,
                          title: l10n.accountLanguage,
                          subtitle: localeLabel(
                            appearance.locale,
                          ),
                          trailing: _LivelyTrailingBadge(
                            icon: Icon(
                              appearance.locale.languageCode == 'vi'
                                  ? DealGoIcons.earth
                                  : DealGoIcons.languages,
                              size: 14,
                              color: appearance.locale.languageCode == 'vi'
                                  ? DealGoColors.brandGreen
                                  : DealGoColors.primary,
                            ),
                            label: appearance.locale.languageCode.toUpperCase(),
                          ),
                          onTap: () => showLanguageSheet(context),
                        ),
                        _MenuRow(
                          key: const Key('account-theme'),
                          icon: switch (appearance.themeChoice) {
                            AppThemeChoice.system => DealGoIcons.devices,
                            AppThemeChoice.light => DealGoIcons.sun,
                            AppThemeChoice.dark => DealGoIcons.moon,
                          },
                          iconBackground:
                              appearance.themeChoice == AppThemeChoice.light
                                  ? DealGoColors.amberSurface
                                  : DealGoColors.subtlePurple,
                          iconColor:
                              appearance.themeChoice == AppThemeChoice.light
                                  ? DealGoColors.amber
                                  : DealGoColors.primary,
                          title: l10n.accountTheme,
                          subtitle: themeChoiceLabel(
                            l10n,
                            appearance.themeChoice,
                          ),
                          trailing: _LivelyTrailingBadge(
                            icon: Icon(
                              switch (appearance.themeChoice) {
                                AppThemeChoice.system => DealGoIcons.devices,
                                AppThemeChoice.light => DealGoIcons.sun,
                                AppThemeChoice.dark => DealGoIcons.moon,
                              },
                              size: 15,
                              color:
                                  appearance.themeChoice == AppThemeChoice.light
                                      ? DealGoColors.amber
                                      : DealGoColors.primary,
                            ),
                          ),
                          onTap: () => showThemeSheet(context),
                        ),
                        if (signedIn != null)
                          _MenuRow(
                            key: const ValueKey('account-notif-row'),
                            icon: DealGoIcons.notifications,
                            title: l10n.accountNotifPrefs,
                            subtitle: l10n.accountNotifPrefsBody,
                            onTap: () => context.push(
                              AccountRoutes.notificationPrefs(shellPath),
                            ),
                          ),
                      ],
                    ),
                    if (signedIn != null) ...[
                      const SizedBox(height: DealGoSpacing.s20),
                      Text(
                        l10n.securityAccountSection,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _MenuGroup(
                        children: [
                          _MenuRow(
                            key: const ValueKey('account-security-row'),
                            icon: DealGoIcons.shield,
                            title: l10n.accountSecurity,
                            subtitle: l10n.accountSecurityBody,
                            onTap: () =>
                                context.push(AccountRoutes.security(shellPath)),
                          ),
                          _MenuRow(
                            key: const ValueKey('account-delete-row'),
                            icon: DealGoIcons.deleteAccount,
                            title: l10n.accountDeleteRow,
                            subtitle: l10n.accountDeleteRowBody,
                            onTap: () => context.push(
                              AccountRoutes.deleteAccount(shellPath),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: DealGoSpacing.s20),
                    Text(
                      l10n.accountSectionHelp,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MenuGroup(
                      children: [
                        _MenuRow(
                          icon: DealGoIcons.help,
                          title: l10n.accountSupport,
                          subtitle: l10n.accountSupportBody,
                          onTap: () async {
                            final router = GoRouter.of(context);
                            if (!await openHelpCenterWeb(context)) {
                              router.push(AccountRoutes.help(shellPath));
                            }
                          },
                        ),
                        _MenuRow(
                          key: const ValueKey('account-support-tickets-row'),
                          icon: DealGoIcons.headset,
                          title: l10n.helpMyTickets,
                          subtitle: l10n.accountSupportTicketsBody,
                          onTap: () => context.push(
                            AccountRoutes.supportTickets(shellPath),
                          ),
                        ),
                        _MenuRow(
                          key: const ValueKey('account-terms-row'),
                          icon: DealGoIcons.document,
                          title: l10n.legalTermsTitle,
                          subtitle: l10n.legalTermsBody,
                          onTap: () =>
                              LegalDocumentPage.open(context, LegalSlug.terms),
                        ),
                        _MenuRow(
                          key: const ValueKey('account-regulations-row'),
                          icon: DealGoIcons.document,
                          title: l10n.legalRegulationsTitle,
                          subtitle: l10n.legalRegulationsBody,
                          onTap: () => LegalDocumentPage.open(
                            context,
                            LegalSlug.regulations,
                          ),
                        ),
                        _MenuRow(
                          key: const ValueKey('account-privacy-row'),
                          icon: DealGoIcons.lock,
                          title: l10n.legalPrivacyTitle,
                          subtitle: l10n.legalPrivacyBody,
                          onTap: () => LegalDocumentPage.open(
                            context,
                            LegalSlug.privacy,
                          ),
                        ),
                        const _LogoutRow(),
                      ],
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

class _CustomerPartnerHubCard extends StatelessWidget {
  const _CustomerPartnerHubCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DealGoCard(
      padding: EdgeInsets.zero,
      borderColor: DealGoColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s16,
              vertical: DealGoSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DealGoRadius.card),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DealGoColors.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    DealGoIcons.stars,
                    color: DealGoColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.accountPartnerHubTitle,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.accountPartnerHubSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: DealGoColors.divider),
          _driverOnboardingRow(context, profile),
          Divider(height: 1, indent: 68, color: DealGoColors.divider),
          _merchantOnboardingRow(context, profile),
        ],
      ),
    );
  }
}

DriverKycCubit? _maybeDriverKycCubit(BuildContext context) {
  try {
    return context.watch<DriverKycCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}

MerchantKybCubit? _maybeMerchantKybCubit(BuildContext context) {
  try {
    return context.watch<MerchantKybCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}

Widget _driverOnboardingRow(BuildContext context, UserProfile? profile) {
  final cubit = _maybeDriverKycCubit(context);
  final l10n = AppLocalizations.of(context);
  final status = (cubit != null && cubit.state.seeded)
      ? cubit.state.status
      : _statusFromGrant(profile?.grantStatus(AppRole.driver));
  return _MenuRow(
    icon: DealGoIcons.helmet,
    iconBackground: DealGoColors.amberSurface,
    iconColor: DealGoColors.amber,
    title: l10n.accountDriverPartner,
    subtitle: _partnerStatusLabel(l10n, status),
    trailing: _LinkLabel(_partnerActionLabel(l10n, status)),
    onTap: () {
      if (cubit != null) {
        if (profile != null) {
          cubit.seedFromProfile(profile);
        }
        // Skip the gate spinner — open the screen matching known grant status.
        context.push(DriverKycRoutes.entryFromCubit(cubit));
      } else {
        context.push(DriverKycRoutes.root);
      }
    },
  );
}

Widget _merchantOnboardingRow(BuildContext context, UserProfile? profile) {
  final cubit = _maybeMerchantKybCubit(context);
  final l10n = AppLocalizations.of(context);
  final status = (cubit != null && cubit.state.seeded)
      ? cubit.state.status
      : _statusFromGrant(profile?.grantStatus(AppRole.merchant));
  return _MenuRow(
    icon: DealGoIcons.store,
    iconBackground: DealGoColors.greenSurface,
    iconColor: DealGoColors.brandGreen,
    title: l10n.accountShopPartner,
    subtitle: _partnerStatusLabel(l10n, status),
    trailing: _LinkLabel(_partnerActionLabel(l10n, status)),
    onTap: () {
      if (cubit != null) {
        if (profile != null) {
          cubit.seedFromProfile(profile);
        }
        context.push(MerchantKybRoutes.entryFromCubit(cubit));
      } else {
        context.push(MerchantKybRoutes.root);
      }
    },
  );
}

String _activityPath(String shellPath) {
  if (shellPath.startsWith('/driver')) {
    return '/driver/jobs';
  }
  if (shellPath.startsWith('/merchant')) {
    return '/merchant/orders';
  }
  return '/customer/trips';
}

PartnerApplicationStatus _statusFromGrant(String? grant) {
  return switch (grant) {
    'ACTIVE' => PartnerApplicationStatus.active,
    'PENDING' => PartnerApplicationStatus.pending,
    'REJECTED' => PartnerApplicationStatus.rejected,
    _ => PartnerApplicationStatus.draft,
  };
}

String _partnerStatusLabel(
  AppLocalizations l10n,
  PartnerApplicationStatus status,
) {
  return switch (status) {
    PartnerApplicationStatus.draft => l10n.partnerStatusDraft,
    PartnerApplicationStatus.pending => l10n.partnerStatusPending,
    PartnerApplicationStatus.rejected => l10n.partnerStatusRejected,
    PartnerApplicationStatus.active => l10n.partnerStatusActive,
  };
}

String _partnerActionLabel(
  AppLocalizations l10n,
  PartnerApplicationStatus status,
) {
  return switch (status) {
    PartnerApplicationStatus.draft => l10n.partnerActionRegister,
    PartnerApplicationStatus.pending => l10n.partnerActionTrack,
    PartnerApplicationStatus.rejected => l10n.partnerActionUpdate,
    PartnerApplicationStatus.active => l10n.partnerActionView,
  };
}

/// Profile header line: the user's name; the phone only when no name is set.
String? accountProfileTitle(String? displayName, String? phone) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) {
    return name;
  }
  final shown = phone?.trim() ?? '';
  return shown.isEmpty ? null : shown;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.phone,
    required this.roleLabel,
    this.avatarUrl,
    this.onTap,
    this.canSwitchRole = false,
    this.onSwitchRole,
  });

  final String? phone;
  final String? avatarUrl;
  final String roleLabel;
  final VoidCallback? onTap;
  final bool canSwitchRole;
  final VoidCallback? onSwitchRole;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shownPhone = phone;
    return DealGoCard(
      padding: EdgeInsets.zero,
      color: DealGoColors.subtlePurple,
      borderColor: DealGoColors.border,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(DealGoRadius.card),
                bottom: Radius.circular(canSwitchRole ? 0 : DealGoRadius.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: DealGoColors.card,
                        shape: BoxShape.circle,
                      ),
                      child: avatarUrl == null
                          ? const Icon(
                              DealGoIcons.user,
                              color: DealGoColors.primary,
                              size: 32,
                            )
                          : DealGoNetworkImage(
                              avatarUrl!,
                              key: const Key('account-avatar'),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              fallback: const Icon(
                                DealGoIcons.user,
                                color: DealGoColors.primary,
                                size: 32,
                              ),
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
                              borderRadius: BorderRadius.circular(
                                DealGoRadius.pill,
                              ),
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
                    if (onTap != null)
                      const Icon(
                        DealGoIcons.edit,
                        color: DealGoColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (canSwitchRole) ...[
            Divider(
              height: 1,
              color: DealGoColors.border.withValues(alpha: 0.6),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSwitchRole,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(DealGoRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s16,
                    vertical: DealGoSpacing.s12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        DealGoIcons.swapHoriz,
                        color: DealGoColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      Text(
                        AppLocalizations.of(context).accountSwitchRole,
                        style: textTheme.labelLarge?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        DealGoIcons.chevronRight,
                        color: DealGoColors.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return DealGoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 68, color: DealGoColors.divider),
            children[i],
          ],
        ],
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

class _LivelyTrailingBadge extends StatelessWidget {
  const _LivelyTrailingBadge({required this.icon, this.label});

  final Widget icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoSpacing.s8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (label != null) ...[
            const SizedBox(width: DealGoSpacing.s4),
            Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DealGoColors.text,
                    fontSize: 12,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.iconBackground,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? iconBackground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.card,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              _IconBadge(
                icon: icon,
                background: iconBackground,
                color: iconColor,
              ),
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
                Icon(
                  DealGoIcons.chevronRight,
                  color: DealGoColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.background, this.color});

  final IconData icon;
  final Color? background;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? DealGoColors.subtlePurple,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color ?? DealGoColors.primary, size: 22),
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDealGoConfirmDialog(
      context: context,
      title: l10n.accountSignOutConfirmTitle,
      body: l10n.accountSignOutConfirmBody,
      confirmLabel: l10n.accountSignOut,
      cancelLabel: l10n.accountSignOutCancel,
      confirmTone: DealGoDialogPrimaryTone.danger,
      confirmKey: const Key('account-signout-confirm'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _signingOut = true);
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
    return Material(
      color: DealGoColors.card,
      child: InkWell(
        key: const Key('account-signout'),
        onTap: _signingOut ? null : _logout,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
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
                        DealGoIcons.logout,
                        color: DealGoColors.danger,
                        size: 22,
                      ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).accountSignOut,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    color: DealGoColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
