enum VoiceThreadKind { ride, foodOrder }

/// LiveKit join data for one participant: audio only, short-lived token.
class VoiceSession {
  const VoiceSession({required this.roomName, required this.token, this.url});

  final String roomName;
  final String token;

  /// LiveKit signalling URL (`ws://` in dev, `wss://` in production).
  final String? url;
}

enum VoiceCallStatus { ringing, accepted, declined, missed, ended }

VoiceCallStatus? parseVoiceCallStatus(Object? raw) => switch (raw) {
  'RINGING' => VoiceCallStatus.ringing,
  'ACCEPTED' => VoiceCallStatus.accepted,
  'DECLINED' => VoiceCallStatus.declined,
  'MISSED' => VoiceCallStatus.missed,
  'ENDED' => VoiceCallStatus.ended,
  _ => null,
};

/// One call between the customer and the assigned driver of a trip. The
/// server owns the state; the `call` socket event and REST return the same shape.
class VoiceCall {
  const VoiceCall({
    required this.id,
    required this.kind,
    required this.aggregateId,
    required this.status,
    required this.callerUserId,
    required this.calleeUserId,
    required this.callerIsCustomer,
    required this.ringUntil,
    this.endReason,
  });

  final String id;
  final VoiceThreadKind kind;
  final String aggregateId;
  final VoiceCallStatus status;
  final String callerUserId;
  final String calleeUserId;

  /// True when the customer placed the call (so the callee is the driver).
  final bool callerIsCustomer;
  final DateTime ringUntil;

  /// HANGUP, CANCELLED, NO_ANSWER, DECLINED, TRIP_CLOSED, TIMEOUT.
  final String? endReason;

  bool get isOpen =>
      status == VoiceCallStatus.ringing || status == VoiceCallStatus.accepted;

  /// Parses the REST view and the `call` socket payload. Null when malformed.
  static VoiceCall? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = raw['id'] ?? raw['callId'];
    final type = raw['aggregateType'];
    final aggregateId = raw['aggregateId'];
    final status = parseVoiceCallStatus(raw['status']);
    final caller = raw['callerUserId'];
    final callee = raw['calleeUserId'];
    final ringUntil = DateTime.tryParse('${raw['ringUntil']}');
    if (id is! String ||
        aggregateId is! String ||
        status == null ||
        caller is! String ||
        callee is! String ||
        ringUntil == null) {
      return null;
    }
    final kind = switch (type) {
      'Ride' => VoiceThreadKind.ride,
      'FoodOrder' => VoiceThreadKind.foodOrder,
      _ => null,
    };
    if (kind == null) {
      return null;
    }
    final reason = raw['endReason'];
    return VoiceCall(
      id: id,
      kind: kind,
      aggregateId: aggregateId,
      status: status,
      callerUserId: caller,
      calleeUserId: callee,
      callerIsCustomer: raw['callerRole'] != 'DRIVER',
      ringUntil: ringUntil,
      endReason: reason is String ? reason : null,
    );
  }
}

/// A call plus this user's join token (start and accept).
class VoiceCallJoin {
  const VoiceCallJoin({required this.call, required this.session});

  final VoiceCall call;
  final VoiceSession session;
}

class VoiceCallConfig {
  const VoiceCallConfig({required this.enabled, required this.ringSeconds});

  final bool enabled;
  final int ringSeconds;
}
