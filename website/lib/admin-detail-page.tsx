import type { ReactNode } from "react";
import { Suspense } from "react";
import { AdminPageSkeleton } from "@/components/ui/admin-state-ui";

export function AdminDetailPage({ children }: { children: ReactNode }) {
  return <Suspense fallback={<AdminPageSkeleton />}>{children}</Suspense>;
}
