import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_store_card.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _full = FoodStoreSummary(
  id: 's1',
  name: 'Bún Bò Huế Cô Hoa Hai Bà Trưng Quận 1',
  category: 'pho',
  distanceKm: 1.2,
  etaMinutes: 25,
  deliveryFeeFromVnd: 15000,
  ratingAverage: 4.8,
  ratingCount: 120,
  closesAtToday: '22:00',
);

const _long = FoodStoreSummary(
  id: 's3',
  name: 'Quán Ăn Vặt Sinh Viên Số 1 Sài Gòn',
  category: 'dessert',
  distanceKm: 12.4,
  etaMinutes: 45,
  deliveryFeeFromVnd: 25000,
  ratingAverage: 4.95,
  ratingCount: 128000,
  closesAtToday: '23:55',
);

void main() {
  for (final scale in [1.0, 1.15, 1.3, 1.6, 2.0]) {
    for (final entry in {'full': _full, 'long': _long}.entries) {
      testWidgets('rail ${entry.key} @$scale', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: DealGoTheme.light,
            locale: const Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  SizedBox(
                    height: 128 * (scale < 1 ? 1 : scale),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: 2,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: 288,
                        child: FoodStoreCard(
                          store: index == 0 ? entry.value : _full,
                          variant: FoodStoreCardVariant.compact,
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
