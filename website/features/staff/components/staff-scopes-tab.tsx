"use client";

const countFormat = new Intl.NumberFormat("vi-VN");

/**
 * Geographic scopes (CITY/ZONE) are not modelled yet: every operator is national and access is
 * narrowed by staff role instead (DEC-PROD-043/044). Shows the real head-count, not sample cards.
 */
export function StaffScopesTab({ total }: { total: number }) {
  return (
    <div role="tabpanel" className="p-4 space-y-4">
      <h2 className="text-base font-semibold text-ink">
        Phạm vi địa lý &amp; giới hạn dữ liệu
      </h2>
      <p className="text-sm text-muted">
        Hiện mọi nhân sự vận hành có phạm vi <strong>Toàn quốc</strong>. Giới hạn theo
        thành phố / khu vực chưa được hỗ trợ; quyền thao tác được giới hạn theo vai trò
        (tab &quot;Vai trò &amp; quyền&quot;) và được kiểm tra trên máy chủ.
      </p>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 pt-2">
        <div className="rounded-xl border border-border p-4 bg-canvas/30">
          <p className="font-semibold text-ink">Toàn quốc</p>
          <p className="mt-1 text-xs text-muted">Toàn bộ dữ liệu vận hành</p>
          <p className="mt-3 text-xs font-medium text-brand">
            {countFormat.format(total)} tài khoản
          </p>
        </div>
      </div>
    </div>
  );
}
