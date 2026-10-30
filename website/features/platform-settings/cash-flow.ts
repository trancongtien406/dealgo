/**
 * "Dòng tiền & hoa hồng": pure money maths for the admin page. Mirrors the
 * backend exactly (whole VND, half-up rounding) so the worked examples show what
 * the ledger will book:
 *  - earnings.math.ts `percentToBps` / `splitFare` (driver commission),
 *  - food.service.ts `merchantCommissionVnd` (store commission, capped at subtotal),
 *  - promotion/voucher-funding.ts `platformFundedDiscountVnd` (who pays a voucher).
 * The backend stays the authority; this module never books anything.
 */

export type VoucherSponsor = "PLATFORM" | "MERCHANT" | "SHARED";

export type CashFlowSettings = {
  rideBikePercent: number;
  rideCarPercent: number;
  foodDriverPercent: number;
  merchantPercent: number;
  voucherSharedPlatformPercent: number;
  settlementCycleDays: number;
  driverDebtLimitVnd: number;
  cancelFeeBikeVnd: number;
  cancelFeeCarVnd: number;
  freeCancelMinutes: number;
  noShowWaitMinutes: number;
};

/** Settings shown (and edited) in the money section, in display order per group. */
export const CASH_FLOW_GROUPS: ReadonlyArray<{
  id: string;
  title: string;
  keys: readonly string[];
}> = [
  {
    id: "commission",
    title: "Hoa hồng DealGo thu",
    keys: [
      "RIDE_COMMISSION_BIKE_PERCENT",
      "RIDE_COMMISSION_CAR_PERCENT",
      "FOOD_DRIVER_COMMISSION_PERCENT",
      "FOOD_MERCHANT_COMMISSION_PERCENT",
    ],
  },
  {
    id: "settlement",
    title: "Đối soát & công nợ",
    keys: ["MERCHANT_SETTLEMENT_CYCLE_DAYS", "DRIVER_DEBT_LIMIT_VND"],
  },
  {
    id: "voucher",
    title: "Voucher",
    keys: ["VOUCHER_SHARED_PLATFORM_PERCENT"],
  },
  {
    id: "cancel",
    title: "Phí huỷ & không gặp khách",
    keys: [
      "RIDE_FREE_CANCEL_MINUTES",
      "RIDE_NO_SHOW_WAIT_MINUTES",
      "RIDE_CANCEL_FEE_BIKE_VND",
      "RIDE_CANCEL_FEE_CAR_VND",
    ],
  },
  {
    // DEC-PROD-071: size surcharges live in PARCEL_SIZE_CLASSES (JSON, general list).
    id: "parcel",
    title: "Giao hàng — phí dịch vụ & phí hoàn hàng",
    keys: ["PARCEL_SERVICE_FEE_VND", "PARCEL_RETURN_FEE_VND"],
  },
  {
    id: "bounds",
    title: "Giới hạn cước & thanh toán",
    keys: [
      "FOOD_MIN_DELIVERY_VND",
      "FOOD_MAX_DELIVERY_VND",
    ],
  },
];

export const CASH_FLOW_KEYS: ReadonlySet<string> = new Set(
  CASH_FLOW_GROUPS.flatMap((group) => group.keys),
);

/** Unit shown beside a value in the money section. */
export function cashFlowUnit(key: string): string {
  if (key.endsWith("_PERCENT")) return "%";
  if (key.endsWith("_VND")) return "đ";
  if (key.endsWith("_DAYS")) return "ngày";
  if (key.endsWith("_MINUTES")) return "phút";
  return "";
}

function num(rows: ReadonlyArray<{ key: string; value: string }>, key: string): number {
  const raw = rows.find((row) => row.key === key)?.value;
  const value = raw == null ? Number.NaN : Number(raw.trim());
  return Number.isFinite(value) && value >= 0 ? value : 0;
}

export function readCashFlowSettings(
  rows: ReadonlyArray<{ key: string; value: string }>,
): CashFlowSettings {
  return {
    rideBikePercent: num(rows, "RIDE_COMMISSION_BIKE_PERCENT"),
    rideCarPercent: num(rows, "RIDE_COMMISSION_CAR_PERCENT"),
    foodDriverPercent: num(rows, "FOOD_DRIVER_COMMISSION_PERCENT"),
    merchantPercent: num(rows, "FOOD_MERCHANT_COMMISSION_PERCENT"),
    voucherSharedPlatformPercent: num(rows, "VOUCHER_SHARED_PLATFORM_PERCENT"),
    settlementCycleDays: num(rows, "MERCHANT_SETTLEMENT_CYCLE_DAYS"),
    driverDebtLimitVnd: num(rows, "DRIVER_DEBT_LIMIT_VND"),
    cancelFeeBikeVnd: num(rows, "RIDE_CANCEL_FEE_BIKE_VND"),
    cancelFeeCarVnd: num(rows, "RIDE_CANCEL_FEE_CAR_VND"),
    freeCancelMinutes: num(rows, "RIDE_FREE_CANCEL_MINUTES"),
    noShowWaitMinutes: num(rows, "RIDE_NO_SHOW_WAIT_MINUTES"),
  };
}

const clampPercent = (percent: number) =>
  Math.max(0, Math.min(100, Number.isFinite(percent) ? percent : 0));
const bps = (percent: number) => Math.round(clampPercent(percent) * 100);
const vnd = (amount: number) =>
  Number.isFinite(amount) && amount > 0 ? Math.round(amount) : 0;

/** Backend `splitFare(fare, percentToBps(p))`. */
export function commissionOf(fareVnd: number, percent: number): number {
  return Math.round((vnd(fareVnd) * bps(percent)) / 10_000);
}

/** Backend `platformFundedDiscountVnd`. */
export function platformFundedDiscount(
  discountVnd: number,
  sponsor: VoucherSponsor,
  sharedPlatformPercent: number,
): number {
  const discount = vnd(discountVnd);
  if (discount === 0 || sponsor === "MERCHANT") return 0;
  if (sponsor === "SHARED") {
    return Math.round((discount * bps(sharedPlatformPercent)) / 10_000);
  }
  return discount;
}

export type RideExample = {
  customerPaysVnd: number;
  driverCollectsCashVnd: number;
  commissionVnd: number;
  driverKeepsVnd: number;
  driverOwesDealGoVnd: number;
  previousDriverGetsVnd: number;
  dealGoEarnsVnd: number;
};

/**
 * Cash ride (DEC-PROD-014): the customer pays the agreed fare (plus a
 * late-cancel fee carried from an earlier ride) to the driver. DealGo's commission is
 * on the fare only; the carried fee passes through to the driver who was cancelled on.
 */
export function rideExample(input: {
  fareVnd: number;
  commissionPercent: number;
  carriedCancelFeeVnd?: number;
}): RideExample {
  const fare = vnd(input.fareVnd);
  const carried = vnd(input.carriedCancelFeeVnd ?? 0);
  const commission = commissionOf(fare, input.commissionPercent);
  return {
    customerPaysVnd: fare + carried,
    driverCollectsCashVnd: fare + carried,
    commissionVnd: commission,
    driverKeepsVnd: fare - commission,
    driverOwesDealGoVnd: commission + carried,
    previousDriverGetsVnd: carried,
    dealGoEarnsVnd: commission,
  };
}

export type FoodExample = {
  customerPaysVnd: number;
  platformFundedVnd: number;
  merchantFundedVnd: number;
  driverPaysMerchantVnd: number;
  merchantCommissionVnd: number;
  merchantKeepsVnd: number;
  driverCommissionVnd: number;
  driverKeepsVnd: number;
  driverOwesDealGoVnd: number;
  dealGoEarnsVnd: number;
};

/**
 * Cash food order: the driver pays the store at pickup
 * (subtotal minus the store-funded part of the voucher) and collects the total at the
 * door. DealGo reimburses the driver its own voucher share, takes its driver commission
 * on the delivery fee, and bills the store its commission once per settlement cycle.
 */
export function foodExample(input: {
  subtotalVnd: number;
  deliveryFeeVnd: number;
  discountVnd: number;
  sponsor: VoucherSponsor;
  merchantPercent: number;
  driverPercent: number;
  sharedPlatformPercent: number;
}): FoodExample {
  const subtotal = vnd(input.subtotalVnd);
  const delivery = vnd(input.deliveryFeeVnd);
  const discount = Math.min(vnd(input.discountVnd), subtotal + delivery);
  const platformFunded = platformFundedDiscount(
    discount,
    input.sponsor,
    input.sharedPlatformPercent,
  );
  const merchantFunded = Math.max(0, discount - platformFunded);
  const driverPaysMerchant = Math.max(0, subtotal - merchantFunded);
  const merchantCommission = Math.min(
    subtotal,
    Math.round((subtotal * bps(input.merchantPercent)) / 10_000),
  );
  const driverCommission = commissionOf(delivery, input.driverPercent);
  return {
    customerPaysVnd: subtotal + delivery - discount,
    platformFundedVnd: platformFunded,
    merchantFundedVnd: merchantFunded,
    driverPaysMerchantVnd: driverPaysMerchant,
    merchantCommissionVnd: merchantCommission,
    merchantKeepsVnd: driverPaysMerchant - merchantCommission,
    driverCommissionVnd: driverCommission,
    driverKeepsVnd: delivery - driverCommission,
    driverOwesDealGoVnd: driverCommission - platformFunded,
    dealGoEarnsVnd: merchantCommission + driverCommission - platformFunded,
  };
}

export function formatVnd(amount: number): string {
  const sign = amount < 0 ? "−" : "";
  return `${sign}${Math.abs(Math.round(amount)).toLocaleString("vi-VN")}đ`;
}
