"use client";

import Link from "next/link";
import { AdminBreadcrumb, ListPager, StatusChip, vnd } from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import { SearchSelect, type SearchSelectOption } from "@/components/ui/search-select";
import { useParcelListFilters, useParcelsQuery } from "@/features/parcels/hooks";
import { parcelOutcomeLabel, parcelOutcomeTone } from "@/features/parcels/mappers";
import { PARCEL_OUTCOMES } from "@/features/parcels/types";
import { isForbiddenError } from "@/lib/api/errors";

const COLUMNS = ["Mã", "Tạo lúc", "Tuyến", "Hạng / cân", "Người gửi", "Người nhận", "Giá", "Trạng thái"];

const PARCEL_OUTCOME_OPTIONS: readonly SearchSelectOption[] = PARCEL_OUTCOMES.map((o) => ({
  value: o,
  label: parcelOutcomeLabel[o],
}));

/** DEC-PROD-071: ops list of parcel jobs (rides with serviceKind PARCEL). */
export function ParcelsList() {
  const [filters, setFilters] = useParcelListFilters();
  const query = useParcelsQuery();
  const data = query.data;
  if (query.isError && isForbiddenError(query.error)) return <AdminForbiddenState />;
  const lastPage = data ? Math.ceil(data.total / Math.max(1, data.limit)) : 1;
  return (
    <div className="space-y-4">
      <AdminBreadcrumb items={[{ label: "Chuyến xe Ride", href: "/rides" }, { label: "Giao hàng" }]} />
      <h1 className="text-2xl font-bold">Đơn giao hàng</h1>
      <div className="flex flex-wrap items-center gap-3">
        <input
          aria-label="Tìm đơn hàng"
          className="rounded-md border border-border bg-white px-3 py-2 text-sm text-ink placeholder:text-muted"
          placeholder="Mã, tên hoặc SĐT"
          defaultValue={filters.q}
          onKeyDown={(e) => {
            if (e.key === "Enter") void setFilters({ q: e.currentTarget.value, page: 1 });
          }}
        />
        <div className="min-w-[14rem]">
          <SearchSelect
            label="Lọc trạng thái"
            icon="sliders"
            value={filters.outcome === "ALL" ? null : filters.outcome}
            options={PARCEL_OUTCOME_OPTIONS}
            placeholder="Tất cả trạng thái"
            emptyLabel="Không tìm thấy trạng thái"
            clearLabel="Tất cả trạng thái"
            onChange={(val) => void setFilters({ outcome: (val ?? "ALL") as typeof filters.outcome, page: 1 })}
          />
        </div>
      </div>
      {query.isError ? <AdminListErrorBanner message="Không tải được danh sách đơn hàng." onRetry={() => void query.refetch()} /> : null}
      <AdminTableContainer>
        <AdminTable caption="Đơn giao hàng" ariaBusy={query.isLoading}>
          <AdminTableHeader>
            <AdminTableRow>
              {COLUMNS.map((c) => (
                <AdminTableHead key={c}>{c}</AdminTableHead>
              ))}
            </AdminTableRow>
          </AdminTableHeader>
          {query.isLoading ? (
            <AdminTableBodyShimmer columns={COLUMNS.length} />
          ) : (
            <AdminTableBody>
              {(data?.items ?? []).map((item) => (
                <AdminTableRow key={item.id}>
                  <AdminTableCell>
                    <Link className="font-semibold text-brand" href={`/parcels/${item.id}`}>
                      {item.id.slice(0, 8)}
                    </Link>
                  </AdminTableCell>
                  <AdminTableCell>{new Date(item.createdAt).toLocaleString("vi-VN")}</AdminTableCell>
                  <AdminTableCell wrap>{item.route}</AdminTableCell>
                  <AdminTableCell>
                    {item.sizeClass} · {item.weightLabel} · {item.vehicleClassCode}
                  </AdminTableCell>
                  <AdminTableCell>{item.sender}</AdminTableCell>
                  <AdminTableCell>{item.recipient}</AdminTableCell>
                  <AdminTableCell>{item.fareVnd == null ? "—" : vnd(item.fareVnd)}</AdminTableCell>
                  <AdminTableCell>
                    <StatusChip tone={parcelOutcomeTone[item.outcome]}>{item.outcomeLabel}</StatusChip>
                  </AdminTableCell>
                </AdminTableRow>
              ))}
            </AdminTableBody>
          )}
        </AdminTable>
      </AdminTableContainer>
      {data && data.items.length === 0 ? <AdminEmptyState title="Chưa có đơn giao hàng" description="Đơn giao hàng mới sẽ hiện ở đây." /> : null}
      <ListPager
        summary={`${data?.total ?? 0} đơn`}
        label="Phân trang đơn giao hàng"
        page={filters.page}
        lastPage={lastPage}
        pageSize={filters.limit}
        onPageChange={(page) => void setFilters({ page })}
        onPageSizeChange={(limit) => void setFilters({ limit, page: 1 })}
      />
    </div>
  );
}
