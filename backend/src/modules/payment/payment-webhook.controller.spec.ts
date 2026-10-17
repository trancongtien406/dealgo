import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentWebhookController } from './payment-webhook.controller.js';
import type { PaymentRepository } from './payment.repository.js';
import { createHmac } from 'node:crypto';

describe('PaymentWebhookController', () => {
  const hashSecret = 'test-vnpay-secret';
  const momoAccessKey = 'test-momo-access';
  const momoSecretKey = 'test-momo-secret';

  let configMap: Record<string, string | undefined> = {};

  const config = {
    get: (key: string) => configMap[key],
  } as unknown as ConfigService<any, true>;

  const recordWebhookMock = vi.fn();
  const mockRepo = {
    recordWebhook: recordWebhookMock,
  } as unknown as PaymentRepository;

  const controller = new PaymentWebhookController(mockRepo, config);

  beforeEach(() => {
    vi.clearAllMocks();
    configMap = {
      VNPAY_HASH_SECRET: hashSecret,
      MOMO_ACCESS_KEY: momoAccessKey,
      MOMO_SECRET_KEY: momoSecretKey,
    };
  });

  describe('vnpay', () => {
    it('rejects with RspCode 99 if VNPAY_HASH_SECRET is missing (fail-closed)', async () => {
      configMap.VNPAY_HASH_SECRET = undefined;
      await expect(
        controller.vnpay({ vnp_TxnRef: 'txn-1', vnp_SecureHash: 'anything' }, {}),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects with RspCode 97 if signature is invalid', async () => {
      await expect(
        controller.vnpay({ vnp_TxnRef: 'txn-1', vnp_SecureHash: 'bad-hash' }, {}),
      ).rejects.toThrow(BadRequestException);
    });

    it('accepts and records webhook if signature is valid', async () => {
      // Build valid hash
      const params: Record<string, string> = {
        vnp_Amount: '100000',
        vnp_Command: 'pay',
        vnp_ResponseCode: '00',
        vnp_TxnRef: 'txn-123',
      };
      const sortedKeys = Object.keys(params).sort();
      const signData = sortedKeys
        .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(params[k]!)}`)
        .join('&');
      const validHash = createHmac('sha512', hashSecret).update(signData).digest('hex');

      recordWebhookMock.mockResolvedValueOnce({
        duplicate: false,
        intent: null,
      });

      const response = await controller.vnpay(
        { ...params, vnp_SecureHash: validHash },
        {},
      );

      expect(response).toEqual({
        RspCode: '00',
        Message: 'Confirm Success',
        duplicate: false,
        status: 'CAPTURED_STUB',
      });
      expect(recordWebhookMock).toHaveBeenCalledWith({
        provider: 'vnpay',
        providerEventId: 'txn-123',
        providerRef: 'txn-123',
        markStatus: 'CAPTURED_STUB',
      });
    });
  });

  describe('momo', () => {
    it('returns resultCode 99 if MoMo keys are missing (fail-closed)', async () => {
      configMap.MOMO_ACCESS_KEY = undefined;
      const result = await controller.momo({ orderId: 'order-1', signature: 'dummy' }, undefined);
      expect(result).toEqual({
        resultCode: 99,
        message: 'Missing MoMo webhook credentials configuration',
      });
    });

    it('returns resultCode 97 if MoMo signature is invalid', async () => {
      const result = await controller.momo(
        { orderId: 'order-1', signature: 'invalid-sig' },
        undefined,
      );
      expect(result).toEqual({
        resultCode: 97,
        message: 'Invalid signature',
      });
    });

    it('accepts and records webhook if MoMo signature is valid', async () => {
      const payload: Record<string, unknown> = {
        amount: 50000,
        extraData: '',
        message: 'Successful',
        orderId: 'momo-order-1',
        orderInfo: 'Payment',
        orderType: 'momo_wallet',
        partnerCode: 'MOMO',
        payType: 'qr',
        requestId: 'req-1',
        responseTime: '1234567890',
        resultCode: 0,
        transId: 'trans-999',
      };

      const raw = [
        `accessKey=${momoAccessKey}`,
        `amount=50000`,
        `extraData=`,
        `message=Successful`,
        `orderId=momo-order-1`,
        `orderInfo=Payment`,
        `orderType=momo_wallet`,
        `partnerCode=MOMO`,
        `payType=qr`,
        `requestId=req-1`,
        `responseTime=1234567890`,
        `resultCode=0`,
        `transId=trans-999`,
      ].join('&');
      const validSig = createHmac('sha256', momoSecretKey).update(raw).digest('hex');
      payload.signature = validSig;

      recordWebhookMock.mockResolvedValueOnce({
        duplicate: false,
        intent: null,
      });

      const result = await controller.momo(payload, undefined);
      expect(result).toEqual({
        resultCode: 0,
        message: 'Success',
        duplicate: false,
        status: 'CAPTURED_STUB',
      });
      expect(recordWebhookMock).toHaveBeenCalledWith({
        provider: 'momo',
        providerEventId: 'trans-999',
        providerRef: 'momo-order-1',
        markStatus: 'CAPTURED_STUB',
      });
    });
  });
});
