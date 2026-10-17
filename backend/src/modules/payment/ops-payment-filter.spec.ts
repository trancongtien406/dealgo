import { describe, expect, it } from 'vitest';
import {
  paymentFilterMatchers,
  paymentMethodDisplay,
} from './ops-payment-filter.js';

describe('ops-payment-filter', () => {
  it('maps CASH UI code to tiền mặt / COD', () => {
    const m = paymentFilterMatchers('CASH');
    expect(m.dbMethods).toEqual(['COD']);
    expect(m.methodNeedles.some((n) => n.includes('tiền mặt') || n === 'cash')).toBe(
      true,
    );
    expect(paymentMethodDisplay('COD')).toBe('Tiền mặt');
  });

  it('maps VNPAY and MOMO', () => {
    expect(paymentFilterMatchers('VNPAY').dbMethods).toEqual(['VNPAY']);
    expect(paymentFilterMatchers('MOMO').dbMethods).toEqual(['MOMO']);
    expect(paymentMethodDisplay('MOMO')).toBe('MoMo');
  });
});
