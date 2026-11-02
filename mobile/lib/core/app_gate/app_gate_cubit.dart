import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_build_info.dart';
import 'app_gate_client.dart';
import 'app_gate_models.dart';

class AppGateState {
  const AppGateState({
    this.update = AppUpdateInfo.none,
    this.optionalDismissed = false,
    this.consents = const [],
    this.accepting = false,
    this.acceptFailed = false,
  });

  final AppUpdateInfo update;

  /// The soft "new version" prompt was closed this session.
  final bool optionalDismissed;
  final List<PendingConsent> consents;
  final bool accepting;
  final bool acceptFailed;

  bool get updateRequired => update.verdict == AppUpdateVerdict.required;
  bool get showOptionalPrompt =>
      update.verdict == AppUpdateVerdict.optional && !optionalDismissed;
  bool get consentRequired => consents.isNotEmpty;

  AppGateState copyWith({
    AppUpdateInfo? update,
    bool? optionalDismissed,
    List<PendingConsent>? consents,
    bool? accepting,
    bool? acceptFailed,
  }) => AppGateState(
    update: update ?? this.update,
    optionalDismissed: optionalDismissed ?? this.optionalDismissed,
    consents: consents ?? this.consents,
    accepting: accepting ?? this.accepting,
    acceptFailed: acceptFailed ?? this.acceptFailed,
  );
}

/// t82u: blocks the app when the build is below the admin minimum
/// (DEC-PROD-089) or the user has not accepted the current terms
/// (DEC-PROD-090). [client] null = disabled (tests, mock builds).
///
/// Fails open: a network error never locks anyone out; the server-side
/// `APP_UPDATE_REQUIRED` guard ([forceRequired]) is the backstop.
class AppGateCubit extends Cubit<AppGateState> {
  AppGateCubit({required this.client, required this.build})
    : super(const AppGateState());

  final AppGateClient? client;
  final AppBuildInfo build;
  var _checking = false;
  var _signedIn = false;

  bool get enabled => client != null;

  /// On launch and on every resume.
  Future<void> checkVersion() async {
    final client = this.client;
    if (client == null || _checking) return;
    _checking = true;
    try {
      await build.load();
      final platform = build.platform;
      final buildNumber = build.build;
      if (platform == null || buildNumber == null) return;
      final info = await client.versionPolicy(
        platform: platform,
        build: buildNumber,
      );
      if (isClosed) return;
      emit(state.copyWith(update: info));
    } on Object {
      // Offline / 5xx: keep the last verdict.
    } finally {
      _checking = false;
    }
  }

  /// Dio saw `426 APP_UPDATE_REQUIRED`: lock now, then fetch the store link.
  void forceRequired() {
    if (isClosed || state.updateRequired) return;
    emit(
      state.copyWith(
        update: AppUpdateInfo(
          verdict: AppUpdateVerdict.required,
          latestVersion: state.update.latestVersion,
          storeUrl: state.update.storeUrl,
          message: state.update.message,
        ),
      ),
    );
    unawaited(checkVersion());
  }

  void dismissOptional() => emit(state.copyWith(optionalDismissed: true));

  /// Auth changed: fetch pending consents when signed in, clear otherwise.
  Future<void> setSignedIn(bool signedIn) async {
    if (signedIn == _signedIn) return; // token refresh re-emits SignedIn
    _signedIn = signedIn;
    if (!signedIn) {
      if (state.consents.isNotEmpty) emit(state.copyWith(consents: const []));
      return;
    }
    await refreshConsents();
  }

  Future<void> refreshConsents() async {
    final client = this.client;
    if (client == null || !_signedIn) return;
    try {
      final list = await client.pendingConsents();
      if (isClosed || !_signedIn) return;
      emit(state.copyWith(consents: list));
    } on Object {
      // Fail open; retried on next resume.
    }
  }

  /// "Tôi đồng ý": accepts every pending document shown on the screen.
  Future<void> acceptAll() async {
    final client = this.client;
    if (client == null || state.accepting || state.consents.isEmpty) return;
    emit(state.copyWith(accepting: true, acceptFailed: false));
    try {
      for (final c in state.consents) {
        await client.acceptConsent(c.id);
      }
      if (isClosed) return;
      emit(state.copyWith(accepting: false, consents: const []));
      unawaited(refreshConsents());
    } on Object {
      if (isClosed) return;
      emit(state.copyWith(accepting: false, acceptFailed: true));
    }
  }

  Future<void> onResume() async {
    await checkVersion();
    await refreshConsents();
  }
}
