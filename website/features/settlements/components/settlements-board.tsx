"use client";

import { useMemo, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  ExportCsvButton,
  formatCompactVnd,
  PreviewButton,
  PreviewLink,
  PreviewTabs,
  TextKpi,
  vnd,
} from "@/components/ui/admin-list-ui";

import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { AdminHeaderDateFilter } from "@/components/ui/admin-header-date-filter";
import type { DateRangeValue } from "@/components/ui/date-picker";
import { SettlementLinesTable } from "@/features/settlements/components/settlement-lines-table";
import { settlementSteps } from "@/features/settlements/constants";
import { useSettlementLinesQuery } from "@/features/settlements/hooks";
import { settlementLineStatusLabel } from "@/features/settlements/mappers";
import { isForbiddenError } from "@/lib/api/errors";

export function SettlementsBoard() {
  const [activeTab, setActiveTab] = useState("Bút toán");
  // Settlement period: batches whose business day falls inside [from, to] (server-side).
  const [period, setPeriod] = useState<DateRangeValue>({ from: null, to: null });
  const linesQuery = useSettlementLinesQuery(1, 50, period);
  const forbidden = linesQuery.isError && isForbiddenError(linesQuery.error);
  const lines = useMemo(
    () => linesQuery.data?.items ?? [],
    [linesQuery.data?.items],
  );
  const totalLines = linesQuery.data?.total ?? lines.length;

  const kpis = useMemo(() => {
    const revenue = lines.reduce((sum, line) => sum + line.revenue, 0);
    const fees = lines.reduce((sum, line) => sum + line.fee, 0);
    const provisional = lines.reduce((sum, line) => sum + line.provisional, 0);
    const awaiting = lines.filter(
      (line) => line.status === "AWAITING_RECONCILE",
    ).length;
    const eligible = lines.filter((line) => line.status === "ELIGIBLE").length;

    return [
      {
        label: "Giao dịch đủ điều kiện",
        value: String(eligible || totalLines),
        note: `${totalLines} bút toán trong trang`,
        icon: "check" as const,
        tone: "success" as const,
      },
      {
        label: "Doanh thu đủ điều kiện",
        value: formatCompactVnd(revenue),
        note: "Theo bút toán đã tải",
        icon: "receipt" as const,
        tone: "brand" as const,
      },
      {
        label: "Phí dịch vụ ước tính",
        value: formatCompactVnd(fees),
        note: "Theo bút toán đã tải",
        icon: "wallet" as const,
        tone: "food" as const,
      },
      {
        label: "Chờ đối soát",
        value: String(awaiting),
        note: "Trạng thái AWAITING_RECONCILE",
        icon: "clock" as const,
        tone: "delivery" as const,
      },
      {
        label: "Tạm tính chi trả",
        value: formatCompactVnd(provisional),
        note: "Tổng provisional",
        icon: "wallet" as const,
        tone: "success" as const,
      },
    ];
  }, [lines, totalLines]);

  const exportLines = lines;

  return (
    <div className="space-y-5">
      {linesQuery.isError && lines.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ dữ liệu đợt đối soát từ máy chủ."
          onRetry={() => void linesQuery.refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Tài chính", href: "/transactions" },
          { label: "Đối soát đối tác" },
        ]}
      />
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập đối soát tài chính"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc xử lý chu kỳ đối soát và chi trả đối tác."
        />
      ) : (
        <>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                Đối soát & thanh toán đối tác
              </h1>
              <p className="mt-1 text-sm text-muted">
                Tổng hợp doanh thu đủ điều kiện, khấu trừ phí nền tảng và quản
                lý chu kỳ chi trả đối tác.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <AdminHeaderDateFilter
                value={period}
                onChange={setPeriod}
                defaultPreset="all"
                labelPrefix="Kỳ đối soát"
              />
              <ExportCsvButton
                filename="settlement-lines.csv"
                headers={[
                  "Loại",
                  "Mã tham chiếu",
                  "Thời gian",
                  "Doanh thu",
                  "Phí",
                  "Tạm tính",
                  "Trạng thái",
                ]}
                rows={exportLines.map((line) => [
                  line.kind,
                  line.ref,
                  line.at,
                  String(line.revenue),
                  String(line.fee),
                  String(line.provisional),
                  settlementLineStatusLabel(line.status),
                ])}
              >
                <OpsIcon name="download" className="size-4" />
                Xuất CSV
              </ExportCsvButton>
              <PreviewLink href="/transactions" tone="brand">
                <OpsIcon name="receipt" className="size-4" />
                Sổ giao dịch
              </PreviewLink>
            </div>
          </div>
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {kpis.map((kpi) => (
              <li key={kpi.label}>
                <TextKpi
                  label={kpi.label}
                  value={kpi.value}
                  note={kpi.note}
                  icon={kpi.icon}
                  tone={kpi.tone}
                />
              </li>
            ))}
          </ul>

          <PreviewTabs
            label="Đối tượng đối soát"
            tabs={[
              "Bút toán",
              "Quy trình",
              "Lịch sử chi trả",
              "Chênh lệch đối soát",
            ]}
            current={activeTab}
            onChange={setActiveTab}
          />

          {activeTab === "Bút toán" && (
            <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(18rem,22rem)]">
              <div className="space-y-4">
                <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h2 className="text-base font-semibold text-ink">
                        Bút toán đối soát
                      </h2>
                      <p className="mt-1 text-sm text-muted">
                        Dữ liệu đợt đối soát. Chưa chọn đối tác cụ thể.
                      </p>
                    </div>
                    <PreviewLink href="/stores" tone="ghost" compact>
                      Danh sách cửa hàng
                    </PreviewLink>
                  </div>
                </section>
                <div className="min-w-0 space-y-4">
                  <div className="flex flex-wrap items-center justify-between gap-2 px-1">
                    <h2 className="text-sm font-semibold text-ink">
                      Bút toán trong kỳ
                    </h2>
                    <PreviewButton
                      compact
                      tone="ghost"
                      onClick={() => void linesQuery.refetch()}
                    >
                      <OpsIcon name="refresh" className="size-4" />
                      Làm mới
                    </PreviewButton>
                  </div>
                  <SettlementLinesTable />
                </div>
              </div>
              <aside className="space-y-4">
                <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                  <h3 className="text-sm font-semibold text-ink">
                    Bảng tính quyết toán
                  </h3>
                  <p className="mt-2 text-sm text-muted">
                    Chưa có dữ liệu đối tác.
                  </p>
                  <dl className="mt-3 space-y-2 text-sm">
                    <div className="flex justify-between gap-3">
                      <dt className="text-muted">Doanh thu (trang)</dt>
                      <dd className="font-medium tabular-nums">
                        {vnd(
                          lines.reduce((sum, line) => sum + line.revenue, 0),
                        )}
                      </dd>
                    </div>
                    <div className="flex justify-between gap-3">
                      <dt className="text-muted">Phí nền tảng</dt>
                      <dd className="font-medium tabular-nums text-danger">
                        −{vnd(lines.reduce((sum, line) => sum + line.fee, 0))}
                      </dd>
                    </div>
                    <div className="flex justify-between gap-3">
                      <dt className="text-muted">Tạm tính</dt>
                      <dd className="font-medium tabular-nums">
                        {vnd(
                          lines.reduce(
                            (sum, line) => sum + line.provisional,
                            0,
                          ),
                        )}
                      </dd>
                    </div>
                  </dl>
                </section>
                <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                  <h3 className="text-sm font-semibold text-ink">
                    Quy trình kiểm soát
                  </h3>
                  <ol className="mt-3 space-y-3">
                    {settlementSteps.map((step) => (
                      <li
                        key={step.title}
                        className="flex items-center gap-2 text-sm"
                      >
                        <span
                          className={`grid size-6 place-items-center rounded-full ${
                            step.done
                              ? "bg-success/15 text-success"
                              : "bg-canvas text-muted"
                          }`}
                        >
                          <OpsIcon
                            name={step.done ? "check" : "clock"}
                            className="size-3.5"
                          />
                        </span>
                        <span className={step.done ? "text-ink" : "text-muted"}>
                          {step.title}
                        </span>
                      </li>
                    ))}
                  </ol>
                  <div className="mt-4 flex flex-wrap gap-2">
                    <PreviewLink href="/exceptions" tone="neutral">
                      Xem ngoại lệ / chênh lệch
                    </PreviewLink>
                    <PreviewLink href="/refunds" tone="brand">
                      Kiểm tra hoàn tiền
                    </PreviewLink>
                  </div>
                </section>
              </aside>
            </div>
          )}

          {activeTab === "Quy trình" && (
            <section className="rounded-2xl border border-border bg-white p-6 shadow-sm">
              <h2 className="text-base font-semibold text-ink">
                Quy trình đối soát
              </h2>
              <ol className="mt-4 space-y-3">
                {settlementSteps.map((step) => (
                  <li
                    key={step.title}
                    className="flex items-center gap-3 text-sm"
                  >
                    <span
                      className={`grid size-7 place-items-center rounded-full ${
                        step.done
                          ? "bg-success/15 text-success"
                          : "bg-canvas text-muted"
                      }`}
                    >
                      <OpsIcon
                        name={step.done ? "check" : "clock"}
                        className="size-3.5"
                      />
                    </span>
                    <span
                      className={
                        step.done ? "text-ink font-medium" : "text-muted"
                      }
                    >
                      {step.title}
                    </span>
                  </li>
                ))}
              </ol>
            </section>
          )}

          {activeTab === "Lịch sử chi trả" && (
            <AdminEmptyState
              icon="wallet"
              title="Chưa có dữ liệu"
              description="Lịch sử đợt chi trả đối tác chưa có. Chỉ hiển thị bút toán đối soát ở tab Bút toán."
              action={
                <PreviewLink href="/transactions" tone="brand" compact>
                  Mở sổ giao dịch
                </PreviewLink>
              }
            />
          )}

          {activeTab === "Chênh lệch đối soát" && (
            <AdminEmptyState
              icon="alert"
              title="Chưa có dữ liệu"
              description="Báo cáo chênh lệch đối soát chưa có. Dùng hàng đợi ngoại lệ khi cần xử lý sai lệch."
              action={
                <PreviewLink href="/exceptions" tone="brand" compact>
                  Xem hàng đợi ngoại lệ
                </PreviewLink>
              }
            />
          )}
        </>
      )}
    </div>
  );
}
