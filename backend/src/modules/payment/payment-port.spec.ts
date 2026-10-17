import { MomoPaymentPort, verifyMomoSignature } from '../../integrations/payment-gateways/momo-payment.port.js';
import { SandboxPaymentPort } from '../../integrations/payment-gateways/sandbox-payment.port.js';
import { MemoryPaymentRepository } from './payment.repository.js';
import { UnavailablePaymentError, UnavailablePaymentPort } from './payment-port.js';
import {
  VnpayPaymentPort,
  buildVnpayRedirectUrl,
  verifyVnpaySecureHash,
} from '../../integrations/payment-gateways/vnpay-payment.port.js';

describe('SandboxPaymentPort', () => {
  it('creates an idempotent COD sandbox intent', async () => {
    const port = new SandboxPaymentPort(new MemoryPaymentRepository());
    const first = await port.createSandboxIntent({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 45_000,
    });
    expect(first.status).toBe('SANDBOX_RECORDED');
    expect(first.provider).toBe('sandbox');
    expect(first.method).toBe('COD');
    expect(first.providerRef).toBeNull();
    expect(first.paymentUrl).toBeNull();

    const second = await port.createSandboxIntent({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 45_000,
    });
    expect(second.id).toBe(first.id);

    const collected = await port.markCodCollected({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
    });
    expect(collected.id).toBe(first.id);
  });

  it('rejects non-positive amounts', async () => {
    const port = new SandboxPaymentPort(new MemoryPaymentRepository());
    await expect(
      port.createSandboxIntent({
        entityType: 'FOOD_ORDER',
        entityId: '22222222-2222-2222-2222-222222222222',
        amountVnd: 0,
      }),
    ).rejects.toBeInstanceOf(UnavailablePaymentError);
  });
});

describe('VnpayPaymentPort', () => {
  it('creates PENDING_REDIRECT intent with signed paymentUrl', async () => {
    const repo = new MemoryPaymentRepository();
    const port = new VnpayPaymentPort(
      {
        tmnCode: 'DEALGO',
        hashSecret: 'secret',
        url: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
      },
      repo,
    );
    const intent = await port.createRedirectIntent({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 50_000,
      returnUrl: 'https://example.com/return',
    });
    expect(intent.status).toBe('PENDING_REDIRECT');
    expect(intent.provider).toBe('vnpay');
    expect(intent.method).toBe('VNPAY');
    expect(intent.paymentUrl).toContain('vnp_SecureHash=');
    expect(intent.providerRef.startsWith('vnp_')).toBe(true);

    const again = await port.createRedirectIntent({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 50_000,
      returnUrl: 'https://example.com/return',
    });
    expect(again.id).toBe(intent.id);
  });

  it('verifies SecureHash round-trip', () => {
    const params = {
      vnp_Amount: '5000000',
      vnp_Command: 'pay',
      vnp_TmnCode: 'DEALGO',
      vnp_TxnRef: 'ref1',
    };
    const url = buildVnpayRedirectUrl('https://pay.example/vnp', params, 'secret');
    const hash = new URL(url).searchParams.get('vnp_SecureHash');
    expect(hash).toBeTruthy();
    expect(verifyVnpaySecureHash({ ...params, vnp_SecureHash: hash! }, 'secret')).toBe(true);
    expect(verifyVnpaySecureHash({ ...params, vnp_SecureHash: 'deadbeef' }, 'secret')).toBe(false);
  });
});

describe('MomoPaymentPort', () => {
  it('creates PENDING_REDIRECT intent with paymentUrl', async () => {
    const port = new MomoPaymentPort(
      {
        partnerCode: 'MOMO',
        accessKey: 'access',
        secretKey: 'secret',
        endpoint: 'https://test-payment.momo.vn',
      },
      new MemoryPaymentRepository(),
    );
    const intent = await port.createRedirectIntent({
      entityType: 'FOOD_ORDER',
      entityId: '22222222-2222-2222-2222-222222222222',
      amountVnd: 75_000,
      returnUrl: 'https://example.com/momo-return',
    });
    expect(intent.status).toBe('PENDING_REDIRECT');
    expect(intent.provider).toBe('momo');
    expect(intent.paymentUrl).toContain('signature=');
  });

  it('verifies MoMo IPN signature shape', () => {
    const payload = {
      partnerCode: 'MOMO',
      orderId: 'ord1',
      requestId: 'req1',
      amount: 1000,
      orderInfo: 'info',
      orderType: 'momo_wallet',
      transId: 1,
      resultCode: 0,
      message: 'Success',
      payType: 'qr',
      responseTime: 1,
      extraData: '',
      signature: '',
    };
    // Wrong signature fails closed.
    expect(
      verifyMomoSignature(payload, { accessKey: 'access', secretKey: 'secret' }),
    ).toBe(false);
  });
});

describe('Payment webhook idempotency', () => {
  it('records webhook once by provider event id', async () => {
    const repo = new MemoryPaymentRepository();
    const port = new VnpayPaymentPort(
      { tmnCode: 'T', hashSecret: 's', url: 'https://vnpay.example/pay' },
      repo,
    );
    const intent = await port.createRedirectIntent({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 10_000,
      returnUrl: 'https://example.com/r',
    });
    const first = await repo.recordWebhook({
      provider: 'vnpay',
      providerEventId: 'evt-1',
      providerRef: intent.providerRef,
      markStatus: 'CAPTURED_STUB',
    });
    expect(first.duplicate).toBe(false);
    expect(first.intent?.status).toBe('CAPTURED_STUB');
    const second = await repo.recordWebhook({
      provider: 'vnpay',
      providerEventId: 'evt-1',
      providerRef: intent.providerRef,
      markStatus: 'CAPTURED_STUB',
    });
    expect(second.duplicate).toBe(true);
  });
});

describe('UnavailablePaymentPort', () => {
  it('throws UnavailablePaymentError', async () => {
    const port = new UnavailablePaymentPort();
    await expect(
      port.createSandboxIntent({
        entityType: 'RIDE',
        entityId: '11111111-1111-1111-1111-111111111111',
        amountVnd: 1,
      }),
    ).rejects.toBeInstanceOf(UnavailablePaymentError);
  });
});
