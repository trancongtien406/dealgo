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
    required FetchMe fetchMe,
    required this.tokens,
    IdentityRepository? identityRepository,
    PostAuthGate? postAuth,
  }) : _fetchMe = fetchMe,
       _identityRepository = identityRepository,
       _postAuth = postAuth,
       super(const AuthRestoring());

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
      await signOut();
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

  void _emitSignedIn(StoredTokens tokens, UserProfile profile) {
    if (isClosed) {
      return;
    }
    emit(AuthSignedIn(tokens: tokens, profile: profile));
  }

  Future<void> signOut() async {
    final current = state;
    if (current is AuthSignedIn) {
      final repo = _identityRepository;
      if (repo != null) {
        try {
          await repo.revokeSession(current.tokens.accessToken);
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
