import 'package:dealgo/features/driver_card/data/driver_card_remote_datasource.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/driver_card/presentation/driver_card_tile.dart';
import 'package:dealgo/features/driver_card/presentation/driver_detail_sheet.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {DriverCard? card}) {
  final repo = FakeDriverCardRemoteDataSource();
  if (card != null) repo.offerCards['o1'] = card;
  return RepositoryProvider<DriverCardRepository>.value(
    value: repo,
    child: MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('tapping the driver row opens vehicle, plate and rating', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const DriverCardTile(
          job: DriverCardJob.rideOffer,
          jobId: 'r1',
          offerId: 'o1',
          accessToken: 'token',
        ),
        card: const DriverCard(
          driverId: 'd1',
          displayName: 'Trần Văn Bình',
          vehicleType: 'MOTORBIKE',
          vehicleName: 'Honda Vision',
          vehiclePlate: '43B1-678.90',
          ratingAverage: 4.9,
          ratingCount: 87,
          completedTrips: 1234,
          phone: '+84903334444',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('driver-card-open-detail')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('driver-detail-title')), findsOneWidget);
    expect(find.text('Trần Văn Bình'), findsWidgets);
    expect(find.text('Honda Vision'), findsWidgets);
    expect(find.text('43B1-678.90'), findsOneWidget);
    expect(find.text('Xe máy'), findsOneWidget);
    expect(find.text('4,9 · 87 đánh giá'), findsOneWidget);
    expect(find.text('1.234 chuyến'), findsOneWidget);
    expect(find.text('0903 334 444'), findsWidgets);
  });

  testWidgets('a driver without ratings shows Mới and no invented plate', (
    tester,
  ) async {
    const card = DriverCard(
      driverId: 'd1',
      displayName: 'Lê C',
      vehicleType: 'Xe máy',
      completedTrips: 0,
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => DriverCardRow(
            card: card,
            onOpenDetail: () => showDriverDetailSheet(context, card),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-card-open-detail')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('driver-detail-new')), findsOneWidget);
    expect(find.byKey(const Key('driver-detail-rating')), findsNothing);
    expect(find.byKey(const Key('driver-detail-plate')), findsNothing);
    expect(find.text('Xe máy'), findsWidgets);
    expect(find.text('0 chuyến'), findsOneWidget);
    expect(find.byKey(const Key('driver-detail-avatar-open')), findsNothing);
  });

  testWidgets('a photo opens a still portrait, not a pinch viewer', (
    tester,
  ) async {
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);
    FlutterError.onError = (details) {
      if (details.exception is NetworkImageLoadException) return;
      previous?.call(details);
    };
    const card = DriverCard(
      driverId: 'd1',
      displayName: 'Trần Văn Bình',
      avatarUrl: 'https://example.invalid/driver.jpg',
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => DriverCardRow(
            card: card,
            onOpenDetail: () => showDriverDetailSheet(context, card),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-card-open-detail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('driver-detail-avatar-open')), findsOneWidget);
    await tester.tap(find.byKey(const Key('driver-detail-avatar-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('driver-avatar-preview')), findsOneWidget);
    expect(find.byKey(const Key('driver-avatar-preview-name')), findsOneWidget);
    expect(find.text('Trần Văn Bình'), findsWidgets);
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.byKey(const Key('driver-avatar-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('driver-avatar-preview')), findsNothing);
  });
}
