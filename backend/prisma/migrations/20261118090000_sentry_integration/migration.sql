-- Admin › Lỗi hệ thống: Sentry read token stored as an encrypted integration setting.
ALTER TYPE "IntegrationKind" ADD VALUE 'SENTRY';
ALTER TYPE "OpsAuditAction" ADD VALUE 'SENTRY_ISSUE_STATUS_UPDATE';
