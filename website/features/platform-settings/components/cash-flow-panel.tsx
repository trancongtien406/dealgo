"use client";

import { useMemo, useState } from "react";
import { focusRing, QuietChip, StatusChip } from "@/components/ui/admin-list-ui";
import { OpsIcon } from "@/components/ui/ops-icons";
import type { PlatformSettingRow } from "../types";
import {
  CASH_FLOW_GROUPS,
  cashFlowUnit,
  foodExample,
  formatVnd,
  readCashFlowSettings,
  rideExample,
  type VoucherSponsor,
} from "../cash-flow";

type Props = {
  rows: PlatformSettingRow[];
  onEdit: (row: PlatformSettingRow) => void;
};

const SPONSORS: ReadonlyArray<[VoucherSponsor, string]> = [
  ["PLATFORM", "DealGo trả"],
  ["MERCHANT", "Quán trả"],
  ["SHARED", "Đồng tài trợ"],
];

function toInt(value: string): number {
  const parsed = Number(value.replace(/[^\d]/g, ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function MoneyInput(props: {
  label: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="block space-y-1">
      <span className="text-[11px] font-medium text-muted">{props.label}</span>
      <input
        inputMode="numeric"
        value={props.value.toLocaleString("vi-VN")}
        onChange={(event) => props.onChange(toInt(event.target.value))}
        className={`h-9 w-full rounded-lg border border-border bg-white px-2.5 font-mono text-sm text-ink ${focusRing}`}
      />
    </label>
  );
}

function Line(props: { label: string; value: number; strong?: boolean; tone?: "brand" | "muted" }) {
  return (
    <div className="flex items-baseline justify-between gap-3 py-1 text-sm">
      <span className={props.tone === "muted" ? "text-muted" : "text-ink"}>{props.label}</span>
      <span
        className={`font-mono ${props.strong ? "font-bold" : "font-medium"} ${
          props.tone === "brand" ? "text-brand" : "text-ink"
        }`}
      >
        {formatVnd(props.value)}
      </span>
    </div>
  );
}

/**
 * "Dòng tiền & hoa hồng": every money setting in one place, who pays whom,
 * and live worked examples computed from the current values (cash model).
 */
export function CashFlowPanel({ rows, onEdit }: Props) {
  const settings = useMemo(() => readCashFlowSettings(rows), [rows]);
  const byKey = useMemo(() => new Map(rows.map((row) => [row.key, row])), [rows]);

  const [isCar, setIsCar] = useState(false);
  const [fareVnd, setFareVnd] = useState(50_000);
  const [carriedFeeVnd, setCarriedFeeVnd] = useState(0);
  const [subtotalVnd, setSubtotalVnd] = useState(100_000);
  const [deliveryVnd, setDeliveryVnd] = useState(20_000);
  const [discountVnd, setDiscountVnd] = useState(10_000);
  const [sponsor, setSponsor] = useState<VoucherSponsor>("SHARED");

  const ridePercent = isCar ? settings.rideCarPercent : settings.rideBikePercent;
  const ride = rideExample({
    fareVnd,
    commissionPercent: ridePercent,
    carriedCancelFeeVnd: carriedFeeVnd,
  });
  const food = foodExample({
    subtotalVnd,
    deliveryFeeVnd: deliveryVnd,
    discountVnd,
    sponsor,
    merchantPercent: settings.merchantPercent,
    driverPercent: settings.foodDriverPercent,
    sharedPlatformPercent: settings.voucherSharedPlatformPercent,
  });

  return (
    <section className="space-y-4" aria-labelledby="cash-flow-title">
      <div className="rounded-2xl border border-border bg-white p-5 shadow-xs">
        <div className="flex items-center gap-2.5">
          <span className="grid size-9 place-items-center rounded-xl bg-brand/10 text-brand">
            <OpsIcon name="wallet" className="size-4" />
          </span>
          <div>
            <h2 id="cash-flow-title" className="text-lg font-bold text-ink">
              Dòng tiền & hoa hồng
            </h2>
            <p className="text-xs text-muted">
              Giai đoạn đầu khách trả tiền mặt cho tài xế; DealGo thu hoa hồng qua công nợ tài xế và
              đối soát quán. Các giá trị dưới đây đều là DRAFT — Admin chốt trước khi chạy thật.
            </p>
          </div>
        </div>
        <ol className="mt-4 grid gap-3 text-sm text-ink md:grid-cols-2">
          <li className="rounded-xl border border-border bg-canvas/60 p-3">
            <p className="font-semibold">Chuyến xe (xe máy / ô tô)</p>
            <ul className="mt-1 list-disc space-y-0.5 pl-5 text-xs text-muted">
              <li>Khách trả tài xế đúng giá đã thoả thuận (cộng phí huỷ muộn của chuyến trước nếu có).</li>
              <li>
                DealGo thu hoa hồng = giá chuyến × % theo hạng xe (xe máy{" "}
                {settings.rideBikePercent}%, ô tô {settings.rideCarPercent}%). Phí huỷ không tính hoa hồng.
              </li>
              <li>Tài xế cầm tiền mặt nên nợ DealGo phần hoa hồng; phí huỷ mang theo được chuyển cho tài xế bị huỷ.</li>
              <li>
                Nợ vượt {formatVnd(settings.driverDebtLimitVnd)} thì tài xế tạm dừng nhận việc tới khi Admin ghi nhận
                đã thu (0 = tắt).
              </li>
            </ul>
          </li>
          <li className="rounded-xl border border-border bg-canvas/60 p-3">
            <p className="font-semibold">Đơn đồ ăn</p>
            <ul className="mt-1 list-disc space-y-0.5 pl-5 text-xs text-muted">
              <li>Lấy món: tài xế trả quán tiền món trừ phần voucher quán chịu.</li>
              <li>Giao: khách trả tài xế tổng tiền (món + phí giao − voucher).</li>
              <li>
                Tài xế: DealGo thu {settings.foodDriverPercent}% trên phí giao (không tính trên tiền món) và hoàn
                cho tài xế phần voucher DealGo chịu.
              </li>
              <li>
                Quán: nợ DealGo {settings.merchantPercent}% tiền món, đối soát mỗi{" "}
                {settings.settlementCycleDays} ngày. Voucher đồng tài trợ: DealGo chịu{" "}
                {settings.voucherSharedPlatformPercent}%, quán chịu phần còn lại.
              </li>
            </ul>
          </li>
        </ol>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="rounded-2xl border border-border bg-white p-5 shadow-xs">
          <div className="flex items-center justify-between gap-2">
            <h3 className="font-semibold text-ink">Ví dụ chuyến xe</h3>
            <div role="radiogroup" aria-label="Hạng xe" className="flex gap-1 rounded-lg bg-canvas p-1 text-xs">
              {(
                [
                  [false, "Xe máy"],
                  [true, "Ô tô"],
                ] as const
              ).map(([car, label]) => (
                <button
                  key={label}
                  type="button"
                  role="radio"
                  aria-checked={isCar === car}
                  onClick={() => setIsCar(car)}
                  className={`rounded-md px-2.5 py-1 font-semibold cursor-pointer ${
                    isCar === car ? "bg-white text-ink shadow-xs" : "text-muted"
                  } ${focusRing}`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <MoneyInput label="Giá đã chốt (đ)" value={fareVnd} onChange={setFareVnd} />
            <MoneyInput label="Phí huỷ chuyến trước (đ)" value={carriedFeeVnd} onChange={setCarriedFeeVnd} />
          </div>
          <div className="mt-3 divide-y divide-border">
            <Line label="Khách trả (tiền mặt cho tài xế)" value={ride.customerPaysVnd} strong />
            <Line label={`Hoa hồng DealGo (${ridePercent}%)`} value={ride.commissionVnd} tone="muted" />
            <Line label="Tài xế giữ" value={ride.driverKeepsVnd} strong />
            <Line label="Tài xế nộp lại DealGo (hoa hồng + phí huỷ)" value={ride.driverOwesDealGoVnd} tone="muted" />
            <Line label="Tài xế bị huỷ trước đó nhận" value={ride.previousDriverGetsVnd} tone="muted" />
            <Line label="DealGo thu về" value={ride.dealGoEarnsVnd} strong tone="brand" />
          </div>
        </div>

        <div className="rounded-2xl border border-border bg-white p-5 shadow-xs">
          <div className="flex items-center justify-between gap-2">
            <h3 className="font-semibold text-ink">Ví dụ đơn đồ ăn</h3>
            <div role="radiogroup" aria-label="Ai trả voucher" className="flex gap-1 rounded-lg bg-canvas p-1 text-xs">
              {SPONSORS.map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  role="radio"
                  aria-checked={sponsor === value}
                  onClick={() => setSponsor(value)}
                  className={`rounded-md px-2 py-1 font-semibold cursor-pointer ${
                    sponsor === value ? "bg-white text-ink shadow-xs" : "text-muted"
                  } ${focusRing}`}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-3 grid grid-cols-3 gap-2">
            <MoneyInput label="Tiền món (đ)" value={subtotalVnd} onChange={setSubtotalVnd} />
            <MoneyInput label="Phí giao (đ)" value={deliveryVnd} onChange={setDeliveryVnd} />
            <MoneyInput label="Voucher (đ)" value={discountVnd} onChange={setDiscountVnd} />
          </div>
          <div className="mt-3 divide-y divide-border">
            <Line label="Khách trả (tiền mặt cho tài xế)" value={food.customerPaysVnd} strong />
            <Line label="Voucher DealGo chịu" value={food.platformFundedVnd} tone="muted" />
            <Line label="Voucher quán chịu" value={food.merchantFundedVnd} tone="muted" />
            <Line label="Tài xế trả quán lúc lấy món" value={food.driverPaysMerchantVnd} tone="muted" />
            <Line
              label={`Hoa hồng quán (${settings.merchantPercent}% tiền món, theo chu kỳ)`}
              value={food.merchantCommissionVnd}
              tone="muted"
            />
            <Line label="Quán thực nhận" value={food.merchantKeepsVnd} strong />
            <Line
              label={`Hoa hồng tài xế (${settings.foodDriverPercent}% phí giao)`}
              value={food.driverCommissionVnd}
              tone="muted"
            />
            <Line label="Tài xế giữ" value={food.driverKeepsVnd} strong />
            <Line
              label="Tài xế nộp DealGo (âm = DealGo trả tài xế)"
              value={food.driverOwesDealGoVnd}
              tone="muted"
            />
            <Line label="DealGo thu về (hoa hồng − voucher DealGo chịu)" value={food.dealGoEarnsVnd} strong tone="brand" />
          </div>
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {CASH_FLOW_GROUPS.map((group) => (
          <div key={group.id} className="rounded-2xl border border-border bg-white p-5 shadow-xs">
            <h3 className="font-semibold text-ink">{group.title}</h3>
            <ul className="mt-2 divide-y divide-border">
              {group.keys.map((key) => {
                const row = byKey.get(key);
                if (!row) {
                  return null;
                }
                const unit = cashFlowUnit(key);
                return (
                  <li key={key} className="flex items-start justify-between gap-3 py-2.5">
                    <div className="min-w-0">
                      <p className="text-sm font-medium text-ink">{row.label}</p>
                      <p className="mt-0.5 text-[11px] leading-relaxed text-muted">{row.hint}</p>
                    </div>
                    <div className="flex shrink-0 flex-col items-end gap-1.5">
                      <span className="font-mono text-sm font-bold text-ink">
                        {unit === "đ" ? formatVnd(Number(row.value) || 0) : `${row.value || "—"}${unit ? ` ${unit}` : ""}`}
                      </span>
                      {row.source === "db" ? (
                        <StatusChip tone="brand">DB override</StatusChip>
                      ) : (
                        <QuietChip>Env default</QuietChip>
                      )}
                      <button
                        type="button"
                        onClick={() => onEdit(row)}
                        aria-label={`Sửa ${row.label}`}
                        className={`inline-flex items-center gap-1 rounded-lg border border-border px-2 py-1 text-xs font-semibold text-ink hover:text-brand cursor-pointer ${focusRing}`}
                      >
                        <OpsIcon name="sliders" className="size-3.5 text-muted" />
                        Sửa
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}
