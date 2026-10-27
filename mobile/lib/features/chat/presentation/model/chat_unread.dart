import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/realtime/snapshot_realtime.dart';

/// Unread counts per chat thread (`Ride:<id>` / `FoodOrder:<id>`), fed by the
/// realtime `chatMessage` push only — no polling, no extra request. A thread
/// that is open in a chat sheet never counts; opening it resets to 0.
/// In-memory: a cold start shows 0 (the push banner covers that case).
class ChatUnread extends ChangeNotifier {
  ChatUnread._();

  static final ChatUnread instance = ChatUnread._();

  final _counts = <String, int>{};
  final _seen = <String>{};
  final _open = <String>{};
  SnapshotRealtime? _realtime;
  String? _userId;
  StreamSubscription<ChatMessageHint>? _sub;

  static String keyFor(String aggregateType, String aggregateId) =>
      '$aggregateType:$aggregateId';

  /// Idempotent: re-attaching the same socket only updates the user id.
  void attach(SnapshotRealtime realtime, {required String? currentUserId}) {
    _userId = currentUserId ?? _userId;
    if (identical(realtime, _realtime)) {
      return;
    }
    unawaited(_sub?.cancel());
    _realtime = realtime;
    _sub = realtime.chatMessages.listen(_onMessage);
  }

  void _onMessage(ChatMessageHint hint) {
    if (!_seen.add(hint.id)) {
      return; // replay / duplicate delivery
    }
    if (_seen.length > 2000) {
      _seen.remove(_seen.first);
    }
    final key = keyFor(hint.aggregateType, hint.aggregateId);
    if (_open.contains(key) || hint.senderUserId == _userId) {
      return;
    }
    _counts[key] = (_counts[key] ?? 0) + 1;
    notifyListeners();
  }

  int count(String key) => _counts[key] ?? 0;

  void markOpen(String key) {
    _open.add(key);
    if (_counts.remove(key) != null) {
      _notifyOutsideBuild();
    }
  }

  /// The chat sheet marks its thread open from `initState`, i.e. while a frame
  /// is building. Notifying then makes the badge's setState throw
  /// "called during build" and the badge keeps its stale count, so defer the
  /// notification to after the frame in that case.
  void _notifyOutsideBuild() {
    SchedulerBinding? binding;
    try {
      binding = SchedulerBinding.instance;
    } on Object {
      binding = null; // plain unit test without a binding
    }
    if (binding != null &&
        binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
      binding.ensureVisualUpdate();
      return;
    }
    notifyListeners();
  }

  void markClosed(String key) {
    _open.remove(key);
  }

  @visibleForTesting
  void resetForTest() {
    unawaited(_sub?.cancel());
    _sub = null;
    _realtime = null;
    _userId = null;
    _counts.clear();
    _seen.clear();
    _open.clear();
  }
}
