import 'dart:typed_data';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/merchant/data/datasources/fake_merchant_orders_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void main() {
  test('M027 FoodMenuItem carries edit fields', () {
    const item = FoodMenuItem(
      id: 'i1',
      name: 'Phở',
      priceVnd: 45000,
      available: true,
      description: 'Nước trong',
      prepMinutes: 15,
      menuCategoryId: 'cat-1',
    );
    final next = item.copyWith(name: 'Phở bò', priceVnd: 50000);
    expect(next.description, 'Nước trong');
    expect(next.prepMinutes, 15);
    expect(next.name, 'Phở bò');
    expect(next.priceVnd, 50000);
  });

  testWidgets('M025 creates a menu category', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [
          FoodMenuItem(id: 'item-1', name: 'Cơm', priceVnd: 30000, available: true),
        ],
      ),
    );
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      merchantOrdersClient: client,
    );
    await tester.tap(navLabel('Thực đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-open-categories')));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý danh mục'), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchant-category-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('merchant-category-name')), 'Tráng miệng');
    await tester.tap(find.byKey(const Key('merchant-category-save')));
    await tester.pumpAndSettle();
    expect(client.menuCategories.any((c) => c.name == 'Tráng miệng'), isTrue);
    expect(find.text('Tráng miệng'), findsWidgets);
  });

  testWidgets('M020 lists finished orders', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [],
      ),
    );
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      merchantOrdersClient: client,
    );
    await tester.tap(navLabel('Thực đơn'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('merchant-open-history')));
    await tester.tap(find.byKey(const Key('merchant-open-history')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lịch sử'), findsWidgets);
    expect(find.byKey(const Key('merchant-history-ord-done-1')), findsOneWidget);
  });

  testWidgets('M027 opens edit and saves', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [
          FoodMenuItem(id: 'item-1', name: 'Cơm', priceVnd: 30000, available: true),
        ],
      ),
      onUpdateItem: (id, name, price) => FoodMenuItem(
        id: id,
        name: name ?? 'Cơm',
        priceVnd: price ?? 30000,
        available: true,
      ),
    );
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      merchantOrdersClient: client,
    );
    await tester.tap(navLabel('Thực đơn'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('merchant-open-edit-item-1')));
    await tester.tap(find.byKey(const Key('merchant-open-edit-item-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-edit-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('merchant-edit-name')), 'Cơm tấm');
    await tester.enterText(find.byKey(const Key('merchant-edit-price')), '35000');
    await tester.ensureVisible(find.byKey(const Key('merchant-edit-save')));
    await tester.tap(find.byKey(const Key('merchant-edit-save')));
    await tester.pumpAndSettle();
    expect(client.updateCalls, isNotEmpty);
  });

  testWidgets('M025 reorders categories', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [],
      ),
    );
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      merchantOrdersClient: client,
    );
    await tester.tap(navLabel('Thực đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-open-categories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-category-reorder')), findsOneWidget);
    expect(client.menuCategories.length, greaterThanOrEqualTo(2));
    final firstBefore = client.menuCategories.first.name;
    final secondBefore = client.menuCategories[1].name;
    final handle = find.byType(ReorderableDragStartListener).first;
    await tester.timedDrag(handle, const Offset(0, 120), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(client.menuCategories.map((c) => c.name).toList(), [secondBefore, firstBefore]);
  });

  testWidgets('M027 uploads item photo', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [
          FoodMenuItem(id: 'item-1', name: 'Cơm', priceVnd: 30000, available: true),
        ],
      ),
      onUpdateItem: (id, name, price) => FoodMenuItem(
        id: id,
        name: name ?? 'Cơm',
        priceVnd: price ?? 30000,
        available: true,
      ),
    );
    final images = FakeDocumentImageSource(
      nextImage: PickedDocumentImage(
        bytes: Uint8List.fromList(List<int>.filled(64, 1)),
        contentType: 'image/jpeg',
      ),
    );
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      merchantOrdersClient: client,
      documentImageSource: images,
    );
    await tester.tap(navLabel('Thực đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-open-edit-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-edit-photo-pick')));
    await tester.pumpAndSettle();
    expect(client.uploadImageCalls, contains('item-1'));
  });
}
