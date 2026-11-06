import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/media/asset_call_ringer.dart';
import '../../domain/ports/call_ringer.dart';
import '../cubit/voice_call_cubit.dart';

/// Puts the call screen above every route while a call is ringing or live.
/// Mounted once in `MaterialApp.builder`, so a call survives navigation.
class VoiceCallHost extends StatelessWidget {
  const VoiceCallHost({
    required this.child,
    this.ringer = AssetCallRinger.new,
    super.key,
  });

  final Widget child;

  /// Builds the ringer used while a call rings in (tests pass a fake).
  final CallRingerFactory ringer;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceCallCubit, VoiceCallState>(
      buildWhen: (a, b) => a.busy != b.busy,
      builder: (context, state) => Stack(
        children: [
          child,
          if (state.busy)
            Positioned.fill(child: VoiceCallScreen(ringer: ringer)),
        ],
      ),
    );
  }
}

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({this.ringer = AssetCallRinger.new, super.key});

  final CallRingerFactory ringer;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Timer? _ticker;
  late final CallRinger _ringer = widget.ringer();
  bool _ringing = false;
  bool _wantRing = false;
  Timer? _ringDelay;

  @override
  void dispose() {
    _ticker?.cancel();
    _ringDelay?.cancel();
    unawaited(_ringer.dispose());
    super.dispose();
  }

  /// Rings (looping ringtone + vibration) only while a call rings in and the
  /// system call screen is not ringing it already (CallKit dedupe).
  void _syncRinger(VoiceCallState state) {
    final ring = state.phase == VoiceCallPhase.incoming && !state.nativeRinging;
    if (ring == _ringing) {
      return;
    }
    _ringing = ring;
    _wantRing = ring;
    _ringDelay?.cancel();
    if (!ring) {
      unawaited(_ringer.stop());
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      unawaited(_ringer.start());
      return;
    }
    // The socket rings while the app is still in the background. Let the
    // system call screen take the audio first: a local ringtone started here
    // fights CallKit's own session (AVAudioSession) and can steal its audio
    // route, and when the native screen turns out to be ringing it is stopped
    // again a moment later anyway.
    _ringDelay = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _wantRing) {
        unawaited(_ringer.start());
      }
    });
  }

  /// Once a second: redraw the timer while live.
  void _syncTicker(VoiceCallPhase phase) {
    if (phase != VoiceCallPhase.active) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<VoiceCallCubit>();
    final state = cubit.state;
    _syncTicker(state.phase);
    _syncRinger(state);
    final textTheme = Theme.of(context).textTheme;
    final white = textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );
    return Material(
      key: const Key('voice-call-screen'),
      color: DealGoColors.primaryDeep,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s24),
          child: Column(
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 48,
                backgroundColor: DealGoColors.primaryLight,
                child: Icon(Icons.person, size: 56, color: Colors.white),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Text(
                cubit.peerIsCustomer
                    ? l10n.voicePeerCustomer
                    : l10n.voicePeerDriver,
                style: white.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                _statusText(l10n, state),
                key: const Key('voice-call-status'),
                textAlign: TextAlign.center,
                style: white.bodyLarge,
              ),
              const Spacer(flex: 2),
              _Controls(state: state),
              const SizedBox(height: DealGoSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(AppLocalizations l10n, VoiceCallState state) {
    return switch (state.phase) {
      VoiceCallPhase.idle ||
      VoiceCallPhase.starting ||
      VoiceCallPhase.connecting => l10n.voiceConnecting,
      VoiceCallPhase.outgoing => l10n.voiceCalling,
      VoiceCallPhase.incoming => l10n.voiceIncoming,
      VoiceCallPhase.active =>
        state.reconnecting
            ? l10n.voiceReconnecting
            : state.connectedAt == null
            ? l10n.voiceConnecting
            : _elapsed(state.connectedAt),
      VoiceCallPhase.ended => switch (state.notice) {
        VoiceCallNotice.declined => l10n.voiceEndedDeclined,
        VoiceCallNotice.noAnswer => l10n.voiceEndedNoAnswer,
        VoiceCallNotice.missed => l10n.voiceEndedMissed,
        VoiceCallNotice.tripClosed => l10n.voiceEndedTripClosed,
        VoiceCallNotice.connectionLost => l10n.voiceEndedConnectionLost,
        VoiceCallNotice.micDenied => l10n.voiceMicDenied,
        VoiceCallNotice.failed =>
          state.error?.resolve(l10n) ?? l10n.voiceOpenFailed,
        VoiceCallNotice.hungUp || null => l10n.voiceEndedHungUp,
      },
    };
  }

  static String _elapsed(DateTime? since) {
    final d = since == null ? Duration.zero : DateTime.now().difference(since);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final VoiceCallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<VoiceCallCubit>();
    switch (state.phase) {
      case VoiceCallPhase.incoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              key: const Key('voice-decline'),
              icon: Icons.call_end,
              label: l10n.voiceDecline,
              color: DealGoColors.danger,
              onPressed: cubit.decline,
            ),
            _RoundButton(
              key: const Key('voice-accept'),
              icon: Icons.call,
              label: l10n.voiceAccept,
              color: DealGoColors.brandGreen,
              onPressed: cubit.accept,
            ),
          ],
        );
      case VoiceCallPhase.ended:
      case VoiceCallPhase.idle:
        return const SizedBox(height: 96);
      case VoiceCallPhase.starting:
      case VoiceCallPhase.outgoing:
      case VoiceCallPhase.connecting:
      case VoiceCallPhase.active:
        final inRoom =
            state.phase == VoiceCallPhase.outgoing ||
            state.phase == VoiceCallPhase.active;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              key: const Key('voice-mute'),
              icon: state.muted ? Icons.mic_off : Icons.mic,
              label: state.muted ? l10n.voiceUnmute : l10n.voiceMute,
              color: state.muted ? Colors.white : Colors.white24,
              iconColor: state.muted ? DealGoColors.primaryDeep : Colors.white,
              onPressed: inRoom ? cubit.toggleMute : null,
            ),
            _RoundButton(
              key: const Key('voice-hangup'),
              icon: Icons.call_end,
              label: l10n.voiceHangUp,
              color: DealGoColors.danger,
              // Cancellable while the server request is in flight too: a slow
              // network must not trap the user on a dial screen with no exit.
              onPressed: cubit.hangUp,
            ),
            _RoundButton(
              key: const Key('voice-speaker'),
              icon: state.speakerOn ? Icons.volume_up : Icons.volume_down,
              label: l10n.voiceSpeaker,
              color: state.speakerOn ? Colors.white : Colors.white24,
              iconColor: state.speakerOn
                  ? DealGoColors.primaryDeep
                  : Colors.white,
              onPressed: inRoom ? cubit.toggleSpeaker : null,
            ),
          ],
        );
    }
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.iconColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final onTap = onPressed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: onTap == null ? color.withValues(alpha: 0.4) : color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap == null ? null : () => unawaited(onTap()),
              child: SizedBox.square(
                dimension: 68,
                child: Icon(icon, color: iconColor, size: 30),
              ),
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
