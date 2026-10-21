import type { ReactNode } from "react";
import { AdminShell } from "@/components/layout/admin-shell";
import { AdminUnavailableNotice } from "@/components/layout/admin-unavailable-notice";
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
  const session = await requireOpsSession();
  if (session && !session.ok && session.unavailable) {
    return (
      <AdminShell>
        <AdminUnavailableNotice message={session.message} />
      </AdminShell>
    );
  }
  return <AdminShell>{children}</AdminShell>;
}
