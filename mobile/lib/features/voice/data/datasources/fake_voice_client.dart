import 'dart:async';

import '../../domain/entities/voice_models.dart';
import 'voice_remote_datasource.dart';

/// In-memory call API for mock builds and tests. Tests drive the callee side
/// by calling [ring] and read what the app sent from [actions].
class FakeVoiceClient implements VoiceClient {
  FakeVoiceClient({this.enabled = true, this.userId = 'me'});

  bool enabled;
  String userId;
  Object? error;

  /// Held open by a test to hang up while the answer request is in flight.
  Completer<void>? acceptGate;

  /// Held open by a test to cancel while the start request is in flight.
  Completer<void>? startGate;
  final Map<String, VoiceCall> calls = {};
  final List<String> actions = [];
  int _seq = 0;

  VoiceSession _session(VoiceCall call) => VoiceSession(
    roomName:
        'dealgo-${call.kind == VoiceThreadKind.ride ? 'ride' : 'food'}-${call.aggregateId}',
    token: 'fake-livekit-token',
    url: 'ws://livekit.fake:7880',
  );

  /// Adds an incoming RINGING call for [userId] and returns it.
  VoiceCall ring({
    VoiceThreadKind kind = VoiceThreadKind.ride,
    String aggregateId = 'ride-1',
    String callerUserId = 'peer',
    bool callerIsCustomer = false,
  }) {
    final call = VoiceCall(
      id: 'call-${++_seq}',
      kind: kind,
      aggregateId: aggregateId,
      status: VoiceCallStatus.ringing,
      callerUserId: callerUserId,
      calleeUserId: userId,
      callerIsCustomer: callerIsCustomer,
      ringUntil: DateTime.now().add(const Duration(seconds: 40)),
    );
    calls[call.id] = call;
    return call;
  }

  VoiceCall _set(VoiceCall c, VoiceCallStatus status, [String? reason]) {
    final next = VoiceCall(
      id: c.id,
      kind: c.kind,
      aggregateId: c.aggregateId,
      status: status,
      callerUserId: c.callerUserId,
      calleeUserId: c.calleeUserId,
      callerIsCustomer: c.callerIsCustomer,
      ringUntil: c.ringUntil,
      endReason: reason,
    );
    calls[c.id] = next;
    return next;
  }

  void _throwIfFailing() {
    final err = error;
    if (err != null) {
      throw err;
    }
  }

  @override
  Future<VoiceCallConfig> config({required String accessToken}) async =>
      VoiceCallConfig(enabled: enabled, ringSeconds: 40);

  @override
  Future<VoiceCallJoin> start({
    required String accessToken,
    required VoiceThreadKind kind,
    required String resourceId,
  }) async {
    actions.add('start:$resourceId');
    final gate = startGate;
    if (gate != null) {
      await gate.future;
    }
    _throwIfFailing();
    final call = VoiceCall(
      id: 'call-${++_seq}',
      kind: kind,
      aggregateId: resourceId,
      status: VoiceCallStatus.ringing,
      callerUserId: userId,
      calleeUserId: 'peer',
      callerIsCustomer: true,
      ringUntil: DateTime.now().add(const Duration(seconds: 40)),
    );
    calls[call.id] = call;
    return VoiceCallJoin(call: call, session: _session(call));
  }

  @override
  Future<VoiceCall> get({
    required String accessToken,
    required String callId,
  }) async {
    _throwIfFailing();
    return calls[callId]!;
  }

  @override
  Future<VoiceCallJoin> accept({
    required String accessToken,
    required String callId,
  }) async {
    final gate = acceptGate;
    actions.add('accept:$callId');
    if (gate != null) {
      await gate.future;
    }
    _throwIfFailing();
    final call = _set(calls[callId]!, VoiceCallStatus.accepted);
    return VoiceCallJoin(call: call, session: _session(call));
  }

  @override
  Future<VoiceCall> decline({
    required String accessToken,
    required String callId,
  }) async {
    actions.add('decline:$callId');
    _throwIfFailing();
    return _set(calls[callId]!, VoiceCallStatus.declined, 'DECLINED');
  }

  @override
  Future<VoiceCall> end({
    required String accessToken,
    required String callId,
  }) async {
    actions.add('end:$callId');
    _throwIfFailing();
    final call = calls[callId]!;
    return call.status == VoiceCallStatus.ringing
        ? _set(call, VoiceCallStatus.missed, 'CANCELLED')
        : _set(call, VoiceCallStatus.ended, 'HANGUP');
  }
}
