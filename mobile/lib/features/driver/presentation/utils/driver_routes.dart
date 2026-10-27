abstract final class DriverRoutes {
  static const services = '/driver/services';

  static String ride(String rideId) {
    return '/driver/rides/${Uri.encodeComponent(rideId)}';
  }

  static String offer(String rideId) {
    return '/driver/rides/${Uri.encodeComponent(rideId)}/offer';
  }

  static String active(String rideId) {
    return '/driver/rides/${Uri.encodeComponent(rideId)}/active';
  }

  static String passengerOtp(String rideId) {
    return '/driver/rides/${Uri.encodeComponent(rideId)}/otp';
  }

  static String food(String orderId) {
    return '/driver/food/${Uri.encodeComponent(orderId)}';
  }

  /// [food]: a picked-up food order (the reason is sent to the server).
  static String failed(String jobId, {bool food = false}) {
    final path = '/driver/jobs/failed/${Uri.encodeComponent(jobId)}';
    return food ? '$path?kind=food' : path;
  }

  static String completed(String jobId) {
    return '/driver/jobs/completed/${Uri.encodeComponent(jobId)}';
  }
}
