enum VoiceThreadKind { ride, foodOrder }

class VoiceSession {
  const VoiceSession({required this.roomName, required this.token, this.url});

  final String roomName;
  final String token;
  final String? url;
}
