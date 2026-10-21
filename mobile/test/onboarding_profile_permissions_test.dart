import 'dart:typed_data';

import 'package:dealgo/core/auth/post_auth_gate.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/permissions/app_permission_service.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/repositories/identity_repository.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/avatar_image_source.dart';
import 'package:dealgo/features/onboarding/presentation/pages/profile_setup_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'support/fake_identity_client.dart';
import 'support/fake_permission_service.dart';
import 'support/test_l10n.dart';
import 'support/memory_token_store.dart';

Widget _wrap(
  Widget child, {
  AppPermissionService? permissions,
  FakeIdentityClient? identityClient,
  AuthCubit? authCubit,
  AvatarImageSource? avatarImageSource,
}) {
  final service = permissions ?? FakeAppPermissionService();
  final client = identityClient ?? FakeIdentityClient();
  final repository = IdentityRepositoryImpl(client);
  final auth =
      authCubit ??
      AuthCubit(
        fetchMe: FetchMe(repository),
        tokens: MemoryTokenStore(),
        identityRepository: repository,
        postAuth: PostAuthGate.seeded(),
      );

  return ChangeNotifierProvider<PostAuthGate>.value(
    value: PostAuthGate.seeded(),
    child: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppPermissionService>.value(value: service),
        RepositoryProvider<IdentityRepository>.value(value: repository),
      ],
      child: BlocProvider<AuthCubit>.value(
        value: auth,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: testLocale,
          home: ProfileSetupPage(
            permissionService: service,
            avatarImageSource: avatarImageSource,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ProfileSetupPage (S005)', () {
    testWidgets('renders all form components and validates required name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox.shrink(),
          avatarImageSource: FakeAvatarImageSource(),
        ),
      );

      expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
      expect(find.textContaining('Chỉ còn một bước'), findsOneWidget);
      expect(find.text('Họ và tên'), findsWidgets);
      expect(find.byKey(const Key('name-field')), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.text('Ngày sinh (tuỳ chọn)'), findsWidgets);
      expect(find.text('Giới tính'), findsOneWidget);
      expect(find.text('Nam'), findsOneWidget);
      expect(find.text('Nữ'), findsOneWidget);
      expect(find.text('Khác'), findsOneWidget);
      expect(find.text('Bổ sung sau'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.text('Ảnh đại diện (tuỳ chọn)'), findsOneWidget);

      final completeButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Hoàn tất'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(completeButton.enabled, isFalse);

      await tester.enterText(
        find.byKey(const Key('name-field')),
        'Trần Văn DealGo',
      );
      await tester.pumpAndSettle();

      final completeButtonEnabled = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Hoàn tất'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(completeButtonEnabled.enabled, isTrue);

      await tester.ensureVisible(find.text('Nữ'));
      await tester.tap(find.text('Nữ'));
      await tester.pumpAndSettle();
    });

    testWidgets('avatar tap uploads image via identity API', (tester) async {
      final permissions = FakeAppPermissionService();
      final client = FakeIdentityClient(profile: needsProfileSetupProfile);
      final repository = IdentityRepositoryImpl(client);
      final tokens = MemoryTokenStore();
      await tokens.write(
        const StoredTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final auth = AuthCubit(
        fetchMe: FetchMe(repository),
        tokens: tokens,
        identityRepository: repository,
        postAuth: PostAuthGate.seeded(),
      );
      await auth.completeSignIn(
        const StoredTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );

      // 1x1 PNG so MemoryImage can decode in widget tests.
      const png1x1 = <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];
      final avatarSource = FakeAvatarImageSource(
        nextImage: PickedAvatarImage(
          bytes: Uint8List.fromList(png1x1),
          contentType: 'image/png',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<PostAuthGate>.value(
          value: PostAuthGate.seeded(),
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AppPermissionService>.value(
                value: permissions,
              ),
              RepositoryProvider<IdentityRepository>.value(value: repository),
            ],
            child: BlocProvider<AuthCubit>.value(
              value: auth,
              child: MaterialApp(
                localizationsDelegates: testLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: testLocale,
                home: ProfileSetupPage(
                  permissionService: permissions,
                  avatarImageSource: avatarSource,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ảnh đại diện (tuỳ chọn)'));
      await tester.pumpAndSettle();

      expect(permissions.requested, contains(Permission.photos));
      expect(avatarSource.pickCount, 1);
      expect(client.avatarUploads, isNotEmpty);
      expect(find.text('Sẽ hỗ trợ tải ảnh trong bản cập nhật'), findsNothing);
    });
  });

}
