import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/post_auth_gate.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/identity_repository.dart';
import '../../domain/usecases/fetch_me.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this._fetchMe,
    required this.tokens,
    this._identityRepository,
    this._postAuth,
  }) : super(const AuthRestoring());

  final FetchMe _fetchMe;
  final TokenStore tokens;
  final IdentityRepository? _identityRepository;
  PostAuthGate? _postAuth;

  void bindPostAuth(PostAuthGate gate) {
    _postAuth = gate;
  }

  Future<void> restore() async {
    try {
      final stored = await tokens.read();
      if (isClosed) {
        return;
      }
      if (stored == null) {
        emit(const AuthSignedOut());
        return;
      }
      final profile = await _fetchMe(stored.accessToken);
      if (isClosed) {
        return;
      }
      await _syncPostAuth(profile);
      emit(AuthSignedIn(tokens: stored, profile: profile));
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearQuietly();
      }
      if (!isClosed) {
        emit(const AuthSignedOut());
      }
    } catch (_) {
      await _clearQuietly();
      if (!isClosed) {
        emit(const AuthSignedOut());
      }
    }
  }

  Future<void> completeSignIn(StoredTokens session) async {
    final profile = await _fetchMe(session.accessToken);
    await _syncPostAuth(profile);
    // A failed keystore write still opens the shell for this process.
    try {
      await tokens.write(session);
    } on Exception {
      return _emitSignedIn(session, profile);
    }
    _emitSignedIn(session, profile);
  }

  Future<void> applyRefreshedTokens(StoredTokens next) async {
    final current = state;
    if (current is AuthSignedIn) {
      _emitSignedIn(next, current.profile);
      return;
    }
    try {
      final profile = await _fetchMe(next.accessToken);
      await _syncPostAuth(profile);
      _emitSignedIn(next, profile);
    } on ApiException {
      await signOut(revokeRemote: false);
    }
  }

  Future<void> applyUpdatedProfile(UserProfile profile) async {
    final current = state;
    if (current is! AuthSignedIn || isClosed) {
      return;
    }
    await _syncPostAuth(profile);
    emit(AuthSignedIn(tokens: current.tokens, profile: profile));
  }

  /// Re-reads `/v1/me` so newly approved partner grants open their shell
  /// without a fresh sign-in. Failures keep the current profile.
  Future<void> refreshProfile() async {
    final current = state;
    if (current is! AuthSignedIn || isClosed) {
      return;
    }
    try {
      final profile = await _fetchMe(current.tokens.accessToken);
      await applyUpdatedProfile(profile);
    } on Exception {
      return;
    }
  }

  void _emitSignedIn(StoredTokens tokens, UserProfile profile) {
    if (isClosed) {
      return;
    }
    emit(AuthSignedIn(tokens: tokens, profile: profile));
  }

  /// Runs with the still-valid access token right before sign-out (push unregister).
  Future<void> Function(String accessToken)? beforeSignOut;
  Future<void>? _signOutFlight;

  Future<void> signOut({bool revokeRemote = true}) {
    final inflight = _signOutFlight;
    if (inflight != null) {
      return inflight;
    }
    final future = _signOutOnce(revokeRemote: revokeRemote);
    _signOutFlight = future.whenComplete(() {
      _signOutFlight = null;
    });
    return _signOutFlight!;
  }

  Future<void> _signOutOnce({required bool revokeRemote}) async {
    final current = state;
    if (current is AuthSignedIn) {
      final accessToken = revokeRemote ? current.tokens.accessToken : '';
      final hook = beforeSignOut;
      if (hook != null) {
        try {
          await hook(accessToken).timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      final repo = _identityRepository;
      if (revokeRemote && repo != null) {
        try {
          await repo
              .revokeSession(current.tokens.accessToken)
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Always clear local tokens even if revoke fails (offline / expired).
        }
      }
    }
    await _clearQuietly();
    if (!isClosed) {
      emit(const AuthSignedOut());
    }
  }

  Future<void> _syncPostAuth(UserProfile profile) async {
    final gate = _postAuth;
    if (gate == null) {
      return;
    }
    await gate.syncFromServerNeedsProfileSetup(profile.needsProfileSetup);
  }

  Future<bool> _clearQuietly() async {
    try {
      await tokens.clear();
      return true;
    } on Exception {
      return false;
    }
  }
}
