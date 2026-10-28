import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { verifyVnpaySecureHash, formatVnpDate } from '../vnpay-payment.port.js';
import { MomoAdapter, momoCreateRawSignature } from './momo.adapter.js';
import { VnpayAdapter, vnpayRefundHashInput } from './vnpay.adapter.js';
import { ZalopayAdapter, zalopayCreateMacInput } from './zalopay.adapter.js';
import { StubPaymentAdapter } from './stub.adapters.js';
import type { HttpPost } from './payment-adapter.js';

// Placeholder sandbox-style values only; not real merchant keys.
const momoCfg = { partnerCode: 'MOMOTEST', accessKey: 'ak_test', secretKey: 'sk_test', endpoint: 'https://test-payment.momo.vn' };
const zaloCfg = { appId: '2553', key1: 'k1_test', key2: 'k2_test', endpoint: 'https://sb-openapi.zalopay.vn' };
const vnpCfg = { tmnCode: 'TMNTEST', hashSecret: 'hs_test', url: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html', apiUrl: 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction' };
const now = new Date('2026-10-28T18:30:00.000Z'); // 2026-10-29 01:30 GMT+7

function recorder(response: Record<string, unknown>) {
  const calls: { url: string; body: Record<string, unknown>; form?: boolean }[] = [];
  const http: HttpPost = async (url, body, options) => {
    calls.push({ url, body, form: options.form });
    return response;
  };
  return { calls, http };
}

const req = {
  orderRef: 'DGR123ABC',
  amountVnd: 50000,
  orderInfo: 'DealGo chuyen xe DGR123ABC',
  returnUrl: 'https://api.example.test/v1/payments/return/x/RIDE/1',
  ipnUrl: 'https://api.example.test/v1/payments/ipn/x',
  clientIp: '1.2.3.4',
  userRef: 'user-1',
  methodCode: 'MOMO',
  now,
};

describe('MomoAdapter', () => {
  it('signs create with HMAC-SHA256 over the documented field order', async () => {
    const { calls, http } = recorder({ resultCode: 0, payUrl: 'https://pay', deeplink: 'momo://x' });
    const out = await new MomoAdapter(momoCfg, http).create(req);
    expect(out).toEqual({ providerRef: 'DGR123ABC', paymentUrl: 'https://pay', deeplink: 'momo://x' });
    const call = calls[0]!;
    expect(call.url).toBe('https://test-payment.momo.vn/v2/gateway/api/create');
    const raw =
      `accessKey=ak_test&amount=50000&extraData=&ipnUrl=${req.ipnUrl}&orderId=DGR123ABC` +
      `&orderInfo=${req.orderInfo}&partnerCode=MOMOTEST&redirectUrl=${req.returnUrl}` +
      `&requestId=DGR123ABC&requestType=captureWallet`;
    expect(momoCreateRawSignature({
      accessKey: 'ak_test', amount: '50000', extraData: '', ipnUrl: req.ipnUrl, orderId: 'DGR123ABC',
      orderInfo: req.orderInfo, partnerCode: 'MOMOTEST', redirectUrl: req.returnUrl, requestId: 'DGR123ABC',
      requestType: 'captureWallet',
    })).toBe(raw);
    expect(call.body.signature).toBe(createHmac('sha256', 'sk_test').update(raw).digest('hex'));
  });

  it('throws when MoMo rejects and when unconfigured', async () => {
    const { http } = recorder({ resultCode: 22, message: 'bad amount' });
    await expect(new MomoAdapter(momoCfg, http).create(req)).rejects.toThrow(/MoMo create failed/);
    await expect(new MomoAdapter({}, http).create(req)).rejects.toThrow(/not configured/);
  });

  it('verifies IPN signature and maps result', () => {
    const p: Record<string, unknown> = {
      partnerCode: 'MOMOTEST', orderId: 'DGR123ABC', requestId: 'DGR123ABC', amount: 50000, orderInfo: 'x',
      orderType: 'momo_wallet', transId: 999, resultCode: 0, message: 'ok', payType: 'qr', responseTime: 1, extraData: '',
    };
    const raw = `accessKey=ak_test&amount=50000&extraData=&message=ok&orderId=DGR123ABC&orderInfo=x&orderType=momo_wallet&partnerCode=MOMOTEST&payType=qr&requestId=DGR123ABC&responseTime=1&resultCode=0&transId=999`;
    p.signature = createHmac('sha256', 'sk_test').update(raw).digest('hex');
    const a = new MomoAdapter(momoCfg);
    const cb = a.verifyCallback(p);
    expect(cb).toMatchObject({ valid: true, success: true, providerRef: 'DGR123ABC', amountVnd: 50000, providerTransId: '999' });
    expect(a.verifyCallback({ ...p, amount: 1 }).valid).toBe(false);
    expect(a.ack('OK').httpStatus).toBe(204);
  });

  it('signs refund', async () => {
    const { calls, http } = recorder({ resultCode: 0, transId: 1 });
    const r = await new MomoAdapter(momoCfg, http).refund({
      providerRef: 'DGR123ABC', providerTransId: '999', providerPayDate: null, amountVnd: 50000,
      capturedAmountVnd: 50000, reason: 'hoan', requestId: 'RF1', actorRef: 'ops', clientIp: '1.1.1.1', now,
    });
    expect(r.status).toBe('ACCEPTED');
    const raw = 'accessKey=ak_test&amount=50000&description=hoan&orderId=RF1&partnerCode=MOMOTEST&requestId=RF1&transId=999';
    expect(calls[0]!.body.signature).toBe(createHmac('sha256', 'sk_test').update(raw).digest('hex'));
  });
});

describe('ZalopayAdapter', () => {
  it('creates with key1 MAC and a GMT+7 yymmdd app_trans_id', async () => {
    const { calls, http } = recorder({ return_code: 1, order_url: 'https://zalo/pay' });
    const out = await new ZalopayAdapter(zaloCfg, http).create(req);
    expect(out.providerRef).toBe('261029_DGR123ABC');
    const b = calls[0]!.body as Record<string, string>;
    expect(calls[0]!.form).toBe(true);
    expect(calls[0]!.url).toBe('https://sb-openapi.zalopay.vn/v2/create');
    const input = zalopayCreateMacInput(b as never);
    expect(input).toBe(`2553|261029_DGR123ABC|user-1|50000|${now.getTime()}|${b.embed_data}|[]`);
    expect(b.mac).toBe(createHmac('sha256', 'k1_test').update(input).digest('hex'));
    expect(JSON.parse(b.embed_data!)).toEqual({ redirecturl: req.returnUrl });
  });

  it('verifies callback with key2 and acks per spec', () => {
    const data = JSON.stringify({ app_trans_id: '261029_DGR123ABC', zp_trans_id: 777, amount: 50000 });
    const mac = createHmac('sha256', 'k2_test').update(data).digest('hex');
    const a = new ZalopayAdapter(zaloCfg);
    expect(a.verifyCallback({ data, mac, type: 1 })).toMatchObject({
      valid: true, success: true, providerRef: '261029_DGR123ABC', providerTransId: '777', amountVnd: 50000,
    });
    expect(a.verifyCallback({ data, mac: 'bad', type: 1 }).valid).toBe(false);
    expect(a.ack('OK').body).toEqual({ return_code: 1, return_message: 'success' });
    expect(a.ack('INVALID_SIGNATURE').body).toMatchObject({ return_code: -1 });
  });

  it('refund MAC = app_id|zp_trans_id|amount|description|timestamp', async () => {
    const { calls, http } = recorder({ return_code: 3 });
    const r = await new ZalopayAdapter(zaloCfg, http).refund({
      providerRef: 'x', providerTransId: '777', providerPayDate: null, amountVnd: 20000, capturedAmountVnd: 50000,
      reason: 'hoan', requestId: 'RF1', actorRef: 'ops', clientIp: '1.1.1.1', now,
    });
    expect(r.status).toBe('PENDING');
    const b = calls[0]!.body;
    expect(b.mac).toBe(createHmac('sha256', 'k1_test').update(`2553|777|20000|hoan|${now.getTime()}`).digest('hex'));
    expect(String(b.m_refund_id)).toMatch(/^261029_2553_/);
  });
});

describe('VnpayAdapter', () => {
  it('formats dates in GMT+7', () => {
    expect(formatVnpDate(now)).toBe('20261029013000');
  });

  it('builds a verifiable pay URL; ATM adds vnp_BankCode=VNBANK', async () => {
    const a = new VnpayAdapter(vnpCfg);
    const out = await a.create({ ...req, methodCode: 'VNPAY_ATM' });
    const url = new URL(out.paymentUrl!);
    const params = Object.fromEntries(url.searchParams.entries());
    expect(params.vnp_BankCode).toBe('VNBANK');
    expect(params.vnp_Amount).toBe('5000000');
    expect(params.vnp_CreateDate).toBe('20261029013000');
    expect(params.vnp_ExpireDate).toBe('20261029014500');
    expect(verifyVnpaySecureHash(params, 'hs_test')).toBe(true);
    const qr = await a.create(req);
    expect(new URL(qr.paymentUrl!).searchParams.get('vnp_BankCode')).toBeNull();
  });

  it('verifies IPN and requires 00/00 for success', async () => {
    const a = new VnpayAdapter(vnpCfg);
    const out = await a.create(req);
    const params = Object.fromEntries(new URL(out.paymentUrl!).searchParams.entries());
    delete params.vnp_SecureHash;
    const ipn: Record<string, string> = { ...params, vnp_ResponseCode: '00', vnp_TransactionStatus: '00', vnp_TransactionNo: '1400', vnp_PayDate: '20261029013500' };
    const sorted = Object.keys(ipn).sort().map((k) => `${k}=${encodeURIComponent(ipn[k]!).replace(/%20/g, '+')}`).join('&');
    ipn.vnp_SecureHash = createHmac('sha512', 'hs_test').update(sorted).digest('hex');
    expect(a.verifyCallback(ipn)).toMatchObject({ valid: true, success: true, amountVnd: 50000, providerTransId: '1400', providerPayDate: '20261029013500' });
    expect(a.verifyCallback({ ...ipn, vnp_Amount: '1' }).valid).toBe(false);
    expect(a.ack('OK').body).toEqual({ RspCode: '00', Message: 'Confirm Success' });
    expect(a.ack('INVALID_SIGNATURE').body).toMatchObject({ RspCode: '97' });
  });

  it('refund checksum is HMAC-SHA512 over pipe-joined fields', async () => {
    const { calls, http } = recorder({ vnp_ResponseCode: '00' });
    const r = await new VnpayAdapter(vnpCfg, http).refund({
      providerRef: 'DGR123ABC', providerTransId: '1400', providerPayDate: '20261029013500', amountVnd: 20000,
      capturedAmountVnd: 50000, reason: 'hoan', requestId: 'RF1', actorRef: 'ops', clientIp: '1.1.1.1', now,
    });
    expect(r.status).toBe('ACCEPTED');
    const b = calls[0]!.body as Record<string, string>;
    expect(b.vnp_TransactionType).toBe('03');
    expect(b.vnp_SecureHash).toBe(createHmac('sha512', 'hs_test').update(vnpayRefundHashInput(b)).digest('hex'));
    expect(vnpayRefundHashInput(b).split('|')).toHaveLength(13);
  });
});

describe('StubPaymentAdapter', () => {
  it('is never configured and refuses to create', async () => {
    const s = new StubPaymentAdapter('shopeepay', ['SHOPEEPAY_CLIENT_ID'], 'ShopeePay');
    expect(s.kind).toBe('STUB');
    expect(s.isConfigured()).toBe(false);
    await expect(s.create()).rejects.toThrow(/stub/);
    expect(s.verifyCallback().valid).toBe(false);
  });
});
