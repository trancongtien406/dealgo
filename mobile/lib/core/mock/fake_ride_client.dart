import '../network/api_exception.dart';
import '../../features/ride/data/datasources/ride_remote_datasource.dart';
import '../../features/ride/data/models/ride_models.dart';
import '../../features/ride/domain/entities/ride_models.dart';
import '../../features/ride/domain/params/create_ride_params.dart';
import '../../features/ride/domain/params/select_ride_offer_params.dart';
import '../../features/ride/domain/params/submit_ride_offer_params.dart';

class FakeRideClient implements RideClient {
  Object? createError;
  Object? getError;
  Object? selectError;
  Object? cancelError;
  Object? openError;
  Object? offerError;

  List<OpenRide> openRides = const [];

  final List<CreateRideRequest> createCalls = [];
  final List<SelectRideOfferRequest> selectCalls = [];
  final List<String> getCalls = [];
  final List<String> cancelCalls = [];
  final List<String> openCalls = [];
  final List<SubmitRideOfferRequest> offerCalls = [];

  RideView Function(CreateRideRequest request)? onCreate;
  RideView Function(SubmitRideOfferRequest request)? onOffer;
  RideView Function(String rideId)? onGet;
  RideView Function(SelectRideOfferRequest request)? onSelect;
  RideView Function(String rideId)? onCancel;

  @override
  Future<List<OpenRideModel>> listOpenRides(String accessToken) async {
    openCalls.add(accessToken);
    final error = openError;
    if (error != null) {
      throw error;
    }
    return List.unmodifiable([
      for (final ride in openRides) OpenRideModel.fromEntity(ride),
    ]);
  }

  @override
  Future<RideViewModel> submitOffer(SubmitRideOfferRequest request) async {
    offerCalls.add(request);
    final error = offerError;
    if (error != null) {
      throw error;
    }
    final handler = onOffer;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeRideClient has no offer handler',
        errorCode: 'FAKE_RIDE',
      );
    }
    return RideViewModel.fromEntity(handler(request));
  }

  @override
  Future<RideViewModel> createRide(CreateRideRequest request) async {
    createCalls.add(request);
    final error = createError;
    if (error != null) {
      throw error;
    }
    final handler = onCreate;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeRideClient has no create handler',
        errorCode: 'FAKE_RIDE',
      );
    }
    return RideViewModel.fromEntity(handler(request));
  }

  @override
  Future<RideViewModel> getRide({
    required String accessToken,
    required String rideId,
  }) async {
    getCalls.add(rideId);
    final error = getError;
    if (error != null) {
      throw error;
    }
    final handler = onGet;
    if (handler == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'Ride not found',
        errorCode: 'RIDE_NOT_FOUND',
      );
    }
    return RideViewModel.fromEntity(handler(rideId));
  }

  @override
  Future<RideViewModel> selectOffer(SelectRideOfferRequest request) async {
    selectCalls.add(request);
    final error = selectError;
    if (error != null) {
      throw error;
    }
    final handler = onSelect;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeRideClient has no select handler',
        errorCode: 'FAKE_RIDE',
      );
    }
    return RideViewModel.fromEntity(handler(request));
  }

  @override
  Future<RideViewModel> cancelRide({
    required String accessToken,
    required String rideId,
  }) async {
    cancelCalls.add(rideId);
    final error = cancelError;
    if (error != null) {
      throw error;
    }
    final handler = onCancel;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeRideClient has no cancel handler',
        errorCode: 'FAKE_RIDE',
      );
    }
    return RideViewModel.fromEntity(handler(rideId));
  }
}
