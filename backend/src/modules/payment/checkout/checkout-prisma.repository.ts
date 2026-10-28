import { Prisma, type PrismaClient } from '../../../generated/prisma/client.js';
import type { PaymentMethodCode } from '../../../platform/settings/payment-method-registry.js';
import type {
  PaymentEntityTypeName,
  PaymentIntentStatusName,
  PaymentMethodName,
  PaymentProviderName,
} from '../payment.constants.js';
import type {
  CheckoutIntent,
  CheckoutRefund,
  CheckoutRepository,
  IntentListQuery,
  RefundStatusName,
  IntentPatch,
  UpsertAttemptInput,
} from './checkout.repository.js';

type Row = Prisma.PaymentIntentGetPayload<object>;

function toIntent(row: Row): CheckoutIntent {
  return {
    id: row.id,
    entityType: row.entityType as PaymentEntityTypeName,
    entityId: row.entityId,
    method: row.method as PaymentMethodName,
    methodCode: row.methodCode,
    status: row.status as PaymentIntentStatusName,
    amountVnd: row.amountVnd,
    provider: row.provider as PaymentProviderName,
    providerRef: row.providerRef,
    providerTransId: row.providerTransId,
    providerPayDate: row.providerPayDate,
    paymentUrl: row.paymentUrl,
    deeplink: row.deeplink,
    refundedVnd: row.refundedVnd,
    failureReason: row.failureReason,
    settledAt: row.settledAt,
    lastReconciledAt: row.lastReconciledAt,
    reconcileAttempts: row.reconcileAttempts,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

export class PrismaCheckoutRepository implements CheckoutRepository {
  constructor(private readonly db: PrismaClient) {}

  async getSelection(entityType: PaymentEntityTypeName, entityId: string) {
    const row = await this.db.paymentSelection.findUnique({
      where: { entityType_entityId: { entityType, entityId } },
    });
    return (row?.methodCode as PaymentMethodCode | undefined) ?? null;
  }

  async setSelection(entityType: PaymentEntityTypeName, entityId: string, code: PaymentMethodCode) {
    await this.db.paymentSelection.upsert({
      where: { entityType_entityId: { entityType, entityId } },
      create: { entityType, entityId, methodCode: code },
      update: { methodCode: code },
    });
  }

  async latestForEntity(entityType: PaymentEntityTypeName, entityId: string) {
    const row = await this.db.paymentIntent.findFirst({
      where: { entityType, entityId },
      orderBy: { updatedAt: 'desc' },
    });
    return row ? toIntent(row) : null;
  }

  async findByEntityMethod(entityType: PaymentEntityTypeName, entityId: string, method: PaymentMethodName) {
    const row = await this.db.paymentIntent.findUnique({
      where: { entityType_entityId_method: { entityType, entityId, method } },
    });
    return row ? toIntent(row) : null;
  }

  async findById(id: string) {
    const row = await this.db.paymentIntent.findUnique({ where: { id } });
    return row ? toIntent(row) : null;
  }

  async findByProviderRef(provider: PaymentProviderName, providerRef: string) {
    const row = await this.db.paymentIntent.findFirst({ where: { provider, providerRef } });
    return row ? toIntent(row) : null;
  }

  async upsertAttempt(input: UpsertAttemptInput) {
    const data = {
      methodCode: input.methodCode,
      status: 'PENDING_REDIRECT' as const,
      amountVnd: input.amountVnd,
      provider: input.provider,
      providerRef: input.providerRef,
      paymentUrl: input.paymentUrl,
      deeplink: input.deeplink,
      providerTransId: null,
      providerPayDate: null,
      refundedVnd: 0,
      failureReason: null,
    };
    const row = await this.db.paymentIntent.upsert({
      where: {
        entityType_entityId_method: {
          entityType: input.entityType,
          entityId: input.entityId,
          method: input.method,
        },
      },
      create: { entityType: input.entityType, entityId: input.entityId, method: input.method, ...data },
      update: data,
    });
    return toIntent(row);
  }

  async update(id: string, patch: IntentPatch) {
    return toIntent(await this.db.paymentIntent.update({ where: { id }, data: patch }));
  }

  async recordEvent(provider: PaymentProviderName, eventId: string, intentId: string | null, status: string) {
    try {
      await this.db.paymentWebhookEvent.create({
        data: { provider, providerEventId: eventId.slice(0, 160), paymentIntentId: intentId, status: status.slice(0, 40) },
      });
      return true;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  async listIntents(query: IntentListQuery) {
    const isUuid = query.q ? /^[0-9a-f-]{36}$/i.test(query.q) : false;
    const rows = await this.db.paymentIntent.findMany({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(query.provider ? { provider: query.provider } : {}),
        ...(query.entityType ? { entityType: query.entityType } : {}),
        ...(query.q
          ? {
              OR: [
                ...(isUuid ? [{ id: query.q }, { entityId: query.q }] : []),
                { providerRef: query.q },
              ],
            }
          : {}),
      },
      orderBy: { updatedAt: 'desc' },
      take: query.limit,
    });
    return rows.map(toIntent);
  }

  async reserveRefund(intentId: string, amountVnd: number) {
    // Single conditional UPDATE: concurrent refunds can never exceed the captured amount.
    const n = await this.db.$executeRaw`
      UPDATE "payment_intents"
         SET "refundedVnd" = "refundedVnd" + ${amountVnd}, "updatedAt" = NOW()
       WHERE "id" = ${intentId}::uuid AND "refundedVnd" + ${amountVnd} <= "amountVnd"`;
    return n === 1;
  }

  async releaseRefund(intentId: string, amountVnd: number) {
    await this.db.$executeRaw`
      UPDATE "payment_intents"
         SET "refundedVnd" = GREATEST(0, "refundedVnd" - ${amountVnd}), "updatedAt" = NOW()
       WHERE "id" = ${intentId}::uuid`;
  }

  async createRefund(input: Omit<CheckoutRefund, 'id' | 'createdAt' | 'updatedAt'>) {
    return toRefund(await this.db.paymentRefund.create({ data: input }));
  }

  async updateRefund(id: string, patch: Partial<Pick<CheckoutRefund, 'status' | 'providerRefundRef'>>) {
    return toRefund(await this.db.paymentRefund.update({ where: { id }, data: patch }));
  }

  async listRefunds(intentId: string) {
    const rows = await this.db.paymentRefund.findMany({
      where: { paymentIntentId: intentId },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(toRefund);
  }

  async pendingForReconcile(query: { olderThan: Date; limit: number; maxAttempts: number }) {
    const rows = await this.db.paymentIntent.findMany({
      where: {
        status: { in: ['PENDING_REDIRECT', 'CREATED'] },
        updatedAt: { lte: query.olderThan },
        reconcileAttempts: { lt: query.maxAttempts },
        providerRef: { not: null },
      },
      orderBy: { updatedAt: 'asc' },
      take: query.limit,
    });
    return rows.map(toIntent);
  }
}

function toRefund(row: Prisma.PaymentRefundGetPayload<object>): CheckoutRefund {
  return {
    id: row.id,
    paymentIntentId: row.paymentIntentId,
    amountVnd: row.amountVnd,
    status: row.status as RefundStatusName,
    requestId: row.requestId,
    providerRefundRef: row.providerRefundRef,
    reason: row.reason,
    actorUserId: row.actorUserId,
    afterSettlement: row.afterSettlement,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}
