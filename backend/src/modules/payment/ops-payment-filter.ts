/**
 * Map Admin UI payment filter codes to display method strings used in
 * OpsTransactionsService fixtures and PaymentIntent projections.
 *
 * UI: CASH | WALLET | CARD | MOMO | VNPAY
 * DB PaymentMethod: COD | VNPAY | MOMO
 */
export function paymentFilterMatchers(raw: string): {
  methodNeedles: string[];
  dbMethods: Array<'COD' | 'VNPAY' | 'MOMO'>;
} {
  const key = raw.trim().toUpperCase();
  switch (key) {
    case 'CASH':
    case 'COD':
    case 'TIEN_MAT':
      return {
        methodNeedles: ['tiền mặt', 'tien mat', 'cash', 'cod'],
        dbMethods: ['COD'],
      };
    case 'WALLET':
    case 'VÍ':
    case 'VI':
      return {
        methodNeedles: ['ví dealgo', 'vi dealgo', 'wallet'],
        dbMethods: [],
      };
    case 'CARD':
    case 'BANK':
      return {
        methodNeedles: ['chuyển khoản', 'chuyen khoan', 'thẻ', 'the', 'card'],
        dbMethods: [],
      };
    case 'MOMO':
      return {
        methodNeedles: ['momo'],
        dbMethods: ['MOMO'],
      };
    case 'VNPAY':
      return {
        methodNeedles: ['vnpay', 'vn pay'],
        dbMethods: ['VNPAY'],
      };
    default:
      return {
        methodNeedles: [raw.trim().toLowerCase()],
        dbMethods: [],
      };
  }
}

export function paymentMethodDisplay(
  method: string,
): string {
  if (method === 'COD') return 'Tiền mặt';
  if (method === 'VNPAY') return 'VNPAY';
  if (method === 'MOMO') return 'MoMo';
  return method;
}
