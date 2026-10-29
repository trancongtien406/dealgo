import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/storage/onboarding_storage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/auth_redirect.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';

/// Launch-screen mark: 288-unit canvas shared with the native launch screens
/// (iOS LaunchImage, Android launch_mark / Android 12 splash icon).
const dealGoLaunchMarkAsset = 'assets/images/launch_mark.png';
const dealGoLaunchMarkSize = 288.0;

/// Launch background; must match `LaunchBackground` (iOS) and
/// `splash_background` (Android values / values-night).
Color dealGoLaunchBackground(Brightness platformBrightness) =>
    platformBrightness == Brightness.dark
    ? DealGoColors.primaryDeep
    : DealGoColors.primary;

/// The `/splash` route: a pixel twin of the native launch screen, so the
/// hand-off from native to Flutter is invisible. It only decides where cold
/// start goes; it never adds delay of its own (no minimum duration).
class DealGoSplashScreen extends StatefulWidget {
  const DealGoSplashScreen({
    super.key,
    this.autoNavigate = true,
    this.minDuration = Duration.zero,
    this.authTimeout = const Duration(seconds: 6),
    this.storage,
  });

  final bool autoNavigate;

  /// Test hook; production keeps zero.
  final Duration minDuration;

  /// Upper bound for waiting on session restore before routing on.
  final Duration authTimeout;
  final OnboardingStorage? storage;

  @override
  State<DealGoSplashScreen> createState() => _DealGoSplashScreenState();
}

class _DealGoSplashScreenState extends State<DealGoSplashScreen> {
  late final OnboardingStorage _storage;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? SecureOnboardingStorage();
    if (widget.autoNavigate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _proceed());
    }
  }

  /// False once something else (a cold-start push tap, a deep link, the auth
  /// redirect) already navigated away: the splash may still be mounted
  /// during the outgoing transition and must not drag the user back to home.
  bool get _stillOnSplash {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  AuthCubit? _authCubit() {
    try {
      return context.read<AuthCubit>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _proceed() async {
    if (!_stillOnSplash) return;
    final seenOnboarding = _storage.hasSeenOnboarding();
    final cubit = _authCubit();
    await Future.wait<void>([
      if (widget.minDuration > Duration.zero)
        Future<void>.delayed(widget.minDuration),
      if (cubit != null && cubit.state is AuthRestoring)
        cubit.stream
            .firstWhere((s) => s is! AuthRestoring)
            .timeout(widget.authTimeout, onTimeout: () => cubit.state)
            .then((_) {}, onError: (_) {}),
    ]);
    if (!mounted || !_stillOnSplash) return;

    // Signed in: the router's auth redirect normally moves on by itself
    // (role entry / profile setup); this is only the fallback.
    if (cubit?.state is AuthSignedIn) {
      context.go('/customer');
      return;
    }
    final hasSeenOnboarding = await seenOnboarding;
    if (!mounted || !_stillOnSplash) return;
    context.go(hasSeenOnboarding ? AuthRoutes.login : AuthRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final background = dealGoLaunchBackground(
      MediaQuery.platformBrightnessOf(context),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: DealGoTheme.darkHeaderOverlay.copyWith(
        systemNavigationBarColor: background,
      ),
      child: Semantics(
        label: AppLocalizations.of(context).splashPreparing,
        child: ColoredBox(
          key: const Key('dealgo-launch-screen'),
          color: background,
          child: Center(
            child: Image.asset(
              dealGoLaunchMarkAsset,
              width: dealGoLaunchMarkSize,
              height: dealGoLaunchMarkSize,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const SizedBox.square(dimension: dealGoLaunchMarkSize),
            ),
          ),
        ),
      ),
    );
  }
}
