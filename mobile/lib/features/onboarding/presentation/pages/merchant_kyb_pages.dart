import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../utils/partner_status_listener.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../places/domain/place.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/partner_documents.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../cubit/merchant_kyb_cubit.dart';
import '../document_image_source.dart';
import '../utils/merchant_kyb_routes.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/partner_kyc_widgets.dart';

Future<void> _loadMerchantKyb(BuildContext context) async {
  final auth = context.read<AuthCubit>().state;
  final cubit = context.read<MerchantKybCubit>();
  if (auth is AuthSignedIn) {
    cubit.seedFromProfile(auth.profile);
  }
  await Future.wait([cubit.refresh(), cubit.loadRequirements()])
      .timeout(const Duration(seconds: 12));
}

bool _isMerchantKybPath(String path) {
  const root = MerchantKybRoutes.root;
  return path == root || path.startsWith('$root/');
}

void _bounceMerchantKybToAccount(GoRouter router) {
  if (_isMerchantKybPath(router.state.uri.path)) {
    router.go('/customer/account');
  }
}

/// Prefer pop so Account → KYB keeps a working Back; bounce away if a pop
/// would leave the gate spinner or any KYB child route on screen.
void _leaveMerchantKyb(BuildContext context) {
  final router = GoRouter.of(context);
  if (!context.canPop()) {
    router.go('/customer/account');
    return;
  }
  context.pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _bounceMerchantKybToAccount(router);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bounceMerchantKybToAccount(router);
    });
  });
}

void _popMerchantKybStepOrEscapeGate(BuildContext context) {
  final router = GoRouter.of(context);
  if (!context.canPop()) {
    context.push(MerchantKybRoutes.intro);
    return;
  }
  context.pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (router.state.uri.path == MerchantKybRoutes.root) {
      router.go('/customer/account');
    }
  });
}

String merchantBusinessTypeLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    MerchantBusinessType.restaurant => l10n.kybTypeRestaurant,
    MerchantBusinessType.cafe => l10n.kybTypeCafe,
    MerchantBusinessType.grocery => l10n.kybTypeGrocery,
    MerchantBusinessType.convenience => l10n.kybTypeConvenience,
    _ => l10n.kybTypeOther,
  };
}

String merchantSubjectLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    MerchantRegistrationSubject.household => l10n.kybSubjectHousehold,
    MerchantRegistrationSubject.company => l10n.kybSubjectCompany,
    _ => l10n.kybSubjectOther,
  };
}

class MerchantKybGatePage extends StatefulWidget {
  const MerchantKybGatePage({super.key});

  @override
  State<MerchantKybGatePage> createState() => _MerchantKybGatePageState();
}

class _MerchantKybGatePageState extends State<MerchantKybGatePage> {
  var _failed = false;
  var _didRedirect = false;
  var _wasCovered = false;
  var _escaping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted || _didRedirect || _escaping) {
      return;
    }
    try {
      await _loadMerchantKyb(context);
    } catch (_) {}
    if (!mounted || _escaping) {
      return;
    }
    final next = MerchantKybRoutes.entryFromCubit(
      context.read<MerchantKybCubit>(),
    );
    if (next == MerchantKybRoutes.root) {
      setState(() => _failed = true);
      return;
    }
    _didRedirect = true;
    context.go(next);
  }

  void _escapeIfRevealed() {
    if (!_didRedirect || !_wasCovered || _failed || _escaping || !mounted) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      return;
    }
    _escaping = true;
    GoRouter.of(context).go('/customer/account');
  }

  void _back() => _leaveMerchantKyb(context);

  @override
  Widget build(BuildContext context) {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (_didRedirect && !isCurrent) {
      _wasCovered = true;
    }
    if (_didRedirect && _wasCovered && isCurrent && !_failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _escapeIfRevealed());
    }
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: _failed
            ? Padding(
                padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _back,
                        icon: const Icon(DealGoIcons.back),
                      ),
                    ),
                    const Spacer(),
                    Text(l10n.errorLoadFailed, textAlign: TextAlign.center),
                    const SizedBox(height: DealGoSpacing.s16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _failed = false;
                          _didRedirect = false;
                          _wasCovered = false;
                          _escaping = false;
                        });
                        _open();
                      },
                      child: Text(l10n.actionRetry),
                    ),
                    const Spacer(),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class MerchantKybIntroPage extends StatefulWidget {
  const MerchantKybIntroPage({super.key});

  @override
  State<MerchantKybIntroPage> createState() => _MerchantKybIntroPageState();
}

class _MerchantKybIntroPageState extends State<MerchantKybIntroPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMerchantKyb(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: l10n.kybIntroTitle,
      roleBadge: l10n.kybRoleBadge,
      onBack: () => _leaveMerchantKyb(context),
      footer: OnboardingContinueBar(
        label: l10n.kybStartCta,
        onPressed: () {
          context.read<MerchantKybCubit>().startDraft();
          context.push(MerchantKybRoutes.steps);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
        children: [
          Row(
            children: [
              Text(
                'DealGo',
                style: textTheme.headlineSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              OnboardingStatusChip(
                label: l10n.partnerModeChip,
                tone: OnboardingBannerTone.neutral,
              ),
            ],
          ),
          Text(
            l10n.kybIntroSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          OnboardingStatusChip(
            label: l10n.kybFlowLabel,
            tone: OnboardingBannerTone.neutral,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(l10n.kybIntroHeadline, style: textTheme.titleLarge),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            l10n.kybIntroBody,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          DealGoCard(
            child: Column(
              children: [
                const Icon(
                  DealGoIcons.store,
                  size: 48,
                  color: DealGoColors.primary,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  l10n.kybIntroHero,
                  style: textTheme.titleMedium?.copyWith(
                    color: DealGoColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text(l10n.kybIntroBenefits, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          const _BenefitGrid(),
          const SizedBox(height: DealGoSpacing.s16),
          BlocBuilder<MerchantKybCubit, MerchantKybState>(
            buildWhen: (a, b) => a.documentsRequired != b.documentsRequired,
            builder: (context, state) => OnboardingInfoBanner(
              key: const Key('kyb-intro-requirements'),
              message: state.documentsRequired
                  ? l10n.kybIntroRequirements
                  : l10n.kybQuickModeBanner,
            ),
          ),
        ],
      ),
    );
  }
}

class MerchantKybStepsPage extends StatelessWidget {
  const MerchantKybStepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<MerchantKybCubit, MerchantKybState>(
      builder: (context, state) {
        final cubit = context.read<MerchantKybCubit>();
        final title = switch (state.step) {
          MerchantKybStep.businessType => l10n.kybStepBusinessType,
          MerchantKybStep.shopInfo => l10n.kybStepShopInfo,
          MerchantKybStep.representative => l10n.kybStepRepresentative,
          MerchantKybStep.documents => l10n.kybStepDocuments,
          MerchantKybStep.review => l10n.kybStepReview,
        };
        final isReview = state.step == MerchantKybStep.review;
        return OnboardingScaffold(
          title: title,
          roleBadge: l10n.kybRoleBadge,
          onBack: () {
            if (state.step == MerchantKybStep.businessType) {
              _popMerchantKybStepOrEscapeGate(context);
              return;
            }
            cubit.previousStep();
          },
          footer: OnboardingContinueBar(
            label: isReview
                ? (state.issues.isEmpty
                      ? l10n.kybSubmitCta
                      : l10n.kybResubmitCta)
                : l10n.partnerContinue,
            enabled:
                !state.submitting &&
                switch (state.step) {
                  MerchantKybStep.shopInfo => state.canContinueShopInfo,
                  MerchantKybStep.representative =>
                    state.canContinueRepresentative,
                  MerchantKybStep.documents => state.canContinueDocuments,
                  MerchantKybStep.review => state.canSubmit,
                  _ => true,
                },
            onPressed: () async {
              if (isReview) {
                await cubit.submit();
                if (!context.mounted) {
                  return;
                }
                if (cubit.state.submitError == null &&
                    cubit.state.status == PartnerApplicationStatus.pending) {
                  context.go(MerchantKybRoutes.status);
                }
                return;
              }
              cubit.nextStep();
            },
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              OnboardingStepHeader(
                flowLabel: l10n.kybStepFlowLabel,
                stepLabel: l10n.partnerStepOf(
                  state.stepNumber,
                  state.totalSteps,
                ),
                currentStep: state.stepNumber,
                totalSteps: state.totalSteps,
                headline: state.step == MerchantKybStep.businessType
                    ? l10n.kybStepBusinessTypeHeadline
                    : title,
                subtitle: switch (state.step) {
                  MerchantKybStep.businessType => l10n.kybSubBusinessType,
                  MerchantKybStep.shopInfo => l10n.kybSubShopInfo,
                  MerchantKybStep.representative => l10n.kybSubRepresentative,
                  MerchantKybStep.documents => l10n.kybSubDocuments,
                  MerchantKybStep.review => l10n.kybSubReview,
                },
              ),
              const SizedBox(height: DealGoSpacing.s20),
              switch (state.step) {
                MerchantKybStep.businessType => _BusinessTypeStep(state: state),
                MerchantKybStep.shopInfo => _ShopInfoStep(state: state),
                MerchantKybStep.representative => _RepStep(state: state),
                MerchantKybStep.documents => _DocumentsStep(state: state),
                MerchantKybStep.review => _MerchantReviewStep(state: state),
              },
              if (state.submitError case final code?) ...[
                const SizedBox(height: DealGoSpacing.s12),
                OnboardingInfoBanner(
                  message: partnerSubmitErrorText(l10n, code),
                  tone: OnboardingBannerTone.warning,
                  icon: DealGoIcons.warning,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class MerchantKybStatusPage extends StatefulWidget {
  const MerchantKybStatusPage({super.key});

  @override
  State<MerchantKybStatusPage> createState() => _MerchantKybStatusPageState();
}

class _MerchantKybStatusPageState extends State<MerchantKybStatusPage>
    with WidgetsBindingObserver, PartnerStatusListener<MerchantKybStatusPage> {
  @override
  String get partnerStatusRole => 'MERCHANT';

  @override
  bool get pendingStatusActive {
    final status = context.read<MerchantKybCubit>().state.status;
    return status != PartnerApplicationStatus.active &&
        status != PartnerApplicationStatus.rejected &&
        status != PartnerApplicationStatus.draft;
  }

  @override
  Future<void> refreshPendingStatus() =>
      context.read<MerchantKybCubit>().refresh();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMerchantKyb(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<MerchantKybCubit, MerchantKybState>(
      builder: (context, state) {
        final isActive = state.status == PartnerApplicationStatus.active;
        final isRejected = state.status == PartnerApplicationStatus.rejected;
        final isDraft = state.status == PartnerApplicationStatus.draft;
        final textTheme = Theme.of(context).textTheme;
        return OnboardingScaffold(
          title: l10n.kybStatusTitle,
          roleBadge: l10n.kybRoleBadge,
          onBack: () => _leaveMerchantKyb(context),
          footer: isRejected
              ? OnboardingContinueBar(
                  label: l10n.partnerStartFix,
                  onPressed: () => context.push(MerchantKybRoutes.rejected),
                )
              : isDraft
              ? OnboardingContinueBar(
                  label: l10n.kybStartCta,
                  onPressed: () {
                    context.read<MerchantKybCubit>().startDraft();
                    context.push(MerchantKybRoutes.steps);
                  },
                )
              : OnboardingContinueBar(
                  label: l10n.kybTrackCta,
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    await context.read<AuthCubit>().refreshProfile();
                    router.go('/merchant');
                  },
                ),
          body: RefreshIndicator(
            onRefresh: () => context.read<MerchantKybCubit>().refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
              children: [
                if (state.loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: DealGoSpacing.s12),
                ],
                DealGoCard(
                  child: Column(
                    children: [
                      Icon(
                        isActive
                            ? DealGoIcons.verified
                            : isRejected
                            ? DealGoIcons.warning
                            : DealGoIcons.document,
                        size: 40,
                        color: DealGoColors.primary,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      Text(
                        isActive
                            ? l10n.kybActiveTitle
                            : isRejected
                            ? l10n.kybRejectedTitle
                            : l10n.kybPendingTitle,
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        isActive ? l10n.kybActiveBody : state.shopName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      OnboardingStatusChip(
                        label: isActive
                            ? l10n.partnerStatusActive
                            : isRejected
                            ? l10n.partnerStatusRejected
                            : l10n.partnerStatusPending,
                        tone: isActive
                            ? OnboardingBannerTone.success
                            : OnboardingBannerTone.warning,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                PartnerTimelineRow(
                  title: l10n.partnerTimelineSubmitted,
                  subtitle: '',
                  done: !isDraft,
                  current: isDraft,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                PartnerTimelineRow(
                  title: state.documentsRequired
                      ? l10n.partnerTimelineReview
                      : l10n.partnerTimelineReviewQuick,
                  subtitle: isActive || isRejected
                      ? l10n.partnerTimelineReviewed
                      : l10n.partnerTimelineReviewing,
                  done: isActive || isRejected,
                  current: !isActive && !isRejected && !isDraft,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                PartnerTimelineRow(
                  title: l10n.kybTimelineActivate,
                  subtitle: l10n.kybTimelineActivateBody,
                  done: isActive,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                OnboardingInfoBanner(
                  message: isActive
                      ? l10n.kybStatusActiveNote
                      : l10n.kybStatusPendingNote,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MerchantKybRejectedPage extends StatefulWidget {
  const MerchantKybRejectedPage({super.key});

  @override
  State<MerchantKybRejectedPage> createState() =>
      _MerchantKybRejectedPageState();
}

class _MerchantKybRejectedPageState extends State<MerchantKybRejectedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMerchantKyb(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<MerchantKybCubit, MerchantKybState>(
      builder: (context, state) {
        final cubit = context.read<MerchantKybCubit>();
        void fix([String? section]) {
          cubit.beginResubmit(section);
          context.push(MerchantKybRoutes.steps);
        }

        return OnboardingScaffold(
          title: l10n.kybRejectedTitle,
          roleBadge: l10n.kybRoleBadge,
          onBack: () => _leaveMerchantKyb(context),
          footer: OnboardingContinueBar(
            label: l10n.partnerStartFix,
            onPressed: fix,
          ),
          body: ListView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            children: [
              if (state.loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: DealGoSpacing.s12),
              ],
              OnboardingInfoBanner(
                message: l10n.kybRejectedBanner,
                tone: OnboardingBannerTone.warning,
                icon: DealGoIcons.warning,
              ),
              const SizedBox(height: DealGoSpacing.s20),
              PartnerReviewIssuesCard(
                reason: state.reason,
                issues: state.issues,
                onFix: fix,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <(IconData, String, String)>[
      (
        DealGoIcons.restaurant,
        l10n.kybBenefitReachTitle,
        l10n.kybBenefitReachBody,
      ),
      (
        DealGoIcons.notifications,
        l10n.kybBenefitOrdersTitle,
        l10n.kybBenefitOrdersBody,
      ),
      (
        DealGoIcons.wallet,
        l10n.kybBenefitRevenueTitle,
        l10n.kybBenefitRevenueBody,
      ),
      (DealGoIcons.shield, l10n.kybBenefitTrustTitle, l10n.kybBenefitTrustBody),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: _BenefitCard(item: items[i])),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: i + 1 < items.length
                    ? _BenefitCard(item: items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (i + 2 < items.length) const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.item});

  final (IconData, String, String) item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.$1, color: DealGoColors.primary),
          const SizedBox(height: DealGoSpacing.s8),
          Text(item.$2, style: textTheme.titleMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: DealGoSpacing.s4),
          Text(item.$3, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BusinessTypeStep extends StatelessWidget {
  const _BusinessTypeStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MerchantKybCubit>();
    final types = <(String, String, IconData, Color, Color)>[
      (
        MerchantBusinessType.restaurant,
        l10n.kybTypeRestaurantBody,
        DealGoIcons.restaurant,
        DealGoColors.subtlePurple,
        DealGoColors.primary,
      ),
      (
        MerchantBusinessType.cafe,
        l10n.kybTypeCafeBody,
        DealGoIcons.coffee,
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      (
        MerchantBusinessType.grocery,
        l10n.kybTypeGroceryBody,
        DealGoIcons.shoppingBag,
        DealGoColors.subtlePurple,
        DealGoColors.primary,
      ),
      (
        MerchantBusinessType.convenience,
        l10n.kybTypeConvenienceBody,
        DealGoIcons.store,
        DealGoColors.subtlePurple,
        DealGoColors.primary,
      ),
      (
        MerchantBusinessType.other,
        l10n.kybTypeOtherBody,
        DealGoIcons.add,
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in types) ...[
          OnboardingSelectCard(
            title: merchantBusinessTypeLabel(l10n, type.$1),
            subtitle: type.$2,
            selected: state.businessType == type.$1,
            icon: type.$3,
            tint: type.$4,
            iconColor: type.$5,
            onTap: () => cubit.selectBusinessType(type.$1),
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        Text(
          l10n.kybSubjectLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DealGoSegmentedControl(
          value: state.registrationSubject,
          onChanged: cubit.selectRegistrationSubject,
          items: [
            for (final subject in MerchantRegistrationSubject.values)
              DealGoSegmentItem(
                id: subject,
                label: merchantSubjectLabel(l10n, subject),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s16),
        OnboardingInfoBanner(message: l10n.kybTypeNote),
      ],
    );
  }
}

class _ShopInfoStep extends StatelessWidget {
  const _ShopInfoStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MerchantKybCubit>();
    return Column(
      children: [
        OnboardingMockField(
          label: l10n.kybShopName,
          value: state.shopName,
          required: true,
          fieldKey: const Key('kyb-shop-name'),
          onChanged: cubit.setShopName,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.kybShopAddress,
          value: state.shopAddress,
          required: true,
          fieldKey: const Key('kyb-shop-address'),
          onChanged: cubit.setShopAddress,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        _ShopPinTile(state: state),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.kybShopType,
          value: merchantBusinessTypeLabel(l10n, state.businessType),
          required: true,
        ),
      ],
    );
  }
}

/// The store must be pinned before KYB can be submitted.
class _ShopPinTile extends StatelessWidget {
  const _ShopPinTile({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final pinned = state.hasShopPin;
    return DealGoCard(
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          key: const Key('kyb-shop-pin'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            DealGoIcons.pin,
            color: pinned ? DealGoColors.primary : DealGoColors.danger,
          ),
          title: Text(
            pinned
                ? '${state.shopLat!.toStringAsFixed(5)}, ${state.shopLng!.toStringAsFixed(5)}'
                : l10n.kybShopPin,
            style: textTheme.bodyMedium,
          ),
          subtitle: Text(
            pinned ? l10n.kybShopPinChange : l10n.kybShopPinRequired,
            style: textTheme.bodySmall,
          ),
          trailing: const Icon(DealGoIcons.chevronRight),
          onTap: () async {
            final cubit = context.read<MerchantKybCubit>();
            final place = await context.push<PlaceOption>(
              MerchantKybRoutes.pin,
            );
            if (place != null) {
              cubit.setShopPin(
                lat: place.lat,
                lng: place.lng,
                label: place.label,
              );
            }
          },
        ),
      ),
    );
  }
}

class _RepStep extends StatelessWidget {
  const _RepStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MerchantKybCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingMockField(
          label: l10n.kybRepName,
          value: state.representativeName,
          required: true,
          fieldKey: const Key('kyb-representative'),
          onChanged: cubit.setRepresentativeName,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingInfoBanner(
          message: l10n.kybRepNote,
          tone: OnboardingBannerTone.neutral,
        ),
        const SizedBox(height: DealGoSpacing.s20),
        PartnerBankFields(
          bankName: state.bankName,
          accountNumber: state.bankAccountNumber,
          holder: state.bankAccountHolder,
          onBankName: cubit.setBankName,
          onAccountNumber: cubit.setBankAccountNumber,
          onHolder: cubit.setBankAccountHolder,
        ),
      ],
    );
  }
}

class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MerchantKybCubit>();
    final source = context.read<DocumentImageSource>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in PartnerDocumentKind.merchantAll) ...[
          PartnerDocumentSlot(
            kind: kind,
            draft: state.documents,
            source: source,
            optional: kind == PartnerDocumentKind.storefront,
            onPicked: (image) => cubit.attachDocument(kind, image),
            onRemove: () => cubit.removeDocument(kind),
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }
}

class _MerchantReviewStep extends StatelessWidget {
  const _MerchantReviewStep({required this.state});

  final MerchantKybState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<MerchantKybCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.kybReviewStatus, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              PartnerReviewRow(
                title: l10n.kybReviewShop,
                subtitle:
                    '${state.shopName} · ${merchantBusinessTypeLabel(l10n, state.businessType)}',
                ok: state.canContinueShopInfo,
              ),
              if (state.documentsRequired) ...[
                PartnerReviewRow(
                  title: l10n.kybReviewRep,
                  subtitle:
                      '${state.representativeName} · ${merchantSubjectLabel(l10n, state.registrationSubject)}',
                  ok: state.representativeName.trim().length >= 2,
                ),
                PartnerReviewRow(
                  title: l10n.kybReviewBank,
                  subtitle: state.bankAccountNumber.isEmpty
                      ? ''
                      : '${state.bankName} · ${partnerMaskAccount(state.bankAccountNumber)}',
                  ok: state.canContinueRepresentative,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        if (state.documentsRequired)
          DealGoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.partnerReviewTitleDocs, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                for (final kind in PartnerDocumentKind.merchantAll)
                  InkWell(
                    onTap: () => cubit.goToStep(MerchantKybStep.documents),
                    child: PartnerReviewRow(
                      title: partnerDocumentLabel(l10n, kind),
                      subtitle: kind == PartnerDocumentKind.storefront
                          ? l10n.partnerDocOptional
                          : '',
                      ok:
                          state.documents.has(kind) ||
                          (kind == PartnerDocumentKind.storefront &&
                              !state.documents.isFlagged(kind)),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingInfoBanner(
          message: state.documentsRequired
              ? l10n.kybReviewNote
              : l10n.kybQuickModeBanner,
        ),
      ],
    );
  }
}
