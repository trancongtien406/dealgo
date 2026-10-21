import 'ride_models.dart';
import '../../../../core/format/short_ref.dart';

/// Ride being booked after the vehicle step. DealGo only dispatches
/// motorbikes today, so there is no vehicle choice to carry yet.
class RideBookingDraft {
  const RideBookingDraft({required this.places});

  final RidePlaces places;

  /// Server reference fare from the quote (0 until it is loaded).
  int get suggestedFareVnd => places.quote?.referenceFareVnd ?? 0;
}

/// Short, real reference for a ride shown to people ("#3F9A1C"): the tail of
/// the server id, so support can find it. Never a made-up code.
String rideShortRef(String rideId) => shortRef(rideId);
