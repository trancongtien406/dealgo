import 'dart:async';
import 'dart:io';

import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/voice/data/datasources/dio_voice_remote_datasource.dart';
import 'package:dealgo/features/voice/data/datasources/fake_voice_client.dart';
import 'package:dealgo/features/voice/data/media/fake_voice_media_engine.dart';
import 'package:dealgo/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:dealgo/features/voice/domain/entities/voice_models.dart';
import 'package:dealgo/features/voice/domain/ports/call_ringer.dart';
import 'package:dealgo/features/voice/domain/ports/voice_media_engine.dart';
import 'package:dealgo/features/voice/domain/usecases/answer_voice_call.dart';
import 'package:dealgo/features/voice/domain/usecases/end_voice_call.dart';
import 'package:dealgo/features/voice/domain/usecases/get_voice_call.dart';
import 'package:dealgo/features/voice/domain/usecases/get_voice_call_config.dart';
import 'package:dealgo/features/voice/domain/usecases/start_voice_call.dart';
import 'package:dealgo/features/voice/presentation/cubit/voice_call_cubit.dart';
import 'package:dealgo/features/voice/presentation/widgets/voice_call_host.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  _Harness({bool micGranted = true, this._token = 'tok'})
    : voice = FakeVoiceClient(),
      media = FakeVoiceMediaEngine(micGranted: micGranted) {
    final repo = VoiceRepositoryImpl(voice);
    cubit = VoiceCallCubit(
      startVoiceCall: StartVoiceCall(repo),
      answerVoiceCall: AnswerVoiceCall(repo),
      endVoiceCall: EndVoiceCall(repo),
      getVoiceCall: GetVoiceCall(repo),
      getVoiceCallConfig: GetVoiceCallConfig(repo),
      media: media,
      callEvents: events.stream,
      reconnects: reconnects.stream,
      accessToken: () => _token,
      currentUserId: () => 'me',
      endedHold: const Duration(milliseconds: 5),
      ringGrace: Duration.zero,
    );
  }

  final FakeVoiceClient voice;
  final FakeVoiceMediaEngine media;
  final events = StreamController<Map<String, Object?>>.broadcast();
  final reconnects = StreamController<void>.broadcast();
  String? _token;

  late final VoiceCallCubit cubit;

  set token(String? value) => _token = value;

  void push(VoiceCall call, {String? status, String? endReason}) {
    events.add({
      'callId': call.id,
      'aggregateType': call.kind == VoiceThreadKind.ride ? 'Ride' : 'FoodOrder',
      'aggregateId': call.aggregateId,
      'status': status ?? 'RINGING',
      'callerUserId': call.callerUserId,
      'calleeUserId': call.calleeUserId,
      'callerRole': call.callerIsCustomer ? 'CUSTOMER' : 'DRIVER',
      'ringUntil': call.ringUntil.toIso8601String(),
      'endReason': ?endReason,
    });
  }

  Future<void> dispose() async {
    await cubit.close();
    await events.close();
    await reconnects.close();
  }
}

class _FakeRinger implements CallRinger {
  final log = <String>[];

  @override
  Future<void> start() async => log.add('start');

  @override
  Future<void> stop() async => log.add('stop');
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  test('outgoing call joins the room, goes live on accept, hangs up', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    expect(h.cubit.state.phase, VoiceCallPhase.outgoing);
    expect(h.media.joined, isTrue);
    expect(h.media.micOn, isTrue);
    final call = h.cubit.state.call!;
    expect(h.voice.actions, ['start:ride-1']);

    h.push(call, status: 'ACCEPTED');
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.active);
    // Accepted on the server, but the callee is not in the room yet.
    expect(h.cubit.state.connectedAt, isNull);
    h.media.emit(VoiceMediaEvent.remoteJoined);
    await _settle();
    expect(h.cubit.state.connectedAt, isNotNull);

    await h.cubit.toggleMute();
    await h.cubit.toggleSpeaker();
    expect(h.cubit.state.muted, isTrue);
    expect(h.cubit.state.speakerOn, isTrue);
    expect(h.media.log, containsAll(['mic:false', 'speaker:true']));

    await h.cubit.hangUp();
    expect(h.cubit.state.phase, VoiceCallPhase.ended);
    expect(h.cubit.state.notice, VoiceCallNotice.hungUp);
    expect(h.media.joined, isFalse);
    expect(h.voice.actions.last, 'end:${call.id}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.cubit.state.phase, VoiceCallPhase.idle);
    await h.dispose();
  });

  test('caller clock waits for the callee to be in the room', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    h.push(h.cubit.state.call!, status: 'ACCEPTED');
    await _settle();
    expect(h.cubit.state.connectedAt, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final before = DateTime.now();
    h.media.emit(VoiceMediaEvent.remoteJoined);
    await _settle();
    final at = h.cubit.state.connectedAt!;
    expect(at.isBefore(before), isFalse);
    // Reconnects and duplicate joins (track subscribed) keep the same start.
    h.media.emit(VoiceMediaEvent.reconnecting);
    h.media.emit(VoiceMediaEvent.reconnected);
    h.media.emit(VoiceMediaEvent.remoteJoined);
    await _settle();
    expect(h.cubit.state.connectedAt, at);
    await h.dispose();
  });

  test('callee clock starts when joined with the caller present', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.push(call);
    await _settle();
    // Caller is already in the room: the engine reports it during join.
    h.media.emit(VoiceMediaEvent.remoteJoined);
    await _settle();
    expect(h.cubit.state.connectedAt, isNull);
    await h.cubit.accept();
    expect(h.cubit.state.phase, VoiceCallPhase.active);
    expect(h.cubit.state.connectedAt, isNotNull);
    await h.dispose();
  });

  test('callee decline reaches the caller as "declined"', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.foodOrder, 'order-1');
    h.push(h.cubit.state.call!, status: 'DECLINED', endReason: 'DECLINED');
    await _settle();
    expect(h.cubit.state.notice, VoiceCallNotice.declined);
    expect(h.media.joined, isFalse);
    await h.dispose();
  });

  test('microphone denied stops before any server call', () async {
    final h = _Harness(micGranted: false);
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    expect(h.cubit.state.notice, VoiceCallNotice.micDenied);
    expect(h.voice.actions, isEmpty);
    await h.dispose();
  });

  test('VOICE_DISABLED hides the call button', () async {
    final h = _Harness();
    expect(h.cubit.state.enabled, isFalse);
    await h.cubit.refreshConfig();
    expect(h.cubit.state.enabled, isTrue);
    h.voice.error = const ApiException(
      statusCode: 403,
      message: 'off',
      errorCode: 'VOICE_DISABLED',
    );
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    expect(h.cubit.state.enabled, isFalse);
    expect(h.cubit.state.notice, VoiceCallNotice.failed);
    await h.dispose();
  });

  test('incoming call rings, accept joins and goes live', () async {
    final h = _Harness();
    final call = h.voice.ring(callerIsCustomer: true);
    h.push(call);
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.incoming);
    expect(h.cubit.peerIsCustomer, isTrue);
    expect(h.media.joined, isFalse);

    await h.cubit.accept();
    expect(h.cubit.state.phase, VoiceCallPhase.active);
    expect(h.media.joined, isTrue);
    expect(h.voice.actions, ['accept:${call.id}']);

    h.media.emit(VoiceMediaEvent.remoteLeft);
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.ended);
    expect(h.voice.actions.last, 'end:${call.id}');
    await h.dispose();
  });

  test('incoming decline tells the server and closes the screen', () async {
    final h = _Harness();
    final call = h.voice.ring();
    h.push(call);
    await _settle();
    await h.cubit.decline();
    expect(h.voice.actions, ['decline:${call.id}']);
    expect(h.cubit.state.phase, VoiceCallPhase.idle);
    await h.dispose();
  });

  test('unanswered incoming call ends as missed', () {
    // Fake clock: the ring timer and the 5 ms ended-hold only advance when the
    // test says so, so the "ended" state can't reset to idle under CPU load.
    fakeAsync((async) {
      final h = _Harness();
      final call = h.voice.ring();
      h.push(
        VoiceCall(
          id: call.id,
          kind: call.kind,
          aggregateId: call.aggregateId,
          status: VoiceCallStatus.ringing,
          callerUserId: call.callerUserId,
          calleeUserId: 'me',
          callerIsCustomer: false,
          ringUntil: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
      async.flushMicrotasks();
      expect(h.cubit.state.phase, VoiceCallPhase.incoming);
      async
        ..elapse(Duration.zero)
        ..flushMicrotasks();
      expect(h.cubit.state.phase, VoiceCallPhase.ended);
      expect(h.cubit.state.notice, VoiceCallNotice.missed);
      async.elapse(const Duration(milliseconds: 5));
      expect(h.cubit.state.phase, VoiceCallPhase.idle);
      unawaited(h.dispose());
      async.flushMicrotasks();
    });
  });

  test('a second incoming call while busy is declined automatically', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    final other = h.voice.ring(aggregateId: 'ride-2');
    h.push(other);
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.outgoing);
    expect(h.voice.actions, contains('decline:${other.id}'));
    await h.dispose();
  });

  test('trip closing ends a live call with its own notice', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    final call = h.cubit.state.call!;
    h.push(call, status: 'ACCEPTED');
    await _settle();
    h.push(call, status: 'ENDED', endReason: 'TRIP_CLOSED');
    await _settle();
    expect(h.cubit.state.notice, VoiceCallNotice.tripClosed);
    await h.dispose();
  });

  test('socket reconnect asks the server for the real state', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    final call = h.cubit.state.call!;
    // The ENDED event was lost while offline; the server has it.
    await h.voice.end(accessToken: 'tok', callId: call.id);
    h.reconnects.add(null);
    await _settle();
    expect(h.cubit.state.phase, VoiceCallPhase.ended);
    await h.dispose();
  });

  test('push tap before sign-in rings once the session is back', () async {
    final h = _Harness(token: null);
    final call = h.voice.ring();
    await h.cubit.openFromPush({
      'eventType': 'Call.incoming',
      'callId': call.id,
    });
    expect(h.cubit.state.phase, VoiceCallPhase.idle);
    h.token = 'tok';
    await h.cubit.refreshConfig();
    expect(h.cubit.state.phase, VoiceCallPhase.incoming);
    expect(h.cubit.state.call?.id, call.id);
    await h.dispose();
  });

  test('media drop ends the call on the server', () async {
    final h = _Harness();
    await h.cubit.start(VoiceThreadKind.ride, 'ride-1');
    final call = h.cubit.state.call!;
    h.media.emit(VoiceMediaEvent.disconnected);
    await _settle();
    expect(h.cubit.state.notice, VoiceCallNotice.connectionLost);
    expect(h.voice.actions.last, 'end:${call.id}');
    await h.dispose();
  });

  test('decoders read the Nest envelope', () {
    final join = decodeVoiceCallJoin({
      'success': true,
      'data': {
        'call': {
          'id': 'c1',
          'aggregateType': 'Ride',
          'aggregateId': 'r1',
          'status': 'RINGING',
          'callerUserId': 'me',
          'calleeUserId': 'drv',
          'callerRole': 'CUSTOMER',
          'ringUntil': '2026-10-26T10:00:40.000Z',
        },
        'session': {
          'roomName': 'dealgo-ride-r1',
          'token': 'jwt',
          'url': 'wss://livekit.example',
        },
      },
    });
    expect(join.call.id, 'c1');
    expect(join.call.callerIsCustomer, isTrue);
    expect(join.session.url, 'wss://livekit.example');
    expect(decodeVoiceSession('nope'), isNull);
    expect(VoiceCall.tryParse({'id': 'x'}), isNull);
  });

  testWidgets('call screen shows answer controls, then live controls', (
    tester,
  ) async {
    final h = _Harness();
    final ringer = _FakeRinger();
    await tester.pumpWidget(
      BlocProvider.value(
        value: h.cubit,
        child: MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) =>
              VoiceCallHost(ringer: () => ringer, child: child!),
          home: const Scaffold(body: Text('trip')),
        ),
      ),
    );
    expect(find.byKey(const Key('voice-call-screen')), findsNothing);

    final call = h.voice.ring();
    await tester.runAsync(() async {
      h.push(call);
      await _settle();
    });
    await tester.pump();
    expect(find.byKey(const Key('voice-call-screen')), findsOneWidget);
    expect(find.text('Cuộc gọi đến'), findsOneWidget);
    expect(find.text('Tài xế'), findsOneWidget);
    // Looping ringtone + vibration while it rings…
    expect(ringer.log, ['start']);

    await tester.tap(find.byKey(const Key('voice-accept')));
    await tester.runAsync(_settle);
    await tester.pump();
    // …and silence once answered.
    expect(ringer.log.last, 'stop');
    expect(ringer.log.where((e) => e == 'start'), hasLength(1));
    expect(find.byKey(const Key('voice-mute')), findsOneWidget);
    expect(find.byKey(const Key('voice-hangup')), findsOneWidget);
    // Clock waits until the other party is actually in the room.
    expect(find.text('00:00'), findsNothing);
    await tester.runAsync(() async {
      h.media.emit(VoiceMediaEvent.remoteJoined);
      await _settle();
    });
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voice-mute')));
    await tester.pump();
    expect(find.text('Bật mic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voice-hangup')));
    await tester.runAsync(_settle);
    await tester.pump();
    expect(find.text('Cuộc gọi đã kết thúc'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('voice-call-screen')), findsNothing);
    await tester.runAsync(h.dispose);
  });

  test('platforms declare what a live call needs', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSMicrophoneUsageDescription'));
    expect(plist, contains('<string>audio</string>'));
    // PushKit incoming calls (CallKit) need the voip background mode.
    expect(plist, contains('<string>voip</string>'));
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final permission in [
      'RECORD_AUDIO',
      'MODIFY_AUDIO_SETTINGS',
      'BLUETOOTH_CONNECT',
    ]) {
      expect(manifest, contains('android.permission.$permission'));
    }
  });
}
