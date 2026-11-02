import { Prisma } from '../../src/generated/prisma/client.js';
import { PaymentModule } from '../../src/modules/payment/payment.module.js';
import { PaymentCallbacksController } from '../../src/modules/payment/checkout/payment-checkout.controller.js';
import { PrismaCheckoutRepository } from '../../src/modules/payment/checkout/checkout-prisma.repository.js';
import { PrismaPaymentRepository } from '../../src/modules/payment/payment-prisma.repository.js';

const intentRow = (status: string) => ({
  id: 'intent-123',
  entityType: 'RIDE',
  entityId: 'ride-1',
  method: 'VNPAY',
  status,
  amountVnd: 50000,
  currency: 'VND',
  provider: 'vnpay',
  providerRef: 'txn-abc',
  paymentUrl: null,
  createdAt: new Date(),
});

describe('PSP entry points (MONEY-001)', () => {
  it('registers only the signed checkout IPN controller, not the legacy webhook stub', () => {
    const controllers = (Reflect.getMetadata('controllers', PaymentModule) ?? []) as { name: string }[];
    expect(controllers).toContain(PaymentCallbacksController);
    expect(controllers.map((c) => c.name)).not.toContain('PaymentWebhookController');
  });
});

describe('PrismaCheckoutRepository.transition (MONEY-003)', () => {
  it('updates only while the intent is still in an allowed status (single conditional UPDATE)', async () => {
    const updateMany = vi.fn().mockResolvedValueOnce({ count: 1 }).mockResolvedValueOnce({ count: 0 });
    const repo = new PrismaCheckoutRepository({ paymentIntent: { updateMany } } as any);
    expect(await repo.transition('intent-123', ['PENDING_REDIRECT'], { status: 'CAPTURED' })).toBe(true);
    // Second writer (callback replay / completion race) loses: the row is no longer PENDING_REDIRECT.
    expect(await repo.transition('intent-123', ['PENDING_REDIRECT'], { status: 'FAILED' })).toBe(false);
    expect(updateMany).toHaveBeenCalledWith({
      where: { id: 'intent-123', status: { in: ['PENDING_REDIRECT'] } },
      data: { status: 'CAPTURED' },
    });
  });
});

describe('PrismaPaymentRepository.recordWebhook (legacy port)', () => {
  it('never overwrites a verified CAPTURED intent', async () => {
    const mockTx = {
      paymentIntent: {
        findFirst: vi.fn().mockResolvedValue(intentRow('CAPTURED')),
        update: vi.fn(),
      },
      paymentWebhookEvent: { create: vi.fn().mockResolvedValue({}) },
    };
    const mockDb = { $transaction: vi.fn(async (cb: (tx: any) => Promise<any>) => cb(mockTx)) };
    const repo = new PrismaPaymentRepository(mockDb as any);
    const result = await repo.recordWebhook({
      provider: 'vnpay',
      providerEventId: 'event-123',
      providerRef: 'txn-abc',
      markStatus: 'SANDBOX_RECORDED',
    });
    expect(mockTx.paymentIntent.update).not.toHaveBeenCalled();
    expect(result.intent?.status).toBe('CAPTURED');
  });

  it('still records non-final intents inside one transaction', async () => {
    const mockTx = {
      paymentIntent: {
        findFirst: vi.fn().mockResolvedValue(intentRow('PENDING_REDIRECT')),
        update: vi.fn().mockResolvedValue(intentRow('CAPTURED_STUB')),
      },
      paymentWebhookEvent: { create: vi.fn().mockResolvedValue({}) },
    };
    const mockDb = { $transaction: vi.fn(async (cb: (tx: any) => Promise<any>) => cb(mockTx)) };
    const repo = new PrismaPaymentRepository(mockDb as any);
    const result = await repo.recordWebhook({
      provider: 'vnpay',
      providerEventId: 'event-123',
      providerRef: 'txn-abc',
      markStatus: 'CAPTURED_STUB',
    });
    expect(mockTx.paymentIntent.update).toHaveBeenCalledWith({
      where: { id: 'intent-123' },
      data: { status: 'CAPTURED_STUB' },
    });
    expect(result).toMatchObject({ duplicate: false, intent: { status: 'CAPTURED_STUB' } });
  });

  it('handles P2002 duplicate by returning duplicate: true and existing intent', async () => {
    const p2002Error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
      code: 'P2002',
      clientVersion: '5.x',
    });
    const mockDb = {
      $transaction: vi.fn().mockRejectedValue(p2002Error),
      paymentIntent: { findFirst: vi.fn().mockResolvedValue(intentRow('CAPTURED_STUB')) },
    };
    const repo = new PrismaPaymentRepository(mockDb as any);
    const result = await repo.recordWebhook({
      provider: 'vnpay',
      providerEventId: 'event-123',
      providerRef: 'txn-abc',
      markStatus: 'CAPTURED_STUB',
    });
    expect(result.duplicate).toBe(true);
    expect(result.intent?.id).toBe('intent-123');
  });
});
