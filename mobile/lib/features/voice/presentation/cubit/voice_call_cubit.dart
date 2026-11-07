import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/ui_message.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/observability/crash_reporting.dart';
import '../../domain/entities/voice_models.dart';
import '../../domain/ports/native_call_ui.dart';
import '../../domain/ports/voice_media_engine.dart';
import '../../domain/usecases/answer_voice_call.dart';
import '../../domain/usecases/end_voice_call.dart';
import '../../domain/usecases/get_voice_call.dart';
import '../../domain/usecases/get_voice_call_config.dart';
import '../../domain/usecases/start_voice_call.dart';

enum VoiceCallPhase {
  idle,

  /// Asking the server to ring the other party.
  starting,

  /// We called; waiting for the other party to answer (we are already in the room).
  outgoing,

  /// The other party is calling us.
  incoming,

  /// We accepted; joining the room.
  connecting,
  active,

  /// Shown briefly with [VoiceCallState.notice], then back to idle.
  ended,
}

enum VoiceCallNotice {
  hungUp,
  declined,
  noAnswer,
  missed,
  tripClosed,
  connectionLost,
  micDenied,
  failed,
}

class VoiceCallState {
  const VoiceCallState({
    this.phase = VoiceCallPhase.idle,
    this.call,
    this.muted = false,
    this.speakerOn = false,
    this.remoteConnected = false,
    this.reconnecting = false,
    this.connectedAt,
    this.notice,
    this.error,
    this.enabled = false,
    this.nativeRinging = false,
  });

  final VoiceCallPhase phase;
  final VoiceCall? call;
  final bool muted;
  final bool speakerOn;
  final bool remoteConnected;
  final bool reconnecting;
  final DateTime? connectedAt;
  final VoiceCallNotice? notice;

  /// Server error behind [VoiceCallNotice.failed], when there is one.
  final UiMessage? error;

  /// Admin toggle and provider (GET /v1/calls/config); hides the call button.
  /// Off until the server says otherwise, so a build without LiveKit shows none.
  final bool enabled;

  /// The system call screen (CallKit / ConnectionService) is ringing this
  /// call already, so the in-app ringtone stays silent (one ring, not two).
  final bool nativeRinging;

  bool get busy => phase != VoiceCallPhase.idle;

  VoiceCallState copyWith({
    VoiceCallPhase? phase,
    VoiceCall? call,
    bool? muted,
    bool? speakerOn,
    bool? remoteConnected,
    bool? reconnecting,
    DateTime? connectedAt,
    VoiceCallNotice? notice,
    UiMessage? error,
    bool? enabled,
    bool? nativeRinging,
  }) => VoiceCallState(
    phase: phase ?? this.phase,
    call: call ?? this.call,
    muted: muted ?? this.muted,
    speakerOn: speakerOn ?? this.speakerOn,
    remoteConnected: remoteConnected ?? this.remoteConnected,
    reconnecting: reconnecting ?? this.reconnecting,
    connectedAt: connectedAt ?? this.connectedAt,
    notice: notice ?? this.notice,
    error: error ?? this.error,
    enabled: enabled ?? this.enabled,
    nativeRinging: nativeRinging ?? this.nativeRinging,
  );
}

/// App-wide call controller: one call at a time, customer ↔ assigned driver.
/// The server owns call state (`/v1/calls`, `call` socket event); this cubit
/// mirrors it and drives the audio room ([VoiceMediaEngine]).
class VoiceCallCubit extends Cubit<VoiceCallState> {
  VoiceCallCubit({
    required StartVoiceCall startVoiceCall,
    required AnswerVoiceCall answerVoiceCall,
    required EndVoiceCall endVoiceCall,
    required GetVoiceCall getVoiceCall,
    required GetVoiceCallConfig getVoiceCallConfig,
    required VoiceMediaEngine media,
    required Stream<Map<String, Object?>> callEvents,
    required Stream<void> reconnects,
    required this._accessToken,
    required this._currentUserId,
    this.endedHold = const Duration(seconds: 2),
    this.ringGrace = const Duration(seconds: 3),
    this.peerGoneGrace = const Duration(seconds: 2),
    NativeCallUi nativeCallUi = const NoopNativeCallUi(),
  }) : _start = startVoiceCall,
       _native = nativeCallUi,
       _answer = answerVoiceCall,
       _end = endVoiceCall,
       _get = getVoiceCall,
       _config = getVoiceCallConfig,
       _media = media,
       super(const VoiceCallState()) {
    _subs
      ..add(callEvents.listen(_onCallEvent))
      ..add(reconnects.listen((_) => unawaited(_reconcile())))
      ..add(media.events.listen(_onMedia))
      ..add(nativeCallUi.actions.listen(_onNativeAction));
  }

  final NativeCallUi _native;

  /// Calls answered on the system call screen (normalized lowercase IDs): it
  /// shows them as connected and must be ended there too.
  final Set<String> _nativeAnswered = {};

  /// Normalized IDs already reported via [NativeCallUi.setConnected] during an
  /// in-app answer while CallKit was ringing, avoiding duplicate transitions.
  final Set<String> _nativeConnectedReported = {};

  /// Normalized IDs dismissed programmatically from Dart so the plugin's
  /// echoed `declined` / `ended` events do not call `/decline` or `/end`.
  final Set<String> _appDismissed = {};
  bool _nativeAutoAccept = false;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String _normId(String id) => id.trim().toLowerCase();

  static bool _sameId(String? a, String? b) =>
      a != null && b != null && _normId(a) == _normId(b);

  /// iOS CXCall emits uppercase UUIDs while the backend stores lowercase UUIDs.
  static String _canonicalCallId(String raw) {
    final trimmed = raw.trim();
    return _uuidPattern.hasMatch(trimmed) ? trimmed.toLowerCase() : trimmed;
  }

  Future<void> _dismissNative(String callId) {
    _appDismissed.add(_normId(callId));
    return _native.dismiss(callId);
  }

  final StartVoiceCall _start;
  final AnswerVoiceCall _answer;
  final EndVoiceCall _end;
  final GetVoiceCall _get;
  final GetVoiceCallConfig _config;
  final VoiceMediaEngine _media;
  final String? Function() _accessToken;
  final String? Function() _currentUserId;
  final Duration endedHold;
  final Duration ringGrace;

  /// How long the peer may stay out of the room before the call ends (a
  /// reconnect, app resume or network switch drops them for a moment).
  final Duration peerGoneGrace;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _ringTimer;
  Timer? _endedTimer;
  Timer? _peerGoneTimer;

  /// Bumped whenever the current call stops being ours. Async work started
  /// under an older epoch (accept, room join, token fetch) must not emit state
  /// or keep the microphone open after the user already hung up.
  int _epoch = 0;

  String? get _token {
    final t = _accessToken()?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Reads the admin toggle; call after sign-in. Failures keep the last value.
  Future<void> refreshConfig() async {
    final token = _token;
    if (token != null) {
      try {
        final config = await _config(accessToken: token);
        if (!isClosed) {
          emit(state.copyWith(enabled: config.enabled));
        }
      } catch (_) {}
    }
    await _drainPending();
  }

  /// Back to the foreground: the system call screen may have been answered or
  /// ended while no Dart code was running (Android kills the process on swipe
  /// away; iOS suspends it), so the last known state can be stale.
  Future<void> onResume() async {
    await _drainPending();
    await _reconcile();
    if (state.phase == VoiceCallPhase.idle && _token != null) {
      for (final ringingId in await _native.ringingCalls()) {
        final canonicalId = _canonicalCallId(ringingId);
        await openFromPush({
          'eventType': 'Call.incoming',
          'callId': canonicalId,
        });
        if (state.phase == VoiceCallPhase.incoming &&
            _sameId(state.call?.id, canonicalId)) {
          _markNativeRinging(state.call!.id);
          break;
        }
      }
    }
    final keep = state.phase == VoiceCallPhase.incoming || _hasCall
        ? state.call?.id
        : null;
    for (final ringingId in await _native.ringingCalls()) {
      if (!_sameId(ringingId, keep)) {
        _appDismissed.add(_normId(ringingId));
      }
    }
    await _native.dismissOthers(keep);
  }

  /// Applies a push tapped on the lock screen and a call answered on the
  /// system call screen. A missing access token defers the work instead of
  /// dropping it: the native ring must still be resolved once the session is
  /// restored.
  Future<void> _drainPending() async {
    final pending = _pendingPush;
    if (pending != null && _token != null) {
      _pendingPush = null;
      await openFromPush(pending);
      if (_nativeAutoAccept) {
        _nativeAutoAccept = false;
        await _acceptRinging(pending['callId']);
      }
    }
    // App launched by "answer" on the system call screen (Android, killed app).
    for (final action in await _native.acceptedOnLaunch()) {
      if (!_nativeAnswered.contains(_normId(action.callId))) {
        await _onNativeAction(action);
      }
    }
  }

  /// Answer / decline on the system call screen (CallKit / ConnectionService).
  Future<void> _onNativeAction(NativeCallAction action) async {
    final callId = _canonicalCallId(action.callId);
    final normId = _normId(callId);
    final ringingHere =
        state.phase == VoiceCallPhase.incoming &&
        _sameId(state.call?.id, callId);
    final liveHere = _sameId(state.call?.id, callId) && _hasCall;
    switch (action.type) {
      case NativeCallActionType.accepted:
        _appDismissed.remove(normId);
        if (ringingHere) {
          _nativeAnswered.add(normId);
          await accept();
          return;
        }
        if (liveHere) {
          // Answered again from the car head unit / watch while the call is
          // already up here: just keep the system call in step.
          _nativeAnswered.add(normId);
          await _native.setConnected(state.call!.id);
          return;
        }
        _nativeAnswered.add(normId);
        final data = <String, Object?>{
          ...action.data,
          'eventType': 'Call.incoming',
          'callId': callId,
        };
        if (_token == null) {
          _pendingPush = data;
          _nativeAutoAccept = true;
          return;
        }
        await openFromPush(data);
        await _acceptRinging(callId);
      case NativeCallActionType.declined:
        if (_appDismissed.remove(normId)) {
          return;
        }
        if (ringingHere) {
          await decline();
        } else if (!(_sameId(state.call?.id, callId) && state.busy)) {
          await _declineOnServer(callId);
        }
      case NativeCallActionType.ended:
        // Hung up from the system UI (Android notification, iOS lock screen).
        // Our own dismiss() echoes back as `ended` too, but by then the id has
        // left [_nativeAnswered].
        if (_appDismissed.remove(normId)) {
          _nativeAnswered.remove(normId);
          _nativeConnectedReported.remove(normId);
          return;
        }
        final answeredNatively = _nativeAnswered.remove(normId);
        _nativeConnectedReported.remove(normId);
        if (answeredNatively && _sameId(state.call?.id, callId) && _hasCall) {
          await hangUp();
        } else if (!answeredNatively && ringingHere) {
          // Ended from the system ring UI (head unit, watch): the caller is
          // still waiting and must be told.
          await decline();
        }
      case NativeCallActionType.timedOut:
        _appDismissed.remove(normId);
        // The native timeout fires at the same 36 s as the server window; the
        // server marks the call missed and pushes "Cuộc gọi nhỡ". Ending the
        // local screen keeps both sides consistent if that push is lost.
        if (ringingHere) {
          _finish(VoiceCallNotice.missed);
        }
        return;
      case NativeCallActionType.shown:
        if (ringingHere) {
          _markNativeRinging(state.call!.id);
          return;
        }
        if (state.phase == VoiceCallPhase.idle && _token != null) {
          await openFromPush({
            ...action.data,
            'eventType': 'Call.incoming',
            'callId': callId,
          });
          if (state.phase == VoiceCallPhase.incoming &&
              _sameId(state.call?.id, callId)) {
            _markNativeRinging(state.call!.id);
          } else if (!state.busy) {
            await _dismissNative(action.callId);
          }
        }
    }
  }

  /// CallKit / ConnectionService rings [callId]: silence the in-app ringer.
  void _markNativeRinging(String callId) {
    if (!isClosed &&
        state.phase == VoiceCallPhase.incoming &&
        _sameId(state.call?.id, callId) &&
        !state.nativeRinging) {
      emit(state.copyWith(nativeRinging: true));
    }
  }

  Future<void> _checkNativeRinging(String callId) async {
    if (await _native.isRinging(callId)) {
      _markNativeRinging(callId);
    }
  }

  Future<void> _acceptRinging(Object? callId) async {
    if (callId is String &&
        state.phase == VoiceCallPhase.incoming &&
        _sameId(state.call?.id, callId)) {
      await accept();
    } else if (callId is String) {
      // No longer ringing (missed or cancelled meanwhile): clear the system UI.
      _nativeAnswered.remove(_normId(callId));
      _nativeConnectedReported.remove(_normId(callId));
      await _dismissNative(callId);
    }
  }

  /// Keeps the system call screen in step with the in-app call.
  @override
  void onChange(Change<VoiceCallState> change) {
    super.onChange(change);
    final before = change.currentState;
    final after = change.nextState;
    final id = before.call?.id;
    // Only calls ringing on this phone can be on the system call screen.
    if (id == null || before.call?.calleeUserId != _currentUserId()) {
      return;
    }
    final normId = _normId(id);
    final sameCall = _sameId(after.call?.id, id);
    if (after.phase == VoiceCallPhase.active &&
        before.phase != VoiceCallPhase.active &&
        _nativeAnswered.contains(normId)) {
      if (!_nativeConnectedReported.remove(normId)) {
        unawaited(_native.setConnected(id));
      }
      return;
    }
    final stoppedRinging =
        before.phase == VoiceCallPhase.incoming &&
        !(sameCall && after.phase == VoiceCallPhase.incoming) &&
        !_nativeAnswered.contains(normId);
    final over =
        !sameCall ||
        after.phase == VoiceCallPhase.ended ||
        after.phase == VoiceCallPhase.idle;
    if (stoppedRinging || (over && before.phase != VoiceCallPhase.ended)) {
      _nativeAnswered.remove(normId);
      _nativeConnectedReported.remove(normId);
      unawaited(_dismissNative(id));
    }
  }

  /// A call push tapped before the session finished restoring.
  Map<String, Object?>? _pendingPush;

  /// Calls the other party of a ride or food order.
  Future<void> start(VoiceThreadKind kind, String resourceId) async {
    if (state.busy && state.phase != VoiceCallPhase.ended) {
      return;
    }
    final token = _token;
    if (token == null) {
      _finish(VoiceCallNotice.failed);
      return;
    }
    _endedTimer?.cancel();
    _peerGoneTimer?.cancel();
    final epoch = ++_epoch;
    emit(
      const VoiceCallState(phase: VoiceCallPhase.starting)
          .copyWith(enabled: state.enabled),
    );
    if (!await _media.ensureMicrophonePermission()) {
      if (_epoch != epoch) {
        return;
      }
      _finish(VoiceCallNotice.micDenied);
      return;
    }
    final VoiceCallJoin join;
    try {
      join = await _start(
        accessToken: token,
        kind: kind,
        resourceId: resourceId,
      );
    } catch (error) {
      if (_epoch != epoch) {
        return;
      }
      if (error is ApiException && error.errorCode == 'VOICE_DISABLED') {
        emit(state.copyWith(enabled: false));
      }
      _finish(VoiceCallNotice.failed, error: error);
      return;
    }
    if (_epoch != epoch) {
      // Cancelled while the request was in flight: the callee may already be
      // ringing, so the call created above has to be ended, not abandoned.
      await _endOnServer(join.call.id);
      return;
    }
    emit(state.copyWith(phase: VoiceCallPhase.outgoing, call: join.call));
    _armRingTimer(
      join.call,
      onExpire: () => hangUp(notice: VoiceCallNotice.noAnswer),
    );
    try {
      await _media.join(url: join.session.url ?? '', token: join.session.token);
    } catch (error) {
      if (_epoch != epoch) {
        await _media.leave();
        return;
      }
      // Transition to failed before ending on the server so the server's own
      // socket MISSED/CANCELLED echo cannot race ahead as "noAnswer".
      _finish(VoiceCallNotice.failed, error: error);
      await _endOnServer(join.call.id);
      return;
    }
    if (_epoch != epoch) {
      // Hung up while the room was connecting; leave() may have run before the
      // room existed, so release the audio here.
      await _media.leave();
    }
  }

  /// Callee: answer the ringing call.
  Future<void> accept() async {
    final call = state.call;
    final token = _token;
    if (state.phase != VoiceCallPhase.incoming ||
        call == null ||
        token == null) {
      return;
    }
    _ringTimer?.cancel();
    _peerGoneTimer?.cancel();
    final normCallId = _normId(call.id);
    final answeredInAppWhileNativeRinging =
        state.nativeRinging && !_nativeAnswered.contains(normCallId);
    if (state.nativeRinging) {
      // Answered in-app while the system call screen rings this call: keep the
      // native call alive and tell CallKit to fulfill CXAnswerCallAction so its
      // audio session activates before WebRTC opens the audio engine.
      _nativeAnswered.add(normCallId);
    }
    final epoch = ++_epoch;
    emit(state.copyWith(phase: VoiceCallPhase.connecting));
    if (!await _media.ensureMicrophonePermission()) {
      if (_epoch != epoch) {
        return;
      }
      _finish(VoiceCallNotice.micDenied);
      await _declineOnServer(call.id);
      return;
    }
    final VoiceCallJoin join;
    try {
      join = await _answer.accept(accessToken: token, callId: call.id);
    } catch (error) {
      if (_epoch != epoch) {
        return;
      }
      _finish(
        error is ApiException && error.errorCode == 'VOICE_CALL_NOT_RINGING'
            ? VoiceCallNotice.missed
            : VoiceCallNotice.failed,
        error: error,
      );
      return;
    }
    if (_epoch != epoch) {
      // Hung up / declined while the answer request was in flight; that path
      // already ended the call, so only the server-side ACCEPTED state can be
      // left over. Never join the room.
      final alreadyClosed =
          state.phase == VoiceCallPhase.ended ||
          state.phase == VoiceCallPhase.idle ||
          state.call?.id != call.id;
      if (!alreadyClosed) {
        await _endOnServer(call.id);
      }
      return;
    }
    if (answeredInAppWhileNativeRinging) {
      _nativeConnectedReported.add(normCallId);
      await _native.setConnected(call.id);
    }
    try {
      await _media.join(
        url: join.session.url ?? '',
        token: join.session.token,
        systemCallOwnsAudio:
            state.nativeRinging || _nativeAnswered.contains(normCallId),
      );
    } catch (error) {
      if (_epoch != epoch) {
        await _media.leave();
        return;
      }
      _finish(VoiceCallNotice.failed, error: error);
      await _endOnServer(call.id);
      return;
    }
    if (_epoch != epoch) {
      // Mic was opened by join() after the user already hung up.
      await _media.leave();
      return;
    }
    if (state.phase == VoiceCallPhase.connecting) {
      emit(state.copyWith(phase: VoiceCallPhase.active, call: join.call));
      _startClockIfLive();
    }
  }

  /// Callee: refuse the ringing call.
  Future<void> decline() async {
    final call = state.call;
    if (state.phase != VoiceCallPhase.incoming || call == null) {
      return;
    }
    ++_epoch;
    await _declineOnServer(call.id);
    _reset();
  }

  /// Either side: hang up (or cancel while ringing / while the request is
  /// still in flight).
  Future<void> hangUp({VoiceCallNotice notice = VoiceCallNotice.hungUp}) async {
    final call = state.call;
    if (state.phase == VoiceCallPhase.starting) {
      // Cancel before the server answered: start() ends the call itself if the
      // request still lands, so nothing to send from here.
      ++_epoch;
      _finish(notice);
      return;
    }
    if (call == null || !_hasCall) {
      return;
    }
    ++_epoch;
    await _media.leave();
    await _endOnServer(call.id);
    _finish(notice);
  }

  Future<void> toggleMute() async {
    if (!_inRoom) {
      return;
    }
    final muted = !state.muted;
    await _media.setMicrophoneEnabled(!muted);
    emit(state.copyWith(muted: muted));
  }

  Future<void> toggleSpeaker() async {
    if (!_inRoom) {
      return;
    }
    final on = !state.speakerOn;
    await _media.setSpeakerOn(on);
    emit(state.copyWith(speakerOn: on));
  }

  /// Tapping an incoming-call push opens the answer screen if it still rings.
  Future<void> openFromPush(Map<String, Object?> data) async {
    final rawCallId = data['callId'];
    if (data['eventType'] != 'Call.incoming' || rawCallId is! String) {
      return;
    }
    final callId = _canonicalCallId(rawCallId);
    final token = _token;
    if (token == null) {
      _pendingPush = <String, Object?>{...data, 'callId': callId};
      return;
    }
    if (state.busy && state.phase != VoiceCallPhase.ended) {
      return;
    }
    try {
      final call = await _get(accessToken: token, callId: callId);
      if (call.status == VoiceCallStatus.ringing &&
          call.calleeUserId == _currentUserId() &&
          !state.busy) {
        _ring(call);
      }
    } catch (_) {}
  }

  /// Sign-out: drop any call without waiting for the server.
  Future<void> signOut() async {
    final call = state.call;
    if (call != null && _inRoom) {
      await _endOnServer(call.id);
    }
    await _media.leave();
    _pendingPush = null;
    _nativeAutoAccept = false;
    _reset();
  }

  /// Who is on the other end, for the call screen title.
  bool get peerIsCustomer {
    final call = state.call;
    if (call == null) {
      return false;
    }
    final iAmCaller = call.callerUserId == _currentUserId();
    return iAmCaller ? !call.callerIsCustomer : call.callerIsCustomer;
  }

  bool get _inRoom =>
      state.phase == VoiceCallPhase.outgoing ||
      state.phase == VoiceCallPhase.active;

  /// Phases that own (or are opening) the audio room.
  bool get _hasCall => const {
    VoiceCallPhase.outgoing,
    VoiceCallPhase.connecting,
    VoiceCallPhase.active,
  }.contains(state.phase);

  void _onCallEvent(Map<String, Object?> raw) {
    final call = VoiceCall.tryParse(raw);
    final me = _currentUserId();
    if (call == null || me == null) {
      return;
    }
    final current = state.call;
    if (current != null && _sameId(current.id, call.id)) {
      _applyServerState(call);
      return;
    }
    if (call.status == VoiceCallStatus.ringing && call.calleeUserId == me) {
      if (state.busy && state.phase != VoiceCallPhase.ended) {
        // Already on a call: the other party hears "busy".
        unawaited(_declineOnServer(call.id));
        return;
      }
      _ring(call);
      return;
    }
    if (call.status != VoiceCallStatus.ringing && call.calleeUserId == me) {
      // PushKit / background push may be ringing CallKit while the app missed
      // the initial RINGING socket frame: take the system UI down immediately.
      unawaited(_dismissNative(call.id));
    }
  }

  void _applyServerState(VoiceCall call) {
    switch (call.status) {
      case VoiceCallStatus.ringing:
        return;
      case VoiceCallStatus.accepted:
        if (state.phase == VoiceCallPhase.outgoing) {
          _ringTimer?.cancel();
          emit(state.copyWith(phase: VoiceCallPhase.active, call: call));
          _startClockIfLive();
        }
        return;
      case VoiceCallStatus.declined:
      case VoiceCallStatus.missed:
      case VoiceCallStatus.ended:
        if (state.phase == VoiceCallPhase.ended ||
            state.phase == VoiceCallPhase.idle) {
          return;
        }
        unawaited(_media.leave());
        _finish(_noticeFor(call));
    }
  }

  VoiceCallNotice _noticeFor(VoiceCall call) {
    final iAmCaller = call.callerUserId == _currentUserId();
    return switch (call.status) {
      VoiceCallStatus.declined => VoiceCallNotice.declined,
      VoiceCallStatus.missed =>
        iAmCaller
            ? (call.endReason == 'CANCELLED'
                  ? VoiceCallNotice.hungUp
                  : VoiceCallNotice.noAnswer)
            : VoiceCallNotice.missed,
      _ => switch (call.endReason) {
        'TRIP_CLOSED' => VoiceCallNotice.tripClosed,
        'TIMEOUT' => VoiceCallNotice.connectionLost,
        _ => VoiceCallNotice.hungUp,
      },
    };
  }

  void _onMedia(VoiceMediaEvent event) {
    switch (event) {
      case VoiceMediaEvent.remoteJoined:
        _peerGoneTimer?.cancel();
        emit(state.copyWith(remoteConnected: true));
        _startClockIfLive();
      case VoiceMediaEvent.remoteLeft:
        emit(state.copyWith(remoteConnected: false));
        if (state.phase != VoiceCallPhase.active || state.reconnecting) {
          // A reconnect drops every participant for a moment; hanging up on
          // the first `remoteLeft` would end healthy calls on a flaky network.
          return;
        }
        // The peer can bounce out for a second (app resume, network switch).
        // Wait for it to stay gone before treating the call as over.
        _peerGoneTimer?.cancel();
        final epoch = _epoch;
        _peerGoneTimer = Timer(peerGoneGrace, () {
          if (!isClosed &&
              _epoch == epoch &&
              state.phase == VoiceCallPhase.active &&
              !state.remoteConnected) {
            unawaited(hangUp());
          }
        });
      case VoiceMediaEvent.reconnecting:
        emit(state.copyWith(reconnecting: true));
      case VoiceMediaEvent.reconnected:
        emit(state.copyWith(reconnecting: false));
      case VoiceMediaEvent.disconnected:
        if (_hasCall) {
          final call = state.call;
          if (call != null) {
            unawaited(_endOnServer(call.id));
          }
          _finish(VoiceCallNotice.connectionLost);
        }
    }
  }

  /// Starts the call clock once, at the moment both parties are in the room.
  ///
  /// The caller learns "accepted" from the socket as soon as the callee taps
  /// answer, but the callee only goes live after its own room join finishes
  /// (seconds later). Starting each clock at its own "active" made the caller
  /// run ahead. Both phones see the other participant at (almost) the same
  /// instant, so the clock starts there: active AND remote participant present.
  /// Kept through reconnects; wall-clock based, so app resume stays correct.
  void _startClockIfLive() {
    if (isClosed ||
        state.connectedAt != null ||
        state.phase != VoiceCallPhase.active ||
        !state.remoteConnected) {
      return;
    }
    emit(state.copyWith(connectedAt: DateTime.now()));
  }

  /// After a socket reconnect the last event may have been lost: ask the server.
  Future<void> _reconcile() async {
    final call = state.call;
    final token = _token;
    if (call == null || token == null || !state.busy) {
      return;
    }
    if (state.phase == VoiceCallPhase.ended) {
      return;
    }
    try {
      _applyServerState(await _get(accessToken: token, callId: call.id));
    } catch (_) {}
  }

  void _ring(VoiceCall call) {
    _endedTimer?.cancel();
    _peerGoneTimer?.cancel();
    ++_epoch;
    emit(
      VoiceCallState(
        phase: VoiceCallPhase.incoming,
        call: call,
        enabled: state.enabled,
      ),
    );
    // A PushKit push may have rung CallKit for this call already (iOS), or the
    // Android background push the system call screen: ring once, not twice.
    unawaited(_checkNativeRinging(call.id));
    _armRingTimer(
      call,
      onExpire: () async {
        if (state.phase == VoiceCallPhase.incoming &&
            state.call?.id == call.id) {
          _finish(VoiceCallNotice.missed);
        }
      },
    );
  }

  void _armRingTimer(
    VoiceCall call, {
    required Future<void> Function() onExpire,
  }) {
    _ringTimer?.cancel();
    var wait = call.ringUntil.difference(DateTime.now()) + ringGrace;
    if (wait.isNegative) {
      wait = Duration.zero;
    }
    _ringTimer = Timer(wait, () {
      if (state.call?.id == call.id) {
        unawaited(onExpire());
      }
    });
  }

  Future<void> _endOnServer(String callId) async {
    final token = _token;
    if (token == null) {
      return;
    }
    try {
      await _end(accessToken: token, callId: callId);
    } catch (_) {}
  }

  Future<void> _declineOnServer(String callId) async {
    final token = _token;
    if (token == null) {
      return;
    }
    try {
      await _answer.decline(accessToken: token, callId: callId);
    } catch (_) {}
  }

  void _finish(VoiceCallNotice notice, {Object? error}) {
    if (isClosed) {
      return;
    }
    // Report once here (the catch site), never from the widget's build.
    if (error != null) {
      reportVoiceFailure(error);
    }
    ++_epoch;
    _ringTimer?.cancel();
    _peerGoneTimer?.cancel();
    emit(
      VoiceCallState(
        phase: VoiceCallPhase.ended,
        call: state.call,
        notice: notice,
        error: error == null ? null : UiMessage.error(error, reported: true),
        enabled: state.enabled,
      ),
    );
    _endedTimer?.cancel();
    _endedTimer = Timer(endedHold, _reset);
  }

  void _reset() {
    if (isClosed) {
      return;
    }
    ++_epoch;
    _ringTimer?.cancel();
    _endedTimer?.cancel();
    _peerGoneTimer?.cancel();
    emit(VoiceCallState(enabled: state.enabled));
  }

  @override
  Future<void> close() async {
    _ringTimer?.cancel();
    _endedTimer?.cancel();
    _peerGoneTimer?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _media.leave();
    return super.close();
  }
}

/// Sends a call failure to crash reporting once, at the catch site. API
/// answers (busy, disabled, …) are business rules, not bugs; only malformed
/// responses and non-API failures (e.g. LiveKit/AVAudioSession) are reported.
@visibleForTesting
void Function(Object error) voiceFailureReporter = _reportVoiceFailure;

void reportVoiceFailure(Object error) => voiceFailureReporter(error);

void _reportVoiceFailure(Object error) {
  if (error is ApiException) {
    if (error.errorCode == 'INVALID_RESPONSE' ||
        error.errorCode == 'MALFORMED_RESPONSE') {
      reportHandledError(error);
    }
    return;
  }
  final errStr = error.toString().toLowerCase();
  if (errStr.contains('audio device module is unavailable') ||
      errStr.contains('audio engine error -4100') ||
      errStr.contains('audiosessionexception')) {
    return;
  }
  reportHandledError(
    error,
    fingerprint: ['voice', error.runtimeType.toString()],
  );
}
