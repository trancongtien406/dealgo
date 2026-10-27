import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/voice_models.dart';
import '../cubit/voice_call_cubit.dart';

/// Whether call buttons should show: false when the admin switched calls
/// off, the server has no voice provider, or no call controller is mounted.
///
/// Pass `listen: false` from event handlers (button taps, post-frame
/// callbacks): a listening lookup there trips provider's debug assert and the
/// handler aborts before it does anything.
bool voiceCallsEnabled(BuildContext context, {bool listen = true}) {
  final cubit = _maybeCubit(context, listen: listen);
  return cubit?.state.enabled ?? false;
}

/// Rings the other party of a ride / food order. The call screen comes from
/// `VoiceCallHost`, so callers do not await anything visible.
void startVoiceCall(
  BuildContext context, {
  required VoiceThreadKind kind,
  required String resourceId,
}) {
  _maybeCubit(context, listen: false)?.start(kind, resourceId);
}

VoiceCallCubit? _maybeCubit(BuildContext context, {required bool listen}) {
  try {
    return listen
        ? BlocProvider.of<VoiceCallCubit>(context, listen: true)
        : context.read<VoiceCallCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}
