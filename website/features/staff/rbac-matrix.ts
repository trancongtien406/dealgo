/** UI labels for the staff RBAC matrix (not live grants from Nest). */

export const rbacRoles = ["Admin", "CSKH", "Vận hành", "Tài chính"] as const;

export type RbacRole = (typeof rbacRoles)[number];

export const rbacGrants = [
  { permission: "Xem đơn/chuyến", marks: [true, true, true, true] },
  { permission: "Xử lý khiếu nại", marks: [true, true, false, false] },
  { permission: "Duyệt KYC/KYB", marks: [true, false, true, false] },
  { permission: "Duyệt hoàn tiền", marks: [true, false, false, true] },
  { permission: "Xuất dữ liệu tài chính", marks: [true, false, false, true] },
  {
    permission: "Quản lý nhân sự & vai trò",
    marks: [true, false, false, false],
  },
] as const;

export const rbacControls = [
  { label: "Xác thực đa yếu tố (MFA)", value: "Bắt buộc", chip: true },
  { label: "Nguyên tắc quyền", value: "Ít quyền nhất", chip: false },
  { label: "Phê duyệt thay đổi vai trò", value: "2 người", chip: false },
  {
    label: "Nhật ký quản trị",
    value: "Hết hạn khi không còn hoạt động",
    chip: false,
  },
] as const;
