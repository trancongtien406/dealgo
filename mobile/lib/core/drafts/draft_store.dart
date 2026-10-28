import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unsent form drafts that survive the app being killed mid-flow.
///
/// Field values (may hold ID / bank numbers) live in the OS keystore; document
/// photos are AES-GCM encrypted files inside the app sandbox, never plain.
abstract interface class DraftStore {
  Future<Map<String, Object?>?> read(String key);
  Future<void> write(String key, Map<String, Object?> data);

  /// Drops the fields and every blob of [key].
  Future<void> clear(String key);

  Future<Uint8List?> readBlob(String key, String name);
  Future<void> writeBlob(String key, String name, Uint8List bytes);
  Future<void> deleteBlob(String key, String name);
}

/// Production store: keystore JSON + a SharedPreferences marker + encrypted
/// files under `<app support>/drafts/`.
///
/// The marker lives in prefs, which an uninstall wipes; the iOS keychain does
/// not, so a draft without its marker is treated as gone (and deleted).
class SecureDraftStore implements DraftStore {
  SecureDraftStore({
    FlutterSecureStorage? secure,
    Future<SharedPreferences> Function()? prefs,
    Future<Directory> Function()? baseDir,
  }) : _secure = secure ?? const FlutterSecureStorage(),
       _prefs = prefs ?? SharedPreferences.getInstance,
       _baseDir = baseDir ?? getApplicationSupportDirectory;

  static const _prefix = 'draft.v1.';
  static const _keyName = 'draft.v1.blob-key';

  final FlutterSecureStorage _secure;
  final Future<SharedPreferences> Function() _prefs;
  final Future<Directory> Function() _baseDir;
  Uint8List? _blobKey;

  @override
  Future<Map<String, Object?>?> read(String key) async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool('$_prefix$key') != true) {
        await _secure.delete(key: '$_prefix$key');
        return null;
      }
      final raw = await _secure.read(key: '$_prefix$key');
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, Object?> data) async {
    try {
      await _secure.write(key: '$_prefix$key', value: jsonEncode(data));
      await (await _prefs()).setBool('$_prefix$key', true);
    } catch (_) {
      // Best effort: a lost draft only costs re-typing.
    }
  }

  @override
  Future<void> clear(String key) async {
    try {
      await (await _prefs()).remove('$_prefix$key');
      await _secure.delete(key: '$_prefix$key');
      final dir = await _dirFor(key);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  @override
  Future<Uint8List?> readBlob(String key, String name) async {
    try {
      final file = File('${(await _dirFor(key)).path}/${_safe(name)}.bin');
      if (!await file.exists()) {
        return null;
      }
      return DraftCipher(await _key()).open(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeBlob(String key, String name, Uint8List bytes) async {
    try {
      final dir = await _dirFor(key);
      await dir.create(recursive: true);
      final file = File('${dir.path}/${_safe(name)}.bin');
      await file.writeAsBytes(
        DraftCipher(await _key()).seal(bytes),
        flush: true,
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteBlob(String key, String name) async {
    try {
      final file = File('${(await _dirFor(key)).path}/${_safe(name)}.bin');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<Directory> _dirFor(String key) async =>
      Directory('${(await _baseDir()).path}/drafts/${_safe(key)}');

  Future<Uint8List> _key() async {
    final cached = _blobKey;
    if (cached != null) {
      return cached;
    }
    final stored = await _secure.read(key: _keyName);
    if (stored != null && stored.isNotEmpty) {
      return _blobKey = base64Decode(stored);
    }
    final fresh = DraftCipher.randomBytes(32);
    await _secure.write(key: _keyName, value: base64Encode(fresh));
    return _blobKey = fresh;
  }

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}

/// AES-256-GCM: `nonce(12) | ciphertext | tag(16)`.
class DraftCipher {
  DraftCipher(this._key) : assert(_key.length == 32);

  final Uint8List _key;

  static final _random = Random.secure();

  static Uint8List randomBytes(int length) => Uint8List.fromList([
    for (var i = 0; i < length; i++) _random.nextInt(256),
  ]);

  Uint8List seal(Uint8List plain) {
    final nonce = randomBytes(12);
    final cipher = GCMBlockCipher(
      AESEngine(),
    )..init(true, AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)));
    final body = cipher.process(plain);
    return Uint8List.fromList([...nonce, ...body]);
  }

  /// Throws when the data was tampered with or the key changed.
  Uint8List open(Uint8List sealed) {
    final nonce = Uint8List.sublistView(sealed, 0, 12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)),
      );
    return cipher.process(Uint8List.sublistView(sealed, 12));
  }
}

/// In-memory store for tests and mock mode.
class MemoryDraftStore implements DraftStore {
  final fields = <String, Map<String, Object?>>{};
  final blobs = <String, Map<String, Uint8List>>{};

  @override
  Future<Map<String, Object?>?> read(String key) async {
    final data = fields[key];
    return data == null
        ? null
        : jsonDecode(jsonEncode(data)) as Map<String, Object?>;
  }

  @override
  Future<void> write(String key, Map<String, Object?> data) async {
    fields[key] = jsonDecode(jsonEncode(data)) as Map<String, Object?>;
  }

  @override
  Future<void> clear(String key) async {
    fields.remove(key);
    blobs.remove(key);
  }

  @override
  Future<Uint8List?> readBlob(String key, String name) async =>
      blobs[key]?[name];

  @override
  Future<void> writeBlob(String key, String name, Uint8List bytes) async {
    (blobs[key] ??= {})[name] = bytes;
  }

  @override
  Future<void> deleteBlob(String key, String name) async {
    blobs[key]?.remove(name);
  }
}

/// Debounced writer for one draft key; also keeps document blobs in sync.
class DraftKeeper {
  DraftKeeper({
    required this.store,
    required this.key,
    this.delay = const Duration(milliseconds: 300),
    this.maxAge = const Duration(days: 30),
  });

  final DraftStore store;
  final String key;
  final Duration delay;
  final Duration maxAge;

  Timer? _timer;
  Map<String, Object?>? _pending;
  var _generation = 0;

  /// Fields saved earlier, or null when none / expired.
  Future<Map<String, Object?>?> load() async {
    final data = await store.read(key);
    if (data == null) {
      return null;
    }
    final savedAt = DateTime.tryParse('${data['savedAt']}');
    if (savedAt == null || DateTime.now().difference(savedAt) > maxAge) {
      await store.clear(key);
      return null;
    }
    return data;
  }

  void schedule(Map<String, Object?> fields) {
    _pending = {...fields, 'savedAt': DateTime.now().toIso8601String()};
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final data = _pending;
    _pending = null;
    if (data != null) {
      final generation = _generation;
      await store.write(key, data);
      // A clear() that raced this write wins: never resurrect a sent draft.
      if (generation != _generation) {
        await store.clear(key);
      }
    }
  }

  Future<void> clear() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    await store.clear(key);
  }
}
