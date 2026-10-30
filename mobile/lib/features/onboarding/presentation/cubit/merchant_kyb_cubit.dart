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

enum MerchantKybStep {
  businessType,
  shopInfo,
  representative,
  documents,
  review,
}

class MerchantKybState {
  const MerchantKybState({
    required this.status,
    required this.step,
    required this.businessType,
    required this.registrationSubject,
    required this.shopName,
    required this.shopAddress,
    required this.representativeName,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountHolder,
    required this.documents,
    required this.issues,
    required this.seeded,
    this.reason,
    this.shopCategory,
    this.shopLat,
    this.shopLng,
    this.loading = false,
    this.submitting = false,
    this.submitError,
    this.documentsRequired = true,
    this.foodSafetyCommitment = false,
    this.ocr = const OcrPrefill(),
    this.ocrReading = false,
  });

  factory MerchantKybState.initial() {
    return const MerchantKybState(
      status: PartnerApplicationStatus.draft,
      step: MerchantKybStep.businessType,
      businessType: MerchantBusinessType.restaurant,
      registrationSubject: MerchantRegistrationSubject.household,
      shopName: '',
      shopAddress: '',
      representativeName: '',
      bankName: '',
      bankAccountNumber: '',
      bankAccountHolder: '',
      documents: PartnerDocumentDraft(),
      issues: [],
      seeded: false,
    );
  }

  final PartnerApplicationStatus status;
  final MerchantKybStep step;

  /// [MerchantBusinessType] code.
  final String businessType;

  /// [MerchantRegistrationSubject] code.
  final String registrationSubject;
  final String shopName;
  final String shopAddress;

  /// Admin-managed food category code (`GET /v1/public/food-categories`);
  /// optional, the merchant can set it later in Hồ sơ quán.
  final String? shopCategory;

  /// The pickup pin, required by the backend for merchant KYB
  /// (GrabFood / ShopeeFood merchant sign-up also pins the store on a map).
  final double? shopLat;
  final double? shopLng;

  bool get hasShopPin => shopLat != null && shopLng != null;
  final String representativeName;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;
  final PartnerDocumentDraft documents;
  final List<PartnerReviewIssue> issues;
  final String? reason;
  final bool seeded;
  final bool loading;
  final bool submitting;
  final String? submitError;

  /// DEC-PROD-048 (DRAFT): false when admin turned KYB off — shop info only,
  /// no documents or bank; ops still approves.
  final bool documentsRequired;

  /// t61u: household shop files the ATTP commitment instead of the certificate.
  final bool foodSafetyCommitment;

  /// t61u: values read from document photos on the device.
  final OcrPrefill ocr;
  final bool ocrReading;

  bool get canUseFoodSafetyCommitment =>
      registrationSubject == MerchantRegistrationSubject.household;

  bool get usesFoodSafetyCommitment =>
      canUseFoodSafetyCommitment && foodSafetyCommitment;

  List<String> get requiredDocumentKinds =>
      PartnerDocumentKind.merchantRequiredFor(
        useCommitment: usesFoodSafetyCommitment,
      );

  List<String> get documentKinds => PartnerDocumentKind.merchantAllFor(
    useCommitment: usesFoodSafetyCommitment,
  );

  List<MerchantKybStep> get steps => documentsRequired
      ? MerchantKybStep.values
      : const [
          MerchantKybStep.businessType,
          MerchantKybStep.shopInfo,
          MerchantKybStep.review,
        ];

  int get stepNumber {
    final index = steps.indexOf(step);
    return (index < 0 ? 0 : index) + 1;
  }

  int get totalSteps => steps.length;

  bool get canContinueShopInfo =>
      shopName.trim().length >= 2 &&
      shopAddress.trim().isNotEmpty &&
      hasShopPin;

  bool get canContinueRepresentative =>
      representativeName.trim().length >= 2 &&
      bankName.trim().length >= 2 &&
      RegExp(r'^\d{6,20}$').hasMatch(bankAccountNumber) &&
      bankAccountHolder.trim().length >= 2;

  bool get canContinueDocuments =>
      documents.hasAll(requiredDocumentKinds) &&
      !documents.isFlagged(PartnerDocumentKind.storefront);

  bool get canSubmit => documentsRequired
      ? canContinueShopInfo && canContinueRepresentative && canContinueDocuments
      : canContinueShopInfo;

  MerchantKybState copyWith({
    PartnerApplicationStatus? status,
    MerchantKybStep? step,
    String? businessType,
    String? registrationSubject,
    String? shopName,
    String? shopAddress,
    String? shopCategory,
    double? shopLat,
    double? shopLng,
    String? representativeName,
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
    bool? foodSafetyCommitment,
    OcrPrefill? ocr,
    bool? ocrReading,
  }) {
    return MerchantKybState(
      foodSafetyCommitment: foodSafetyCommitment ?? this.foodSafetyCommitment,
      ocr: ocr ?? this.ocr,
      ocrReading: ocrReading ?? this.ocrReading,
      documentsRequired: documentsRequired ?? this.documentsRequired,
      status: status ?? this.status,
      step: step ?? this.step,
      businessType: businessType ?? this.businessType,
      registrationSubject: registrationSubject ?? this.registrationSubject,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopCategory: shopCategory ?? this.shopCategory,
      shopLat: shopLat ?? this.shopLat,
      shopLng: shopLng ?? this.shopLng,
      representativeName: representativeName ?? this.representativeName,
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

class MerchantKybCubit extends Cubit<MerchantKybState> {
  MerchantKybCubit({
    this._submitPartnerApplication,
    this._getMyPartnerApplication,
    this._accessToken,
    this._loadDocumentsRequired,
    this._draftStore,
    this._draftOwner,
    bool? useMock,
    this._textReader,
  }) : _useMock = useMock ?? useMockData,
       super(MerchantKybState.initial());

  final DocumentTextReader? _textReader;

  static const role = 'MERCHANT';

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
    final stepIndex = MerchantKybStep.values.indexWhere(
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
    final saved = MerchantKybStep.values
        .where((step) => step.name == d['step'])
        .firstOrNull;
    final step = saved != null && state.steps.contains(saved)
        ? saved
        : MerchantKybStep.businessType;
    final type = draftString(d, 'businessType');
    final subject = draftString(d, 'registrationSubject');
    _editing = true;
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: step,
        businessType: MerchantBusinessType.values.contains(type) ? type : null,
        registrationSubject:
            MerchantRegistrationSubject.values.contains(subject)
            ? subject
            : null,
        shopName: draftString(d, 'shopName'),
        shopAddress: draftString(d, 'shopAddress'),
        shopCategory: draftString(d, 'shopCategory'),
        shopLat: _coordinate(d['shopLat']),
        shopLng: _coordinate(d['shopLng']),
        representativeName: draftString(d, 'representativeName'),
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

  Map<String, Object?> _metadataOf(MerchantKybState state) => {
    ...state.documents.captureMetadata(),
    'businessType': state.businessType,
    'registrationSubject': state.registrationSubject,
    'shopName': state.shopName.trim(),
    'shopAddress': state.shopAddress.trim(),
    'shopCategory': ?state.shopCategory,
    'shopLat': ?state.shopLat,
    'shopLng': ?state.shopLng,
    'representativeName': state.representativeName.trim(),
    'bankName': state.bankName.trim(),
    'bankAccountNumber': state.bankAccountNumber,
    'bankAccountHolder': state.bankAccountHolder.trim(),
    if (state.usesFoodSafetyCommitment) 'foodSafetyCommitment': true,
    ...state.ocr.toMetadata(extraKeys: ocrExtraKeys),
  };

  @override
  void onChange(Change<MerchantKybState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (!_editing || next.status != PartnerApplicationStatus.draft) {
      return;
    }
    _draftKeeper()?.schedule({
      ..._metadataOf(next),
      // Untrimmed so a restored field reads exactly as typed.
      'shopName': next.shopName,
      'shopAddress': next.shopAddress,
      'representativeName': next.representativeName,
      'step': next.step.name,
      'docs': draftDocumentTypes(next.documents),
    });
  }

  @override
  Future<void> close() async {
    await _keeper?.flush();
    return super.close();
  }

  /// DEC-PROD-048: reads the admin KYB switch; keeps documents required on error.
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
          : next.copyWith(step: MerchantKybStep.businessType),
    );
  }

  void seedFromProfile(UserProfile profile) {
    if (state.seeded) {
      return;
    }
    final grant = profile.grantStatus(AppRole.merchant);
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
        representativeName: state.representativeName.isEmpty && name.isNotEmpty
            ? name
            : null,
        bankAccountHolder: state.bankAccountHolder.isEmpty && name.isNotEmpty
            ? name.toUpperCase()
            : null,
      ),
    );
  }

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
      final m = view.metadata;
      String keep(String current, String key) => current.trim().isNotEmpty
          ? current
          : (metadataText(m, key) ?? current);
      final type = metadataText(m, 'businessType');
      final subject = metadataText(m, 'registrationSubject');
      final category = metadataText(m, 'shopCategory');
      emit(
        state.copyWith(
          status: partnerStatusFromServer(view.status),
          loading: false,
          reason: view.reason,
          clearReason: view.reason == null,
          issues: view.issues,
          documents: state.documents.synced(view.storedKinds),
          businessType: MerchantBusinessType.values.contains(type)
              ? type
              : null,
          registrationSubject:
              MerchantRegistrationSubject.values.contains(subject)
              ? subject
              : null,
          shopName: keep(state.shopName, 'shopName'),
          shopAddress: keep(state.shopAddress, 'shopAddress'),
          shopCategory: state.shopCategory ?? category,
          shopLat: state.shopLat ?? _coordinate(m['shopLat']),
          shopLng: state.shopLng ?? _coordinate(m['shopLng']),
          representativeName: metadataText(m, 'representativeName'),
          bankName: keep(state.bankName, 'bankName'),
          bankAccountNumber: keep(state.bankAccountNumber, 'bankAccountNumber'),
          bankAccountHolder: metadataText(m, 'bankAccountHolder'),
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(loading: false));
      }
    }
  }

  void setShopName(String value) => emit(state.copyWith(shopName: value));

  void setShopAddress(String value) => emit(state.copyWith(shopAddress: value));

  void setShopCategory(String code) => emit(state.copyWith(shopCategory: code));

  /// Pins the store; fills an empty address with the picked place label.
  void setShopPin({
    required double lat,
    required double lng,
    required String label,
  }) {
    emit(
      state.copyWith(
        shopLat: lat,
        shopLng: lng,
        shopAddress: state.shopAddress.trim().isEmpty ? label : null,
      ),
    );
  }

  void setRepresentativeName(String value) => emit(
    state.copyWith(
      representativeName: value,
      ocr: state.ocr.onEdit('representativeName', value),
    ),
  );

  void setFoodSafetyCommitment(bool value) =>
      emit(state.copyWith(foodSafetyCommitment: value));

  static const ocrExtraKeys = [
    OcrKeys.businessLicenseNumber,
    OcrKeys.businessName,
    'representativeIdNumber',
  ];

  /// t61u: reads the photo on the device and prefills empty fields.
  Future<void> readDocumentText(String kind, PickedDocumentImage image) async {
    final reader = _textReader;
    if (reader == null || !state.documentsRequired) return;
    emit(state.copyWith(ocrReading: true));
    final text = await reader.read(image.bytes);
    if (isClosed) return;
    var parsed = text == null
        ? const <String, String>{}
        : parseDocumentText(kind, text);
    if (kind == PartnerDocumentKind.repIdFront) {
      parsed = {
        if (parsed[OcrKeys.fullName] != null)
          'representativeName': parsed[OcrKeys.fullName]!,
        if (parsed[OcrKeys.idNumber] != null)
          'representativeIdNumber': parsed[OcrKeys.idNumber]!,
      };
    } else if (kind != PartnerDocumentKind.businessLicense) {
      parsed = const {};
    }
    applyOcr(parsed);
  }

  void applyOcr(Map<String, String> parsed) {
    final merged = state.ocr.merge(parsed, {
      'representativeName': state.representativeName,
      for (final key in ocrExtraKeys) key: state.ocr.values[key] ?? '',
    });
    emit(
      state.copyWith(
        ocrReading: false,
        ocr: merged.prefill,
        representativeName: merged.apply['representativeName'],
      ),
    );
  }

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
        step: MerchantKybStep.businessType,
        clearSubmitError: true,
      ),
    );
  }

  void selectBusinessType(String value) {
    emit(state.copyWith(businessType: value));
  }

  void selectRegistrationSubject(String value) {
    emit(state.copyWith(registrationSubject: value));
  }

  void goToStep(MerchantKybStep step) {
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

  static MerchantKybStep stepForSection(String? section) {
    return switch (section) {
      'SHOP_INFO' => MerchantKybStep.shopInfo,
      'REPRESENTATIVE' || 'BANK' => MerchantKybStep.representative,
      'BUSINESS_DOCS' || 'STOREFRONT' => MerchantKybStep.documents,
      _ => MerchantKybStep.businessType,
    };
  }

  Future<void> submit() => _submitApplication();

  Future<void> resubmit() => _submitApplication();

  Future<void> _submitApplication() async {
    if (state.submitting) {
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
          metadata: _metadataOf(state),
          documents: state.documentsRequired
              ? state.documents.uploads(state.documentKinds)
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

double? _coordinate(Object? value) => value is num ? value.toDouble() : null;
