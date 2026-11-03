import 'package:dealgo/core/config/api_base_url.dart';
import 'package:dealgo/features/food/presentation/widgets/food_dish_gallery.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('one image renders no counter', (tester) async {
    await _pump(
      tester,
      const FoodDishGallery(
        imageUrls: [],
        fallbackImageUrl: null,
        placeholderAsset: 'assets/images/food_dish.jpg',
      ),
    );

    expect(find.byKey(const Key('food-dish-gallery')), findsNothing);
    expect(find.textContaining('/1'), findsNothing);
  });

  testWidgets('three images page and update the counter', (tester) async {
    await _pump(
      tester,
      const FoodDishGallery(
        imageUrls: ['a.jpg', 'b.jpg', 'c.jpg'],
        fallbackImageUrl: null,
        placeholderAsset: 'assets/images/food_dish.jpg',
      ),
    );

    expect(find.byKey(const Key('food-dish-gallery')), findsOneWidget);
    expect(find.text('Ảnh 1/3'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('food-dish-gallery')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ảnh 2/3'), findsOneWidget);
  });

  testWidgets('a duplicated cover is not shown twice', (tester) async {
    await _pump(
      tester,
      const FoodDishGallery(
        imageUrls: ['a.jpg', 'a.jpg'],
        fallbackImageUrl: 'a.jpg',
        placeholderAsset: 'assets/images/food_dish.jpg',
      ),
    );

    expect(find.byKey(const Key('food-dish-gallery')), findsNothing);
  });

  testWidgets('a shrunken gallery never prints an unreachable counter', (
    tester,
  ) async {
    final urls = ValueNotifier<List<String>>(['a.jpg', 'b.jpg', 'c.jpg']);
    addTearDown(urls.dispose);
    await _pump(
      tester,
      ValueListenableBuilder<List<String>>(
        valueListenable: urls,
        builder: (context, value, _) => FoodDishGallery(
          imageUrls: value,
          fallbackImageUrl: null,
          placeholderAsset: 'assets/images/food_dish.jpg',
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('food-dish-gallery')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ảnh 2/3'), findsOneWidget);

    urls.value = ['a.jpg'];
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-dish-gallery')), findsNothing);

    urls.value = ['a.jpg', 'b.jpg', 'c.jpg'];
    await tester.pumpAndSettle();
    expect(find.text('Ảnh 1/3'), findsOneWidget);
  });

  test('a cover repeated as an absolute URL is one photo', () {
    final absolute = resolveMediaUrl('/media/a.jpg')!;
    final images = foodDishGalleryImages(
      imageUrls: [absolute, 'b.jpg', 'b.jpg'],
      fallbackImageUrl: '/media/a.jpg',
    );

    expect(images, ['/media/a.jpg', 'b.jpg']);
  });
}
