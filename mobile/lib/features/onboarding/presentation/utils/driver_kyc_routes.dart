import '../../domain/entities/partner_onboarding.dart';
import '../cubit/driver_kyc_cubit.dart';

abstract final class DriverKycRoutes {
  static const root = '/driver/kyc';
  static const intro = '/driver/kyc/intro';
  static const steps = '/driver/kyc/steps';
  static const status = '/driver/kyc/status';
  static const rejected = '/driver/kyc/rejected';

  static String entryFor(PartnerApplicationStatus applicationStatus) {
    return switch (applicationStatus) {
      PartnerApplicationStatus.draft => intro,
      PartnerApplicationStatus.pending => status,
      PartnerApplicationStatus.rejected => rejected,
      PartnerApplicationStatus.active => status,
    };
  }

  static String entryFromCubit(DriverKycCubit cubit) {
    return entryFor(cubit.state.status);
  }
}
