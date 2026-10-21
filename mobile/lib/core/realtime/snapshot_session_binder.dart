import 'dart:async';

import '../../features/identity/domain/entities/auth_state.dart';
import '../../features/identity/presentation/cubit/auth_cubit.dart';
import '../config/app_env.dart';
import 'snapshot_realtime.dart';

/// Connects [SnapshotRealtime] when the user signs in and disconnects on
/// sign-out. Room subscribe/unsubscribe remains owned by feature bindings.
class SnapshotSessionBinder {
  SnapshotSessionBinder({required this._authCubit, required this._realtime});

  final AuthCubit _authCubit;
  final SnapshotRealtime _realtime;
  StreamSubscription<AuthState>? _sub;
  String? _connectedToken;

  void start() {
    _sub ??= _authCubit.stream.listen(_onAuth);
    _onAuth(_authCubit.state);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _connectedToken = null;
    await _realtime.disconnect();
  }

  void _onAuth(AuthState state) {
    if (useMockData) {
      return;
    }
    if (state is AuthSignedIn) {
      final token = state.tokens.accessToken.trim();
      if (token.isEmpty || token == _connectedToken) {
        return;
      }
      _connectedToken = token;
      unawaited(_realtime.connect(accessToken: token));
      return;
    }
    if (_connectedToken != null || state is AuthSignedOut) {
      _connectedToken = null;
      unawaited(_realtime.disconnect());
    }
  }
}
