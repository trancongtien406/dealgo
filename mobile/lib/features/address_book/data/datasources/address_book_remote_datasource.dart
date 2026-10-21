import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/repositories/address_book_repository.dart';

class DioAddressBookRemoteDataSource implements AddressBookRepository {
  DioAddressBookRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<SavedAddress>> list({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.meAddresses,
        options: _auth(accessToken),
      );
      final items = requireSuccessData(response.data)['items'];
      if (items is! List) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      return [for (final raw in items) ?decodeSavedAddress(raw)];
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<SavedAddress> create({
    required String accessToken,
    required SavedAddressDraft draft,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.meAddresses,
        data: draft.toJson(),
        options: _auth(accessToken),
      );
      return _requireAddress(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<SavedAddress> update({
    required String accessToken,
    required String id,
    SavedAddressDraft? draft,
    bool makeDefault = false,
  }) async {
    try {
      final response = await dio.patch<Object?>(
        ApiPaths.meAddress(id),
        data: {...?draft?.toJson(), if (makeDefault) 'isDefault': true},
        options: _auth(accessToken),
      );
      return _requireAddress(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> remove({required String accessToken, required String id}) async {
    try {
      await dio.delete<Object?>(
        ApiPaths.meAddress(id),
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  SavedAddress _requireAddress(Object? body) {
    final address = decodeSavedAddress(requireSuccessData(body));
    if (address == null) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return address;
  }
}

SavedAddress? decodeSavedAddress(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final id = map['id'];
  final label = map['label'];
  final line = map['addressLine'];
  if (id is! String || label is! String || line is! String) {
    return null;
  }
  final note = map['note'];
  final lat = map['lat'];
  final lng = map['lng'];
  return SavedAddress(
    id: id,
    kind: SavedAddressKind.fromWire(map['kind']),
    label: label,
    addressLine: line,
    note: note is String && note.isNotEmpty ? note : null,
    lat: lat is num ? lat.toDouble() : null,
    lng: lng is num ? lng.toDouble() : null,
    isDefault: map['isDefault'] == true,
  );
}

/// In-memory book for tests, screenshots and mock builds; mirrors the server rules.
class FakeAddressBookRemoteDataSource implements AddressBookRepository {
  FakeAddressBookRemoteDataSource({List<SavedAddress>? seed})
    : _items = [...?seed];

  static const limit = 20;

  final List<SavedAddress> _items;
  var _serial = 0;

  static List<SavedAddress> sample() => const [
    SavedAddress(
      id: 'addr-home',
      kind: SavedAddressKind.home,
      label: 'Nhà',
      addressLine: '12 Lê Duẩn, Hải Châu, Đà Nẵng',
      note: 'Cổng màu xanh',
      lat: 16.0718,
      lng: 108.2208,
      isDefault: true,
    ),
    SavedAddress(
      id: 'addr-work',
      kind: SavedAddressKind.work,
      label: 'Công ty',
      addressLine: '99 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      isDefault: false,
    ),
  ];

  List<SavedAddress> _sorted() {
    final copy = [..._items];
    copy.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
    return List.unmodifiable(copy);
  }

  Never _fail(int status, String code) =>
      throw ApiException(statusCode: status, message: code, errorCode: code);

  void _assertKindFree(SavedAddressKind kind, {String? exceptId}) {
    if (kind == SavedAddressKind.other) {
      return;
    }
    if (_items.any((a) => a.kind == kind && a.id != exceptId)) {
      _fail(409, 'ADDRESS_KIND_TAKEN');
    }
  }

  @override
  Future<List<SavedAddress>> list({required String accessToken}) async =>
      _sorted();

  @override
  Future<SavedAddress> create({
    required String accessToken,
    required SavedAddressDraft draft,
  }) async {
    if (_items.length >= limit) {
      _fail(409, 'ADDRESS_LIMIT_REACHED');
    }
    _assertKindFree(draft.kind);
    final makeDefault = draft.isDefault || _items.isEmpty;
    if (makeDefault) {
      _replaceAll((a) => _copy(a, isDefault: false));
    }
    _serial += 1;
    final created = SavedAddress(
      id: 'addr-new-$_serial',
      kind: draft.kind,
      label: draft.label,
      addressLine: draft.addressLine,
      note: draft.note,
      lat: draft.lat,
      lng: draft.lng,
      isDefault: makeDefault,
    );
    _items.insert(0, created);
    return created;
  }

  @override
  Future<SavedAddress> update({
    required String accessToken,
    required String id,
    SavedAddressDraft? draft,
    bool makeDefault = false,
  }) async {
    final index = _items.indexWhere((a) => a.id == id);
    if (index < 0) {
      _fail(404, 'ADDRESS_NOT_FOUND');
    }
    if (draft != null) {
      _assertKindFree(draft.kind, exceptId: id);
    }
    if (makeDefault) {
      _replaceAll((a) => _copy(a, isDefault: a.id == id));
    }
    final current = _items[index];
    final next = draft == null
        ? current
        : SavedAddress(
            id: id,
            kind: draft.kind,
            label: draft.label,
            addressLine: draft.addressLine,
            note: draft.note,
            lat: draft.lat,
            lng: draft.lng,
            isDefault: current.isDefault,
          );
    _items[index] = next;
    return next;
  }

  @override
  Future<void> remove({required String accessToken, required String id}) async {
    final index = _items.indexWhere((a) => a.id == id);
    if (index < 0) {
      _fail(404, 'ADDRESS_NOT_FOUND');
    }
    final removed = _items.removeAt(index);
    if (removed.isDefault && _items.isNotEmpty) {
      _items[0] = _copy(_items[0], isDefault: true);
    }
  }

  void _replaceAll(SavedAddress Function(SavedAddress) map) {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = map(_items[i]);
    }
  }

  SavedAddress _copy(SavedAddress a, {required bool isDefault}) => SavedAddress(
    id: a.id,
    kind: a.kind,
    label: a.label,
    addressLine: a.addressLine,
    note: a.note,
    lat: a.lat,
    lng: a.lng,
    isDefault: isDefault,
  );
}
