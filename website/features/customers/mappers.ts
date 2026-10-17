import { personInitials, type StatusTone } from "@/lib/admin-format";
import type { NestOpsCustomer } from "@/features/customers/nest-types";
import type {
  CustomerListItem,
  CustomerStatus,
} from "@/features/customers/types";
import { formatOpsClock } from "@/lib/ops-time";

const labels: Record<CustomerStatus, string> = {
  ACTIVE: "Đang hoạt động",
  NEEDS_SUPPORT: "Cần hỗ trợ",
  SUSPENDED: "Tạm khóa",
};
const tones: Record<CustomerStatus, StatusTone> = {
  ACTIVE: "success",
  NEEDS_SUPPORT: "food",
  SUSPENDED: "danger",
};
export function customerStatusLabel(status: CustomerStatus) {
  return labels[status];
}
export function customerStatusTone(status: CustomerStatus) {
  return tones[status];
}
export const customerStatusFilterOptions = [
  { value: "ALL" as const, label: "Tất cả trạng thái" },
  { value: "ACTIVE" as const, label: labels.ACTIVE },
  { value: "NEEDS_SUPPORT" as const, label: labels.NEEDS_SUPPORT },
  { value: "SUSPENDED" as const, label: labels.SUSPENDED },
];

export function mapNestCustomerToListItem(
  customer: NestOpsCustomer,
): CustomerListItem {
  const name = customer.displayName.trim() || "Khách hàng";
  return {
    code: customer.id,
    initials: personInitials(name) || "KH",
    name,
    phone: customer.phoneMasked || customer.phone || "—",
    area: "—",
    rides: 0,
    food: 0,
    delivery: 0,
    spend: 0,
    status: customerStatusFromGrants(customer),
    time: formatOpsClock(customer.createdAt),
  };
}

function customerStatusFromGrants(customer: NestOpsCustomer): CustomerStatus {
  const grant = customer.grants.find((row) => row.role === "CUSTOMER");
  if (!grant) {
    return "NEEDS_SUPPORT";
  }
  if (grant.status === "ACTIVE") {
    return "ACTIVE";
  }
  if (grant.status === "SUSPENDED") {
    return "SUSPENDED";
  }
  return "NEEDS_SUPPORT";
}
