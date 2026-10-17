class CreateRideVoiceSessionParams {
  const CreateRideVoiceSessionParams({
    required this.accessToken,
    required this.rideId,
  });

  final String accessToken;
  final String rideId;
}

class CreateFoodOrderVoiceSessionParams {
  const CreateFoodOrderVoiceSessionParams({
    required this.accessToken,
    required this.orderId,
  });

  final String accessToken;
  final String orderId;
}
