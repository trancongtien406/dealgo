import 'dart:typed_data';

import 'package:dealgo/core/app_gate/app_build_info.dart';
import 'package:dealgo/core/app_gate/app_gate_client.dart';
import 'package:dealgo/core/app_gate/app_gate_cubit.dart';
import 'package:dealgo/core/app_gate/app_gate_host.dart';
import 'package:dealgo/core/app_gate/app_gate_models.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_l10n.dart';

class _FakeClient implements AppGateClient {
  AppUpdateInfo info = AppUpdateInfo.none;
  List<PendingConsent> pending = [];
  final accepted = <String>[];
  bool failVersion = false;

  @override
  Future<AppUpdateInfo> versionPolicy({
    required String platform,
    required int build,
  }) async {
    if (failVersion) throw Exception('offline');
    return info;
  }

  @override
  Future<List<PendingConsent>> pendingConsents() async => pending;

  @override
  Future<void> acceptConsent(String id) async {
    accepted.add(id);
    pending = pending.where((c) => c.id != id).toList();
  }
}

const _terms = PendingConsent(
  id: 'v1',
  slug: 'terms',
  version: 2,
  title: 'Điều khoản sử dụng',
  changelog: 'Cập nhật phí',
  url: 'https://example.test/terms',
);

AppBuildInfo _build() => AppBuildInfo(platform: 'ios', build: 10);

Future<void> _pump(WidgetTester t, AppGateCubit c, {List<String>? opened}) =>
    t.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        locale: testLocale,
        home: BlocProvider.value(
          value: c,
          child: AppGateHost(
            openUrl: (u) async => opened?.add(u),
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );

void main() {
  test('verdicts + fail open', () async {
    final client = _FakeClient()
      ..info = const AppUpdateInfo(verdict: AppUpdateVerdict.optional);
    final c = AppGateCubit(client: client, build: _build());
    await c.checkVersion();
    expect(c.state.showOptionalPrompt, isTrue);
    c.dismissOptional();
    expect(c.state.showOptionalPrompt, isFalse);
    client.failVersion = true;
    await c.checkVersion();
    expect(c.state.updateRequired, isFalse);
    c.forceRequired();
    expect(c.state.updateRequired, isTrue);
    await c.close();
  });

  test('disabled cubit (null client) never blocks', () async {
    final c = AppGateCubit(client: null, build: _build());
    await c.checkVersion();
    await c.setSignedIn(true);
    expect(c.state.updateRequired || c.state.consentRequired, isFalse);
    await c.close();
  });

  testWidgets('required update covers the app', (t) async {
    final client = _FakeClient()
      ..info = const AppUpdateInfo(
        verdict: AppUpdateVerdict.required,
        storeUrl: 'https://store.test/app',
      );
    final c = AppGateCubit(client: client, build: _build());
    await c.checkVersion();
    final opened = <String>[];
    await _pump(t, c, opened: opened);
    expect(find.byKey(const Key('app-update-required')), findsOneWidget);
    await t.tap(find.byKey(const Key('app-update-now')));
    expect(opened, ['https://store.test/app']);
    await c.close();
  });

  testWidgets('optional prompt can be dismissed', (t) async {
    final client = _FakeClient()
      ..info = const AppUpdateInfo(verdict: AppUpdateVerdict.optional);
    final c = AppGateCubit(client: client, build: _build());
    await c.checkVersion();
    await _pump(t, c);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('app-update-optional')), findsOneWidget);
    await t.tap(find.byKey(const Key('app-update-later')));
    await t.pump();
    expect(find.byKey(const Key('app-update-optional')), findsNothing);
    await c.close();
  });

  testWidgets('consent tray over visible home; one accept for all docs', (
    t,
  ) async {
    const privacy = PendingConsent(
      id: 'v2',
      slug: 'privacy',
      version: 3,
      title: 'Chính sách quyền riêng tư',
      changelog: 'Thêm mục dữ liệu vị trí',
      url: '',
    );
    final client = _FakeClient()..pending = [_terms, privacy];
    final c = AppGateCubit(client: client, build: _build());
    await c.setSignedIn(true);
    await _pump(t, c);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('legal-consent-required')), findsOneWidget);
    expect(find.text('home'), findsOneWidget); // still rendered behind
    expect(find.byKey(const Key('legal-consent-v1')), findsOneWidget);
    expect(find.byKey(const Key('legal-consent-v2')), findsOneWidget);
    // Tap outside: not dismissed.
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('legal-consent-required')), findsOneWidget);
    await t.tap(find.byKey(const Key('legal-consent-agree')));
    await t.pumpAndSettle();
    expect(client.accepted, ['v1', 'v2']);
    expect(find.byKey(const Key('legal-consent-required')), findsNothing);
    await c.setSignedIn(false);
    await c.close();
  });

  test('interceptor adds build headers and maps 426', () async {
    var hits = 0;
    final adapter = _Adapter426();
    final dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AppVersionInterceptor(
          appBuild: _build(),
          onUpdateRequired: () => hits++,
        ),
      );
    await expectLater(
      dio.get<Object?>('https://api.test/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.last!.headers['X-App-Build'], '10');
    expect(adapter.last!.headers['X-App-Platform'], 'ios');
    expect(hits, 1);
  });
}

class _Adapter426 implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      '{"errorCode":"APP_UPDATE_REQUIRED"}',
      426,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
