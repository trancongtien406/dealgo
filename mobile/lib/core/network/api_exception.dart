class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    required this.errorCode,
  });

  final int statusCode;
  final String message;
  final String errorCode;

  @override
  String toString() => '$errorCode: $message';
}
