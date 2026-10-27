import 'package:dealgo/features/account_deletion/data/account_deletion_remote_datasource.dart';
import 'package:dealgo/features/account_deletion/domain/account_deletion.dart';
import 'package:dealgo/features/account_deletion/presentation/delete_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

Future<void> _openDelete(
  WidgetTester tester,
  FakeAccountDeletionRepository repo,
) async {
  await pumpSignedIn(tester, profile: customerProfile, accountDeletion: repo);
  await tester.tap(navLabel('Tôi'));
  await tester.pumpAndSettle();
  final row = find.byKey(const ValueKey('account-delete-row'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('delete-account-form')), findsOneWidget);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('delete-account-form')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _fillForm(WidgetTester tester) async {
  final backup = find.byKey(const ValueKey('delete-check-backup'));
  await _reveal(tester, backup);
  await tester.tap(
    find.descendant(of: backup, matching: find.byType(Checkbox)),
  );
  await tester.pump();
  final word = find.byKey(const ValueKey('delete-confirm-word'));
  await _reveal(tester, word);
  await tester.enterText(word, 'xóa');
  await tester.pump();
}

FilledButton _button(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(FilledButton),
      ),
    );

void main() {
  test('the typed word accepts both Vietnamese spellings only', () {
    expect(isDeleteConfirmationWord(' xóa '), isTrue);
    expect(isDeleteConfirmationWord('XOÁ'), isTrue);
    expect(isDeleteConfirmationWord('XOA'), isTrue);
    expect(isDeleteConfirmationWord('DELETE'), isFalse);
    expect(isDeleteConfirmationWord(''), isFalse);
  });

  test('blockers decode from the 409 details', () {
    final blockers = decodeAccountDeletionBlockers([
      {'code': 'ACTIVE_RIDE', 'count': 1},
      {'code': 'UNSETTLED_COD', 'amountVnd': 15000},
    ]);
    expect(blockers.map((b) => b.code), ['ACTIVE_RIDE', 'UNSETTLED_COD']);
    expect(blockers.last.amountVnd, 15000);
  });

  testWidgets('S027 shows the server blockers and keeps the request disabled', (
    tester,
  ) async {
    final repo = FakeAccountDeletionRepository(
      blockers: const [
        AccountDeletionBlocker(code: 'ACTIVE_RIDE', count: 1),
        AccountDeletionBlocker(code: 'UNSETTLED_COD', amountVnd: 15000),
      ],
    );
    await _openDelete(tester, repo);

    await _reveal(tester, find.text('Bạn đang có 1 chuyến xe chưa kết thúc.'));
    expect(find.text('Bạn đang có 1 chuyến xe chưa kết thúc.'), findsOneWidget);
    expect(find.textContaining('15.000đ'), findsOneWidget);
    expect(
      find.text('Không có chuyến hoặc đơn đang thực hiện'),
      findsOneWidget,
    );
    await _fillForm(tester);
    expect(_button(tester, 'delete-continue').onPressed, isNull);
    expect(repo.calls, ['overview']);
  });

  testWidgets(
    'S027 OTP: needs the word and backup tick, rejects a wrong code, then schedules',
    (tester) async {
      final repo = FakeAccountDeletionRepository();
      await _openDelete(tester, repo);
      expect(find.text('Tiếp tục yêu cầu xóa'), findsOneWidget);
      expect(_button(tester, 'delete-continue').onPressed, isNull);

      await _fillForm(tester);
      expect(_button(tester, 'delete-continue').onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('delete-continue')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('delete-account-verify')),
        findsOneWidget,
      );
      expect(find.textContaining('090***4567'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('delete-secret')),
        '000000',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Mã xác minh không đúng.'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-done')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('delete-secret')),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account-done')), findsOneWidget);
      expect(find.text('Đã ghi nhận yêu cầu xoá'), findsOneWidget);
      expect(find.textContaining('26/10/2026'), findsOneWidget);
      expect(repo.calls, [
        'overview',
        'start',
        'confirm:000000',
        'confirm:123456',
      ]);

      await tester.tap(find.byKey(const ValueKey('delete-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account-done')), findsNothing);
      expect(navLabel('Tôi'), findsNothing);
    },
  );

  testWidgets('S027 password re-auth when there is no verified phone', (
    tester,
  ) async {
    final repo = FakeAccountDeletionRepository(
      method: AccountDeletionMethod.password,
    );
    await _openDelete(tester, repo);
    await _fillForm(tester);
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('delete-secret')),
      'password123',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-account-done')), findsOneWidget);
    expect(repo.calls.last, 'confirm:password123');
  });

  testWidgets('S027 locks after five wrong codes and offers a new request', (
    tester,
  ) async {
    final repo = FakeAccountDeletionRepository();
    await _openDelete(tester, repo);
    await _fillForm(tester);
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.enterText(
        find.byKey(const ValueKey('delete-secret')),
        '11111$i',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Nhập sai quá nhiều lần'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-restart')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'start').length, 2);
    expect(find.byKey(const ValueKey('delete-confirm')), findsOneWidget);
  });
}
