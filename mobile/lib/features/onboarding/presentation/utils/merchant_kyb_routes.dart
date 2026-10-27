import '../../domain/entities/partner_onboarding.dart';
import '../cubit/merchant_kyb_cubit.dart';

abstract final class MerchantKybRoutes {
  static const root = '/merchant/kyb';
  static const intro = '/merchant/kyb/intro';
  static const steps = '/merchant/kyb/steps';
  static const status = '/merchant/kyb/status';
  static const rejected = '/merchant/kyb/rejected';
  static const pin = '/merchant/kyb/pin';

  static String entryFor(PartnerApplicationStatus applicationStatus) {
    return switch (applicationStatus) {
      PartnerApplicationStatus.draft => intro,
      PartnerApplicationStatus.pending => status,
      PartnerApplicationStatus.rejected => rejected,
      PartnerApplicationStatus.active => status,
    };
  }

  static String entryFromCubit(MerchantKybCubit cubit) {
    return entryFor(cubit.state.status);
  }
}
