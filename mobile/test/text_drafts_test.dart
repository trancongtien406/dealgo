import 'package:dealgo/core/drafts/draft_store.dart';
import 'package:dealgo/core/drafts/text_draft.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/food_cart_draft.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// T85 — typed forms and the food cart survive an app kill.
class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> with TextDraftMixin {
  final note = TextEditingController();
  var stars = 0;

  @override
  void initState() {
    super.initState();
    bindTextDraft(
      'test.form',
      {'note': note},
      extras: () => {'stars': stars},
      restoreExtras: (saved) {
        final v = saved['stars'];
        if (v is! int || v == stars) return false;
        setState(() => stars = v);
        return true;
      },
    );
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(key: const Key('note'), controller: note),
        Text('stars=$stars'),
        TextButton(
          onPressed: () {
            setState(() => stars = 4);
            markTextDraftDirty();
          },
          child: const Text('rate'),
        ),
        TextButton(onPressed: clearTextDraft, child: const Text('send')),
      ],
    ),
  );
}

Widget _app() => const MaterialApp(
  locale: Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: _Form(),
);

void main() {
  late MemoryDraftStore store;
  var user = 'user-1';

  setUp(() {
    store = MemoryDraftStore();
    user = 'user-1';
    FormDrafts.store = store;
    FormDrafts.owner = () => user;
  });

  tearDown(() {
    FormDrafts.store = null;
    FormDrafts.owner = null;
  });

  testWidgets('text + extras restore after a kill, clear on send', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note')), 'Giao trước 7h');
    await tester.tap(find.text('rate'));
    await tester.pump(const Duration(milliseconds: 400));
    // "Kill": tear the tree down and start again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump();
    expect(find.text('Giao trước 7h'), findsOneWidget);
    expect(find.text('stars=4'), findsOneWidget);
    expect(find.text('Đã khôi phục bản nháp chưa gửi.'), findsOneWidget);

    await tester.tap(find.text('send'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.fields, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump();
    expect(find.text('Giao trước 7h'), findsNothing);
    expect(find.text('stars=0'), findsOneWidget);
  });

  testWidgets('drafts are per user and off without DI', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note')), 'riêng tư');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    user = 'user-2';
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump();
    expect(find.text('riêng tư'), findsNothing);
    await tester.pumpWidget(const SizedBox());

    FormDrafts.store = null;
    store.fields.clear();
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note')), 'x');
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.fields, isEmpty);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  FoodCartCubit fill(FoodCartCubit cart) {
    cart.addConfiguredItem(
      storeId: 'store-1',
      storeName: 'Quán Bà Ba',
      lineId: 'item-1',
      name: 'Cơm tấm',
      unitPriceVnd: 45000,
      catalogItemId: 'item-1',
      optionIds: const ['opt-egg'],
    );
    cart.setDropoff(label: '12 Lê Lợi, Q1', lat: 10.77, lng: 106.70);
    return cart;
  }

  test(
    'food cart comes back after a kill with the same idempotency key',
    () async {
      final first = fill(attachFoodCartDraft(FoodCartCubit()));
      await settle();
      final key = first.state.idempotencyKey;
      await first.close();

      final second = attachFoodCartDraft(FoodCartCubit());
      await settle();
      expect(second.state.lines.single.name, 'Cơm tấm');
      expect(second.state.lines.single.optionIds, ['opt-egg']);
      expect(second.state.dropoffLabel, '12 Lê Lợi, Q1');
      expect(second.state.idempotencyKey, key);

      // Order accepted -> checkout rotates the key -> cart is not resurrected.
      second.rotateIdempotencyKey();
      await settle();
      await second.close();
      final third = attachFoodCartDraft(FoodCartCubit());
      await settle();
      expect(third.state.lines, isEmpty);
      await third.close();
    },
  );

  test('food cart restores only for its owner, once signed in', () async {
    final first = fill(attachFoodCartDraft(FoodCartCubit()));
    await settle();
    await first.close();

    user = '';
    final auth = Stream<Object?>.periodic(const Duration(milliseconds: 50))
        .take(1);
    final cart = attachFoodCartDraft(FoodCartCubit(), ownerChanges: auth);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cart.state.lines, isEmpty);
    user = 'user-2';
    await settle();
    expect(cart.state.lines, isEmpty, reason: 'other user');
    await cart.close();

    user = 'user-1';
    final mine = attachFoodCartDraft(FoodCartCubit());
    await settle();
    expect(mine.state.lines, hasLength(1));
    await mine.close();
  });
}
