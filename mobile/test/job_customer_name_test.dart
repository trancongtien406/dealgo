import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/driver/presentation/widgets/job_customer_name.dart';
import 'package:dealgo/features/driver_card/data/driver_card_remote_datasource.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The arrived screen names the real customer, never a placeholder.
void main() {
  Future<void> pump(WidgetTester tester, AuthState auth, String name) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider<AuthCubit>(create: (_) => _Auth(auth))],
        child: RepositoryProvider<DriverCardRepository>.value(
          value: FakeDriverCardRemoteDataSource(customerName: name),
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: JobCustomerName(jobId: 'r1', subtitle: '4,8★ (12 lượt)'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the customer name from the backend', (tester) async {
    await pump(tester, _signedIn, 'Nguyễn Thị An');
    expect(find.text('Nguyễn Thị An'), findsOneWidget);
    expect(find.text('Khách hàng'), findsNothing);
    expect(find.text('4,8★ (12 lượt)'), findsOneWidget);
  });

  testWidgets('keeps the generic label when the name is empty', (tester) async {
    await pump(tester, _signedIn, '');
    expect(find.text('Khách hàng'), findsOneWidget);
  });
}

const _signedIn = AuthSignedIn(
  tokens: StoredTokens(accessToken: 'token', refreshToken: 'r'),
  profile: UserProfile(
    id: 'd1',
    phone: '+84900000000',
    email: null,
    phoneVerifiedAt: null,
    emailVerifiedAt: null,
    grants: [],
    displayName: 'Dũng',
  ),
);

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
