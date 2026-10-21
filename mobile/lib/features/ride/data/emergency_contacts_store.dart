import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, String> toJson() => {'name': name, 'phone': phone};
}

/// Safety contacts the customer adds on this device only (never uploaded).
class EmergencyContactsStore {
  EmergencyContactsStore._();

  static const _key = 'dealgo.emergencyContacts';
  static const maxContacts = 3;
  static List<EmergencyContact> _memory = const [];

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<List<EmergencyContact>> load() async {
    final prefs = await _prefs();
    final raw = prefs?.getStringList(_key);
    if (raw == null) return _memory;
    return [for (final entry in raw) ?_decode(entry)];
  }

  static Future<List<EmergencyContact>> add(EmergencyContact contact) async {
    final current = await load();
    final next = [
      ...current.where((c) => c.phone != contact.phone),
      contact,
    ].take(maxContacts).toList(growable: false);
    await _save(next);
    return next;
  }

  static Future<List<EmergencyContact>> remove(String phone) async {
    final next = [
      for (final c in await load())
        if (c.phone != phone) c,
    ];
    await _save(next);
    return next;
  }

  static Future<void> _save(List<EmergencyContact> contacts) async {
    _memory = List.unmodifiable(contacts);
    final prefs = await _prefs();
    await prefs?.setStringList(_key, [
      for (final c in contacts) jsonEncode(c.toJson()),
    ]);
  }

  static EmergencyContact? _decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map && map['name'] is String && map['phone'] is String) {
        return EmergencyContact(
          name: map['name'] as String,
          phone: map['phone'] as String,
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
