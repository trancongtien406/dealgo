import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/user_profile.dart';
import '../../domain/entities/partner_application.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../../domain/usecases/submit_partner_application.dart';

enum DriverKycStep {
  services,
  personal,
  identity,
  ocrConfirm,
  selfie,
  license,
  vehicle,
  bank,
  review,
}

class DriverKycState {
  const DriverKycState({
    required this.status,
    required this.step,
    required this.rideService,
    required this.foodService,
    required this.fullName,
    required this.birthDate,
    required this.address,
    required this.idAttached,
    required this.selfieAttached,
    required this.licenseAttached,
    required this.bankAttached,
    required this.vehiclePlate,
    required this.vehicleType,
    required this.rejections,
    required this.seeded,
    this.submitting = false,
    this.submitError,
  });

  factory DriverKycState.initial() {
    return const DriverKycState(
      status: PartnerApplicationStatus.draft,
      step: DriverKycStep.services,
      rideService: true,
      foodService: true,
      fullName: 'NGUYỄN VĂN A',
      birthDate: '01/01/1995',
      address: 'Đà Nẵng, Việt Nam',
      idAttached: false,
      selfieAttached: false,
      licenseAttached: false,
      bankAttached: false,
      vehiclePlate: '43B1-123.45',
      vehicleType: 'Xe máy',
      rejections: driverDemoRejections,
      seeded: false,
    );
  }

  final PartnerApplicationStatus status;
  final DriverKycStep step;
  final bool rideService;
  final bool foodService;
  final String fullName;
  final String birthDate;
  final String address;
  final bool idAttached;
  final bool selfieAttached;
  final bool licenseAttached;
  final bool bankAttached;
  final String vehiclePlate;
  final String vehicleType;
  final List<OnboardingRejection> rejections;
  final bool seeded;
  final bool submitting;
  final String? submitError;

  int get stepNumber => DriverKycStep.values.indexOf(step) + 1;
  int get totalSteps => DriverKycStep.values.length;

  bool get canContinueServices => rideService || foodService;

  bool get canContinueDocs => idAttached && licenseAttached;

  DriverKycState copyWith({
    PartnerApplicationStatus? status,
    DriverKycStep? step,
    bool? rideService,
    bool? foodService,
    String? fullName,
    String? birthDate,
    String? address,
    bool? idAttached,
    bool? selfieAttached,
    bool? licenseAttached,
    bool? bankAttached,
    String? vehiclePlate,
    String? vehicleType,
    List<OnboardingRejection>? rejections,
    bool? seeded,
    bool? submitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return DriverKycState(
      status: status ?? this.status,
      step: step ?? this.step,
      rideService: rideService ?? this.rideService,
      foodService: foodService ?? this.foodService,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      idAttached: idAttached ?? this.idAttached,
      selfieAttached: selfieAttached ?? this.selfieAttached,
      licenseAttached: licenseAttached ?? this.licenseAttached,
      bankAttached: bankAttached ?? this.bankAttached,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      rejections: rejections ?? this.rejections,
      seeded: seeded ?? this.seeded,
      submitting: submitting ?? this.submitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class DriverKycCubit extends Cubit<DriverKycState> {
  DriverKycCubit({
    SubmitPartnerApplication? submitPartnerApplication,
    this._accessToken,
    bool? useMock,
  }) : _submitPartnerApplication = submitPartnerApplication,
       _useMock = useMock ?? useMockData,
       super(DriverKycState.initial());

  final SubmitPartnerApplication? _submitPartnerApplication;
  final String? Function()? _accessToken;
  final bool _useMock;

  void seedFromProfile(UserProfile profile) {
    if (state.seeded) {
      return;
    }
    final grant = profile.grantStatus(AppRole.driver);
    final status = switch (grant) {
      'ACTIVE' => PartnerApplicationStatus.active,
      'PENDING' => PartnerApplicationStatus.pending,
      'REJECTED' => PartnerApplicationStatus.rejected,
      _ => PartnerApplicationStatus.draft,
    };
    emit(state.copyWith(status: status, seeded: true));
  }

  void startDraft() {
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: DriverKycStep.services,
        idAttached: false,
        selfieAttached: false,
        licenseAttached: false,
        bankAttached: false,
        clearSubmitError: true,
      ),
    );
  }

  void toggleRide() {
    emit(state.copyWith(rideService: !state.rideService));
  }

  void toggleFood() {
    emit(state.copyWith(foodService: !state.foodService));
  }

  void goToStep(DriverKycStep step) {
    emit(state.copyWith(step: step, status: PartnerApplicationStatus.draft));
  }

  void nextStep() {
    final index = DriverKycStep.values.indexOf(state.step);
    if (index >= DriverKycStep.values.length - 1) {
      return;
    }
    emit(state.copyWith(step: DriverKycStep.values[index + 1]));
  }

  void previousStep() {
    final index = DriverKycStep.values.indexOf(state.step);
    if (index <= 0) {
      return;
    }
    emit(state.copyWith(step: DriverKycStep.values[index - 1]));
  }

  void toggleIdAttached() {
    emit(state.copyWith(idAttached: !state.idAttached));
  }

  void toggleSelfieAttached() {
    emit(state.copyWith(selfieAttached: !state.selfieAttached));
  }

  void toggleLicenseAttached() {
    emit(state.copyWith(licenseAttached: !state.licenseAttached));
  }

  void toggleBankAttached() {
    emit(state.copyWith(bankAttached: !state.bankAttached));
  }

  Future<void> submit() => _submitApplication();

  void simulateReject() {
    emit(state.copyWith(status: PartnerApplicationStatus.rejected));
  }

  void beginResubmit() {
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: DriverKycStep.identity,
        idAttached: false,
        selfieAttached: false,
        licenseAttached: false,
        bankAttached: false,
        clearSubmitError: true,
      ),
    );
  }

  Future<void> resubmit() => _submitApplication();

  Future<void> _submitApplication() async {
    if (state.submitting) {
      return;
    }
    final submit = _submitPartnerApplication;
    if (_useMock || submit == null) {
      emit(
        state.copyWith(
          status: PartnerApplicationStatus.pending,
          clearSubmitError: true,
        ),
      );
      return;
    }
    final token = _accessToken?.call()?.trim() ?? '';
    if (token.isEmpty) {
      emit(state.copyWith(submitError: 'Phiên đăng nhập không còn hiệu lực'));
      return;
    }
    emit(state.copyWith(submitting: true, clearSubmitError: true));
    try {
      final view = await submit(
        SubmitPartnerApplicationRequest(
          accessToken: token,
          role: 'DRIVER',
          metadata: {
            'rideService': state.rideService,
            'foodService': state.foodService,
            'fullName': state.fullName,
            'birthDate': state.birthDate,
            'address': state.address,
            'vehiclePlate': state.vehiclePlate,
            'vehicleType': state.vehicleType,
            'idAttached': state.idAttached,
            'licenseAttached': state.licenseAttached,
          },
        ),
      );
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          status: _mapStatus(view.status),
          submitting: false,
          clearSubmitError: true,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(submitting: false, submitError: error.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          submitting: false,
          submitError: 'Không thể kết nối máy chủ',
        ),
      );
    }
  }
}

PartnerApplicationStatus _mapStatus(String status) {
  return switch (status.toUpperCase()) {
    'APPROVED' => PartnerApplicationStatus.active,
    'SUBMITTED' => PartnerApplicationStatus.pending,
    'REJECTED' => PartnerApplicationStatus.rejected,
    'DRAFT' => PartnerApplicationStatus.draft,
    _ => PartnerApplicationStatus.pending,
  };
}
