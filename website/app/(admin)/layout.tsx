import type { ReactNode } from "react";
import { AdminShell } from "@/components/layout/admin-shell";
import { requireOpsSession } from "@/lib/ops-session";

/**
 * Authenticated admin chrome. Shell mounts once for the route group so
 * navigations only swap `children` (and `loading.tsx`), not the sidebar.
 */
export default async function AdminLayout({
  children,
}: {
  children: ReactNode;
}) {
  await requireOpsSession();
  return <AdminShell>{children}</AdminShell>;
}
