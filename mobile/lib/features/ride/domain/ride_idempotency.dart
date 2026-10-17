String createRideIdempotencyKey() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = identityHashCode(Object()).toUnsigned(32).toRadixString(16);
  return 'ride-$time-$salt';
}
