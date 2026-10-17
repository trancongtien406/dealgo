import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/fetch_me.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required this._fetchMe, required this.tokens})
    : super(const AuthRestoring());

  final FetchMe _fetchMe;
  final TokenStore tokens;

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
      _emitSignedIn(next, profile);
    } on ApiException {
      await signOut();
    }
  }

  void _emitSignedIn(StoredTokens tokens, UserProfile profile) {
    if (isClosed) {
      return;
    }
    emit(AuthSignedIn(tokens: tokens, profile: profile));
  }

  Future<void> signOut() async {
    await _clearQuietly();
    if (!isClosed) {
      emit(const AuthSignedOut());
    }
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
