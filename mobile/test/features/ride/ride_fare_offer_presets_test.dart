import 'package:dealgo/features/ride/domain/ride_fare_presets.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_offer_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a headroom of 30 splits into 10/20/30 and rounds up to 1.000đ', () {
    final p = rideFareRaisePresets(
      suggestedVnd: 45_500,
      maxBidVnd: 1_000_000,
      maxHeadroomPercent: 30,
    );
    expect(p.map((e) => e.percent), [10, 20, 30]);
    // 45.500 × 1.1 = 50.050 → 51.000; × 1.2 = 54.600 → 55.000; × 1.3 = 59.150 → 60.000.
    expect(p.map((e) => e.amountVnd), [51_000, 55_000, 60_000]);
    expect(p.every((e) => e.enabled), isTrue);
  });

  test('a changed max is split in three', () {
    final p = rideFareRaisePresets(
      suggestedVnd: 100_000,
      maxBidVnd: 1_000_000,
      maxHeadroomPercent: 45,
    );
    expect(p.map((e) => e.percent), [15, 30, 45]);
    expect(p.map((e) => e.amountVnd), [115_000, 130_000, 145_000]);
  });

  test('round-up that would leave the ceiling stays on the ceiling', () {
    // 46.000 × 130% = 59.800, and the server ceiling rounds down to 59.000.
    // +30% rounded up would be 60.000, which the band rejects.
    final p = rideFareRaisePresets(
      suggestedVnd: 46_000,
      maxBidVnd: 59_000,
      maxHeadroomPercent: 30,
    );
    expect(p.last.amountVnd, 59_000);
    expect(p.every((e) => e.amountVnd <= 59_000), isTrue);
    expect(p.map((e) => e.amountVnd).toSet().length, p.length);
  });

  test('a tight cap drops percents that cannot raise', () {
    final p = rideFareRaisePresets(
      suggestedVnd: 100_000,
      maxBidVnd: 115_000,
      maxHeadroomPercent: 30,
    );
    expect(p.map((e) => e.amountVnd), [105_000, 110_000, 115_000]);
    expect(p.every((e) => e.enabled && e.amountVnd <= 115_000), isTrue);
  });

  testWidgets('offer card stays visible and disappears at expiry', (t) async {
    var now = DateTime.utc(2026, 10, 31, 12);
    final exp = now.add(const Duration(seconds: 20)).toIso8601String();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RideOfferCountdown(
            expiresAt: exp,
            now: () => now,
            builder: (context, progress, seconds) =>
                Text('offer ${progress.toStringAsFixed(2)} $seconds'),
          ),
        ),
      ),
    );
    expect(find.text('offer 1.00 20'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    now = now.add(const Duration(seconds: 10));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.text('offer 0.50 10'), findsOneWidget);
    now = now.add(const Duration(seconds: 11));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('offer'), findsNothing);
    expect(find.byKey(const Key('ride-offer-expired')), findsOneWidget);
  });
}
