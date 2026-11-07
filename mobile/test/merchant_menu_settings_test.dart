import 'dart:typed_data';

import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/merchant/data/datasources/fake_merchant_orders_client.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_order_page.dart';
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

Future<void> _openItemEdit(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.tap(navLabel('Thực đơn'));
  await tester.pumpAndSettle();
  final edit = find.byKey(const Key('merchant-open-edit-item-1'));
  // Keep above the merchant tab bar so the tap hit-tests the TextButton.
  await Scrollable.ensureVisible(tester.element(edit), alignment: 0.2);
  await tester.pumpAndSettle();
  await tester.tap(edit);
  await tester.pumpAndSettle();
}

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
          FoodMenuItem(
            id: 'item-1',
            name: 'Cơm',
            priceVnd: 30000,
            available: true,
          ),
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
    await tester.enterText(
      find.byKey(const Key('merchant-category-name')),
      'Tráng miệng',
    );
    await tester.tap(find.byKey(const Key('merchant-category-save')));
    await tester.pumpAndSettle();
    expect(client.menuCategories.any((c) => c.name == 'Tráng miệng'), isTrue);
    expect(find.text('Tráng miệng'), findsWidgets);
  });

  testWidgets('M020 lists finished orders and opens order details', (
    tester,
  ) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () =>
          const FoodStoreDetail(id: 'store-1', name: 'Quán Test', items: []),
      onGetOrder: (id) => const FoodOrderDetail(
        id: 'ord-done-1',
        status: 'DELIVERED',
        subtotalVnd: 85000,
        deliveryFareVnd: 10000,
        totalVnd: 95000,
        dropoff: FoodDropoff(lat: 16.0, lng: 108.0, label: '123 Đường Lớn'),
        lines: [],
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
    expect(
      find.byKey(const Key('merchant-history-ord-done-1')),
      findsOneWidget,
    );

    // Tap order to open details
    final orderCard = find.byKey(
      const Key('merchant-history-order-ord-done-1'),
    );
    await tester.ensureVisible(orderCard);
    await tester.tap(orderCard);
    await tester.pumpAndSettle();

    expect(find.byType(MerchantOrderPage), findsOneWidget);
    expect(find.textContaining('95.000'), findsWidgets);
  });

  testWidgets('M020 search and filter interaction with summary and reset', (
    tester,
  ) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () =>
          const FoodStoreDetail(id: 'store-1', name: 'Quán Test', items: []),
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

    // Verify compact summary strip on body
    expect(find.textContaining('Doanh thu món'), findsOneWidget);

    // Open detailed filter & stats bottom sheet
    await tester.tap(find.byKey(const Key('merchant-history-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bộ lọc & Thống kê chi tiết'), findsOneWidget);
    expect(find.text('Tổng quan theo bộ lọc'), findsOneWidget);
    expect(find.text('Khoảng thời gian'), findsOneWidget);

    // Close the bottom sheet
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();

    // Enter search that yields no results
    final searchInput = find.byKey(const Key('merchant-history-search'));
    await tester.enterText(searchInput, 'NonExistentDish12345');
    await tester.tap(find.byKey(const Key('merchant-history-search-go')));
    await tester.pumpAndSettle();

    // Verify empty search state and reset button
    expect(find.text('Không tìm thấy đơn hàng'), findsOneWidget);
    expect(find.text('Xóa bộ lọc'), findsOneWidget);

    // Tap clear search button
    await tester.tap(find.byKey(const Key('merchant-history-search-clear')));
    await tester.pumpAndSettle();

    // Orders are back
    expect(
      find.byKey(const Key('merchant-history-ord-done-1')),
      findsOneWidget,
    );
  });

  testWidgets('M027 opens edit and saves', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [
          FoodMenuItem(
            id: 'item-1',
            name: 'Cơm',
            priceVnd: 30000,
            available: true,
          ),
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
    await _openItemEdit(tester);
    expect(find.byKey(const Key('merchant-edit-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('merchant-edit-name')),
      'Cơm tấm',
    );
    await tester.enterText(
      find.byKey(const Key('merchant-edit-price')),
      '35000',
    );
    await tester.ensureVisible(find.byKey(const Key('merchant-edit-save')));
    await tester.tap(find.byKey(const Key('merchant-edit-save')));
    await tester.pumpAndSettle();
    expect(client.updateCalls, isNotEmpty);
  });

  testWidgets('M025 reorders categories', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () =>
          const FoodStoreDetail(id: 'store-1', name: 'Quán Test', items: []),
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
    await tester.timedDrag(
      handle,
      const Offset(0, 120),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(client.menuCategories.map((c) => c.name).toList(), [
      secondBefore,
      firstBefore,
    ]);
  });

  testWidgets('M027 uploads item photo together with form save', (tester) async {
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => const FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: [
          FoodMenuItem(
            id: 'item-1',
            name: 'Cơm',
            priceVnd: 30000,
            available: true,
          ),
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
    await _openItemEdit(tester);
    await tester.tap(find.byKey(const Key('merchant-edit-photo-pick')));
    await tester.pumpAndSettle();
    // Staged in-form: not uploaded until the merchant saves the form.
    expect(client.uploadImageCalls, isEmpty);
    expect(
      find.byKey(const Key('merchant-edit-photo-pending-0')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('merchant-edit-save')));
    await tester.tap(find.byKey(const Key('merchant-edit-save')));
    await tester.pumpAndSettle();
    expect(client.uploadImageCalls, contains('item-1'));
  });

  testWidgets('M027 deletes item from menu with confirmation', (tester) async {
    var deleted = false;
    final client = FakeMerchantOrdersClient(
      onGetCatalog: () => FoodStoreDetail(
        id: 'store-1',
        name: 'Quán Test',
        items: deleted
            ? const []
            : const [
                FoodMenuItem(
                  id: 'item-1',
                  name: 'Cơm sườn',
                  priceVnd: 30000,
                  available: true,
                ),
              ],
      ),
      onDeleteItem: (id) {
        if (id == 'item-1') deleted = true;
      },
    );
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      merchantOrdersClient: client,
    );
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.tap(navLabel('Thực đơn'));
    await tester.pumpAndSettle();
    final deleteBtn = find.byKey(const Key('merchant-delete-item-item-1'));
    await Scrollable.ensureVisible(tester.element(deleteBtn), alignment: 0.2);
    await tester.pumpAndSettle();
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-confirm-delete-item-1')));
    await tester.pumpAndSettle();
    expect(client.deleteCalls, ['item-1']);
  });

  testWidgets(
    'M027 quick category & inline option group dialogs dispose controllers after exit animation',
    (tester) async {
      final client = FakeMerchantOrdersClient(
        onGetCatalog: () => const FoodStoreDetail(
          id: 'store-1',
          name: 'Quán Test',
          items: [
            FoodMenuItem(
              id: 'item-1',
              name: 'Cơm',
              priceVnd: 30000,
              available: true,
            ),
          ],
        ),
      );
      await pumpSignedIn(
        tester,
        profile: _merchantProfile,
        merchantOrdersClient: client,
      );
      await _openItemEdit(tester);

      // Quick create category dialog
      await tester.ensureVisible(
        find.byKey(const Key('merchant-edit-category-add')),
      );
      await tester.tap(find.byKey(const Key('merchant-edit-category-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('merchant-edit-quick-category-name')),
        'Tráng miệng',
      );
      await tester.tap(
        find.byKey(const Key('merchant-edit-quick-category-save')),
      );
      // Step frame-by-frame through exit transition
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Inline option group dialog
      await tester.ensureVisible(
        find.byKey(const Key('merchant-edit-add-option-group')),
      );
      await tester.tap(
        find.byKey(const Key('merchant-edit-add-option-group')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('merchant-inline-group-title')),
        'Kích cỡ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('merchant-inline-group-apply')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
