import type { PrismaClient } from '../../generated/prisma/client.js';

export const EMAIL_SUPPRESSION_REPOSITORY = Symbol('EMAIL_SUPPRESSION_REPOSITORY');

export type EmailSuppressionReasonName = 'BOUNCE' | 'COMPLAINT';

/** Addresses SES reported as permanently bouncing or complaining; we stop mailing them. */
export interface EmailSuppressionRepository {
  isSuppressed(email: string): Promise<boolean>;
  suppress(input: { email: string; reason: EmailSuppressionReasonName; detail?: string }): Promise<void>;
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export class MemoryEmailSuppressionRepository implements EmailSuppressionRepository {
  readonly rows = new Map<string, { reason: EmailSuppressionReasonName; detail?: string }>();

  async isSuppressed(email: string): Promise<boolean> {
    return this.rows.has(normalizeEmail(email));
  }

  async suppress(input: { email: string; reason: EmailSuppressionReasonName; detail?: string }): Promise<void> {
    this.rows.set(normalizeEmail(input.email), { reason: input.reason, detail: input.detail });
  }
}

export class PrismaEmailSuppressionRepository implements EmailSuppressionRepository {
  constructor(private readonly db: PrismaClient) {}

  async isSuppressed(email: string): Promise<boolean> {
    const row = await this.db.emailSuppression.findUnique({ where: { email: normalizeEmail(email) } });
    return row !== null;
  }

  async suppress(input: { email: string; reason: EmailSuppressionReasonName; detail?: string }): Promise<void> {
    const email = normalizeEmail(input.email);
    const detail = input.detail?.slice(0, 500) ?? null;
    await this.db.emailSuppression.upsert({
      where: { email },
      create: { email, reason: input.reason, detail },
      update: { reason: input.reason, detail },
    });
  }
}
