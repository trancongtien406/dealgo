export const LEGAL_CONSENT_SLUGS = ['terms', 'privacy', 'regulations'] as const;
/** pt5u: documents a driver/shop applicant must accept (current published version) to submit. */
export const PARTNER_APPLICATION_CONSENT_SLUGS = ['regulations', 'privacy'] as const;
export type AcceptedLegalDocument = { slug: string; version: number };
export type LegalConsentSlug = (typeof LEGAL_CONSENT_SLUGS)[number];
export const LEGAL_AUDIENCE_ROLES = ['CUSTOMER', 'DRIVER', 'MERCHANT'] as const;
export type LegalAudienceRole = (typeof LEGAL_AUDIENCE_ROLES)[number];

export const LEGAL_POLICY_AGGREGATE = 'LegalPolicy';
export const LEGAL_POLICY_EMAIL_EVENT = 'legal.policy.email';
/** Users per outbox row; the next batch is a new row → one batch per relay tick. */
export const LEGAL_EMAIL_BATCH = 100;
/** Pause between two emails inside a batch (provider rate limit). */
export const LEGAL_EMAIL_PACE_MS = 150;

export type LegalPolicyVersionView = {
  id: string;
  slug: string;
  version: number;
  title: string;
  changelog: string;
  effectiveAt: string | null;
  audienceRoles: string[];
  requiresConsent: boolean;
  publishedAt: string;
  emailStatus: string;
  emailQueuedAt: string | null;
  emailRecipients: number | null;
  emailSentCount: number;
  emailFailedCount: number;
  consentCount?: number;
};

export type PendingConsentView = {
  id: string;
  slug: string;
  version: number;
  title: string;
  changelog: string;
  effectiveAt: string | null;
  publishedAt: string;
  url: string;
};
