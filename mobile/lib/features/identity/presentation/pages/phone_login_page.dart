import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/design_system/components/dealgo_icon_badge.dart';
import '../../../../core/design_system/components/dealgo_pressable.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/auth_redirect.dart';
import '../../domain/entities/auth_method_policy.dart';
import '../../domain/entities/auth_state.dart';
import '../auth_methods_store.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/phone_auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_widgets.dart';
import '../../../../core/l10n/api_error_text.dart';

const _methodsMotion = Duration(milliseconds: 220);

/// S003 — sign-in method picker (layout locked: methods first, no inline
/// phone field on `/login`).
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  late final AuthMethodsStore _methods = context.read<AuthMethodsStore>();

  @override
  void initState() {
    super.initState();
    // Usually already resolved behind the launch screen; this revalidates a
    // cached answer (sign-out, returning from another auth page).
    unawaited(_methods.load());
  }

  void _enterMockDemo() {
    if (!useMockData) {
      return;
    }
    unawaited(context.read<PhoneAuthCubit>().enterMockDemo());
  }

  /// One button: signs in with an existing passkey, or creates the account
  /// and its passkey when the device has none (then profile completion).
  Future<void> _continueWithPasskey(BuildContext context) =>
      context.read<PhoneAuthCubit>().continueWithPasskey();

  /// Real options only: a same-height placeholder while nothing is known, a
  /// retry when the first request fails, and a gentle size/fade change if the
  /// server answer differs from the cached one.
  Widget _methodSection(BuildContext context, AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: _methods,
      builder: (context, _) {
        final Widget child = switch (_methods.status) {
          AuthMethodsStatus.loading => const _AuthMethodsPlaceholder(
            key: Key('auth-methods-loading'),
          ),
          AuthMethodsStatus.failed => DealGoStateView.failure(
            context,
            key: const Key('auth-methods-error'),
            cause: _methods.error,
            compact: true,
            onRetry: () => unawaited(_methods.retry()),
          ),
          AuthMethodsStatus.ready => Column(
            key: const Key('auth-methods-ready'),
            children: _methodTiles(context, l10n),
          ),
        };
        return AnimatedSize(
          duration: _methodsMotion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _methodsMotion,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(
                _methods.status == AuthMethodsStatus.ready
                    ? 'ready-${_enabledSignature()}'
                    : _methods.status.name,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  String _enabledSignature() => [
    AuthMethodPolicy.phoneSms,
    AuthMethodPolicy.email,
    AuthMethodPolicy.passkey,
  ].where(_methods.isEnabled).join(',');

  List<Widget> _methodTiles(BuildContext context, AppLocalizations l10n) {
    final tiles = <Widget>[
      if (_methods.isEnabled(AuthMethodPolicy.phoneSms))
        _AuthMethodTile(
          key: const Key('auth-method-phone'),
          icon: DealGoIcons.phone,
          label: l10n.authPhoneLabel,
          onTap: () => context.push(AuthRoutes.phoneLogin),
        ),
      if (_methods.isEnabled(AuthMethodPolicy.email))
        _AuthMethodTile(
          key: const Key('auth-method-email'),
          icon: DealGoIcons.mail,
          label: l10n.authEmailLabel,
          onTap: () => context.push(AuthRoutes.emailLogin),
        ),
      if (_methods.isEnabled(AuthMethodPolicy.passkey))
        _AuthMethodTile(
          key: const Key('auth-method-passkey'),
          icon: DealGoIcons.fingerprint,
          label: l10n.passkeyContinue,
          onTap: () => unawaited(_continueWithPasskey(context)),
        ),
    ];
    if (tiles.isEmpty) {
      return [
        DealGoStateView(
          key: const Key('auth-methods-empty'),
          art: DealGoStateArt.security,
          title: l10n.authMethodsEmptyTitle,
          message: l10n.authMethodsEmptyBody,
          compact: true,
        ),
      ];
    }
    return [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(height: DealGoSpacing.s12),
        tiles[i],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final restoring = context.watch<AuthCubit>().state is AuthRestoring;
    if (restoring) {
      return const SessionRestoringPage();
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
      listenWhen: (previous, current) =>
          current is PhoneAuthError && current.phase == PhoneAuthPhase.passkey,
      listener: (context, state) {
        if (state is PhoneAuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                apiErrorText(AppLocalizations.of(context), state.error),
              ),
            ),
          );
          context.read<PhoneAuthCubit>().clearError();
        }
      },
      builder: (context, authState) {
        return AuthScaffold(
          onLogoDoubleTap: _enterMockDemo,
          padBody: false,
          body: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // Art ratio, but capped by screen height so the welcome
                  // text and every method tile fit above the fold on SE.
                  final byWidth = constraints.maxWidth * 560 / 767;
                  final byHeight = MediaQuery.sizeOf(context).height * 0.3;
                  final height = (byWidth < byHeight ? byWidth : byHeight)
                      .clamp(160.0, 300.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s16,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                      child: ColoredBox(
                        color: DealGoColors.lavender,
                        child: SizedBox(
                          width: double.infinity,
                          height: height,
                          child: Image.asset(
                            'assets/images/hero_dealgo_danang.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(
                                  color: DealGoColors.subtlePurple,
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s20,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: DealGoSpacing.s16),
                    Semantics(
                      header: true,
                      child: Text.rich(
                        TextSpan(
                          style: textTheme.headlineMedium,
                          children: [
                            TextSpan(text: '${l10n.authWelcomeTo}\n'),
                            TextSpan(
                              text: 'Deal',
                              style: textTheme.headlineLarge?.copyWith(
                                color: DealGoColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: 'Go',
                              style: textTheme.headlineLarge?.copyWith(
                                color: DealGoColors.brandGreen,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      l10n.onbSlide1Body,
                      style: textTheme.bodyMedium?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DealGoSpacing.s24),
                    _methodSection(context, l10n),
                    const AuthLegalFooter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Neutral stand-in with the footprint of one method tile: no label, so it
/// never promises an option the server might have switched off.
class _AuthMethodsPlaceholder extends StatelessWidget {
  const _AuthMethodsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: DealGoShimmer(
        child: DealGoSkeletonBox(height: 60, radius: DealGoRadius.button),
      ),
    );
  }
}

class _AuthMethodTile extends StatelessWidget {
  const _AuthMethodTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DealGoPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: DealGoColors.card,
          borderRadius: BorderRadius.circular(DealGoRadius.button),
          border: Border.all(color: DealGoColors.border),
          boxShadow: DealGoShadows.card,
        ),
        child: Row(
          children: [
            DealGoIconBadge(icon, size: 38),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            const Icon(
              DealGoIcons.chevronRight,
              color: DealGoColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
