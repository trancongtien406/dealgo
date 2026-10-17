import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type {
  PaymentEntityTypeName,
  PaymentIntentStatusName,
  PaymentMethodName,
  PaymentProviderName,
} from './payment.constants.js';
import type {
  CreateSandboxIntentInput,
  PaymentIntentView,
  RedirectPaymentIntentView,
} from './payment-port.js';
import type {
  PaymentRepository,
  PersistRedirectIntentInput,
  WebhookRecordInput,
  WebhookRecordResult,
} from './payment.repository.js';

export class PrismaPaymentRepository implements PaymentRepository {
  constructor(private readonly db: PrismaClient) {}

  async createSandboxIntent(input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    const method = input.method ?? 'COD';
    try {
      const created = await this.db.paymentIntent.create({
        data: {
          entityType: input.entityType,
          entityId: input.entityId,
          method,
          status: 'SANDBOX_RECORDED',
          amountVnd: input.amountVnd,
          currency: 'VND',
          provider: 'sandbox',
        },
      });
      return toView(created);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const existing = await this.findByEntity(input.entityType, input.entityId, method);
        if (existing) {
          return existing;
        }
      }
      throw error;
    }
  }

  async createRedirectIntent(input: PersistRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    const existing = await this.findByEntity(input.entityType, input.entityId, input.method);
    if (existing?.paymentUrl && existing.providerRef) {
      return {
        ...existing,
        paymentUrl: existing.paymentUrl,
        providerRef: existing.providerRef,
      };
    }
    try {
      const created = await this.db.paymentIntent.create({
        data: {
          entityType: input.entityType,
          entityId: input.entityId,
          method: input.method,
          status: input.status ?? 'PENDING_REDIRECT',
          amountVnd: input.amountVnd,
          currency: 'VND',
          provider: input.provider,
          providerRef: input.providerRef,
          paymentUrl: input.paymentUrl,
        },
      });
      return toRedirectView(created);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const again = await this.findByEntity(input.entityType, input.entityId, input.method);
        if (again?.paymentUrl && again.providerRef) {
          return {
            ...again,
            paymentUrl: again.paymentUrl,
            providerRef: again.providerRef,
          };
        }
      }
      throw error;
    }
  }

  async findByEntity(
    entityType: PaymentEntityTypeName,
    entityId: string,
    method: PaymentMethodName = 'COD',
  ): Promise<PaymentIntentView | null> {
    const intent = await this.db.paymentIntent.findUnique({
      where: {
        entityType_entityId_method: {
          entityType,
          entityId,
          method,
        },
      },
    });
    return intent ? toView(intent) : null;
  }

  async findByProviderRef(
    provider: PaymentProviderName,
    providerRef: string,
  ): Promise<PaymentIntentView | null> {
    const intent = await this.db.paymentIntent.findFirst({
      where: { provider, providerRef },
    });
    return intent ? toView(intent) : null;
  }

  async recordWebhook(input: WebhookRecordInput): Promise<WebhookRecordResult> {
    try {
      return await this.db.$transaction(async (tx) => {
        let intent: PaymentIntentView | null = null;
        if (input.providerRef) {
          const matching = await tx.paymentIntent.findFirst({
            where: { provider: input.provider, providerRef: input.providerRef },
          });
          if (matching) {
            const updated = await tx.paymentIntent.update({
              where: { id: matching.id },
              data: { status: input.markStatus },
            });
            intent = toView(updated);
          }
        }

        await tx.paymentWebhookEvent.create({
          data: {
            provider: input.provider,
            providerEventId: input.providerEventId,
            status: input.markStatus,
            paymentIntentId: intent ? intent.id : undefined,
          },
        });

        return { duplicate: false, intent };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const intent = input.providerRef
          ? await this.findByProviderRef(input.provider, input.providerRef)
          : null;
        return { duplicate: true, intent };
      }
      throw error;
    }
  }
}

function toView(row: {
  id: string;
  entityType: PaymentEntityTypeName;
  entityId: string;
  method: PaymentMethodName;
  status: PaymentIntentStatusName;
  amountVnd: number;
  currency: string;
  provider: string;
  providerRef: string | null;
  paymentUrl: string | null;
  createdAt: Date;
}): PaymentIntentView {
  return {
    id: row.id,
    entityType: row.entityType,
    entityId: row.entityId,
    method: row.method,
    status: row.status,
    amountVnd: row.amountVnd,
    currency: 'VND',
    provider: row.provider as PaymentProviderName,
    providerRef: row.providerRef,
    paymentUrl: row.paymentUrl,
    createdAt: row.createdAt.toISOString(),
  };
}

function toRedirectView(row: {
  id: string;
  entityType: PaymentEntityTypeName;
  entityId: string;
  method: PaymentMethodName;
  status: PaymentIntentStatusName;
  amountVnd: number;
  currency: string;
  provider: string;
  providerRef: string | null;
  paymentUrl: string | null;
  createdAt: Date;
}): RedirectPaymentIntentView {
  const view = toView(row);
  if (!view.paymentUrl || !view.providerRef) {
    throw new Error('Redirect intent missing paymentUrl/providerRef');
  }
  return {
    ...view,
    paymentUrl: view.paymentUrl,
    providerRef: view.providerRef,
  };
}
