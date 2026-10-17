"use client";

import { useMemo, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import {
  formatUpdatedAt,
  priceStatusLabel,
  resolveCityCenter,
  zoneServiceLabel,
  zoneServiceTone,
} from "@/features/zones/mappers";
import type { CreateZoneInput, ZoneItem } from "@/features/zones/types";
import {
  useCreateZoneMutation,
  usePatchZoneMutation,
  useZoneRulesQuery,
  useZonesQuery,
} from "@/features/zones/hooks";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  ExportCsvButton,
  focusRing,
  ListPager,
  PreviewButton,
  PreviewLink,
  StatusChip,
  KpiCard,
  type PageSize,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminFilterField,
  AdminFilterToolbar,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import { SearchSelect } from "@/components/ui/search-select";
import { isForbiddenError } from "@/lib/api/errors";
import {
  LazyRealMapView,
  type MapMarker,
} from "@/components/ui/lazy-real-map-view";

import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import {
  ZONE_RULE_COLUMN_COUNT,
  ZONE_RULE_TABLE_COLUMNS,
  ZONE_SERVICE_FILTER_OPTIONS,
  ZONE_STATUS_FILTER_OPTIONS,
  ZONE_STATUS_TABS,
} from "@/features/zones/constants";

export function ZonesBoard() {
  const [zoneTab, setZoneTab] = useState<"ACTIVE" | "ALL" | "PLANNED">(
    "ACTIVE",
  );
  const [selectedCode, setSelectedCode] = useState<string | null>(null);
  const [service, setService] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);

  // Modals
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showStatusModal, setShowStatusModal] = useState(false);

  const {
    data: zones = [],
    isPending: zonesPending,
    isError: zonesError,
    error: zonesQueryError,
    refetch: refetchZones,
  } = useZonesQuery(zoneTab);

  const createZoneMutation = useCreateZoneMutation();
  const patchZoneMutation = usePatchZoneMutation();

  const selectedZone =
    zones.find((zone) => zone.code === selectedCode) ?? zones[0] ?? null;

  const {
    data,
    isPending: rulesPending,
    isError: rulesError,
    error: rulesQueryError,
    refetch: refetchRules,
  } = useZoneRulesQuery({
    page,
    limit: pageSize,
    q: query,
    service,
    status,
  });

  const rules = data?.items ?? [];
  const total = data?.total ?? 0;
  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const activeRuleCount =
    status === "ACTIVE"
      ? total
      : status && status !== "ALL"
        ? 0
        : rules.filter((row) => row.status === "ACTIVE").length;
  const rulesKpiNote =
    status === "ACTIVE"
      ? "theo bộ lọc"
      : status && status !== "ALL"
        ? "ngoài bộ lọc trạng thái"
        : "trên trang hiện tại · service/status lọc tại BFF";
  const totalDemand = zones.reduce((sum, zone) => sum + zone.demandCount, 0);
  const totalRideDemand = zones.reduce(
    (sum, zone) => sum + zone.demandRideCount,
    0,
  );
  const totalFoodDemand = zones.reduce(
    (sum, zone) => sum + zone.demandFoodCount,
    0,
  );

  const mapMarkers: MapMarker[] = useMemo(
    () =>
      zones.map((zone) => {
        const [lat, lng] = resolveCityCenter(zone);
        const selected = selectedZone?.code === zone.code;
        return {
          id: zone.code,
          lat,
          lng,
          label: zone.name,
          type: selected ? "pickup" : "hub",
          status: selected ? "Đang chọn" : zone.status,
          detail: `${zone.demandCount} nhu cầu 24h · ${zone.demandRideCount} xe · ${zone.demandFoodCount} ăn`,
        };
      }),
    [zones, selectedZone?.code],
  );

  const mapCenter = resolveCityCenter(selectedZone ?? undefined);
  const mapZoom = zones.length > 1 && !selectedCode ? 5.2 : 11;

  const resetFilters = () => {
    setQuery("");
    setService(null);
    setStatus(null);
    setPage(1);
  };

  const isError = zonesError || rulesError;
  const forbidden =
    (zonesError && isForbiddenError(zonesQueryError)) ||
    (rulesError && isForbiddenError(rulesQueryError));

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && rules.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ khu vực / quy tắc giá từ máy chủ."
          onRetry={() => {
            void refetchZones();
            void refetchRules();
          }}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Khu vực & Giá" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Khu vực hoạt động & quy tắc giá
          </h1>
          <p className="mt-1 max-w-3xl text-sm text-muted">
            Quản lý các vùng hoạt động (bảng service_regions) và bảng giá sàn.
            Nhãn pilot toàn hệ thống tự động đồng bộ từ các vùng ACTIVE.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewButton tone="brand" onClick={() => setShowCreateModal(true)}>
            <OpsIcon name="plus" className="size-4" />
            Thêm khu vực
          </PreviewButton>
          <PreviewLink href="/settings/platform" tone="neutral">
            <OpsIcon name="settings" className="size-4" />
            Sửa cấu hình sàn
          </PreviewLink>
          <ExportCsvButton
            filename="zone-rules.csv"
            headers={[
              "Mã",
              "Tên",
              "Dịch vụ",
              "Phạm vi",
              "Giá trị",
              "Đơn vị",
              "Trạng thái",
            ]}
            rows={rules.map((row) => [
              row.code,
              row.name,
              row.service,
              row.zone,
              row.value,
              row.unit,
              row.status,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất quy tắc
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <li>
          <KpiCard
            label="Khu vực hiển thị"
            value={zones.length}
            note={
              zoneTab === "ACTIVE" ? "Đang phục vụ (ACTIVE)" : "Theo bộ lọc tab"
            }
            icon="pin"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Quy tắc đang áp dụng"
            value={activeRuleCount}
            note={rulesKpiNote}
            icon="wallet"
            tone="success"
          />
        </li>
        <li>
          <KpiCard
            label="Nhu cầu xe (24h)"
            value={totalRideDemand}
            note="Open rides theo mã vùng"
            icon="car"
            tone="brand"
          />
        </li>
        <li>
          <KpiCard
            label="Nhu cầu đồ ăn (24h)"
            value={totalFoodDemand}
            note={`Tổng nhu cầu ${countFormat.format(totalDemand)}`}
            icon="utensils"
            tone="food"
          />
        </li>
      </ul>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền quản lý khu vực & quy tắc giá"
          description="Tài khoản Ops hiện tại không được phân quyền xem hoặc thiết lập vùng hoạt động và quy tắc tính giá."
        />
      ) : (
        <>
          <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,18rem)_minmax(0,1.35fr)_minmax(15rem,18rem)]">
            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <div className="flex items-center justify-between gap-2">
                <h2 className="text-base font-semibold text-ink">
                  Danh sách khu vực
                </h2>
                <span className="text-xs text-muted tabular-nums">
                  {zones.length} vùng
                </span>
              </div>

              {/* Tab filter */}
              <div className="mt-3 flex rounded-xl border border-border bg-canvas/60 p-0.5 text-xs font-medium">
                {ZONE_STATUS_TABS.map((tab) => (
                  <button
                    key={tab.value}
                    type="button"
                    onClick={() => setZoneTab(tab.value)}
                    className={`flex-1 rounded-lg py-1.5 text-center transition-colors cursor-pointer ${
                      zoneTab === tab.value
                        ? "bg-white font-semibold text-ink shadow-xs"
                        : "text-muted hover:text-ink"
                    }`}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>

              <ul className="mt-3 space-y-1">
                {zonesPending ? (
                  <li className="px-3 py-6 text-sm text-muted">
                    Đang tải vùng…
                  </li>
                ) : zones.length === 0 ? (
                  <li className="px-3 py-6 text-sm text-muted">
                    Chưa có khu vực nào trong mục này.
                  </li>
                ) : (
                  zones.map((zone) => {
                    const selected = selectedZone?.code === zone.code;
                    const isActive = zone.status === "ACTIVE";
                    return (
                      <li key={zone.code}>
                        <button
                          type="button"
                          onClick={() => setSelectedCode(zone.code)}
                          aria-current={selected ? "true" : undefined}
                          className={`flex w-full min-w-0 items-center gap-2 rounded-xl px-3 py-2.5 text-left transition-colors cursor-pointer ${
                            selected
                              ? "bg-brand/10 font-medium text-brand shadow-xs"
                              : "text-ink hover:bg-canvas"
                          } ${focusRing}`}
                        >
                          <OpsIcon
                            name="pin"
                            className={`size-4 shrink-0 ${selected ? "text-brand" : "text-muted"}`}
                          />
                          <span className="min-w-0 flex-1">
                            <span className="block truncate text-sm font-medium text-ink">
                              {zone.name}
                            </span>
                            <span className="block truncate text-xs text-muted">
                              {countFormat.format(zone.demandCount)} nhu cầu ·{" "}
                              {zone.code}
                            </span>
                          </span>
                          <StatusChip tone={isActive ? "success" : "delivery"}>
                            {isActive ? "Hoạt động" : "Kế hoạch"}
                          </StatusChip>
                        </button>
                      </li>
                    );
                  })
                )}
              </ul>
              <div className="mt-4 border-t border-border pt-3">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(true)}
                  className="inline-flex w-full items-center justify-center gap-1.5 rounded-xl border border-dashed border-border py-2 text-xs font-semibold text-muted hover:border-brand hover:text-brand transition-colors cursor-pointer"
                >
                  <OpsIcon name="plus" className="size-3.5" />
                  Thêm khu vực mới
                </button>
              </div>
            </section>

            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <h2 className="text-base font-semibold text-ink">
                    Bản đồ khu vực
                  </h2>
                  <p className="mt-1 text-sm text-muted">
                    Hiển thị tâm khu vực hoạt động DealGo
                  </p>
                </div>
                {selectedZone ? (
                  <StatusChip
                    tone={
                      selectedZone.status === "ACTIVE" ? "brand" : "delivery"
                    }
                  >
                    {selectedZone.name} ({selectedZone.code})
                  </StatusChip>
                ) : null}
              </div>
              <div className="mt-4">
                <LazyRealMapView
                  center={mapCenter}
                  zoom={mapZoom}
                  height={360}
                  markers={mapMarkers}
                  showControls
                  showAttribution
                />
              </div>
            </section>

            <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <h2 className="text-base font-semibold text-ink">
                    Thông tin vùng
                  </h2>
                  <p className="mt-1 text-sm text-muted">
                    {selectedZone?.name ?? "Chưa chọn"}
                  </p>
                </div>
                <StatusChip
                  tone={
                    selectedZone?.status === "ACTIVE" ? "success" : "delivery"
                  }
                >
                  {selectedZone?.status === "ACTIVE"
                    ? "Đang phục vụ"
                    : "Kế hoạch / Tắt"}
                </StatusChip>
              </div>
              <dl className="mt-3">
                <InfoRow label="Mã vùng" value={selectedZone?.code ?? "—"} />
                <InfoRow label="Tên nhãn" value={selectedZone?.label ?? "—"} />
                <InfoRow
                  label="Tọa độ tâm"
                  value={
                    selectedZone?.centerLat != null &&
                    selectedZone?.centerLng != null
                      ? `${selectedZone.centerLat.toFixed(4)}, ${selectedZone.centerLng.toFixed(4)}`
                      : "—"
                  }
                />
                <InfoRow
                  label="Nhu cầu xe (24h)"
                  value={countFormat.format(selectedZone?.demandRideCount ?? 0)}
                />
                <InfoRow
                  label="Nhu cầu đồ ăn (24h)"
                  value={countFormat.format(selectedZone?.demandFoodCount ?? 0)}
                />
                <InfoRow
                  label="Tổng nhu cầu"
                  value={countFormat.format(selectedZone?.demandCount ?? 0)}
                />
              </dl>

              {selectedZone ? (
                <div className="mt-4 space-y-2 border-t border-border pt-3">
                  <button
                    type="button"
                    onClick={() => setShowStatusModal(true)}
                    className={`w-full rounded-xl py-2 px-3 text-xs font-semibold transition-colors cursor-pointer ${
                      selectedZone.status === "ACTIVE"
                        ? "bg-amber-500/10 text-amber-700 hover:bg-amber-500/20"
                        : "bg-brand text-white hover:bg-brand/90"
                    }`}
                  >
                    {selectedZone.status === "ACTIVE"
                      ? "Tạm dừng khu vực này"
                      : "Kích hoạt phục vụ (ACTIVE)"}
                  </button>
                </div>
              ) : null}

              <p className="mt-4 rounded-2xl bg-canvas p-3 text-xs leading-5 text-muted">
                Vùng phục vụ được lưu trong cơ sở dữ liệu. Mọi thay đổi đều được
                ghi vết tại Nhật ký kiểm toán.
              </p>
            </section>
          </div>

          <section className="min-w-0 rounded-2xl border border-border bg-white shadow-sm">
            <div className="flex flex-wrap items-start justify-between gap-3 px-4 pt-4">
              <div className="min-w-0">
                <h2
                  id="price-rules"
                  className="text-base font-semibold text-ink"
                >
                  Tham số giá & bán kính sàn
                </h2>
                <p className="mt-1 max-w-3xl text-sm text-muted">
                  Giá sàn / trần / tham chiếu km và bán kính tìm tài xế. Tự động
                  áp dụng cho các vùng ACTIVE — chỉnh tại Cấu hình sàn.
                </p>
              </div>
            </div>

            <div className="px-4 py-3">
              <AdminFilterToolbar>
                <AdminFilterField grow>
                  <label
                    htmlFor="zone-rule-query"
                    className="text-xs font-medium text-muted"
                  >
                    Tìm quy tắc
                  </label>
                  <div className="relative mt-1.5">
                    <OpsIcon
                      name="search"
                      className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
                    />
                    <input
                      id="zone-rule-query"
                      type="search"
                      autoComplete="off"
                      value={query}
                      onChange={(event) => {
                        setQuery(event.target.value);
                        setPage(1);
                      }}
                      placeholder="Tìm mã, tên quy tắc..."
                      className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
                    />
                  </div>
                </AdminFilterField>
                <AdminFilterField>
                  <SearchSelect
                    label="Dịch vụ"
                    value={service}
                    options={ZONE_SERVICE_FILTER_OPTIONS}
                    placeholder="Tất cả dịch vụ"
                    onChange={(value) => {
                      setService(value);
                      setPage(1);
                    }}
                  />
                </AdminFilterField>
                <AdminFilterField>
                  <SearchSelect
                    label="Trạng thái"
                    value={status}
                    options={ZONE_STATUS_FILTER_OPTIONS}
                    placeholder="Tất cả"
                    onChange={(value) => {
                      setStatus(value);
                      setPage(1);
                    }}
                  />
                </AdminFilterField>
                <div className="flex shrink-0 flex-wrap items-end gap-2">
                  <PreviewButton onClick={() => void refetchRules()}>
                    <OpsIcon name="refresh" className="size-4" />
                    Làm mới
                  </PreviewButton>
                  <AdminResetFilterButton onClick={resetFilters} />
                </div>
              </AdminFilterToolbar>
            </div>

            {rulesError && rules.length === 0 ? (
              <div className="p-4">
                <AdminListErrorBanner
                  message="Không thể tải quy tắc giá từ máy chủ."
                  onRetry={() => void refetchRules()}
                />
              </div>
            ) : !rulesPending && rules.length === 0 ? (
              <div className="p-4">
                <AdminEmptyState
                  icon="pin"
                  title="Không có quy tắc giá"
                  description="Không tìm thấy quy tắc giá nào phù hợp với bộ lọc."
                  action={<AdminResetFilterButton onClick={resetFilters} />}
                />
              </div>
            ) : (
              <>
                <AdminTableContainer minWidth="min-w-[880px]">
                  <AdminTable
                    caption="Bảng quy tắc giá"
                    ariaBusy={rulesPending}
                  >
                    <AdminTableHeader>
                      <AdminTableRow>
                        {ZONE_RULE_TABLE_COLUMNS.map((col) => (
                          <AdminTableHead
                            key={col.id}
                            align={"align" in col ? col.align : "left"}
                          >
                            {col.label}
                          </AdminTableHead>
                        ))}
                      </AdminTableRow>
                    </AdminTableHeader>
                    <AdminTableBody>
                      {rulesPending ? (
                        <AdminTableBodyShimmer
                          columns={ZONE_RULE_COLUMN_COUNT}
                          rows={5}
                        />
                      ) : (
                        rules.map((rule) => (
                          <AdminTableRow key={rule.code}>
                            <AdminTableCell className="font-semibold text-brand">
                              {rule.code}
                            </AdminTableCell>
                            <AdminTableCell className="font-medium">
                              {rule.name}
                            </AdminTableCell>
                            <AdminTableCell>
                              <StatusChip tone={zoneServiceTone(rule.service)}>
                                {zoneServiceLabel(rule.service)}
                              </StatusChip>
                            </AdminTableCell>
                            <AdminTableCell className="max-w-[12rem] truncate">
                              {rule.zone}
                            </AdminTableCell>
                            <AdminTableCell
                              align="right"
                              className="font-semibold tabular-nums"
                            >
                              {rule.displayValue}
                            </AdminTableCell>
                            <AdminTableCell className="text-muted">
                              {formatUpdatedAt(rule.updatedAt)}
                            </AdminTableCell>
                            <AdminTableCell>
                              <StatusChip
                                tone={
                                  rule.status === "ACTIVE" ? "success" : "food"
                                }
                              >
                                {priceStatusLabel(rule.status)}
                              </StatusChip>
                            </AdminTableCell>
                            <AdminTableCell>
                              <PreviewLink
                                href="/settings/platform"
                                compact
                                tone="ghost"
                                label="Sửa tại cấu hình"
                              >
                                <OpsIcon name="settings" className="size-4" />
                              </PreviewLink>
                            </AdminTableCell>
                          </AdminTableRow>
                        ))
                      )}
                    </AdminTableBody>
                  </AdminTable>
                </AdminTableContainer>

                <ListPager
                  summary={`Hiển thị ${rules.length} / ${countFormat.format(total)} quy tắc`}
                  label="Phân trang quy tắc giá"
                  page={currentPage}
                  onPageChange={setPage}
                  lastPage={lastPage}
                  pageSize={pageSize}
                  onPageSizeChange={(size) => {
                    setPageSize(size);
                    setPage(1);
                  }}
                />
              </>
            )}
          </section>
        </>
      )}

      {/* Modal: Thêm khu vực mới */}
      {showCreateModal ? (
        <CreateZoneModal
          onClose={() => setShowCreateModal(false)}
          onSubmit={async (input) => {
            await createZoneMutation.mutateAsync(input);
            setShowCreateModal(false);
          }}
          isSubmitting={createZoneMutation.isPending}
        />
      ) : null}

      {/* Modal: Đổi trạng thái khu vực */}
      {showStatusModal && selectedZone ? (
        <ToggleZoneStatusModal
          zone={selectedZone}
          onClose={() => setShowStatusModal(false)}
          onSubmit={async (reason) => {
            const nextStatus =
              selectedZone.status === "ACTIVE" ? "PLANNED" : "ACTIVE";
            await patchZoneMutation.mutateAsync({
              code: selectedZone.code,
              input: { status: nextStatus, reason },
            });
            setShowStatusModal(false);
          }}
          isSubmitting={patchZoneMutation.isPending}
        />
      ) : null}
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-3 border-t border-border py-2.5 text-sm">
      <dt className="shrink-0 text-muted">{label}</dt>
      <dd className="min-w-0 text-right font-medium text-ink">{value}</dd>
    </div>
  );
}

function CreateZoneModal({
  onClose,
  onSubmit,
  isSubmitting,
}: {
  onClose: () => void;
  onSubmit: (input: CreateZoneInput) => Promise<void>;
  isSubmitting: boolean;
}) {
  const [code, setCode] = useState("");
  const [label, setLabel] = useState("");
  const [centerLat, setCenterLat] = useState("");
  const [centerLng, setCenterLng] = useState("");
  const [minLat, setMinLat] = useState("");
  const [maxLat, setMaxLat] = useState("");
  const [minLng, setMinLng] = useState("");
  const [maxLng, setMaxLng] = useState("");
  const [status, setStatus] = useState<"ACTIVE" | "PLANNED">("ACTIVE");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);

  const autoFillBbox = () => {
    const lat = parseFloat(centerLat);
    const lng = parseFloat(centerLng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      setError("Vui lòng nhập toạ độ tâm hợp lệ trước khi tự tính BBox.");
      return;
    }
    setError(null);
    setMinLat((lat - 0.15).toFixed(4));
    setMaxLat((lat + 0.15).toFixed(4));
    setMinLng((lng - 0.15).toFixed(4));
    setMaxLng((lng + 0.15).toFixed(4));
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);

    const cLat = parseFloat(centerLat);
    const cLng = parseFloat(centerLng);
    const miLat = parseFloat(minLat);
    const maLat = parseFloat(maxLat);
    const miLng = parseFloat(minLng);
    const maLng = parseFloat(maxLng);

    if (!code.trim() || !label.trim() || !reason.trim()) {
      setError("Vui lòng điền đầy đủ mã, tên khu vực và lý do.");
      return;
    }

    if (
      !Number.isFinite(cLat) ||
      !Number.isFinite(cLng) ||
      !Number.isFinite(miLat) ||
      !Number.isFinite(maLat) ||
      !Number.isFinite(miLng) ||
      !Number.isFinite(maLng)
    ) {
      setError("Toạ độ và khung BBox phải là số hợp lệ.");
      return;
    }

    try {
      await onSubmit({
        code: code.trim().toUpperCase(),
        label: label.trim(),
        centerLat: cLat,
        centerLng: cLng,
        bbox: { minLat: miLat, maxLat: maLat, minLng: miLng, maxLng: maLng },
        status,
        reason: reason.trim(),
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Không thể tạo khu vực.";
      setError(msg);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="create-zone-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4 overflow-y-auto"
    >
      <div
        className="fixed inset-0 bg-ink/40 backdrop-blur-xs"
        onClick={onClose}
      />
      <div className="relative z-10 w-full max-w-lg rounded-2xl border border-border bg-white p-6 shadow-2xl my-8">
        <div className="flex items-start justify-between gap-3 border-b border-border pb-4">
          <div className="min-w-0">
            <h3 id="create-zone-title" className="text-lg font-bold text-ink">
              Thêm khu vực hoạt động mới
            </h3>
            <p className="mt-1 text-sm text-muted">
              Định nghĩa mã, tâm và khung ranh giới sơ bộ cho khu vực mới.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-1 text-muted hover:bg-canvas hover:text-ink cursor-pointer"
          >
            <OpsIcon name="close" className="size-5" />
          </button>
        </div>

        {error ? (
          <div className="mt-4 rounded-xl bg-red-500/10 p-3 text-sm text-red-600">
            {error}
          </div>
        ) : null}

        <form onSubmit={(e) => void handleSubmit(e)} className="mt-4 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-ink">
                Mã vùng (2–8 ký tự) *
              </label>
              <input
                type="text"
                required
                maxLength={8}
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                placeholder="VD: QN, BD, VT"
                className={`mt-1 h-9 w-full rounded-xl border border-border px-3 text-sm font-semibold uppercase text-brand placeholder:text-muted ${focusRing}`}
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink">
                Tên hiển thị *
              </label>
              <input
                type="text"
                required
                value={label}
                onChange={(e) => setLabel(e.target.value)}
                placeholder="VD: Quảng Ngãi"
                className={`mt-1 h-9 w-full rounded-xl border border-border px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-ink">
                Vĩ độ tâm (Center Lat) *
              </label>
              <input
                type="number"
                step="any"
                required
                value={centerLat}
                onChange={(e) => setCenterLat(e.target.value)}
                placeholder="VD: 15.1200"
                className={`mt-1 h-9 w-full rounded-xl border border-border px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink">
                Kinh độ tâm (Center Lng) *
              </label>
              <input
                type="number"
                step="any"
                required
                value={centerLng}
                onChange={(e) => setCenterLng(e.target.value)}
                placeholder="VD: 108.8000"
                className={`mt-1 h-9 w-full rounded-xl border border-border px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </div>

          <div className="rounded-xl border border-border bg-canvas/40 p-3 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-ink">
                Khung toạ độ BBox (min/max)
              </span>
              <button
                type="button"
                onClick={autoFillBbox}
                className="text-xs font-medium text-brand hover:underline cursor-pointer"
              >
                Gợi ý từ tâm (±0.15°)
              </button>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <input
                type="number"
                step="any"
                required
                value={minLat}
                onChange={(e) => setMinLat(e.target.value)}
                placeholder="Min Lat (VD: 15.00)"
                className={`h-8 w-full rounded-lg border border-border bg-white px-2.5 text-xs text-ink ${focusRing}`}
              />
              <input
                type="number"
                step="any"
                required
                value={maxLat}
                onChange={(e) => setMaxLat(e.target.value)}
                placeholder="Max Lat (VD: 15.25)"
                className={`h-8 w-full rounded-lg border border-border bg-white px-2.5 text-xs text-ink ${focusRing}`}
              />
              <input
                type="number"
                step="any"
                required
                value={minLng}
                onChange={(e) => setMinLng(e.target.value)}
                placeholder="Min Lng (VD: 108.70)"
                className={`h-8 w-full rounded-lg border border-border bg-white px-2.5 text-xs text-ink ${focusRing}`}
              />
              <input
                type="number"
                step="any"
                required
                value={maxLng}
                onChange={(e) => setMaxLng(e.target.value)}
                placeholder="Max Lng (VD: 108.95)"
                className={`h-8 w-full rounded-lg border border-border bg-white px-2.5 text-xs text-ink ${focusRing}`}
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-ink">
                Trạng thái ban đầu
              </label>
              <select
                value={status}
                onChange={(e) =>
                  setStatus(e.target.value as "ACTIVE" | "PLANNED")
                }
                className={`mt-1 h-9 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              >
                <option value="ACTIVE">ACTIVE (Đang phục vụ)</option>
                <option value="PLANNED">PLANNED (Kế hoạch / Thử nghiệm)</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-ink">
                Lý do tạo (Audit log) *
              </label>
              <input
                type="text"
                required
                minLength={3}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="VD: Mở rộng pilot khu vực mới"
                className={`mt-1 h-9 w-full rounded-xl border border-border px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
              />
            </div>
          </div>

          <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="rounded-xl bg-canvas px-4 py-2 text-xs font-semibold text-ink hover:bg-border/60 cursor-pointer"
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="rounded-xl bg-brand px-4 py-2 text-xs font-semibold text-white hover:bg-brand/90 disabled:opacity-50 cursor-pointer"
            >
              {isSubmitting ? "Đang lưu…" : "Tạo khu vực"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function ToggleZoneStatusModal({
  zone,
  onClose,
  onSubmit,
  isSubmitting,
}: {
  zone: ZoneItem;
  onClose: () => void;
  onSubmit: (reason: string) => Promise<void>;
  isSubmitting: boolean;
}) {
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const nextStatus = zone.status === "ACTIVE" ? "PLANNED" : "ACTIVE";
  const actionLabel =
    zone.status === "ACTIVE"
      ? "Tạm dừng khu vực (chuyển sang PLANNED)"
      : "Kích hoạt phục vụ (chuyển sang ACTIVE)";

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!reason.trim()) {
      setError("Vui lòng nhập lý do thay đổi trạng thái.");
      return;
    }
    setError(null);
    try {
      await onSubmit(reason.trim());
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Thao tác thất bại.";
      setError(msg);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="toggle-status-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <div
        className="fixed inset-0 bg-ink/40 backdrop-blur-xs"
        onClick={onClose}
      />
      <div className="relative z-10 w-full max-w-md rounded-2xl border border-border bg-white p-6 shadow-2xl">
        <h3 id="toggle-status-title" className="text-lg font-bold text-ink">
          {actionLabel}
        </h3>
        <p className="mt-1 text-sm text-muted">
          Khu vực:{" "}
          <strong className="text-ink">
            {zone.name} ({zone.code})
          </strong>
          . Trạng thái sau thay đổi:{" "}
          <strong className="text-brand">{nextStatus}</strong>.
        </p>

        {error ? (
          <div className="mt-3 rounded-xl bg-red-500/10 p-3 text-sm text-red-600">
            {error}
          </div>
        ) : null}

        <form onSubmit={(e) => void handleSubmit(e)} className="mt-4 space-y-4">
          <div>
            <label className="block text-xs font-semibold text-ink">
              Lý do thay đổi trạng thái (Audit log) *
            </label>
            <input
              type="text"
              required
              minLength={3}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="VD: Mở rộng phạm vi phục vụ pilot..."
              className={`mt-1 h-9 w-full rounded-xl border border-border px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
            />
          </div>

          <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="rounded-xl bg-canvas px-4 py-2 text-xs font-semibold text-ink hover:bg-border/60 cursor-pointer"
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className={`rounded-xl px-4 py-2 text-xs font-semibold text-white disabled:opacity-50 cursor-pointer ${
                zone.status === "ACTIVE"
                  ? "bg-amber-600 hover:bg-amber-700"
                  : "bg-brand hover:bg-brand/90"
              }`}
            >
              {isSubmitting ? "Đang xử lý…" : "Xác nhận thay đổi"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
