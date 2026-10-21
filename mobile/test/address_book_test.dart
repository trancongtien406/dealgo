import 'package:dealgo/features/address_book/data/datasources/address_book_remote_datasource.dart';
import 'package:dealgo/features/address_book/domain/entities/saved_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

Future<FakeAddressBookRemoteDataSource> _open(
  WidgetTester tester, {
  List<SavedAddress>? seed,
}) async {
  final book = FakeAddressBookRemoteDataSource(seed: seed);
  await pumpSignedIn(tester, profile: customerProfile, addressBook: book);
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push('/customer/account/addresses');
  await tester.pumpAndSettle();
  return book;
}

Future<void> _fillAndSave(
  WidgetTester tester, {
  String? label,
  required String line,
}) async {
  if (label != null) {
    await tester.enterText(find.byKey(const Key('address-label')), label);
  }
  await tester.enterText(find.byKey(const Key('address-line')), line);
  await tester.ensureVisible(find.byKey(const Key('address-save')));
  await tester.tap(find.byKey(const Key('address-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adds the first address as default from the empty state', (
    tester,
  ) async {
    final book = await _open(tester);
    expect(find.text('Chưa có địa chỉ nào'), findsOneWidget);

    await tester.tap(find.byKey(const Key('address-add')));
    await tester.pumpAndSettle();
    expect(find.text('Thêm địa chỉ'), findsWidgets);
    // Home is preselected and pre-fills the name.
    await _fillAndSave(tester, line: '12 Lê Duẩn, Hải Châu');

    expect(find.text('Nhà'), findsOneWidget);
    expect(find.text('12 Lê Duẩn, Hải Châu'), findsOneWidget);
    expect(find.text('Mặc định'), findsOneWidget);
    final saved = await book.list(accessToken: 't');
    expect(saved.single.kind, SavedAddressKind.home);
    expect(saved.single.isDefault, isTrue);
  });

  testWidgets('validates the form before saving', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('address-add')));
    await tester.pumpAndSettle();
    await _fillAndSave(tester, label: '', line: 'ab');

    expect(find.text('Nhập tên gợi nhớ'), findsOneWidget);
    expect(find.text('Nhập địa chỉ (ít nhất 3 ký tự)'), findsOneWidget);
  });

  testWidgets('sets another address as default and deletes with confirm', (
    tester,
  ) async {
    final book = await _open(
      tester,
      seed: FakeAddressBookRemoteDataSource.sample(),
    );
    expect(find.text('Công ty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('address-menu-addr-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt làm mặc định'));
    await tester.pumpAndSettle();
    var saved = await book.list(accessToken: 't');
    expect(saved.firstWhere((a) => a.isDefault).id, 'addr-work');

    await tester.tap(find.byKey(const Key('address-menu-addr-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();
    expect(find.text('Xóa địa chỉ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('address-delete-confirm')));
    await tester.pumpAndSettle();

    saved = await book.list(accessToken: 't');
    expect(saved.map((a) => a.id), ['addr-work']);
    expect(find.text('Đã xóa địa chỉ'), findsOneWidget);
  });

  testWidgets('the form blocks a second home address', (tester) async {
    await _open(tester, seed: FakeAddressBookRemoteDataSource.sample());
    await tester.tap(find.byKey(const Key('address-add')));
    await tester.pumpAndSettle();
    // Home and work are taken, so "Other" is preselected; switch back to Home.
    await tester.tap(find.text('Nhà').last);
    await tester.pumpAndSettle();
    await _fillAndSave(tester, line: '1 Trần Phú');

    expect(find.byKey(const Key('address-form-error')), findsOneWidget);
  });
}
