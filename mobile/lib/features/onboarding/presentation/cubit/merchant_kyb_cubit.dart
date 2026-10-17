import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/domain/entities/user_profile.dart';
import '../../domain/entities/partner_application.dart';
import '../../domain/entities/partner_onboarding.dart';
import '../../domain/usecases/submit_partner_application.dart';

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
    required this.docsAttached,
    required this.rejections,
    required this.seeded,
    this.submitting = false,
    this.submitError,
  });

  factory MerchantKybState.initial() {
    return const MerchantKybState(
      status: PartnerApplicationStatus.draft,
      step: MerchantKybStep.businessType,
      businessType: 'Quán ăn / Nhà hàng',
      registrationSubject: 'Hộ kinh doanh',
      shopName: 'Bún Bò Huế O Cô',
      shopAddress: 'Hải Châu, Đà Nẵng',
      representativeName: 'Nguyễn Thị B',
      docsAttached: false,
      rejections: merchantDemoRejections,
      seeded: false,
    );
  }

  final PartnerApplicationStatus status;
  final MerchantKybStep step;
  final String businessType;
  final String registrationSubject;
  final String shopName;
  final String shopAddress;
  final String representativeName;
  final bool docsAttached;
  final List<OnboardingRejection> rejections;
  final bool seeded;
  final bool submitting;
  final String? submitError;

  int get stepNumber => MerchantKybStep.values.indexOf(step) + 1;
  int get totalSteps => MerchantKybStep.values.length;

  MerchantKybState copyWith({
    PartnerApplicationStatus? status,
    MerchantKybStep? step,
    String? businessType,
    String? registrationSubject,
    String? shopName,
    String? shopAddress,
    String? representativeName,
    bool? docsAttached,
    List<OnboardingRejection>? rejections,
    bool? seeded,
    bool? submitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return MerchantKybState(
      status: status ?? this.status,
      step: step ?? this.step,
      businessType: businessType ?? this.businessType,
      registrationSubject: registrationSubject ?? this.registrationSubject,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      representativeName: representativeName ?? this.representativeName,
      docsAttached: docsAttached ?? this.docsAttached,
      rejections: rejections ?? this.rejections,
      seeded: seeded ?? this.seeded,
      submitting: submitting ?? this.submitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class MerchantKybCubit extends Cubit<MerchantKybState> {
  MerchantKybCubit({
    SubmitPartnerApplication? submitPartnerApplication,
    this._accessToken,
    bool? useMock,
  }) : _submitPartnerApplication = submitPartnerApplication,
       _useMock = useMock ?? useMockData,
       super(MerchantKybState.initial());

  final SubmitPartnerApplication? _submitPartnerApplication;
  final String? Function()? _accessToken;
  final bool _useMock;

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
    emit(state.copyWith(status: status, seeded: true));
  }

  void startDraft() {
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: MerchantKybStep.businessType,
        docsAttached: false,
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
    final index = MerchantKybStep.values.indexOf(state.step);
    if (index >= MerchantKybStep.values.length - 1) {
      return;
    }
    emit(state.copyWith(step: MerchantKybStep.values[index + 1]));
  }

  void previousStep() {
    final index = MerchantKybStep.values.indexOf(state.step);
    if (index <= 0) {
      return;
    }
    emit(state.copyWith(step: MerchantKybStep.values[index - 1]));
  }

  void toggleDocsAttached() {
    emit(state.copyWith(docsAttached: !state.docsAttached));
  }

  Future<void> submit() => _submitApplication();

  void simulateReject() {
    emit(state.copyWith(status: PartnerApplicationStatus.rejected));
  }

  void beginResubmit() {
    emit(
      state.copyWith(
        status: PartnerApplicationStatus.draft,
        step: MerchantKybStep.documents,
        docsAttached: false,
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
          role: 'MERCHANT',
          metadata: {
            'businessType': state.businessType,
            'registrationSubject': state.registrationSubject,
            'shopName': state.shopName,
            'shopAddress': state.shopAddress,
            'representativeName': state.representativeName,
            'docsAttached': state.docsAttached,
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
