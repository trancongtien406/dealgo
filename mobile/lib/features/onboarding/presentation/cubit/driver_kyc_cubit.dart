import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/user_profile.dart';
import '../../domain/entities/partner_application.dart';
import '../../domain/entities/partner_documents.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../../domain/usecases/get_my_partner_application.dart';
import '../../domain/usecases/submit_partner_application.dart';
import '../document_image_source.dart';
import 'partner_document_draft.dart';

export 'partner_document_draft.dart' show PartnerSubmitError;

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

/// Legacy display fallbacks (UI labels only). KYC draft must not pre-select a class.
const driverDefaultVehicleType = 'Xe máy';
const driverDefaultVehicleClassCode = 'MOTORBIKE';

class DriverKycState {
  const DriverKycState({
    required this.status,
    required this.step,
    required this.rideService,
    required this.foodService,
    required this.fullName,
    required this.birthDate,
    required this.address,
    required this.idNumber,
    required this.licenseClass,
    required this.licenseNumber,
    required this.vehiclePlate,
    this.vehicleClassCode,
    this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountHolder,
    required this.documents,
    required this.issues,
    required this.seeded,
    this.reason,
    this.loading = false,
    this.submitting = false,
    this.submitError,
    this.documentsRequired = true,
  });

  factory DriverKycState.initial() {
    return const DriverKycState(
      status: PartnerApplicationStatus.draft,
      step: DriverKycStep.services,
      // Nothing preselected: with both cards pre-ticked, the natural "choose
      // Chở khách" tap unticked it. The applicant opts in.
      rideService: false,
      foodService: false,
      fullName: '',
      birthDate: '',
      address: '',
      idNumber: '',
      licenseClass: 'A1',
      licenseNumber: '',
      vehiclePlate: '',
      vehicleClassCode: null,
      vehicleType: null,
      vehicleBrand: '',
      vehicleModel: '',
      bankName: '',
      bankAccountNumber: '',
      bankAccountHolder: '',
      documents: PartnerDocumentDraft(),
      issues: [],
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
  final String idNumber;
  final String licenseClass;
  final String licenseNumber;
  final String vehiclePlate;

  /// Null until the applicant picks MOTORBIKE | CAR_4 | CAR_7 (fail closed).
  final String? vehicleClassCode;
  final String? vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;
  final PartnerDocumentDraft documents;

  /// Sections ops asked to fix on the last review (server data).
  final List<PartnerReviewIssue> issues;
  final String? reason;
  final bool seeded;
  final bool loading;
  final bool submitting;

  /// A [PartnerSubmitError] code or a server `errorCode`.
  final String? submitError;

  /// DEC-PROD-048 (DRAFT): false when admin turned KYC off — no documents,
  /// only services, name and vehicle class; ops still approves.
  final bool documentsRequired;

  /// Steps for the current mode (full KYC or the quick registration).
  List<DriverKycStep> get steps => documentsRequired
      ? DriverKycStep.values
      : const [
          DriverKycStep.services,
          DriverKycStep.personal,
          DriverKycStep.vehicle,
          DriverKycStep.review,
        ];

  int get stepNumber {
    final index = steps.indexOf(step);
    return (index < 0 ? 0 : index) + 1;
  }

  int get totalSteps => steps.length;

  bool get canContinueServices => rideService || foodService;

  bool get canContinuePersonal =>
      fullName.trim().length >= 2 &&
      (!documentsRequired ||
          (birthDate.trim().isNotEmpty && address.trim().isNotEmpty));

  bool get canContinueIdentity => documents.hasAll(const [
    PartnerDocumentKind.idFront,
    PartnerDocumentKind.idBack,
  ]);

  bool get canContinueIdNumber => RegExp(r'^\d{9,12}$').hasMatch(idNumber);

  bool get canContinueSelfie => documents.has(PartnerDocumentKind.selfie);

  bool get canContinueLicense =>
      documents.has(PartnerDocumentKind.license) &&
      licenseNumber.trim().length >= 6;

  bool get canContinueVehicle => vehiclePlate.trim().length >= 5;

  bool get hasSelectedVehicleClass {
    final code = vehicleClassCode?.trim().toUpperCase() ?? '';
    return code == 'MOTORBIKE' || code == 'CAR_4' || code == 'CAR_7';
  }

  bool get canContinueVehicleStep {
    if (!documentsRequired) {
      // Quick registration: plate + an explicit class (fail closed), no photos.
      return canContinueVehicle && hasSelectedVehicleClass;
    }
    if (!canContinueVehicle || !documents.has(PartnerDocumentKind.vehicleReg)) {
      return false;
    }
    // Fail closed: must explicitly choose a catalog class before continue/submit.
    if (!hasSelectedVehicleClass) {
      return false;
    }
    // OPEN-006 Car scaffold: require insurance photo for Car classes (fail closed in UI).
    if (PartnerDocumentKind.isCarClass(vehicleClassCode!) &&
        !documents.has(PartnerDocumentKind.vehicleInsurance)) {
      return false;
    }
    return true;
  }

  List<String> get requiredDriverDocumentKinds =>
      PartnerDocumentKind.driverRequiredFor(vehicleClassCode ?? '');

  bool get canContinueBank =>
      bankName.trim().length >= 2 &&
      RegExp(r'^\d{6,20}$').hasMatch(bankAccountNumber) &&
      bankAccountHolder.trim().length >= 2;

  bool get canSubmit => documentsRequired
      ? canSubmitFull
      : canContinueServices && canContinuePersonal && canContinueVehicleStep;

  bool get canSubmitFull =>
      canContinueServices &&
      canContinuePersonal &&
      canContinueIdentity &&
      canContinueSelfie &&
      canContinueLicense &&
      canContinueVehicleStep &&
      canContinueBank;

  DriverKycState copyWith({
    PartnerApplicationStatus? status,
    DriverKycStep? step,
    bool? rideService,
    bool? foodService,
    String? fullName,
    String? birthDate,
    String? address,
    String? idNumber,
    String? licenseClass,
    String? licenseNumber,
    String? vehiclePlate,
    String? vehicleClassCode,
    bool clearVehicleClassCode = false,
    String? vehicleType,
    bool clearVehicleType = false,
    String? vehicleBrand,
    String? vehicleModel,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    PartnerDocumentDraft? documents,
    List<PartnerReviewIssue>? issues,
    String? reason,
    bool clearReason = false,
    bool? seeded,
    bool? loading,
    bool? submitting,
    String? submitError,
    bool clearSubmitError = false,
    bool? documentsRequired,
  }) {
    return DriverKycState(
      documentsRequired: documentsRequired ?? this.documentsRequired,
      status: status ?? this.status,
      step: step ?? this.step,
      rideService: rideService ?? this.rideService,
      foodService: foodService ?? this.foodService,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      idNumber: idNumber ?? this.idNumber,
      licenseClass: licenseClass ?? this.licenseClass,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleClassCode: clearVehicleClassCode
          ? null
          : (vehicleClassCode ?? this.vehicleClassCode),
      vehicleType: clearVehicleType ? null : (vehicleType ?? this.vehicleType),
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      documents: documents ?? this.documents,
      issues: issues ?? this.issues,
      reason: clearReason ? null : (reason ?? this.reason),
      seeded: seeded ?? this.seeded,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class DriverKycCubit extends Cubit<DriverKycState> {
  DriverKycCubit({
    this._submitPartnerApplication,
    this._getMyPartnerApplication,
    this._accessToken,
    this._loadDocumentsRequired,
    bool? useMock,
  }) : _useMock = useMock ?? useMockData,
       super(DriverKycState.initial());

  static const role = 'DRIVER';

  final SubmitPartnerApplication? _submitPartnerApplication;
  final GetMyPartnerApplication? _getMyPartnerApplication;
  final String? Function()? _accessToken;
  final Future<bool> Function({
    required String accessToken,
    required String role,
  })?
  _loadDocumentsRequired;
  final bool _useMock;

  /// DEC-PROD-048: reads the admin KYC switch; keeps documents required on error.
  Future<void> loadRequirements() async {
    final load = _loadDocumentsRequired;
    final token = _accessToken?.call()?.trim() ?? '';
    if (load == null || token.isEmpty) {
      return;
    }
    final required = await load(accessToken: token, role: role);
    if (isClosed || required == state.documentsRequired) {
      return;
    }
    final next = state.copyWith(documentsRequired: required);
    emit(
      next.steps.contains(next.step)
          ? next
          : next.copyWith(step: DriverKycStep.services),
    );
  }

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
    final name = profile.displayName.trim();
    emit(
      state.copyWith(
        status: status,
        seeded: true,
        fullName: state.fullName.isEmpty && name.isNotEmpty ? name : null,
        bankAccountHolder: state.bankAccountHolder.isEmpty && name.isNotEmpty
            ? name.toUpperCase()
            : null,
      ),
    );
  }

  /// Loads the server application: status, review reason/issues, stored
  /// documents, and previously entered fields.
  Future<void> refresh() async {
    final load = _getMyPartnerApplication;
    final token = _accessToken?.call()?.trim() ?? '';
    if (_useMock || load == null || token.isEmpty || state.loading) {
      return;
    }
    emit(state.copyWith(loading: true));
    try {
      final view = await load(accessToken: token, role: role);
      if (isClosed) {
        return;
      }
      if (view == null) {
        emit(state.copyWith(loading: false));
        return;
      }
      _applyView(view);
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false));
      }
    }
  }

  void _applyView(PartnerApplicationView view) {
    final m = view.metadata;
    String keep(String current, String key) =>
        current.trim().isNotEmpty ? current : (metadataText(m, key) ?? current);
    emit(
      state.copyWith(
        status: partnerStatusFromServer(view.status),
        loading: false,
        reason: view.reason,
        clearReason: view.reason == null,
        issues: view.issues,
        documents: state.documents.synced(view.storedKinds),
        rideService: m['rideService'] is bool ? m['rideService'] as bool : null,
        foodService: m['foodService'] is bool ? m['foodService'] as bool : null,
        fullName: keep(state.fullName, 'fullName'),
        birthDate: keep(state.birthDate, 'birthDate'),
        address: keep(state.address, 'address'),
        idNumber: keep(state.idNumber, 'idNumber'),
        licenseClass: metadataText(m, 'licenseClass'),
        licenseNumber: keep(state.licenseNumber, 'licenseNumber'),
        vehiclePlate: keep(state.vehiclePlate, 'vehiclePlate'),
        vehicleClassCode: metadataText(m, 'vehicleClassCode'),
        clearVehicleClassCode: metadataText(m, 'vehicleClassCode') == null,
        vehicleType: metadataText(m, 'vehicleType'),
        clearVehicleType: metadataText(m, 'vehicleType') == null,
        vehicleBrand: keep(state.vehicleBrand, 'vehicleBrand'),
        vehicleModel: keep(state.vehicleModel, 'vehicleModel'),
        bankName: keep(state.bankName, 'bankName'),
        bankAccountNumber: keep(state.bankAccountNumber, 'bankAccountNumber'),
        bankAccountHolder: metadataText(m, 'bankAccountHolder'),
      ),
    );
  }

  void setFullName(String value) => emit(state.copyWith(fullName: value));

  void setBirthDate(String value) => emit(state.copyWith(birthDate: value));

  void setAddress(String value) => emit(state.copyWith(address: value));

  void setIdNumber(String value) =>
      emit(state.copyWith(idNumber: value.replaceAll(RegExp(r'\D'), '')));

  void setLicenseClass(String value) =>
      emit(state.copyWith(licenseClass: value));

  void setLicenseNumber(String value) =>
      emit(state.copyWith(licenseNumber: value.trim()));

  void setVehiclePlate(String value) =>
      emit(state.copyWith(vehiclePlate: value.toUpperCase()));

  void setVehicleClass({required String code, required String name}) =>
      emit(state.copyWith(vehicleClassCode: code, vehicleType: name));

  void setVehicleBrand(String value) =>
      emit(state.copyWith(vehicleBrand: value));

  void setVehicleModel(String value) =>
      emit(state.copyWith(vehicleModel: value));

  void setBankName(String value) => emit(state.copyWith(bankName: value));

  void setBankAccountNumber(String value) => emit(
    state.copyWith(bankAccountNumber: value.replaceAll(RegExp(r'\D'), '')),
  );

  void setBankAccountHolder(String value) =>
      emit(state.copyWith(bankAccountHolder: value.toUpperCase()));

  void attachDocument(String kind, PickedDocumentImage image) {
    emit(state.copyWith(documents: state.documents.attach(kind, image)));
  }

  void removeDocument(String kind) {
    emit(state.copyWith(documents: state.documents.detach(kind)));
  }

  void startDraft() {
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: DriverKycStep.services,
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
    final steps = state.steps;
    final index = steps.indexOf(state.step);
    if (index < 0 || index >= steps.length - 1) {
      return;
    }
    emit(state.copyWith(step: steps[index + 1]));
  }

  void previousStep() {
    final steps = state.steps;
    final index = steps.indexOf(state.step);
    if (index <= 0) {
      return;
    }
    emit(state.copyWith(step: steps[index - 1]));
  }

  /// Opens the flow at the step for [section] (or the first flagged one) and
  /// requires re-capturing every flagged document.
  void beginResubmit([String? section]) {
    final sections = [for (final issue in state.issues) issue.section];
    final target = section ?? (sections.isEmpty ? null : sections.first);
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: stepForSection(target),
        documents: state.documents.flag(sections),
        clearSubmitError: true,
      ),
    );
  }

  static DriverKycStep stepForSection(String? section) {
    return switch (section) {
      'PERSONAL' => DriverKycStep.personal,
      'ID_CARD' => DriverKycStep.identity,
      'SELFIE' => DriverKycStep.selfie,
      'LICENSE' => DriverKycStep.license,
      'VEHICLE' => DriverKycStep.vehicle,
      'BANK' => DriverKycStep.bank,
      _ => DriverKycStep.services,
    };
  }

  Future<void> submit() => _submitApplication();

  Future<void> resubmit() => _submitApplication();

  Map<String, Object?> _metadata() => {
    'rideService': state.rideService,
    'foodService': state.foodService,
    'fullName': state.fullName.trim(),
    'birthDate': state.birthDate.trim(),
    'address': state.address.trim(),
    'idNumber': state.idNumber,
    'licenseClass': state.licenseClass,
    'licenseNumber': state.licenseNumber,
    'vehiclePlate': state.vehiclePlate.trim(),
    if (state.vehicleClassCode != null &&
        state.vehicleClassCode!.trim().isNotEmpty)
      'vehicleClassCode': state.vehicleClassCode!.trim().toUpperCase(),
    if (state.vehicleType != null && state.vehicleType!.trim().isNotEmpty)
      'vehicleType': state.vehicleType!.trim(),
    'vehicleBrand': state.vehicleBrand.trim(),
    'vehicleModel': state.vehicleModel.trim(),
    'bankName': state.bankName.trim(),
    'bankAccountNumber': state.bankAccountNumber,
    'bankAccountHolder': state.bankAccountHolder.trim(),
  };

  Future<void> _submitApplication() async {
    if (state.submitting) {
      return;
    }
    if (!state.hasSelectedVehicleClass) {
      emit(state.copyWith(submitError: PartnerSubmitError.validation));
      return;
    }
    final submit = _submitPartnerApplication;
    if (_useMock || submit == null) {
      emit(
        state.copyWith(
          status: PartnerApplicationStatus.pending,
          documents: state.documents.synced({
            ...state.documents.stored,
            ...state.documents.picked.keys,
          }),
          issues: const [],
          clearReason: true,
          clearSubmitError: true,
        ),
      );
      return;
    }
    final token = _accessToken?.call()?.trim() ?? '';
    if (token.isEmpty) {
      emit(state.copyWith(submitError: PartnerSubmitError.sessionExpired));
      return;
    }
    emit(state.copyWith(submitting: true, clearSubmitError: true));
    try {
      final view = await submit(
        SubmitPartnerApplicationRequest(
          accessToken: token,
          role: role,
          metadata: _metadata(),
          documents: state.documentsRequired
              ? state.documents.uploads(state.requiredDriverDocumentKinds)
              : const [],
        ),
      );
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          status: partnerStatusFromServer(view.status),
          submitting: false,
          documents: state.documents.synced(view.storedKinds),
          issues: view.issues,
          clearReason: true,
          clearSubmitError: true,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(submitting: false, submitError: error.errorCode));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          submitting: false,
          submitError: PartnerSubmitError.network,
        ),
      );
    }
  }
}
