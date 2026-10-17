import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../presence/domain/params/set_presence_params.dart';
import '../../../presence/domain/usecases/set_presence.dart';

class DriverDutyCubit extends Cubit<bool> {
  DriverDutyCubit({
    SetPresence? setPresence,
    String? Function()? accessToken,
  }) : _setPresence = setPresence,
       _accessToken = accessToken,
       super(false);

  final SetPresence? _setPresence;
  final String? Function()? _accessToken;

  Future<void> connect() async {
    if (state) {
      return;
    }
    emit(true);
    await _postPresence(online: true);
  }

  Future<void> disconnect() async {
    if (!state) {
      return;
    }
    emit(false);
    await _postPresence(online: false);
  }

  Future<void> _postPresence({required bool online}) async {
    final setPresence = _setPresence;
    final token = _accessToken?.call()?.trim() ?? '';
    if (setPresence == null || token.isEmpty) {
      return;
    }
    try {
      await setPresence(
        SetPresenceParams(accessToken: token, online: online),
      );
    } catch (_) {
      // Soft-fail: local duty toggle remains authoritative for UI.
    }
  }
}
