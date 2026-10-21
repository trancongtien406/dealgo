import '../entities/saved_address.dart';

abstract interface class AddressBookRepository {
  Future<List<SavedAddress>> list({required String accessToken});

  Future<SavedAddress> create({
    required String accessToken,
    required SavedAddressDraft draft,
  });

  Future<SavedAddress> update({
    required String accessToken,
    required String id,
    SavedAddressDraft? draft,
    bool makeDefault = false,
  });

  Future<void> remove({required String accessToken, required String id});
}
