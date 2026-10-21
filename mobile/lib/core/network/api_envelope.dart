import 'api_exception.dart';

Map<String, Object?>? asJsonMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final mapped = <String, Object?>{};
  value.forEach((key, item) {
    mapped[key.toString()] = item;
  });
  return mapped;
}

Map<String, Object?> requireSuccessData(Object? body) {
  final data = asJsonMap(readSuccessPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return data;
}

Object? readSuccessPayload(Object? body) {
  final root = asJsonMap(body);
  if (root == null) {
    throw const ApiException(
      statusCode: 0,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  if (root['success'] != true) {
    throw errorFromEnvelope(root, statusCode: _asInt(root['statusCode']) ?? 0);
  }
  if (!root.containsKey('data') || root['data'] == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return root['data'];
}

ApiException errorFromEnvelope(
  Map<String, Object?> body, {
  required int statusCode,
}) {
  final code = body['errorCode'];
  return ApiException(
    statusCode: _asInt(body['statusCode']) ?? statusCode,
    message: readMessage(body['message']),
    errorCode: code is String && code.isNotEmpty ? code : 'HTTP_ERROR',
    details: asJsonMap(body['details']),
  );
}

String readMessage(Object? message) {
  if (message is String && message.trim().isNotEmpty) {
    return message;
  }
  if (message is List) {
    final parts = message.whereType<String>().where((part) => part.isNotEmpty);
    final joined = parts.join('; ');
    if (joined.isNotEmpty) {
      return joined;
    }
  }
  return 'Request failed';
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
