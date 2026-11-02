import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

/// One contact picked for a parcel recipient.
class PickedContact {
  const PickedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Opens the OS contact picker (CNContactPickerViewController / Android
/// pick intent). The system picker needs no READ_CONTACTS permission: the
/// user grants access to the one contact they tap.
abstract interface class ContactPicker {
  Future<PickedContact?> pickPhone();
}

class NativeContactPicker implements ContactPicker {
  NativeContactPicker([FlutterNativeContactPicker? picker])
    : _picker = picker ?? FlutterNativeContactPicker();

  final FlutterNativeContactPicker _picker;

  @override
  Future<PickedContact?> pickPhone() async {
    final contact = await _picker.selectPhoneNumber();
    if (contact == null) return null;
    final phone =
        contact.selectedPhoneNumber ??
        ((contact.phoneNumbers?.isNotEmpty ?? false)
            ? contact.phoneNumbers!.first
            : null);
    if (phone == null) return null;
    return PickedContact(
      name: (contact.fullName ?? '').trim(),
      phone: normalizeVnPhone(phone),
    );
  }
}

/// `+84 912 345 678` / `0912.345.678` → `0912345678`.
String normalizeVnPhone(String raw) {
  var s = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (s.startsWith('+84')) s = '0${s.substring(3)}';
  if (s.startsWith('84') && s.length == 11) s = '0${s.substring(2)}';
  return s;
}
