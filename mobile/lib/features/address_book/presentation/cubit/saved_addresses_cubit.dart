import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/repositories/address_book_repository.dart';

sealed class SavedAddressesState {
  const SavedAddressesState();
}

class SavedAddressesLoading extends SavedAddressesState {
  const SavedAddressesLoading();
}

class SavedAddressesLoaded extends SavedAddressesState {
  const SavedAddressesLoaded(this.items);

  final List<SavedAddress> items;

  bool get isFull => items.length >= SavedAddressesCubit.limit;
}

class SavedAddressesFailed extends SavedAddressesState {
  const SavedAddressesFailed({required this.offline, this.cause});

  final bool offline;
  final Object? cause;
}

/// Result of a write: `null` on success, otherwise the server error code.
typedef AddressWriteResult = String?;

class SavedAddressesCubit extends Cubit<SavedAddressesState> {
  SavedAddressesCubit({required this.repository, required this.accessToken})
    : super(const SavedAddressesLoading());

  static const limit = 20;

  final AddressBookRepository repository;
  final String? Function() accessToken;

  Future<void> load() async {
    final token = accessToken();
    if (token == null) {
      emit(
        const SavedAddressesFailed(offline: false, cause: sessionExpiredFailure),
      );
      return;
    }
    if (state is! SavedAddressesLoaded) {
      emit(const SavedAddressesLoading());
    }
    try {
      final items = await repository.list(accessToken: token);
      emit(SavedAddressesLoaded(items));
    } catch (error) {
      emit(SavedAddressesFailed(offline: _isOffline(error), cause: error));
    }
  }

  Future<AddressWriteResult> save(SavedAddressDraft draft, {String? id}) {
    return _write(
      (token) => id == null
          ? repository.create(accessToken: token, draft: draft)
          : repository.update(accessToken: token, id: id, draft: draft),
    );
  }

  Future<AddressWriteResult> makeDefault(String id) {
    return _write(
      (token) =>
          repository.update(accessToken: token, id: id, makeDefault: true),
    );
  }

  Future<AddressWriteResult> remove(String id) {
    return _write((token) => repository.remove(accessToken: token, id: id));
  }

  /// Writes, then reloads so default/order rules always match the server.
  Future<AddressWriteResult> _write(
    Future<Object?> Function(String token) work,
  ) async {
    final token = accessToken();
    if (token == null) {
      return 'UNAUTHENTICATED';
    }
    try {
      await work(token);
    } on ApiException catch (error) {
      return error.errorCode.isEmpty ? 'UNKNOWN' : error.errorCode;
    } catch (_) {
      return 'UNKNOWN';
    }
    await load();
    return null;
  }

  bool _isOffline(Object error) =>
      error is ApiException &&
      (error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR');
}
