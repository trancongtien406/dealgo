"use client";

export function StaffScopesTab() {
  return (
    <div role="tabpanel" className="p-4 space-y-4">
      <h2 className="text-base font-semibold text-ink">
        Phạm vi địa lý &amp; giới hạn dữ liệu
      </h2>
      <p className="text-sm text-muted">
        Nhân viên chỉ được truy cập vào dữ liệu người dùng, đối tác và chuyến xe
        thuộc phạm vi được phân công.
      </p>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 pt-2">
        <div className="rounded-xl border border-border p-4 bg-canvas/30">
          <p className="font-semibold text-ink">Toàn hệ thống</p>
          <p className="mt-1 text-xs text-muted">
            Toàn bộ 63 tỉnh thành &amp; dữ liệu tổng
          </p>
          <p className="mt-3 text-xs font-medium text-brand">4 tài khoản</p>
        </div>
        <div className="rounded-xl border border-border p-4 bg-canvas/30">
          <p className="font-semibold text-ink">Đà Nẵng</p>
          <p className="mt-1 text-xs text-muted">
            Hải Châu, Sơn Trà, Thanh Khê, Cẩm Lệ
          </p>
          <p className="mt-3 text-xs font-medium text-brand">6 tài khoản</p>
        </div>
        <div className="rounded-xl border border-border p-4 bg-canvas/30">
          <p className="font-semibold text-ink">TP. Hồ Chí Minh</p>
          <p className="mt-1 text-xs text-muted">
            Khu vực trung tâm &amp; các quận lân cận
          </p>
          <p className="mt-3 text-xs font-medium text-brand">2 tài khoản</p>
        </div>
        <div className="rounded-xl border border-border p-4 bg-canvas/30">
          <p className="font-semibold text-ink">Chỉ đọc (Kiểm toán)</p>
          <p className="mt-1 text-xs text-muted">
            Không được chỉnh sửa hoặc duyệt giao dịch
          </p>
          <p className="mt-3 text-xs font-medium text-muted">1 tài khoản</p>
        </div>
      </div>
    </div>
  );
}
