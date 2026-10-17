export const AUDIT_RESULTS = [
  "SUCCESS",
  "PENDING_APPROVAL",
  "LOGGED",
  "REJECTED",
] as const;
export type AuditResult = (typeof AUDIT_RESULTS)[number];
