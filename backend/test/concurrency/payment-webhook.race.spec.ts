import { Prisma } from '../../src/generated/prisma/client.js';
import { PrismaPaymentRepository } from '../../src/modules/payment/payment-prisma.repository.js';

describe('PrismaPaymentRepository.recordWebhook', () => {
  it('updates payment intent and creates webhook event inside transaction', async () => {
    const mockTx = {
      paymentIntent: {
        findFirst: vi.fn().mockResolvedValue({
          id: 'intent-123',
          entityType: 'RIDE',
          entityId: 'ride-1',
          method: 'VNPAY',
          status: 'PENDING_REDIRECT',
          amountVnd: 50000,
          currency: 'VND',
          provider: 'vnpay',
          providerRef: 'txn-abc',
          paymentUrl: 'https://vnpay.vn/pay',
          createdAt: new Date(),
        }),
        update: vi.fn().mockResolvedValue({
          id: 'intent-123',
          entityType: 'RIDE',
          entityId: 'ride-1',
          method: 'VNPAY',
          status: 'CAPTURED_STUB',
          amountVnd: 50000,
          currency: 'VND',
          provider: 'vnpay',
          providerRef: 'txn-abc',
          paymentUrl: 'https://vnpay.vn/pay',
          createdAt: new Date(),
        }),
      },
      paymentWebhookEvent: {
        create: vi.fn().mockResolvedValue({
          id: 'event-1',
          provider: 'vnpay',
          providerEventId: 'event-123',
          paymentIntentId: 'intent-123',
          status: 'CAPTURED_STUB',
          createdAt: new Date(),
        }),
      },
    };

    const mockDb = {
      $transaction: vi.fn(async (cb: (tx: any) => Promise<any>) => cb(mockTx)),
      paymentIntent: {
        findFirst: vi.fn(),
      },
    };

    const repo = new PrismaPaymentRepository(mockDb as any);

    const result = await repo.recordWebhook({
      provider: 'vnpay',
      providerEventId: 'event-123',
      providerRef: 'txn-abc',
      markStatus: 'CAPTURED_STUB',
    });

    expect(mockDb.$transaction).toHaveBeenCalled();
    expect(mockTx.paymentIntent.findFirst).toHaveBeenCalledWith({
      where: { provider: 'vnpay', providerRef: 'txn-abc' },
    });
    expect(mockTx.paymentIntent.update).toHaveBeenCalledWith({
      where: { id: 'intent-123' },
      data: { status: 'CAPTURED_STUB' },
    });
    expect(mockTx.paymentWebhookEvent.create).toHaveBeenCalledWith({
      data: {
        provider: 'vnpay',
        providerEventId: 'event-123',
        status: 'CAPTURED_STUB',
        paymentIntentId: 'intent-123',
      },
    });
    expect(result.duplicate).toBe(false);
    expect(result.intent?.status).toBe('CAPTURED_STUB');
  });

  it('handles P2002 duplicate by returning duplicate: true and existing intent', async () => {
    const p2002Error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
      code: 'P2002',
      clientVersion: '5.x',
    });

    const mockDb = {
      $transaction: vi.fn().mockRejectedValue(p2002Error),
      paymentIntent: {
        findFirst: vi.fn().mockResolvedValue({
          id: 'intent-123',
          entityType: 'RIDE',
          entityId: 'ride-1',
          method: 'VNPAY',
          status: 'CAPTURED_STUB',
          amountVnd: 50000,
          currency: 'VND',
          provider: 'vnpay',
          providerRef: 'txn-abc',
          paymentUrl: null,
          createdAt: new Date(),
        }),
      },
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
