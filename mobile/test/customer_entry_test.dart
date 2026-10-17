import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  testWidgets('login screen shows Tiếp tục', (tester) async {
    await pumpDealGo(tester, client: FakeIdentityClient());

    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Chào mừng bạn\nđến với DealGo!'), findsOneWidget);
  });

  testWidgets('customer home shows Đặt xe and Đồ ăn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(tester, profile: customerProfile);

    expect(find.text('Đặt xe'), findsWidgets);
    expect(find.text('Đồ ăn'), findsWidgets);
    expect(find.text('Xe máy'), findsOneWidget);
    expect(find.text('Bún Bò Huế Ô Cồ'), findsOneWidget);
    expect(navLabel('Trang chủ'), findsOneWidget);
  });
}
