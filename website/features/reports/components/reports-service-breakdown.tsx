import React from "react";
import Link from "next/link";
import { countFormat } from "@/lib/admin-format";
import { barTone, type ServiceActivity } from "../types";

interface ReportsServiceBreakdownProps {
  services: readonly ServiceActivity[];
  activityTotal: number;
  largestService: number;
  range: { from: string; to: string };
  isPending: boolean;
  isError: boolean;
}

export function ReportsServiceBreakdown({
  services,
  activityTotal,
  largestService,
  range,
  isPending,
  isError,
}: ReportsServiceBreakdownProps) {
  return (
    <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1.4fr)_minmax(18rem,22rem)]">
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-base font-semibold text-ink">
              Điểm nhấn vận hành
            </h2>
            <p className="mt-0.5 text-xs text-muted">
              So sánh các nhóm hoạt động
            </p>
          </div>
          <Link
            href="/overview"
            className="shrink-0 text-sm font-medium text-brand hover:underline cursor-pointer"
          >
            Chi tiết
          </Link>
        </div>

        {isError ? (
          <div className="py-8 text-center text-sm text-danger">
            Không thể tải dữ liệu phân bổ dịch vụ.
          </div>
        ) : (
          <>
            <div className="mt-4 flex items-baseline justify-between gap-3">
              <p className="text-sm text-muted">Hoạt động trong kỳ</p>
              <p className="text-2xl font-bold text-ink tabular-nums">
                {isPending ? "Đang tải…" : countFormat.format(activityTotal)}
              </p>
            </div>
            <div
              className="mt-3 flex h-3 overflow-hidden rounded-full bg-canvas"
              role="img"
              aria-label={`Cơ cấu ${countFormat.format(activityTotal)} hoạt động`}
            >
              {services.map((service) => (
                <span
                  key={service.label}
                  className={barTone[service.accent]}
                  style={{
                    width: `${activityTotal > 0 ? (service.value / activityTotal) * 100 : 0}%`,
                  }}
                />
              ))}
            </div>
            <ul className="mt-4 space-y-3">
              {services.map((service) => (
                <li
                  key={service.label}
                  className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-3 gap-y-1"
                >
                  <span className="min-w-0 text-sm text-ink">
                    {service.label}
                  </span>
                  <span className="text-sm font-semibold text-ink tabular-nums">
                    {isPending ? "…" : countFormat.format(service.value)}
                  </span>
                  <span className="col-span-2 block h-1.5 overflow-hidden rounded-full bg-canvas">
                    <span
                      className={`block h-full rounded-full ${barTone[service.accent]}`}
                      style={{
                        width: `${largestService > 0 ? (service.value / largestService) * 100 : 0}%`,
                      }}
                    />
                  </span>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <h2 className="text-sm font-semibold text-ink">
          Ghi chú &amp; Nguồn dữ liệu
        </h2>
        <p className="mt-0.5 text-xs text-muted">Đồng bộ từ backend DealGo</p>
        <dl className="mt-4 space-y-3 text-sm">
          <div>
            <dt className="text-muted">Phạm vi</dt>
            <dd className="mt-0.5 font-medium text-ink">
              {range.from === range.to
                ? range.from
                : `${range.from} → ${range.to}`}{" "}
              · giờ Việt Nam
            </dd>
          </div>
          <div>
            <dt className="text-muted">Nguồn sự thật</dt>
            <dd className="mt-0.5 leading-5 text-ink">
              GET /v1/ops/reports — chuyến/đơn tính theo ngày kết thúc; doanh thu là
              giá trị đặt chỗ (GMV), hoa hồng gồm phí tài xế và hoa hồng quán.
            </dd>
          </div>
          <div>
            <dt className="text-muted">Trạng thái đồng bộ</dt>
            <dd
              className={`mt-0.5 leading-5 font-semibold ${
                isError
                  ? "text-danger"
                  : isPending
                    ? "text-muted"
                    : "text-success font-medium"
              }`}
            >
              {isPending
                ? "Đang đồng bộ..."
                : isError
                  ? "Mất kết nối máy chủ · Không khả dụng"
                  : "Hoạt động bình thường · Sẵn sàng"}
            </dd>
          </div>
        </dl>
      </section>
    </div>
  );
}
