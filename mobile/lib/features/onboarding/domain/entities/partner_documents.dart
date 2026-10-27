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
  static const repIdFront = 'REP_ID_FRONT';
  static const repIdBack = 'REP_ID_BACK';
  static const storefront = 'STOREFRONT';

  static const driverRequired = [idFront, idBack, selfie, license, vehicleReg];
  static const merchantRequired = [businessLicense, repIdFront, repIdBack];
  static const merchantAll = [...merchantRequired, storefront];

  /// Class-appropriate DRIVER checklist (Car adds insurance when applying as Car).
  static List<String> driverRequiredFor(String vehicleClassCode) {
    final code = vehicleClassCode.trim().toUpperCase();
    if (code == 'CAR_4' || code == 'CAR_7') {
      return [...driverRequired, vehicleInsurance];
    }
    return List<String>.from(driverRequired);
  }

  static bool isCarClass(String vehicleClassCode) {
    final code = vehicleClassCode.trim().toUpperCase();
    return code == 'CAR_4' || code == 'CAR_7';
  }
}

/// Which document kinds must be re-captured when ops flags a section.
const partnerIssueSectionKinds = <String, List<String>>{
  'ID_CARD': [PartnerDocumentKind.idFront, PartnerDocumentKind.idBack],
  'SELFIE': [PartnerDocumentKind.selfie],
  'LICENSE': [PartnerDocumentKind.license],
  'VEHICLE': [
    PartnerDocumentKind.vehicleReg,
    PartnerDocumentKind.vehicleInsurance,
  ],
  'BUSINESS_DOCS': [PartnerDocumentKind.businessLicense],
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
