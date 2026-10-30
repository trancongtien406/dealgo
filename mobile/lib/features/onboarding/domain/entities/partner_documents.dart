/// Document and review-section codes shared with the backend
/// (PARTNER_DOCUMENT_KINDS / PARTNER_ISSUE_SECTIONS, DEC-PROD-020).
abstract final class PartnerDocumentKind {
  static const idFront = 'ID_FRONT';
  static const idBack = 'ID_BACK';
  static const selfie = 'SELFIE';
  static const license = 'LICENSE';
  static const vehicleReg = 'VEHICLE_REG';

  /// OPEN-006 Car KYC scaffold — checklist only; not a legal determination.
  static const vehicleInsurance = 'VEHICLE_INSURANCE';
  static const businessLicense = 'BUSINESS_LICENSE';

  /// t60u: giấy chứng nhận an toàn thực phẩm (or the small-shop commitment).
  static const foodSafetyCert = 'FOOD_SAFETY_CERT';

  /// t61u (DEC-PROD-070): bản cam kết bảo đảm ATTP — a household shop may file
  /// it in place of [foodSafetyCert] (backend documentAlternatives).
  static const foodSafetyCommitment = 'FOOD_SAFETY_COMMITMENT';
  static const repIdFront = 'REP_ID_FRONT';
  static const repIdBack = 'REP_ID_BACK';
  static const storefront = 'STOREFRONT';

  /// t53u: optional face-liveness clip; ops-only evidence, never required.
  static const selfieVideo = 'SELFIE_VIDEO';

  static const driverRequired = [
    idFront,
    idBack,
    selfie,
    selfieVideo,
    license,
    vehicleReg,
  ];
  static const merchantRequired = [
    businessLicense,
    foodSafetyCert,
    repIdFront,
    repIdBack,
  ];
  static const merchantAll = [...merchantRequired, storefront];

  /// Required merchant kinds; a household using the commitment swaps the cert.
  static List<String> merchantRequiredFor({required bool useCommitment}) => [
    for (final kind in merchantRequired)
      kind == foodSafetyCert && useCommitment ? foodSafetyCommitment : kind,
  ];

  static List<String> merchantAllFor({required bool useCommitment}) => [
    ...merchantRequiredFor(useCommitment: useCommitment),
    storefront,
  ];

  /// Class-appropriate DRIVER checklist (Car adds insurance when applying as Car).
  static List<String> driverRequiredFor(String vehicleClassCode) {
    final code = vehicleClassCode.trim().toUpperCase();
    if (code == 'CAR_4' || code == 'CAR_7') {
      return [...driverRequired, vehicleInsurance];
    }
    return List<String>.from(driverRequired);
  }

  /// t60u: licence classes shown in the app (2024 law); backend also accepts
  /// older cards (A2, B1, B2, E). Mirrors LICENSE_CLASSES_FOR_VEHICLE.
  static const licenseClasses = ['A1', 'A', 'B', 'C1', 'C', 'D'];

  static const _motorbikeLicenses = {'A1', 'A', 'A2'};
  static const _carLicenses = {
    'B', 'B1', 'B2', 'C1', 'C', 'D1', 'D2', 'D', 'E', //
  };

  /// Whether [licenseClass] lets the driver operate [vehicleClassCode].
  static bool licenseCoversVehicle(
    String licenseClass,
    String vehicleClassCode,
  ) {
    final lic = licenseClass.trim().toUpperCase();
    final code = vehicleClassCode.trim().toUpperCase();
    if (code == 'MOTORBIKE') return _motorbikeLicenses.contains(lic);
    if (isCarClass(code)) return _carLicenses.contains(lic);
    return false;
  }

  static bool isCarClass(String vehicleClassCode) {
    final code = vehicleClassCode.trim().toUpperCase();
    return code == 'CAR_4' || code == 'CAR_7';
  }
}

/// Which document kinds must be re-captured when ops flags a section.
const partnerIssueSectionKinds = <String, List<String>>{
  'ID_CARD': [PartnerDocumentKind.idFront, PartnerDocumentKind.idBack],
  'SELFIE': [PartnerDocumentKind.selfie, PartnerDocumentKind.selfieVideo],
  'LICENSE': [PartnerDocumentKind.license],
  'VEHICLE': [
    PartnerDocumentKind.vehicleReg,
    PartnerDocumentKind.vehicleInsurance,
  ],
  'BUSINESS_DOCS': [
    PartnerDocumentKind.businessLicense,
    PartnerDocumentKind.foodSafetyCert,
    PartnerDocumentKind.foodSafetyCommitment,
  ],
  'REPRESENTATIVE': [
    PartnerDocumentKind.repIdFront,
    PartnerDocumentKind.repIdBack,
  ],
  'STOREFRONT': [PartnerDocumentKind.storefront],
};

Set<String> flaggedDocumentKinds(Iterable<String> sections) => {
  for (final section in sections) ...?partnerIssueSectionKinds[section],
};

/// Business type and registration subject codes stored in KYB metadata.
abstract final class MerchantBusinessType {
  static const restaurant = 'FOOD_RESTAURANT';
  static const cafe = 'CAFE_TEA';
  static const grocery = 'GROCERY';
  static const convenience = 'CONVENIENCE';
  static const other = 'OTHER';
  static const values = [restaurant, cafe, grocery, convenience, other];
}

abstract final class MerchantRegistrationSubject {
  static const household = 'HOUSEHOLD';
  static const company = 'COMPANY';
  static const other = 'OTHER';
  static const values = [household, company, other];
}
