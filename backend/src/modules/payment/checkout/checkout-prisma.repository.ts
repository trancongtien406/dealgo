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
  CheckoutRepository,
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

  async listIntents(query: { limit: number; status?: PaymentIntentStatusName }) {
    const rows = await this.db.paymentIntent.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { updatedAt: 'desc' },
      take: query.limit,
    });
    return rows.map(toIntent);
  }
}
