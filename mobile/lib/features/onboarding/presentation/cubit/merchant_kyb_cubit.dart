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
    this.shopLat,
    this.shopLng,
    this.loading = false,
    this.submitting = false,
    this.submitError,
    this.documentsRequired = true,
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
      documents.hasAll(PartnerDocumentKind.merchantRequired) &&
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
  }) {
    return MerchantKybState(
      documentsRequired: documentsRequired ?? this.documentsRequired,
      status: status ?? this.status,
      step: step ?? this.step,
      businessType: businessType ?? this.businessType,
      registrationSubject: registrationSubject ?? this.registrationSubject,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
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
    bool? useMock,
  }) : _useMock = useMock ?? useMockData,
       super(MerchantKybState.initial());

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

  void setRepresentativeName(String value) =>
      emit(state.copyWith(representativeName: value));

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
          metadata: {
            'businessType': state.businessType,
            'registrationSubject': state.registrationSubject,
            'shopName': state.shopName.trim(),
            'shopAddress': state.shopAddress.trim(),
            'shopLat': ?state.shopLat,
            'shopLng': ?state.shopLng,
            'representativeName': state.representativeName.trim(),
            'bankName': state.bankName.trim(),
            'bankAccountNumber': state.bankAccountNumber,
            'bankAccountHolder': state.bankAccountHolder.trim(),
          },
          documents: state.documentsRequired
              ? state.documents.uploads(PartnerDocumentKind.merchantAll)
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

double? _coordinate(Object? value) => value is num ? value.toDouble() : null;
