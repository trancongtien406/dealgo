import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_paths.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dealgo/features/identity/data/datasources/dio_identity_remote_datasource.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restore signs out when mock tokens fail refresh', () async {
    final store = MemoryTokenStore();
    await store.write(
      const StoredTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );

    late final AuthCubit auth;
    final dio = createDealGoDio(
      baseUrl: 'https://api.test',
      tokenStore: store,
      onSessionRefreshed: (next) => auth.applyRefreshedTokens(next),
      onUnauthorized: () => auth.signOut(),
      enableLogging: false,
    );
    dio.httpClientAdapter = _InvalidSessionAdapter();

    final identity = DioIdentityRemoteDataSource(dio: dio);
    final repo = IdentityRepositoryImpl(identity);
    auth = AuthCubit(fetchMe: FetchMe(repo), tokens: store);

    await auth.restore().timeout(const Duration(seconds: 3));

    expect(auth.state, isA<AuthSignedOut>());
    expect(await store.read(), isNull);
  });
}

class _InvalidSessionAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains(ApiPaths.sessionsRefresh) || path.contains('refresh')) {
      return ResponseBody.fromString(
        '{"success":false,"statusCode":400,'
        '"message":"refreshToken must be longer than or equal to 20 characters",'
        '"errorCode":"VALIDATION_ERROR"}',
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"success":false,"statusCode":401,'
      '"message":"Authentication required","errorCode":"UNAUTHORIZED"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
