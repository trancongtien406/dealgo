"use client";

import { useState } from "react";
import { toast } from "sonner";
import { rbacControls } from "@/features/staff/rbac-matrix";
import {
  isStaffAdminRole,
  staffRoleLabel,
  staffScopeLabel,
  staffStatusLabel,
  staffStatusTone,
} from "@/features/staff/mappers";
import {
  useSetStaffRoleMutation,
  useSetStaffSuperAdminMutation,
  useStaffMeQuery,
  useStaffQuery,
} from "@/features/staff/hooks";
import type { PersonItem } from "@/features/staff/api";
import { canResetStaffPassword } from "@/lib/api/ops-password-reset-body";
import { canChangeSuperAdmin } from "@/lib/api/ops-reason-body";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { StaffPasswordResetDialog } from "@/features/staff/components/staff-password-reset-dialog";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  countFormat,
  ExportCsvButton,
  focusRing,
  ListPager,
  PreviewTabs,
  StatusChip,
  TextKpi,
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
import {
  staffRoleOptions,
  staffScopeOptions,
  staffStatusOptions,
} from "@/lib/admin-filter-options";
import { isForbiddenError } from "@/lib/api/errors";
import { StaffPendingGrants } from "@/features/staff/components/staff-pending-grants";
import { StaffRbacTab } from "@/features/staff/components/staff-rbac-tab";
import { StaffScopesTab } from "@/features/staff/components/staff-scopes-tab";
import { StaffAuditTab } from "@/features/staff/components/staff-audit-tab";
import { SelectMark } from "@/features/staff/components/staff-select-mark";

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
  STAFF_COLUMN_COUNT,
  STAFF_MODULE_TABS,
  STAFF_TABLE_COLUMNS,
} from "@/features/staff/constants";

export function StaffBoard() {
  const [activeTab, setActiveTab] = useState("Danh sách nhân sự");
  const [query, setQuery] = useState("");
  const [role, setRole] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [scope, setScope] = useState<string | null>(null);
  const [selectedEmails, setSelectedEmails] = useState<Set<string>>(
    new Set(["minh@dealgo.vn"]),
  );
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);

  const { data, isPending, isError, error, refetch } = useStaffQuery({
    page,
    limit: pageSize,
    q: query,
    role,
    status,
    scope,
  });
  const forbidden = isError && isForbiddenError(error);
  const { data: me } = useStaffMeQuery();
  const [resetTarget, setResetTarget] = useState<PersonItem | null>(null);
  const [superAdminTarget, setSuperAdminTarget] = useState<PersonItem | null>(null);
  const [roleTarget, setRoleTarget] = useState<PersonItem | null>(null);
  const [pendingRole, setPendingRole] = useState<string>("SUPPORT");
  const superAdminMutation = useSetStaffSuperAdminMutation();
  const roleMutation = useSetStaffRoleMutation();

  const pagedPeople = (data?.items ?? []).filter((p) => !p.superAdmin);
  const total = data?.total ?? pagedPeople.length;
  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const allPageSelected =
    pagedPeople.length > 0 &&
    pagedPeople.every((p) => selectedEmails.has(p.email));

  const toggleSelectAll = () => {
    const next = new Set(selectedEmails);
    if (allPageSelected) {
      pagedPeople.forEach((p) => next.delete(p.email));
    } else {
      pagedPeople.forEach((p) => next.add(p.email));
    }
    setSelectedEmails(next);
  };

  const toggleSelectPerson = (email: string) => {
    const next = new Set(selectedEmails);
    if (next.has(email)) {
      next.delete(email);
    } else {
      next.add(email);
    }
    setSelectedEmails(next);
  };

  const handleResetFilters = () => {
    setQuery("");
    setRole(null);
    setStatus(null);
    setScope(null);
    setPage(1);
  };

  const counts = data?.counts;
  const activeCount =
    counts?.active ??
    (status === "ACTIVE" || status === null
      ? status === "ACTIVE"
        ? total
        : pagedPeople.filter((p) => p.status === "ACTIVE").length
      : 0);
  const invitedCount =
    counts?.pending ??
    (status === "INVITED"
      ? total
      : pagedPeople.filter((p) => p.status === "INVITED").length);
  const suspendedCount =
    counts?.suspended ??
    (status === "SUSPENDED"
      ? total
      : pagedPeople.filter((p) => p.status === "SUSPENDED").length);
  const adminCount = pagedPeople.filter((p) => isStaffAdminRole(p.role)).length;
  const statusKpiNote = counts
    ? "theo bộ lọc hiện tại"
    : "ước tính từ trang / bộ lọc trạng thái";

  return (
    <div className="min-w-0 space-y-5">
      {isError && !forbidden && pagedPeople.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách tài khoản nhân sự từ máy chủ."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Nhân sự" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Nhân sự &amp; phân quyền
          </h1>
          <p className="mt-1 text-sm text-muted">
            Quản lý tài khoản nội bộ, vai trò và quyền truy cập theo nguyên tắc
            tối thiểu.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <ExportCsvButton
            filename="staff.csv"
            headers={[
              "Họ tên",
              "Email",
              "Vai trò",
              "Phạm vi",
              "Trạng thái",
              "Đăng nhập gần nhất",
            ]}
            rows={pagedPeople.map((p) => [
              p.name,
              p.email,
              staffRoleLabel(p.role),
              staffScopeLabel(p.scope),
              p.status,
              p.seen,
            ])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất danh sách
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <li>
          <TextKpi
            label="Nhân sự nội bộ"
            value={String(total)}
            note={`${countFormat.format(activeCount)} đang hoạt động · ${statusKpiNote}`}
            icon="staff"
            tone="brand"
          />
        </li>
        <li>
          <TextKpi
            label="Quản trị viên"
            value={String(adminCount)}
            note="trên trang hiện tại"
            icon="shield"
            tone="delivery"
          />
        </li>
        <li>
          <TextKpi
            label="Lời mời đang chờ"
            value={String(invitedCount)}
            note={statusKpiNote}
            noteTone="food"
            icon="receipt"
            tone="food"
          />
        </li>
        <li>
          <TextKpi
            label="Tài khoản bị khóa"
            value={String(suspendedCount)}
            note={statusKpiNote}
            noteTone="danger"
            icon="lock"
            tone="danger"
          />
        </li>
      </ul>

      <StaffPendingGrants />

      <section className="min-w-0 overflow-hidden rounded-2xl border border-border bg-white shadow-sm">
        <div className="px-4 pt-4">
          <PreviewTabs
            label="Phân hệ nhân sự"
            current={activeTab}
            onChange={setActiveTab}
            tabs={STAFF_MODULE_TABS as unknown as string[]}
          />
        </div>

        {activeTab === "Danh sách nhân sự" && (
          <div role="tabpanel">
            <div className="px-4 py-3">
              <AdminFilterToolbar>
                <AdminFilterField className="min-w-[14rem] flex-1">
                  <div className="relative min-w-0">
                    <label htmlFor="staff-query" className="sr-only">
                      Tìm nhân sự
                    </label>
                    <OpsIcon
                      name="search"
                      className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
                    />
                    <input
                      id="staff-query"
                      type="search"
                      autoComplete="off"
                      value={query}
                      onChange={(e) => {
                        setQuery(e.target.value);
                        setPage(1);
                      }}
                      placeholder="Tìm theo tên, email, vai trò..."
                      className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
                    />
                  </div>
                </AdminFilterField>
                <AdminFilterField className="w-44">
                  <SearchSelect
                    label="Vai trò"
                    value={role}
                    options={staffRoleOptions.filter((o) => o.value !== "ALL")}
                    placeholder="Tất cả"
                    onChange={(val) => {
                      setRole(val);
                      setPage(1);
                    }}
                  />
                </AdminFilterField>
                <AdminFilterField className="w-44">
                  <SearchSelect
                    label="Trạng thái"
                    value={status}
                    options={staffStatusOptions.filter(
                      (o) => o.value !== "ALL",
                    )}
                    placeholder="Tất cả"
                    onChange={(val) => {
                      setStatus(val);
                      setPage(1);
                    }}
                  />
                </AdminFilterField>
                <AdminFilterField className="w-44">
                  <SearchSelect
                    label="Phạm vi"
                    value={scope}
                    options={staffScopeOptions.filter((o) => o.value !== "ALL")}
                    placeholder="Tất cả"
                    onChange={(val) => {
                      setScope(val);
                      setPage(1);
                    }}
                  />
                </AdminFilterField>
                <div className="flex shrink-0 items-end">
                  <AdminResetFilterButton onClick={handleResetFilters} />
                </div>
              </AdminFilterToolbar>
            </div>

            {forbidden ? (
              <div className="p-4">
                <AdminForbiddenState
                  title="Không có quyền quản lý nhân sự"
                  description="Tài khoản Ops hiện tại không được phân quyền xem hoặc quản lý danh sách tài khoản nhân sự."
                />
              </div>
            ) : isError && pagedPeople.length === 0 ? (
              <div className="p-4">
                <AdminListErrorBanner
                  message="Không thể tải danh sách tài khoản nhân sự từ máy chủ."
                  onRetry={() => void refetch()}
                />
              </div>
            ) : !isPending && pagedPeople.length === 0 ? (
              <div className="p-4">
                <AdminEmptyState
                  icon="staff"
                  title="Không tìm thấy nhân sự"
                  description="Không tìm thấy tài khoản nhân sự phù hợp với bộ lọc."
                  action={
                    <AdminResetFilterButton onClick={handleResetFilters} />
                  }
                />
              </div>
            ) : (
              <>
                <AdminTableContainer minWidth="min-w-[760px]">
                  <AdminTable
                    caption="Danh sách tài khoản nhân sự DealGo"
                    ariaBusy={isPending}
                  >
                    <AdminTableHeader>
                      <AdminTableRow>
                        <AdminTableHead className="w-10">
                          <SelectMark
                            checked={allPageSelected}
                            label="Chọn tất cả nhân sự trên trang"
                            onChange={toggleSelectAll}
                          />
                        </AdminTableHead>
                        {STAFF_TABLE_COLUMNS.filter(
                          (col) => col.id !== "select",
                        ).map((col) => (
                          <AdminTableHead key={col.id}>
                            {col.label}
                          </AdminTableHead>
                        ))}
                      </AdminTableRow>
                    </AdminTableHeader>
                    <AdminTableBody>
                      {isPending ? (
                        <AdminTableBodyShimmer
                          columns={STAFF_COLUMN_COUNT}
                          rows={5}
                        />
                      ) : (
                        pagedPeople.map((person, index) => {
                          const isSelected = selectedEmails.has(person.email);
                          return (
                            <AdminTableRow
                              key={person.email}
                              className={isSelected ? "bg-brand/5" : undefined}
                            >
                              <AdminTableCell>
                                <SelectMark
                                  checked={isSelected}
                                  label={`Chọn ${person.name}`}
                                  onChange={() =>
                                    toggleSelectPerson(person.email)
                                  }
                                />
                              </AdminTableCell>
                              <AdminTableCell>
                                <div className="flex min-w-0 items-center gap-2">
                                  <Avatar
                                    letters={person.letters}
                                    tone={avatarTone(index)}
                                  />
                                  <div className="min-w-0">
                                    <p className="truncate font-medium text-ink">
                                      {person.name}
                                    </p>
                                    <p className="truncate text-xs text-muted">
                                      {person.email}
                                    </p>
                                    {person.superAdmin ? (
                                      <span
                                        data-testid="staff-super-admin-badge"
                                        className="mt-0.5 inline-flex rounded-full bg-brand/10 px-2 py-0.5 text-[11px] font-semibold text-brand"
                                      >
                                        Super-admin
                                      </span>
                                    ) : null}
                                  </div>
                                </div>
                              </AdminTableCell>
                              <AdminTableCell>
                                {staffRoleLabel(person.role)}
                              </AdminTableCell>
                              <AdminTableCell>
                                {staffScopeLabel(person.scope)}
                              </AdminTableCell>
                              <AdminTableCell>
                                <StatusChip
                                  tone={staffStatusTone(person.status)}
                                >
                                  {staffStatusLabel(person.status)}
                                </StatusChip>
                              </AdminTableCell>
                              <AdminTableCell>{person.seen}</AdminTableCell>
                              <AdminTableCell>
                                {me?.superAdmin ? (
                                  <button
                                    type="button"
                                    data-testid="staff-assign-role"
                                    onClick={() => setRoleTarget(person)}
                                    className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-semibold text-brand hover:bg-brand/10 cursor-pointer"
                                  >
                                    Phân quyền
                                  </button>
                                ) : null}
                                {canResetStaffPassword(me, person) ? (
                                  <button
                                    type="button"
                                    data-testid="staff-reset-password"
                                    onClick={() => setResetTarget(person)}
                                    className="ml-1 inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-semibold text-danger hover:bg-danger/10 cursor-pointer"
                                  >
                                    Đặt lại mật khẩu
                                  </button>
                                ) : null}
                                {canChangeSuperAdmin(me, person) ? (
                                  <button
                                    type="button"
                                    data-testid="staff-super-admin-toggle"
                                    onClick={() => setSuperAdminTarget(person)}
                                    className="ml-1 inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-semibold text-ink hover:bg-canvas cursor-pointer"
                                  >
                                    Cấp super-admin
                                  </button>
                                ) : null}
                              </AdminTableCell>
                            </AdminTableRow>
                          );
                        })
                      )}
                    </AdminTableBody>
                  </AdminTable>
                </AdminTableContainer>

                <ListPager
                  summary={`Hiển thị ${pagedPeople.length} / ${countFormat.format(total)} nhân sự`}
                  label="Phân trang nhân sự"
                  page={currentPage}
                  onPageChange={setPage}
                  lastPage={lastPage}
                  pageSize={pageSize}
                  onPageSizeChange={(newSize) => {
                    setPageSize(newSize);
                    setPage(1);
                  }}
                />
              </>
            )}
          </div>
        )}

        {activeTab === "Vai trò & quyền" && <StaffRbacTab />}
        {activeTab === "Phạm vi truy cập" && <StaffScopesTab total={total} />}
        {activeTab === "Lịch sử thay đổi" && <StaffAuditTab />}
      </section>

      <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1.4fr)_minmax(16rem,22rem)]">
        <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
          <h2 className="text-base font-semibold text-ink">
            Kiểm soát bảo mật nội bộ
          </h2>
          <p className="mt-1 text-sm text-muted">
            Các tiêu chuẩn an toàn thông tin áp dụng cho nhân sự DealGo
          </p>
          <dl className="mt-2">
            {rbacControls.map((control) => (
              <div
                key={control.label}
                className="flex items-start justify-between gap-3 border-b border-border py-3 text-sm last:border-b-0"
              >
                <dt className="min-w-0 text-ink">{control.label}</dt>
                <dd className="max-w-[12rem] shrink-0 text-right">
                  {control.chip ? (
                    <StatusChip tone="success">{control.value}</StatusChip>
                  ) : (
                    <span className="font-medium text-ink">
                      {control.value}
                    </span>
                  )}
                </dd>
              </div>
            ))}
          </dl>
          <p className="mt-3 rounded-2xl bg-brand/5 p-3 text-sm leading-5 text-muted">
            Mọi hành động thay đổi quyền, xuất dữ liệu và duyệt chi trả đều được
            lưu vết kiểm toán tự động trên máy chủ.
          </p>
        </section>

        <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
          <h2 className="text-base font-semibold text-ink">
            Quy trình cấp quyền mới
          </h2>
          <p className="mt-1 text-sm text-muted">Yêu cầu xác nhận 2 bước</p>
          <div className="mt-4 space-y-3 text-sm text-muted">
            <p>1. Trưởng bộ phận gửi đề xuất cấp quyền qua hệ thống nội bộ.</p>
            <p>
              2. Quản trị viên hệ thống phê duyệt kèm chữ ký số hoặc mã OTP.
            </p>
            <p>
              3. Người dùng nhận email kích hoạt có hiệu lực trong vòng 7 ngày.
            </p>
          </div>
        </section>
      </div>
      <StaffPasswordResetDialog
        person={resetTarget}
        onClose={() => setResetTarget(null)}
      />
      <ReasonDialog
        open={roleTarget !== null}
        title={roleTarget ? `Gán vai trò ops — ${roleTarget.name}` : "Gán vai trò ops"}
        description={`Chọn role rồi nhập lý do. Hiện tại: ${roleTarget?.role ?? "—"}. Super-admin bypass mọi permission.`}
        confirmLabel="Gán vai trò"
        tone="brand"
        testId="staff-role-dialog"
        onClose={() => setRoleTarget(null)}
        onSubmit={async (reason) => {
          if (!roleTarget) return;
          const staffRole =
            typeof window !== "undefined"
              ? window.prompt(
                  "Nhập role: ADMIN | SUPPORT | OPERATIONS | FINANCE",
                  pendingRole,
                )
              : pendingRole;
          if (
            !staffRole ||
            !["ADMIN", "SUPPORT", "OPERATIONS", "FINANCE"].includes(staffRole)
          ) {
            throw new Error("Role không hợp lệ");
          }
          setPendingRole(staffRole);
          await roleMutation.mutateAsync({
            id: roleTarget.id,
            staffRole,
            reason,
          });
          toast.success(`Đã gán ${staffRole} cho ${roleTarget.name}.`);
        }}
      />
      <ReasonDialog
        open={superAdminTarget !== null}
        title="Cấp quyền super-admin"
        description={`${superAdminTarget?.name ?? ""} sẽ được đặt lại mật khẩu nhân sự khác và cấp quyền quản trị cao nhất.`}
        confirmLabel="Cấp quyền"
        tone="brand"
        testId="staff-super-admin-dialog"
        onClose={() => setSuperAdminTarget(null)}
        onSubmit={async (reason) => {
          if (!superAdminTarget) return;
          await superAdminMutation.mutateAsync({
            id: superAdminTarget.id,
            superAdmin: true,
            reason,
          });
          toast.success(`Đã cấp super-admin cho ${superAdminTarget.name}.`);
        }}
      />
    </div>
  );
}
