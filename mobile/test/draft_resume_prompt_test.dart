// "Tiếp tục hồ sơ đang làm?" after the app was killed mid-registration.
// PNGs only with --dart-define=SHOT_DIR=/abs/dir.
import 'dart:typed_data';

import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/drafts/draft_store.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/onboarding/presentation/pages/driver_kyc_pages.dart';
import 'package:dealgo/features/onboarding/presentation/pages/merchant_kyb_pages.dart';
import 'package:dealgo/features/onboarding/presentation/utils/driver_kyc_routes.dart';
import 'package:dealgo/features/onboarding/presentation/utils/merchant_kyb_routes.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/visual_shot.dart';

final _jpeg = PickedDocumentImage(
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]),
  contentType: 'image/jpeg',
);

const _shotKey = Key('shot-root');

Widget _app<C extends Cubit<Object?>>(
  C cubit,
  String intro,
  String steps,
  Widget introPage,
) {
  final router = GoRouter(
    initialLocation: intro,
    routes: [
      GoRoute(path: intro, builder: (_, _) => introPage),
      GoRoute(
        path: steps,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('steps-page'))),
      ),
    ],
  );
  return BlocProvider<C>.value(
    value: cubit,
    child: RepaintBoundary(
      key: _shotKey,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: DealGoTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

Future<void> _phone(WidgetTester tester, Size size) async {
  await loadShotFonts(tester);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

DriverKycCubit _driver(DraftStore store) =>
    DriverKycCubit(draftStore: store, draftOwner: () => 'u1', useMock: true);

MerchantKybCubit _merchant(DraftStore store) =>
    MerchantKybCubit(draftStore: store, draftOwner: () => 'u1', useMock: true);

void main() {
  for (final (name, size) in [
    ('se', const Size(375, 667)),
    ('pro', const Size(390, 844)),
  ]) {
    testWidgets('driver reopen offers the draft and resumes it ($name)', (
      tester,
    ) async {
      await _phone(tester, size);
      final store = MemoryDraftStore();
      await tester.runAsync(() async {
        final killed = _driver(store)
          ..startDraft()
          ..setFullName('Trần Công Tiến')
          ..attachDocument(PartnerDocumentKind.idFront, _jpeg)
          ..goToStep(DriverKycStep.license);
        await killed.close();
      });
      final cubit = _driver(store);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _app(
          cubit,
          DriverKycRoutes.intro,
          DriverKycRoutes.steps,
          const DriverKycIntroPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-resume-dialog')), findsOneWidget);
      expect(find.text('Tiếp tục hồ sơ đang làm?'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await saveShot(
        tester,
        'resume-driver-prompt-$name',
        finder: find.byKey(_shotKey),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('draft-resume-continue')));
      await tester.pumpAndSettle();
      expect(find.text('steps-page'), findsOneWidget);
      expect(find.text('Đã khôi phục bản nháp chưa gửi.'), findsOneWidget);
      expect(cubit.state.step, DriverKycStep.license);
      expect(cubit.state.fullName, 'Trần Công Tiến');
      await saveShot(
        tester,
        'resume-driver-restored-$name',
        finder: find.byKey(_shotKey),
      );
    });
  }

  testWidgets('merchant: dismiss keeps the draft, start CTA asks again, '
      'start over clears it', (tester) async {
    await _phone(tester, const Size(390, 844));
    final store = MemoryDraftStore();
    await tester.runAsync(() async {
      final killed = _merchant(store)
        ..startDraft()
        ..setShopName('Quán Bún Bò')
        ..goToStep(MerchantKybStep.documents);
      await killed.close();
    });
    final cubit = _merchant(store);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _app(
        cubit,
        MerchantKybRoutes.intro,
        MerchantKybRoutes.steps,
        const MerchantKybIntroPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draft-resume-dialog')), findsOneWidget);
    await saveShot(
      tester,
      'resume-merchant-prompt-pro',
      finder: find.byKey(_shotKey),
    );

    // Tap outside: nothing lost, still on the intro.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draft-resume-dialog')), findsNothing);
    expect(store.fields, isNotEmpty);

    // Start CTA re-offers the draft instead of silently wiping it.
    await tester.tap(find.text('Bắt đầu đăng ký Shop'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draft-resume-dialog')), findsOneWidget);
    await tester.tap(find.text('Làm lại từ đầu'));
    await tester.pumpAndSettle();
    expect(find.text('steps-page'), findsOneWidget);
    expect(cubit.state.shopName, '');
    // Old draft is gone; only the fresh step-1 draft (never offered) remains.
    final fresh = store.fields.values.single;
    expect(fresh['shopName'], '');
    expect(fresh['step'], 'businessType');
  });
}
