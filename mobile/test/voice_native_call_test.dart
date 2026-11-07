import 'dart:async';
import 'dart:io';

import 'package:dealgo/features/voice/data/datasources/fake_voice_client.dart';
import 'package:dealgo/features/voice/data/media/fake_voice_media_engine.dart';
import 'package:dealgo/features/voice/data/native/callkit_native_call_ui.dart';
import 'package:dealgo/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:dealgo/features/voice/domain/entities/voice_models.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/voice/domain/ports/native_call_ui.dart';
import 'package:dealgo/features/voice/domain/usecases/answer_voice_call.dart';
import 'package:dealgo/features/voice/domain/usecases/end_voice_call.dart';
import 'package:dealgo/features/voice/domain/usecases/get_voice_call.dart';
import 'package:dealgo/features/voice/domain/usecases/get_voice_call_config.dart';
import 'package:dealgo/features/voice/domain/usecases/start_voice_call.dart';
import 'package:dealgo/features/voice/presentation/cubit/voice_call_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNativeCallUi implements NativeCallUi {
  final controller = StreamController<NativeCallAction>.broadcast();
  final log = <String>[];
  final shown = <NativeIncomingCall>[];
  List<NativeCallAction> launch = const [];

  @override
  Stream<NativeCallAction> get actions => controller.stream;

  @override
  Future<void> showIncoming(NativeIncomingCall call) async {
    shown.add(call);
    log.add('show:${call.callId}');
  }

  @override
  Future<void> dismiss(String callId) async {
    log.add('dismiss:$callId');
    final existing = ringingNatively
        .where((id) => id.toLowerCase() == callId.toLowerCase())
        .toList(growable: false);
    for (final id in existing) {
      ringingNatively.remove(id);
      if (echoDeclineOnUnansweredDismiss) {
        // Mirrors iOS CXEndCallAction (wasUnanswered) and Android endCall
        // (!isAccepted), which both emit ACTION_CALL_DECLINE back to Dart.
        controller.add(NativeCallAction(NativeCallActionType.declined, id));
      }
    }
  }

  @override
  Future<void> dismissOthers(String? keepCallId) async {
    log.add('dismissOthers:${keepCallId ?? ''}');
    final stale = ringingNatively
        .where((id) => id.toLowerCase() != keepCallId?.toLowerCase())
        .toList(growable: false);
    for (final id in stale) {
      ringingNatively.remove(id);
      if (echoDeclineOnUnansweredDismiss) {
        controller.add(NativeCallAction(NativeCallActionType.declined, id));
      }
    }
  }

  bool echoDeclineOnUnansweredDismiss = false;

  @override
  Future<void> setConnected(String callId) async =>
      log.add('connected:$callId');

  @override
  Future<List<NativeCallAction>> acceptedOnLaunch() async {
    final out = launch;
    launch = const [];
    return out;
  }

  @override
  Future<String?> voipPushToken() async => null;

  @override
  Stream<void> get voipTokenChanges => const Stream.empty();

  @override
  Future<void> ensureFullScreenCalls() async {}

  final ringingNatively = <String>{};

  @override
  Future<bool> isRinging(String callId) async => ringingNatively.any(
    (id) => id.toLowerCase() == callId.toLowerCase(),
  );

  @override
  Future<List<String>> ringingCalls() async =>
      ringingNatively.toList(growable: false);
}

class _Harness {
  _Harness({this._token = 'tok'}) {
    final repo = VoiceRepositoryImpl(voice);
    cubit = VoiceCallCubit(
      startVoiceCall: StartVoiceCall(repo),
      answerVoiceCall: AnswerVoiceCall(repo),
      endVoiceCall: EndVoiceCall(repo),
      getVoiceCall: GetVoiceCall(repo),
      getVoiceCallConfig: GetVoiceCallConfig(repo),
      media: media,
      callEvents: events.stream,
      reconnects: const Stream.empty(),
      accessToken: () => _token,
      currentUserId: () => 'me',
      // Long enough that a loaded test runner cannot reset to idle between the
      // ending action and the assertion (real-time 1ms settles).
      endedHold: const Duration(seconds: 1),
      ringGrace: Duration.zero,
      peerGoneGrace: Duration.zero,
      nativeCallUi: native,
    );
  }

  final voice = FakeVoiceClient();
  final media = FakeVoiceMediaEngine();
  final native = FakeNativeCallUi();
  final events = StreamController<Map<String, Object?>>.broadcast();
  String? _token;
  late final VoiceCallCubit cubit;

  void ringViaSocket(VoiceCall call) => events.add({
    'callId': call.id,
    'aggregateType': 'Ride',
    'aggregateId': call.aggregateId,
    'status': 'RINGING',
    'callerUserId': call.callerUserId,
    'calleeUserId': call.calleeUserId,
    'callerRole': call.callerIsCustomer ? 'CUSTOMER' : 'DRIVER',
    'ringUntil': call.ringUntil.toIso8601String(),
  });

  Future<void> dispose() async {
    await cubit.close();
    await events.close();
    await native.controller.close();
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

const _uuid = '6f1c2a9e-1b2c-4d5e-8f90-a1b2c3d4e5f6';

void main() {
  test('Call.incoming push becomes a native call; other pushes do not', () {
    final call = NativeIncomingCall.fromPush(
      {'eventType': 'Call.incoming', 'callId': _uuid, 'role': 'DRIVER'},
      title: 'Khách đang gọi cho bạn',
      body: 'Chuyến #ABCD: chạm để nghe máy.',
    );
    expect(call?.callId, _uuid);
    expect(call?.callerLabel, 'Khách đang gọi cho bạn');
    expect(call?.ringSeconds, 40);
    expect(call?.data['role'], 'DRIVER');
    expect(
      NativeIncomingCall.fromPush({
        'eventType': 'Call.missed',
        'callId': _uuid,
      }),
      isNull,
    );
    // CallKit only takes UUIDs.
    expect(
      NativeIncomingCall.fromPush({
        'eventType': 'Call.incoming',
        'callId': 'c1',
      }),
      isNull,
    );
    final fallback = NativeIncomingCall.fromPush({
      'eventType': 'Call.incoming',
      'callId': _uuid,
      'role': 'CUSTOMER',
    });
    expect(fallback?.callerLabel, 'Tài xế đang gọi cho bạn');
  });

  test(
    'Android background push rings the system UI, missed push clears it',
    () async {
      final ui = FakeNativeCallUi();
      await handleCallPushInBackground(
        {'eventType': 'Call.incoming', 'callId': _uuid, 'role': 'DRIVER'},
        title: 'Khách đang gọi cho bạn',
        ui: ui,
      );
      await handleCallPushInBackground({
        'eventType': 'Call.missed',
        'callId': _uuid,
      }, ui: ui);
      await handleCallPushInBackground({'eventType': 'Ride.updated'}, ui: ui);
      expect(ui.log, ['show:$_uuid', 'dismiss:$_uuid']);
      await ui.controller.close();
    },
  );

  test('Android background push does NOT ring if user is signed out', () async {
    final ui = FakeNativeCallUi();
    final emptyTokenStore = MemoryTokenStore();
    await handleCallPushInBackground(
      {'eventType': 'Call.incoming', 'callId': _uuid, 'role': 'DRIVER'},
      title: 'Khách đang gọi cho bạn',
      ui: ui,
      tokenStore: emptyTokenStore,
    );
    expect(ui.log, isEmpty);
    await ui.controller.close();
  });

  test(
    'data-only incoming call push takes its caller copy from data',
    () async {
      final ui = FakeNativeCallUi();
      await handleCallPushInBackground({
        'eventType': 'Call.incoming',
        'callId': _uuid,
        'role': 'DRIVER',
        'title': 'Khách Lan đang gọi',
        'body': 'Chuyến DealGo',
      }, ui: ui);
      expect(ui.shown.single.callerLabel, 'Khách Lan đang gọi');
      expect(ui.shown.single.subtitle, 'Chuyến DealGo');
      await ui.controller.close();
    },
  );

  test('CallKit params are audio-only with the server ring window', () {
    final params = CallkitNativeCallUi.paramsFor(
      NativeIncomingCall.fromPush({
        'eventType': 'Call.incoming',
        'callId': _uuid,
      }, title: 'Khách đang gọi cho bạn')!,
    );
    expect(params.id, _uuid);
    expect(params.type, 0);
    expect(params.duration, 40000);
    expect(params.ios?.supportsVideo, isFalse);
    expect(params.android?.textAccept, 'Nghe');
    expect(params.extra?['callId'], _uuid);
  });

  test('answer on the system screen joins the call and marks it connected', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.ringViaSocket(call);
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.incoming);

    h.native.controller.add(
      NativeCallAction(NativeCallActionType.accepted, call.id),
    );
    await _settle();
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.active);
    expect(h.voice.actions, ['accept:${call.id}']);
    expect(h.native.log, ['connected:${call.id}']);
    expect(h.media.lastSystemCallOwnsAudio, isTrue);

    await h.cubit.hangUp();
    expect(h.native.log.last, 'dismiss:${call.id}');
    // The plugin echoes our endCall as "ended": must not hang up anything else.
    h.native.controller.add(
      NativeCallAction(NativeCallActionType.ended, call.id),
    );
    await _settle();
    expect(h.voice.actions.where((a) => a.startsWith('end:')), hasLength(1));
    await h.dispose();
  });

  test('CallKit already ringing → the in-app ringer stays silent', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.native.ringingNatively.add(call.id);
    h.ringViaSocket(call);
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.incoming);
    expect(h.cubit.state.nativeRinging, isTrue);
    // Still one call on the system UI: nothing dismissed or re-shown.
    expect(h.native.log, isEmpty);
    await h.dispose();
  });

  test(
    'CallKit starts ringing after the socket → in-app ringer stops',
    () async {
      final h = _Harness();
      final call = h.voice.ring();
      h.ringViaSocket(call);
      await _settle();
      expect(h.cubit.state.nativeRinging, isFalse);
      h.native.controller.add(
        NativeCallAction(NativeCallActionType.shown, call.id),
      );
      await _settle();
      expect(h.cubit.state.phase, VoiceCallPhase.incoming);
      expect(h.cubit.state.nativeRinging, isTrue);
      // A "shown" for another call does nothing.
      h.native.controller.add(
        const NativeCallAction(NativeCallActionType.shown, 'other'),
      );
      await _settle();
      expect(h.cubit.state.call?.id, call.id);
      await h.dispose();
    },
  );

  test('answering in the app stops the system ringing', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.ringViaSocket(call);
    await _settle();
    await h.cubit.accept();
    expect(h.cubit.state.phase, VoiceCallPhase.active);
    expect(h.native.log, ['dismiss:${call.id}']);
    await h.dispose();
  });

  test('hang up from the system UI ends a natively answered call', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.ringViaSocket(call);
    await _settle();
    h.native.controller.add(
      NativeCallAction(NativeCallActionType.accepted, call.id),
    );
    await _settle();
    await _settle();
    h.native.controller.add(
      NativeCallAction(NativeCallActionType.ended, call.id),
    );
    await _settle();
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.ended);
    expect(h.voice.actions.last, 'end:${call.id}');
    await h.dispose();
  });

  test('decline on the system screen declines on the server', () async {
    final h = _Harness();
    final call = h.voice.ring();
    // App was in the background: nothing rings in-app.
    h.native.controller.add(
      NativeCallAction(NativeCallActionType.declined, call.id),
    );
    await _settle();
    expect(h.voice.actions, ['decline:${call.id}']);
    expect(h.cubit.state.phase, VoiceCallPhase.idle);
    await h.dispose();
  });

  test(
    'answered on the system screen before sign-in restored: accepts after',
    () async {
      final h = _Harness(token: null);
      final call = h.voice.ring();
      h.native.controller.add(
        NativeCallAction(NativeCallActionType.accepted, call.id),
      );
      await _settle();
      expect(h.voice.actions, isEmpty);
      h._token = 'tok';
      await h.cubit.refreshConfig();
      expect(h.cubit.state.phase, VoiceCallPhase.active);
      expect(h.voice.actions, ['accept:${call.id}']);
      expect(h.native.log, ['connected:${call.id}']);
      expect(h.media.lastSystemCallOwnsAudio, isTrue);
      await h.dispose();
    },
  );

  test('cold start from an accepted system call joins it', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.native.launch = [
      NativeCallAction(NativeCallActionType.accepted, call.id),
    ];
    await h.cubit.refreshConfig();
    expect(h.cubit.state.phase, VoiceCallPhase.active);
    expect(h.voice.actions, ['accept:${call.id}']);
    await h.dispose();
  });

  test(
    'answering a call that already stopped ringing clears the system UI',
    () async {
      final h = _Harness();
      h.native.controller.add(
        NativeCallAction(NativeCallActionType.accepted, 'gone-call'),
      );
      await _settle();
      await _settle();
      expect(h.cubit.state.phase, VoiceCallPhase.idle);
      expect(h.native.log, ['dismiss:gone-call']);
      await h.dispose();
    },
  );

  test(
    'CallKit iOS params disable plugin configureAudioSession so LiveKit + CallKit own AVAudioSession',
    () {
      final params = CallkitNativeCallUi.paramsFor(
        NativeIncomingCall.fromPush({
          'eventType': 'Call.incoming',
          'callId': _uuid,
        }, title: 'Khách đang gọi cho bạn')!,
      );
      expect(params.ios?.configureAudioSession, isFalse);
    },
  );

  test(
    'onResume while a background CallKit call still rings adopts it instead of dismissing and declining',
    () async {
      final h = _Harness();
      h.native.echoDeclineOnUnansweredDismiss = true;
      final call = h.voice.ring();
      h.native.ringingNatively.add(call.id);

      await h.cubit.onResume();
      await _settle();
      await _settle();

      expect(h.cubit.state.phase, VoiceCallPhase.incoming);
      expect(h.cubit.state.call?.id, call.id);
      expect(h.cubit.state.nativeRinging, isTrue);
      expect(h.native.ringingNatively, contains(call.id));
      expect(h.voice.actions, isEmpty);
      await h.dispose();
    },
  );

  test(
    'CallKit shown event for an already-cancelled call dismisses CallKit immediately without declining',
    () async {
      final h = _Harness();
      h.native.echoDeclineOnUnansweredDismiss = true;
      final call = h.voice.ring();
      await h.voice.end(accessToken: 'tok', callId: call.id);
      h.voice.actions.clear();
      h.native.ringingNatively.add(call.id);

      h.native.controller.add(
        NativeCallAction(NativeCallActionType.shown, call.id, {
          'callId': call.id,
        }),
      );
      await _settle();
      await _settle();

      expect(h.native.log, contains('dismiss:${call.id}'));
      expect(h.voice.actions, isEmpty);
      await h.dispose();
    },
  );

  test(
    'MISSED socket event while state.call is null still dismisses background CallKit without declining',
    () async {
      final h = _Harness();
      h.native.echoDeclineOnUnansweredDismiss = true;
      final call = h.voice.ring();
      h.native.ringingNatively.add(call.id);

      h.events.add({
        'callId': call.id,
        'aggregateType': 'Ride',
        'aggregateId': call.aggregateId,
        'status': 'MISSED',
        'callerUserId': call.callerUserId,
        'calleeUserId': 'me',
        'callerRole': 'DRIVER',
        'ringUntil': call.ringUntil.toIso8601String(),
        'endReason': 'CANCELLED',
      });
      await _settle();
      await _settle();

      expect(h.native.log, contains('dismiss:${call.id}'));
      expect(h.voice.actions, isEmpty);
      await h.dispose();
    },
  );

  test(
    'answering in-app while CallKit rings marks native call connected before media.join completes',
    () async {
      final h = _Harness();
      final call = h.voice.ring();
      h.native.ringingNatively.add(call.id);
      h.ringViaSocket(call);
      await _settle();
      expect(h.cubit.state.nativeRinging, isTrue);

      final joinGate = Completer<void>();
      h.media.joinGate = joinGate;
      final accepting = h.cubit.accept();
      await _settle();
      await _settle();

      expect(h.native.log, ['connected:${call.id}']);
      joinGate.complete();
      await accepting;
      expect(h.cubit.state.phase, VoiceCallPhase.active);
      await h.dispose();
    },
  );

  test(
    'uppercase CallKit UUID from iOS matches lowercase backend call ID',
    () async {
      final h = _Harness();
      final call = VoiceCall(
        id: _uuid,
        kind: VoiceThreadKind.ride,
        aggregateId: 'ride-1',
        status: VoiceCallStatus.ringing,
        callerUserId: 'peer',
        calleeUserId: 'me',
        callerIsCustomer: false,
        ringUntil: DateTime.now().add(const Duration(seconds: 40)),
      );
      h.voice.calls[_uuid] = call;
      h.ringViaSocket(call);
      await _settle();

      h.native.controller.add(
        NativeCallAction(NativeCallActionType.accepted, _uuid.toUpperCase()),
      );
      await _settle();
      await _settle();

      expect(h.cubit.state.phase, VoiceCallPhase.active);
      expect(h.voice.actions, ['accept:$_uuid']);
      await h.dispose();
    },
  );

  test(
    'Android background handler dismisses ringing UI on data-only Call.cancelled push',
    () async {
      final ui = FakeNativeCallUi();
      await handleCallPushInBackground({
        'eventType': 'Call.incoming',
        'callId': _uuid,
        'title': 'Tài xế đang gọi',
      }, ui: ui);
      await handleCallPushInBackground({
        'eventType': 'Call.cancelled',
        'callId': _uuid,
      }, ui: ui);
      expect(ui.log, ['show:$_uuid', 'dismiss:$_uuid']);
      await ui.controller.close();
    },
  );

  test(
    'Android CallkitIncomingBroadcastReceiver rings, tracks activeCalls, and emits shown even when isFullScreen is true',
    () {
      final receiver = File(
        'packages/flutter_callkit_incoming/android/src/main/kotlin/com/hiennv/flutter_callkit_incoming/CallkitIncomingBroadcastReceiver.kt',
      ).readAsStringSync();
      // Previously `if (incomingData.isFullScreen)` skipped the `else` block
      // containing showIncomingNotification + sendEventFlutter + addCall, which
      // broke ringtone, activeCalls(), and endCall() on Android!
      expect(
        receiver.contains(
          'if (incomingData.isFullScreen) {\n'
          '                        val intent = CallkitIncomingActivity.getIntent(context, data)\n'
          '                        context.startActivity(intent)\n'
          '                    } else {',
        ),
        isFalse,
      );
      expect(receiver, contains('showIncomingNotification(data)'));
      expect(
        receiver,
        contains('sendEventFlutter(CallkitConstants.ACTION_CALL_INCOMING, data)'),
      );
      expect(receiver, contains('addCall(context, incomingData)'));
    },
  );
}
