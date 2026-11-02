import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/parcel/data/contact_picker.dart';
import 'package:dealgo/features/parcel/data/fake_parcel_client.dart';
import 'package:dealgo/features/parcel/domain/parcel_client.dart';
import 'package:dealgo/features/parcel/presentation/cubit/parcel_booking_cubit.dart';
import 'package:dealgo/features/parcel/presentation/pages/parcel_details_page.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _places = RidePlaces(
  pickup: RidePoint(lat: 10.77, lng: 106.70, label: 'A'),
  dropoff: RidePoint(lat: 10.80, lng: 106.66, label: 'B'),
);

class _SignedIn extends Cubit<AuthState> implements AuthCubit {
  _SignedIn()
    : super(
        const AuthSignedIn(
          tokens: StoredTokens(accessToken: 'tok', refreshToken: 'r'),
          profile: UserProfile(
            id: 'c1',
            phone: '+84901234567',
            email: null,
            phoneVerifiedAt: null,
            emailVerifiedAt: null,
            grants: [],
            displayName: 'Tiến',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker implements ContactPicker {
  var calls = 0;
  @override
  Future<PickedContact?> pickPhone() async {
    calls++;
    return const PickedContact(name: 'Bình', phone: '0912345678');
  }
}

void main() {
  group('one-sheet parcel pricing', () {
    test('start(places) loads sizes and prices the default size', () async {
      final client = FakeParcelClient();
      final cubit = ParcelBookingCubit(
        client: client,
        accessToken: () => 'tok',
      );
      await cubit.start(_places);
      expect(cubit.state.sizeCode, 'S');
      expect(cubit.state.quote, isNotNull);
      expect(cubit.state.fareVnd, isNotNull);
      await cubit.close();
    });

    test('changing size re-prices without a quote tap', () async {
      final client = FakeParcelClient();
      final cubit = ParcelBookingCubit(
        client: client,
        accessToken: () => 'tok',
      );
      await cubit.start(_places);
      final before = client.calls.where((c) => c.startsWith('quote')).length;
      cubit.selectSize('L');
      await pumpEventQueue();
      expect(cubit.state.sizeCode, 'L');
      expect(cubit.state.quote, isNotNull);
      expect(
        client.calls.where((c) => c.startsWith('quote')).length,
        before + 1,
      );
      await cubit.close();
    });

    test('normalizeVnPhone', () {
      expect(normalizeVnPhone('+84 912 345 678'), '0912345678');
      expect(normalizeVnPhone('0912.345.678'), '0912345678');
      expect(normalizeVnPhone('84912345678'), '0912345678');
    });
  });

  testWidgets('panel: price auto, sender prefilled, recipient from contacts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picker = _Picker();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ParcelClient>.value(value: FakeParcelClient()),
          RepositoryProvider<ContactPicker>.value(value: picker),
        ],
        child: BlocProvider<AuthCubit>(
          create: (_) => _SignedIn(),
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ParcelDetailsPanel(places: _places)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Priced without tapping "quote".
    expect(find.byKey(const Key('parcel-submit')), findsOneWidget);
    // Sender collapsed to the account.
    expect(find.byKey(const Key('parcel-sender-summary')), findsOneWidget);
    expect(find.textContaining('Tiến'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.byKey(const Key('parcel-sender-name')), findsNothing);

    await tester.tap(find.byKey(const Key('parcel-pick-contact')));
    await tester.pump();
    expect(picker.calls, 1);
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('Bình'), findsOneWidget);
  });
}
