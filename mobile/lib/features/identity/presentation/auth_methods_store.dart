import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/auth_method_policy.dart';

enum AuthMethodsStatus { loading, ready, failed }

/// Whether [method] is switched on; with [listen] the caller rebuilds when
/// that changes. Screens mounted without the app's store (isolated widget
/// tests) count every method as on.
bool authMethodEnabled(
  BuildContext context,
  String method, {
  bool listen = true,
}) {
  try {
    return Provider.of<AuthMethodsStore>(
      context,
      listen: listen,
    ).isEnabled(method);
  } on ProviderNotFoundException {
    return true;
  }
}

/// Last known `GET /v1/auth/methods` answer, kept on device so the sign-in
/// picker can draw the real options on the next launch before the network
/// answers.
abstract class AuthMethodsCache {
  Future<List<AuthMethodPolicy>?> read();
  Future<void> write(List<AuthMethodPolicy> methods);
}

class PrefsAuthMethodsCache implements AuthMethodsCache {
  const PrefsAuthMethodsCache();

  static const _key = 'dealgo.authMethods';

  @override
  Future<List<AuthMethodPolicy>?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final list = jsonDecode(raw);
      if (list is! List) return null;
      return [
        for (final item in list.whereType<Map<String, dynamic>>())
          AuthMethodPolicy(
            method: item['method'] as String? ?? '',
            enabled: item['enabled'] as bool? ?? false,
          ),
      ];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(List<AuthMethodPolicy> methods) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode([
          for (final m in methods) {'method': m.method, 'enabled': m.enabled},
        ]),
      );
    } catch (_) {
      // Next launch falls back to the placeholder; nothing else depends on it.
    }
  }
}

class MemoryAuthMethodsCache implements AuthMethodsCache {
  MemoryAuthMethodsCache([this.value]);

  List<AuthMethodPolicy>? value;

  @override
  Future<List<AuthMethodPolicy>?> read() async => value;

  @override
  Future<void> write(List<AuthMethodPolicy> methods) async => value = methods;
}

/// Single source for which sign-in methods are switched on (Admin › Đăng
/// nhập). Never guesses: until the server or the device cache answers the
/// status is [AuthMethodsStatus.loading], so screens draw a placeholder
/// instead of options that could disappear a moment later. Started at app
/// launch, behind the native splash.
class AuthMethodsStore extends ChangeNotifier {
  AuthMethodsStore(
    this._fetch, {
    AuthMethodsCache? cache,
    this.timeout = const Duration(seconds: 10),
  }) : _cache = cache ?? const PrefsAuthMethodsCache();

  final Future<List<AuthMethodPolicy>> Function() _fetch;
  final AuthMethodsCache _cache;
  final Duration timeout;

  AuthMethodsStatus _status = AuthMethodsStatus.loading;
  List<AuthMethodPolicy> _methods = const [];
  Object? _error;
  Future<void>? _inFlight;
  bool _disposed = false;

  AuthMethodsStatus get status => _status;
  Object? get error => _error;

  bool isEnabled(String method) =>
      _status == AuthMethodsStatus.ready &&
      _methods.any((p) => p.method == method && p.enabled);

  /// Cache first (instant), then the server. Concurrent calls share one
  /// request.
  Future<void> load() => _inFlight ??= _load().whenComplete(() {
    _inFlight = null;
  });

  Future<void> retry() {
    if (_status == AuthMethodsStatus.failed) {
      _status = AuthMethodsStatus.loading;
      _notify();
    }
    return load();
  }

  Future<void> _load() async {
    if (_status != AuthMethodsStatus.ready) {
      final cached = await _cache.read();
      if (cached != null && _status != AuthMethodsStatus.ready) {
        _set(AuthMethodsStatus.ready, cached);
      }
    }
    try {
      final fresh = await _fetch().timeout(timeout);
      _error = null;
      _set(AuthMethodsStatus.ready, fresh);
      unawaited(_cache.write(fresh));
    } catch (error) {
      _error = error;
      if (_status != AuthMethodsStatus.ready) {
        _status = AuthMethodsStatus.failed;
        _notify();
      }
    }
  }

  void _set(AuthMethodsStatus status, List<AuthMethodPolicy> methods) {
    final same =
        status == _status &&
        methods.length == _methods.length &&
        [
          for (var i = 0; i < methods.length; i++)
            methods[i].method == _methods[i].method &&
                methods[i].enabled == _methods[i].enabled,
        ].every((e) => e);
    _status = status;
    _methods = List.unmodifiable(methods);
    if (!same) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
