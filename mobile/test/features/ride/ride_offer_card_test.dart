import 'package:dealgo/features/driver_card/data/driver_card_remote_datasource.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/driver_card/presentation/contact_phone_line.dart';
import 'package:dealgo/features/driver_card/presentation/driver_card_tile.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_offer_countdown.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Offer card shows the real vehicle, inline stars + trips, and the
/// countdown lives in the Accept button only.
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

const _tile = DriverCardTile(
  job: DriverCardJob.rideOffer,
  jobId: 'r1',
  offerId: 'o1',
  accessToken: 'token',
);

void main() {
  test('vehicle line replaces the class with make/model, keeps the plate', () {
    const named = DriverCard(
      driverId: 'd1',
      displayName: 'A',
      vehicleType: 'Xe máy',
      vehicleName: 'Honda Vision',
      vehiclePlate: '43B1-678.90',
    );
    expect(named.vehicleLine, 'Honda Vision · 43B1-678.90');
    const legacy = DriverCard(
      driverId: 'd1',
      displayName: 'A',
      vehicleType: 'Xe máy',
    );
    expect(legacy.vehicleLine, 'Xe máy');
  });

  testWidgets('rating and trips sit next to the name', (t) async {
    await t.pumpWidget(
      _app(
        _tile,
        card: const DriverCard(
          driverId: 'd1',
          displayName: 'Trần Văn Bình',
          vehicleType: 'Ô tô',
          vehicleName: 'Mitsubishi Xpander',
          ratingAverage: 4.9,
          ratingCount: 87,
          completedTrips: 1234,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Mitsubishi Xpander'), findsOneWidget);
    expect(find.text('Ô tô'), findsNothing);
    expect(find.text('4,9'), findsOneWidget);
    expect(find.text(' · 1.234 chuyến'), findsOneWidget);
    final nameY = t.getCenter(find.byKey(const Key('driver-card-name'))).dy;
    final ratingY = t.getCenter(find.byKey(const Key('driver-card-rating'))).dy;
    expect((nameY - ratingY).abs(), lessThan(4));
  });

  testWidgets('new driver shows Mới and falls back to the class', (t) async {
    await t.pumpWidget(
      _app(
        _tile,
        card: const DriverCard(
          driverId: 'd1',
          displayName: 'Lê C',
          vehicleType: 'Xe máy',
          completedTrips: 0,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Mới'), findsOneWidget);
    expect(find.byKey(const Key('driver-card-rating')), findsNothing);
    expect(find.byKey(const Key('driver-card-trips')), findsNothing);
    expect(find.text('Xe máy'), findsOneWidget);
  });

  testWidgets('assigned driver: full name, real vehicle and a dial button', (
    t,
  ) async {
    Uri? dialed;
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 240,
          child: DriverCardRow(
            card: const DriverCard(
              driverId: 'd1',
              displayName: 'Nguyễn Hoàng Minh Khôi Phạm',
              vehicleType: 'Ô tô',
              vehicleName: 'Mercedes C300',
              vehiclePlate: '43A-123.45',
              phone: '+84903334444',
            ),
            trailing: const SizedBox.square(dimension: 46),
          ),
        ),
      ),
    );
    final name = t.widget<Text>(find.byKey(const Key('driver-card-name')));
    expect(name.data, 'Nguyễn Hoàng Minh Khôi Phạm');
    expect(name.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text('Mercedes C300 · 43A-123.45'), findsOneWidget);
    expect(find.text('Ô tô'), findsNothing);
    expect(find.text('0903 334 444'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(
      _app(
        ContactPhoneLine(
          phone: '+84903334444',
          dialer: (uri) async {
            dialed = uri;
            return true;
          },
        ),
      ),
    );
    await t.tap(find.byKey(const Key('contact-phone-dial')));
    expect(dialed.toString(), 'tel:+84903334444');
  });

  testWidgets('countdown drains inside the Accept button', (t) async {
    var now = DateTime.utc(2026, 10, 31, 12);
    var taps = 0;
    final exp = now.add(const Duration(seconds: 20)).toIso8601String();
    await t.pumpWidget(
      _app(
        RideOfferCountdown(
          expiresAt: exp,
          now: () => now,
          builder: (context, progress, seconds) => Column(
            children: [
              const Text('card body'),
              RideOfferAcceptButton(
                label: 'Chấp nhận',
                progress: progress,
                seconds: seconds,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    double fill() => t
        .widget<FractionallySizedBox>(
          find.byKey(const Key('ride-offer-countdown-bar')),
        )
        .widthFactor!;
    expect(fill(), closeTo(1, 1e-6));
    expect(find.text('20s'), findsOneWidget);
    now = now.add(const Duration(seconds: 15));
    await t.pump(const Duration(milliseconds: 250));
    expect(fill(), closeTo(0.25, 1e-6));
    expect(find.text('5s'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('card body'), matching: find.byType(Opacity)),
      findsNothing,
    );
    await t.tap(find.text('Chấp nhận'));
    expect(taps, 1);
    now = now.add(const Duration(seconds: 6));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.text('card body'), findsNothing);
  });
}
