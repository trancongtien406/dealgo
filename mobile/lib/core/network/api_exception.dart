class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    required this.errorCode,
    this.details,
  });

  final int statusCode;
  final String message;
  final String errorCode;

  /// Machine-readable extras from the error envelope, when the server sent any.
  final Map<String, Object?>? details;

  @override
  String toString() => '$errorCode: $message';
}
