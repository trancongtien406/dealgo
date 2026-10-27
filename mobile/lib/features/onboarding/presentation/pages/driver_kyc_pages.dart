import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../utils/partner_status_listener.dart';
import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../pricing/domain/pricing.dart';
import '../../domain/entities/partner_documents.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../cubit/driver_kyc_cubit.dart';
import '../document_image_source.dart';
import '../utils/driver_kyc_routes.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/partner_kyc_widgets.dart';

/// Seeds from the profile grant, then loads the server application.
Future<void> _loadDriverKyc(BuildContext context) async {
  final auth = context.read<AuthCubit>().state;
  final cubit = context.read<DriverKycCubit>();
  if (auth is AuthSignedIn) {
    cubit.seedFromProfile(auth.profile);
  }
  await Future.wait([cubit.refresh(), cubit.loadRequirements()])
      .timeout(const Duration(seconds: 12));
}

bool _isDriverKycPath(String path) {
  const root = DriverKycRoutes.root;
  return path == root || path.startsWith('$root/');
}

void _bounceDriverKycToAccount(GoRouter router) {
  if (_isDriverKycPath(router.state.uri.path)) {
    router.go('/customer/account');
  }
}

/// Prefer pop so Account → KYC keeps a working Back; bounce away if a pop
/// would leave the gate spinner or any KYC child route on screen.
void _leaveDriverKyc(BuildContext context) {
  final router = GoRouter.of(context);
  if (!context.canPop()) {
    router.go('/customer/account');
    return;
  }
  context.pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _bounceDriverKycToAccount(router);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bounceDriverKycToAccount(router);
    });
  });
}

void _popDriverKycStepOrEscapeGate(BuildContext context) {
  final router = GoRouter.of(context);
  if (!context.canPop()) {
    context.push(DriverKycRoutes.intro);
    return;
  }
  context.pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (router.state.uri.path == DriverKycRoutes.root) {
      router.go('/customer/account');
    }
  });
}

class DriverKycGatePage extends StatefulWidget {
  const DriverKycGatePage({super.key});

  @override
  State<DriverKycGatePage> createState() => _DriverKycGatePageState();
}

class _DriverKycGatePageState extends State<DriverKycGatePage> {
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
      await _loadDriverKyc(context);
    } catch (_) {
      // Fall through with seeded/draft status so the user is never stuck.
    }
    if (!mounted || _escaping) {
      return;
    }
    final next = DriverKycRoutes.entryFromCubit(context.read<DriverKycCubit>());
    if (next == DriverKycRoutes.root) {
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

  void _back() => _leaveDriverKyc(context);

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

class DriverKycIntroPage extends StatefulWidget {
  const DriverKycIntroPage({super.key});

  @override
  State<DriverKycIntroPage> createState() => _DriverKycIntroPageState();
}

class _DriverKycIntroPageState extends State<DriverKycIntroPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDriverKyc(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: l10n.kycIntroTitle,
      roleBadge: l10n.kycRoleBadge,
      onBack: () => _leaveDriverKyc(context),
      footer: Row(
        children: [
          Expanded(
            child: DealGoSecondaryButton(
              label: l10n.kycExistingCta,
              onPressed: () async {
                final cubit = context.read<DriverKycCubit>();
                try {
                  await cubit.refresh().timeout(const Duration(seconds: 12));
                } catch (_) {}
                if (context.mounted) {
                  context.push(DriverKycRoutes.status);
                }
              },
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: OnboardingContinueBar(
              label: l10n.kycStartCta,
              onPressed: () {
                context.read<DriverKycCubit>().startDraft();
                context.push(DriverKycRoutes.steps);
              },
            ),
          ),
        ],
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
            l10n.kycIntroSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoCard(
            child: Column(
              children: [
                const Icon(
                  DealGoIcons.motorbike,
                  size: 48,
                  color: DealGoColors.primary,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  l10n.kycIntroHero,
                  style: textTheme.titleMedium?.copyWith(
                    color: DealGoColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text(l10n.kycIntroHeadline, style: textTheme.titleLarge),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            l10n.kycIntroBody,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          _IntroFeature(
            icon: DealGoIcons.car,
            title: l10n.kycIntroRideTitle,
            subtitle: l10n.kycIntroRideBody,
            badge: 'Ride',
          ),
          const SizedBox(height: DealGoSpacing.s12),
          _IntroFeature(
            icon: DealGoIcons.delivery,
            title: l10n.kycIntroFoodTitle,
            subtitle: l10n.kycIntroFoodBody,
            badge: 'Food',
            green: true,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          _IntroFeature(
            icon: DealGoIcons.wallet,
            title: l10n.kycIntroEarnTitle,
            subtitle: l10n.kycIntroEarnBody,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          BlocBuilder<DriverKycCubit, DriverKycState>(
            buildWhen: (a, b) => a.documentsRequired != b.documentsRequired,
            builder: (context, state) => OnboardingInfoBanner(
              key: const Key('kyc-intro-requirements'),
              message: state.documentsRequired
                  ? l10n.kycIntroRequirements
                  : l10n.kycQuickModeBanner,
              icon: state.documentsRequired
                  ? DealGoIcons.shield
                  : DealGoIcons.bolt,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverKycStepsPage extends StatelessWidget {
  const DriverKycStepsPage({super.key});

  static String stepTitle(AppLocalizations l10n, DriverKycStep step) {
    return switch (step) {
      DriverKycStep.services => l10n.kycStepServices,
      DriverKycStep.personal => l10n.kycStepPersonal,
      DriverKycStep.identity => l10n.kycStepIdentity,
      DriverKycStep.ocrConfirm => l10n.kycStepConfirm,
      DriverKycStep.selfie => l10n.kycStepSelfie,
      DriverKycStep.license => l10n.kycStepLicense,
      DriverKycStep.vehicle => l10n.kycStepVehicle,
      DriverKycStep.bank => l10n.kycStepBank,
      DriverKycStep.review => l10n.kycStepReview,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DriverKycCubit, DriverKycState>(
      builder: (context, state) {
        final cubit = context.read<DriverKycCubit>();
        final title = stepTitle(l10n, state.step);
        final isReview = state.step == DriverKycStep.review;
        return OnboardingScaffold(
          title: title,
          roleBadge: l10n.kycRoleBadge,
          onBack: () {
            if (state.step == DriverKycStep.services) {
              _popDriverKycStepOrEscapeGate(context);
              return;
            }
            cubit.previousStep();
          },
          footer: OnboardingContinueBar(
            label: isReview
                ? (state.issues.isEmpty
                      ? l10n.kycSubmitCta
                      : l10n.kycResubmitCta)
                : l10n.partnerContinue,
            enabled:
                !state.submitting &&
                switch (state.step) {
                  DriverKycStep.services => state.canContinueServices,
                  DriverKycStep.personal => state.canContinuePersonal,
                  DriverKycStep.identity => state.canContinueIdentity,
                  DriverKycStep.ocrConfirm => state.canContinueIdNumber,
                  DriverKycStep.selfie => state.canContinueSelfie,
                  DriverKycStep.license => state.canContinueLicense,
                  DriverKycStep.vehicle => state.canContinueVehicleStep,
                  DriverKycStep.bank => state.canContinueBank,
                  DriverKycStep.review => state.canSubmit,
                },
            onPressed: () async {
              if (isReview) {
                await cubit.submit();
                if (!context.mounted) {
                  return;
                }
                if (cubit.state.submitError == null &&
                    cubit.state.status == PartnerApplicationStatus.pending) {
                  context.go(DriverKycRoutes.status);
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
                flowLabel: l10n.kycFlowLabel,
                stepLabel: l10n.partnerStepOf(
                  state.stepNumber,
                  state.totalSteps,
                ),
                currentStep: state.stepNumber,
                totalSteps: state.totalSteps,
                headline: title,
                subtitle: switch (state.step) {
                  DriverKycStep.services => l10n.kycSubServices,
                  DriverKycStep.personal => l10n.kycSubPersonal,
                  DriverKycStep.identity => l10n.kycSubIdentity,
                  DriverKycStep.ocrConfirm => l10n.kycSubConfirm,
                  DriverKycStep.selfie => l10n.kycSubSelfie,
                  DriverKycStep.license => l10n.kycSubLicense,
                  DriverKycStep.vehicle => l10n.kycSubVehicle,
                  DriverKycStep.bank => l10n.kycSubBank,
                  DriverKycStep.review => l10n.kycSubReview,
                },
              ),
              const SizedBox(height: DealGoSpacing.s20),
              switch (state.step) {
                DriverKycStep.services => _ServicesStep(state: state),
                DriverKycStep.personal => _PersonalStep(state: state),
                DriverKycStep.identity => _DocSlots(
                  state: state,
                  kinds: const [
                    PartnerDocumentKind.idFront,
                    PartnerDocumentKind.idBack,
                  ],
                ),
                DriverKycStep.ocrConfirm => _ConfirmStep(state: state),
                DriverKycStep.selfie => _DocSlots(
                  state: state,
                  kinds: const [PartnerDocumentKind.selfie],
                  frontCamera: true,
                ),
                DriverKycStep.license => _LicenseStep(state: state),
                DriverKycStep.vehicle => _VehicleStep(state: state),
                DriverKycStep.bank => _BankStep(state: state),
                DriverKycStep.review => _ReviewStep(state: state),
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

class DriverKycStatusPage extends StatefulWidget {
  const DriverKycStatusPage({super.key});

  @override
  State<DriverKycStatusPage> createState() => _DriverKycStatusPageState();
}

class _DriverKycStatusPageState extends State<DriverKycStatusPage>
    with WidgetsBindingObserver, PartnerStatusListener<DriverKycStatusPage> {
  @override
  String get partnerStatusRole => 'DRIVER';

  @override
  bool get pendingStatusActive {
    final status = context.read<DriverKycCubit>().state.status;
    return status != PartnerApplicationStatus.active &&
        status != PartnerApplicationStatus.rejected &&
        status != PartnerApplicationStatus.draft;
  }

  @override
  Future<void> refreshPendingStatus() =>
      context.read<DriverKycCubit>().refresh();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDriverKyc(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DriverKycCubit, DriverKycState>(
      builder: (context, state) {
        final isActive = state.status == PartnerApplicationStatus.active;
        final isRejected = state.status == PartnerApplicationStatus.rejected;
        final isDraft = state.status == PartnerApplicationStatus.draft;
        final textTheme = Theme.of(context).textTheme;
        return OnboardingScaffold(
          title: state.documentsRequired
              ? l10n.kycStatusTitle
              : l10n.kycStatusTitleQuick,
          roleBadge: l10n.kycRoleBadge,
          onBack: () => _leaveDriverKyc(context),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isRejected)
                OnboardingContinueBar(
                  label: l10n.partnerStartFix,
                  onPressed: () => context.push(DriverKycRoutes.rejected),
                )
              else if (isDraft)
                OnboardingContinueBar(
                  label: l10n.kycStartCta,
                  onPressed: () {
                    context.read<DriverKycCubit>().startDraft();
                    context.push(DriverKycRoutes.steps);
                  },
                )
              else
                OnboardingContinueBar(
                  label: l10n.kycTrackCta,
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    await context.read<AuthCubit>().refreshProfile();
                    router.go('/driver');
                  },
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<DriverKycCubit>().refresh(),
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
                            : DealGoIcons.clock,
                        size: 40,
                        color: DealGoColors.primary,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      Text(
                        isActive
                            ? l10n.kycActiveTitle
                            : isRejected
                            ? l10n.kycRejectedTitle
                            : l10n.kycPendingTitle,
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        isActive
                            ? l10n.kycActiveBody
                            : l10n.kycPendingBody(state.fullName),
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
                  title: l10n.kycTimelineActivate,
                  subtitle: l10n.kycTimelineActivateBody,
                  done: isActive,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                OnboardingInfoBanner(
                  message: isActive
                      ? l10n.kycStatusActiveNote
                      : l10n.kycStatusPendingNote,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DriverKycRejectedPage extends StatefulWidget {
  const DriverKycRejectedPage({super.key});

  @override
  State<DriverKycRejectedPage> createState() => _DriverKycRejectedPageState();
}

class _DriverKycRejectedPageState extends State<DriverKycRejectedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDriverKyc(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DriverKycCubit, DriverKycState>(
      builder: (context, state) {
        final cubit = context.read<DriverKycCubit>();
        void fix([String? section]) {
          cubit.beginResubmit(section);
          context.push(DriverKycRoutes.steps);
        }

        return OnboardingScaffold(
          title: l10n.kycRejectedTitle,
          roleBadge: l10n.kycRoleBadge,
          onBack: () => _leaveDriverKyc(context),
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
                message: l10n.kycRejectedBanner,
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

class _IntroFeature extends StatelessWidget {
  const _IntroFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.green = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Row(
        children: [
          Icon(
            icon,
            color: green ? DealGoColors.brandGreen : DealGoColors.primary,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (badge != null)
            OnboardingStatusChip(
              label: badge!,
              tone: green
                  ? OnboardingBannerTone.success
                  : OnboardingBannerTone.neutral,
            ),
        ],
      ),
    );
  }
}

class _DocSlots extends StatelessWidget {
  const _DocSlots({
    required this.state,
    required this.kinds,
    this.frontCamera = false,
  });

  final DriverKycState state;
  final List<String> kinds;
  final bool frontCamera;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DriverKycCubit>();
    final source = context.read<DocumentImageSource>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in kinds) ...[
          PartnerDocumentSlot(
            kind: kind,
            draft: state.documents,
            source: source,
            frontCamera: frontCamera,
            onPicked: (image) => cubit.attachDocument(kind, image),
            onRemove: () => cubit.removeDocument(kind),
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }
}

class _ServicesStep extends StatelessWidget {
  const _ServicesStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverKycCubit>();
    return Column(
      children: [
        OnboardingSelectCard(
          title: l10n.kycIntroRideTitle,
          subtitle: l10n.kycServiceRideBody,
          selected: state.rideService,
          multiSelect: true,
          icon: DealGoIcons.car,
          tint: DealGoColors.subtlePurple,
          iconColor: DealGoColors.primary,
          onTap: cubit.toggleRide,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingSelectCard(
          title: l10n.kycIntroFoodTitle,
          subtitle: l10n.kycServiceFoodBody,
          selected: state.foodService,
          multiSelect: true,
          icon: DealGoIcons.shoppingBag,
          tint: DealGoColors.greenSurface,
          iconColor: DealGoColors.brandGreen,
          onTap: cubit.toggleFood,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        OnboardingInfoBanner(message: l10n.kycServicesNote),
      ],
    );
  }
}

class _PersonalStep extends StatelessWidget {
  const _PersonalStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverKycCubit>();
    return Column(
      children: [
        OnboardingMockField(
          label: l10n.kycFullName,
          value: state.fullName,
          required: true,
          fieldKey: const Key('kyc-full-name'),
          hint: l10n.kycFullNameHint,
          onChanged: cubit.setFullName,
        ),
        if (state.documentsRequired) ...[
          const SizedBox(height: DealGoSpacing.s12),
          OnboardingMockField(
            label: l10n.kycBirthDate,
            value: state.birthDate,
            required: true,
            fieldKey: const Key('kyc-birth-date'),
            hint: 'dd/mm/yyyy',
            keyboardType: TextInputType.datetime,
            onChanged: cubit.setBirthDate,
            trailing: const Icon(
              DealGoIcons.calendar,
              size: 18,
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          OnboardingMockField(
            label: l10n.kycNationality,
            value: l10n.kycNationalityVn,
            required: true,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          OnboardingMockField(
            label: l10n.kycAddress,
            value: state.address,
            required: true,
            fieldKey: const Key('kyc-address'),
            onChanged: cubit.setAddress,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        OnboardingInfoBanner(
          message: l10n.kycPrivacyNote,
          tone: OnboardingBannerTone.neutral,
          icon: DealGoIcons.shieldPlain,
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingMockField(label: l10n.kycFullName, value: state.fullName),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(label: l10n.kycBirthDate, value: state.birthDate),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(label: l10n.kycAddress, value: state.address),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.kycIdNumber,
          value: state.idNumber,
          required: true,
          fieldKey: const Key('kyc-id-number'),
          hint: l10n.kycIdNumberHint,
          keyboardType: TextInputType.number,
          onChanged: context.read<DriverKycCubit>().setIdNumber,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingInfoBanner(message: l10n.kycConfirmNote),
      ],
    );
  }
}

class _LicenseStep extends StatelessWidget {
  const _LicenseStep({required this.state});

  final DriverKycState state;

  static const classes = ['A1', 'A'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverKycCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DocSlots(state: state, kinds: const [PartnerDocumentKind.license]),
        Text(
          l10n.kycLicenseClass,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Wrap(
          spacing: DealGoSpacing.s8,
          children: [
            for (final value in classes)
              ChoiceChip(
                label: Text(value),
                selected: state.licenseClass == value,
                onSelected: (_) => cubit.setLicenseClass(value),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.kycLicenseNumber,
          value: state.licenseNumber,
          required: true,
          fieldKey: const Key('kyc-license-number'),
          keyboardType: TextInputType.number,
          onChanged: cubit.setLicenseNumber,
        ),
      ],
    );
  }
}

class _VehicleClassChipLabel extends StatelessWidget {
  const _VehicleClassChipLabel({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (resolved != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: Image.network(
              resolved,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
        ],
        Text(name),
      ],
    );
  }
}

class _VehicleStep extends StatefulWidget {
  const _VehicleStep({required this.state});

  final DriverKycState state;

  @override
  State<_VehicleStep> createState() => _VehicleStepState();
}

class _VehicleStepState extends State<_VehicleStep> {
  static const _fallback = [
    RideVehicleClassOption(code: 'MOTORBIKE', name: 'Xe máy', seats: 1),
    RideVehicleClassOption(code: 'CAR_4', name: 'Xe 4 chỗ', seats: 4),
    RideVehicleClassOption(code: 'CAR_7', name: 'Xe 7 chỗ', seats: 7),
  ];

  List<RideVehicleClassOption> _classes = _fallback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  Future<void> _loadClasses() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) {
      return;
    }
    try {
      final classes = await context
          .read<PricingRepository>()
          .listVehicleClasses(accessToken: auth.tokens.accessToken);
      if (!mounted || classes.isEmpty) {
        return;
      }
      setState(() => _classes = classes);
    } catch (_) {
      // Keep the built-in classes so registration can still name a vehicle.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverKycCubit>();
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.kycVehicleType,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            for (final vehicle in _classes)
              ChoiceChip(
                key: Key('kyc-vehicle-${vehicle.code}'),
                label: _VehicleClassChipLabel(
                  name: vehicle.name,
                  imageUrl: vehicle.imageUrl,
                ),
                selected: state.vehicleClassCode == vehicle.code,
                onSelected: (_) => cubit.setVehicleClass(
                  code: vehicle.code,
                  name: vehicle.name,
                ),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.kycVehiclePlate,
          value: state.vehiclePlate,
          required: true,
          fieldKey: const Key('kyc-vehicle-plate'),
          hint: '43B1-123.45',
          onChanged: cubit.setVehiclePlate,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: OnboardingMockField(
                label: l10n.kycVehicleBrand,
                value: state.vehicleBrand,
                fieldKey: const Key('kyc-vehicle-brand'),
                hint: 'Honda',
                onChanged: cubit.setVehicleBrand,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: OnboardingMockField(
                label: l10n.kycVehicleModel,
                value: state.vehicleModel,
                fieldKey: const Key('kyc-vehicle-model'),
                hint: 'Vision',
                onChanged: cubit.setVehicleModel,
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s16),
        if (state.documentsRequired) ...[
          _DocSlots(
            state: state,
            kinds: [
              PartnerDocumentKind.vehicleReg,
              if (PartnerDocumentKind.isCarClass(state.vehicleClassCode ?? ''))
                PartnerDocumentKind.vehicleInsurance,
            ],
          ),
          OnboardingInfoBanner(message: l10n.kycVehicleNote),
          if (PartnerDocumentKind.isCarClass(state.vehicleClassCode ?? ''))
            OnboardingInfoBanner(message: l10n.kycVehicleInsuranceNote),
        ] else
          OnboardingInfoBanner(
            message: l10n.kycQuickModeBanner,
            icon: DealGoIcons.bolt,
          ),
      ],
    );
  }
}

class _BankStep extends StatelessWidget {
  const _BankStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DriverKycCubit>();
    return PartnerBankFields(
      bankName: state.bankName,
      accountNumber: state.bankAccountNumber,
      holder: state.bankAccountHolder,
      onBankName: cubit.setBankName,
      onAccountNumber: cubit.setBankAccountNumber,
      onHolder: cubit.setBankAccountHolder,
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final DriverKycState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<DriverKycCubit>();
    final services = [
      if (state.rideService) l10n.kycIntroRideTitle,
      if (state.foodService) l10n.kycIntroFoodTitle,
    ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.kycReviewProfile, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              PartnerReviewRow(
                title: l10n.kycReviewDriver,
                subtitle: state.fullName,
                ok:
                    state.canContinuePersonal &&
                    (!state.documentsRequired || state.canContinueIdNumber),
              ),
              PartnerReviewRow(
                title: l10n.kycReviewServices,
                subtitle: services,
                ok: state.canContinueServices,
              ),
              PartnerReviewRow(
                title: l10n.kycStepVehicle,
                subtitle: [
                  state.vehicleType ?? '',
                  state.vehiclePlate,
                  state.vehicleBrand,
                  state.vehicleModel,
                ].where((v) => v.trim().isNotEmpty).join(' · '),
                ok: state.canContinueVehicleStep,
              ),
              if (state.documentsRequired)
                PartnerReviewRow(
                  title: l10n.kycReviewBank,
                  subtitle: state.bankAccountNumber.isEmpty
                      ? ''
                      : '${state.bankName} · ${partnerMaskAccount(state.bankAccountNumber)}',
                  ok: state.canContinueBank,
                ),
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
                for (final kind in state.requiredDriverDocumentKinds)
                  InkWell(
                    onTap: () => cubit.goToStep(_stepForKind(kind)),
                    child: PartnerReviewRow(
                      title: partnerDocumentLabel(l10n, kind),
                      subtitle: '',
                      ok: state.documents.has(kind),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingInfoBanner(
          message: state.documentsRequired
              ? l10n.kycReviewNote
              : l10n.kycQuickModeBanner,
        ),
      ],
    );
  }

  static DriverKycStep _stepForKind(String kind) {
    return switch (kind) {
      PartnerDocumentKind.selfie => DriverKycStep.selfie,
      PartnerDocumentKind.license => DriverKycStep.license,
      PartnerDocumentKind.vehicleReg => DriverKycStep.vehicle,
      PartnerDocumentKind.vehicleInsurance => DriverKycStep.vehicle,
      _ => DriverKycStep.identity,
    };
  }
}
