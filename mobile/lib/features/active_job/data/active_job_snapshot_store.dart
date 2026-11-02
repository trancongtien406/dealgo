import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/active_job_snapshot.dart';

/// One owner + snapshot pair; the counterpart's phone makes it personal data.
class StoredActiveJob {
  const StoredActiveJob({required this.userId, required this.snapshot});

  final String userId;
  final ActiveJobSnapshot snapshot;
}

abstract interface class ActiveJobSnapshotStore {
  Future<StoredActiveJob?> read();
  Future<void> write(StoredActiveJob value);
  Future<void> clear();
}

/// Keeps the snapshot in the OS keystore (Keychain / Android Keystore), never
/// in plain SharedPreferences.
class SecureActiveJobSnapshotStore implements ActiveJobSnapshotStore {
  SecureActiveJobSnapshotStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'dealgo.activeJob.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredActiveJob?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final userId = decoded['userId'];
      final snapshot = ActiveJobSnapshot.fromJson(decoded['job']);
      if (userId is! String || userId.isEmpty || snapshot == null) return null;
      return StoredActiveJob(userId: userId, snapshot: snapshot);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(StoredActiveJob value) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'userId': value.userId,
          'job': value.snapshot.toJson(),
        }),
      );
    } catch (_) {
      // Offline view falls back to what the page still holds in memory.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

class MemoryActiveJobSnapshotStore implements ActiveJobSnapshotStore {
  MemoryActiveJobSnapshotStore([this.value]);

  StoredActiveJob? value;

  @override
  Future<StoredActiveJob?> read() async => value;

  @override
  Future<void> write(StoredActiveJob value) async => this.value = value;

  @override
  Future<void> clear() async => value = null;
}
