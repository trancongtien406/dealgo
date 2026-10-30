import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/drafts/draft_store.dart';
import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/user_profile.dart';
import '../../domain/entities/partner_application.dart';
import '../../domain/entities/partner_documents.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../../domain/ocr/document_ocr_parser.dart';
import '../../domain/ocr/document_text_reader.dart';
import '../../domain/ocr/ocr_prefill.dart';
import '../../domain/usecases/get_my_partner_application.dart';
import '../../domain/usecases/submit_partner_application.dart';
import '../document_image_source.dart';
import 'partner_document_draft.dart';
import 'partner_draft_support.dart';

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
    this.ocr = const OcrPrefill(),
    this.ocrReading = false,
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

  /// t61u: values read from document photos on the device.
  final OcrPrefill ocr;
  final bool ocrReading;

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

  bool get canContinueSelfie =>
      documents.has(PartnerDocumentKind.selfie) &&
      documents.has(PartnerDocumentKind.selfieVideo);

  bool get canContinueLicense =>
      documents.has(PartnerDocumentKind.license) &&
      licenseNumber.trim().length >= 6;

  bool get canContinueVehicle => vehiclePlate.trim().length >= 5;

  bool get hasSelectedVehicleClass {
    final code = vehicleClassCode?.trim().toUpperCase() ?? '';
    return code == 'MOTORBIKE' || code == 'CAR_4' || code == 'CAR_7';
  }

  /// t60u: false when e.g. an A1 (motorbike) licence is paired with CAR_4.
  bool get licenseMatchesVehicle =>
      !hasSelectedVehicleClass ||
      PartnerDocumentKind.licenseCoversVehicle(licenseClass, vehicleClassCode!);

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
    // t60u: the declared licence class must cover the chosen vehicle class.
    if (!licenseMatchesVehicle) {
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
    OcrPrefill? ocr,
    bool? ocrReading,
  }) {
    return DriverKycState(
      documentsRequired: documentsRequired ?? this.documentsRequired,
      ocr: ocr ?? this.ocr,
      ocrReading: ocrReading ?? this.ocrReading,
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
    this._draftStore,
    this._draftOwner,
    bool? useMock,
    this._textReader,
  }) : _useMock = useMock ?? useMockData,
       super(DriverKycState.initial());

  final DocumentTextReader? _textReader;

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

  /// Unsent-draft persistence (app killed mid-flow); off without a store/user.
  final DraftStore? _draftStore;
  final String? Function()? _draftOwner;
  DraftKeeper? _keeper;
  var _editing = false;
  PartnerDraftSnapshot? _pendingDraft;

  /// Draft found by [loadDraft], until [restoreDraft] or [discardDraft].
  PartnerDraftSnapshot? get pendingDraft => _pendingDraft;

  DraftKeeper? _draftKeeper() {
    final store = _draftStore;
    final owner = _draftOwner?.call()?.trim() ?? '';
    if (store == null || owner.isEmpty) {
      return null;
    }
    final key = partnerDraftKey(role, owner);
    final current = _keeper;
    if (current != null && current.key == key) {
      return current;
    }
    return _keeper = DraftKeeper(store: store, key: key);
  }

  /// Looks for an unsent draft from an earlier session (call after
  /// [refresh]). True when one worth resuming exists: see [pendingDraft].
  Future<bool> loadDraft() async {
    final keeper = _draftKeeper();
    if (keeper == null || _editing) {
      return false;
    }
    if (state.status == PartnerApplicationStatus.pending ||
        state.status == PartnerApplicationStatus.active) {
      _pendingDraft = null;
      await keeper.clear();
      return false;
    }
    final data = await keeper.load();
    if (data == null || isClosed) {
      return false;
    }
    final stepIndex = DriverKycStep.values.indexWhere(
      (step) => step.name == data['step'],
    );
    final images = await loadDraftImages(
      keeper.store,
      keeper.key,
      data['docs'],
    );
    if (stepIndex <= 0 && images.isEmpty) {
      return false;
    }
    _pendingDraft = PartnerDraftSnapshot(
      fields: data,
      images: images,
      savedAt: DateTime.tryParse('${data['savedAt']}'),
    );
    return true;
  }

  /// Puts the saved draft back, at the step the applicant left.
  void restoreDraft() {
    final draft = _pendingDraft;
    if (draft == null) {
      return;
    }
    _pendingDraft = null;
    final d = draft.fields;
    var documents = state.documents;
    for (final entry in draft.images.entries) {
      documents = documents.attach(entry.key, entry.value);
    }
    final saved = DriverKycStep.values
        .where((step) => step.name == d['step'])
        .firstOrNull;
    final step = saved != null && state.steps.contains(saved)
        ? saved
        : DriverKycStep.services;
    _editing = true;
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: step,
        rideService: d['rideService'] is bool ? d['rideService'] as bool : null,
        foodService: d['foodService'] is bool ? d['foodService'] as bool : null,
        fullName: draftString(d, 'fullName'),
        birthDate: draftString(d, 'birthDate'),
        address: draftString(d, 'address'),
        idNumber: draftString(d, 'idNumber'),
        licenseClass: draftString(d, 'licenseClass'),
        licenseNumber: draftString(d, 'licenseNumber'),
        vehiclePlate: draftString(d, 'vehiclePlate'),
        vehicleClassCode: draftString(d, 'vehicleClassCode'),
        vehicleType: draftString(d, 'vehicleType'),
        vehicleBrand: draftString(d, 'vehicleBrand'),
        vehicleModel: draftString(d, 'vehicleModel'),
        bankName: draftString(d, 'bankName'),
        bankAccountNumber: draftString(d, 'bankAccountNumber'),
        bankAccountHolder: draftString(d, 'bankAccountHolder'),
        documents: documents,
        clearSubmitError: true,
      ),
    );
  }

  /// "Làm lại từ đầu": drops the saved draft (fields and photos).
  Future<void> discardDraft() async {
    _pendingDraft = null;
    _editing = false;
    await _draftKeeper()?.clear();
  }

  void _finishDraft() {
    _pendingDraft = null;
    _editing = false;
    unawaited(_draftKeeper()?.clear());
  }

  @override
  void onChange(Change<DriverKycState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (!_editing || next.status != PartnerApplicationStatus.draft) {
      return;
    }
    _draftKeeper()?.schedule({
      ..._metadataOf(next),
      'step': next.step.name,
      'docs': draftDocumentTypes(next.documents),
    });
  }

  @override
  Future<void> close() async {
    await _keeper?.flush();
    return super.close();
  }

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

  void setFullName(String value) => emit(
    state.copyWith(fullName: value, ocr: state.ocr.onEdit('fullName', value)),
  );

  void setBirthDate(String value) => emit(
    state.copyWith(birthDate: value, ocr: state.ocr.onEdit('birthDate', value)),
  );

  void setAddress(String value) => emit(
    state.copyWith(address: value, ocr: state.ocr.onEdit('address', value)),
  );

  void setIdNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    emit(
      state.copyWith(
        idNumber: digits,
        ocr: state.ocr.onEdit('idNumber', digits),
      ),
    );
  }

  void setLicenseClass(String value) => emit(
    state.copyWith(
      licenseClass: value,
      ocr: state.ocr.onEdit('licenseClass', value),
    ),
  );

  void setLicenseNumber(String value) => emit(
    state.copyWith(
      licenseNumber: value.trim(),
      ocr: state.ocr.onEdit('licenseNumber', value.trim()),
    ),
  );

  void setVehiclePlate(String value) => emit(
    state.copyWith(
      vehiclePlate: value.toUpperCase(),
      ocr: state.ocr.onEdit('vehiclePlate', value.toUpperCase()),
    ),
  );

  /// Extra keys OCR may fill that have no own form field (sent as metadata).
  static const ocrExtraKeys = [
    OcrKeys.gender,
    OcrKeys.hometown,
    OcrKeys.idIssueDate,
    OcrKeys.licenseExpiry,
  ];

  /// t61u: reads the photo on the device and prefills empty fields.
  Future<void> readDocumentText(String kind, PickedDocumentImage image) async {
    final reader = _textReader;
    if (reader == null || !state.documentsRequired) return;
    emit(state.copyWith(ocrReading: true));
    final text = await reader.read(image.bytes);
    if (isClosed) return;
    final parsed = text == null
        ? const <String, String>{}
        : parseDocumentText(kind, text);
    applyOcr(parsed);
  }

  /// Applies parsed OCR values (public for tests).
  void applyOcr(Map<String, String> parsed) {
    final usable = {
      for (final e in parsed.entries)
        if (e.key != 'mrzName' &&
            (e.key != OcrKeys.licenseClass ||
                PartnerDocumentKind.licenseClasses.contains(e.value)))
          e.key: e.value,
    };
    final merged = state.ocr.merge(usable, {
      'fullName': state.fullName,
      'birthDate': state.birthDate,
      'address': state.address,
      'idNumber': state.idNumber,
      // The class chip always has a value; only an OCR'd class may move it.
      'licenseClass': state.ocr.prefilled.contains('licenseClass')
          ? state.licenseClass
          : '',
      'licenseNumber': state.licenseNumber,
      'vehiclePlate': state.vehiclePlate,
      for (final key in ocrExtraKeys) key: state.ocr.values[key] ?? '',
    });
    final a = merged.apply;
    emit(
      state.copyWith(
        ocrReading: false,
        ocr: merged.prefill,
        fullName: a['fullName'],
        birthDate: a['birthDate'],
        address: a['address'],
        idNumber: a['idNumber'],
        licenseClass: a['licenseClass'],
        licenseNumber: a['licenseNumber'],
        vehiclePlate: a['vehiclePlate'],
      ),
    );
  }

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
    final keeper = _editing ? _draftKeeper() : null;
    if (keeper != null) {
      unawaited(keeper.store.writeBlob(keeper.key, kind, image.bytes));
    }
    unawaited(readDocumentText(kind, image));
  }

  void removeDocument(String kind) {
    emit(state.copyWith(documents: state.documents.detach(kind)));
    final keeper = _editing ? _draftKeeper() : null;
    if (keeper != null) {
      unawaited(keeper.store.deleteBlob(keeper.key, kind));
    }
  }

  void startDraft() {
    _editing = true;
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
    _editing = true;
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

  Map<String, Object?> _metadata() => _metadataOf(state);

  Map<String, Object?> _metadataOf(DriverKycState state) => {
    ...state.documents.captureMetadata(),
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
    ...state.ocr.toMetadata(extraKeys: ocrExtraKeys),
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
      _finishDraft();
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
      _finishDraft();
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
      if (error.errorCode == partnerAlreadySubmitted) {
        // An earlier tap (or a retry after a dropped response) already
        // landed: show the application under review, not an error.
        _finishDraft();
        emit(
          state.copyWith(
            status: PartnerApplicationStatus.pending,
            submitting: false,
            clearSubmitError: true,
          ),
        );
        await refresh();
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
