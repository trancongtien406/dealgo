import 'package:dealgo/features/ride/data/emergency_contacts_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'emergency contacts stay on the device, unique by phone, max 3',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await EmergencyContactsStore.load(), isEmpty);
      await EmergencyContactsStore.add(
        const EmergencyContact(name: 'Mẹ', phone: '0901111111'),
      );
      await EmergencyContactsStore.add(
        const EmergencyContact(name: 'Mẹ (mới)', phone: '0901111111'),
      );
      await EmergencyContactsStore.add(
        const EmergencyContact(name: 'Anh', phone: '0902222222'),
      );
      await EmergencyContactsStore.add(
        const EmergencyContact(name: 'Chị', phone: '0903333333'),
      );
      final four = await EmergencyContactsStore.add(
        const EmergencyContact(name: 'Bạn', phone: '0904444444'),
      );
      expect(four.map((c) => c.name), ['Mẹ (mới)', 'Anh', 'Chị']);
      final left = await EmergencyContactsStore.remove('0902222222');
      expect(left.map((c) => c.phone), ['0901111111', '0903333333']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('dealgo.emergencyContacts'), hasLength(2));
    },
  );
}
