import type { ReactNode } from "react";
import { Suspense } from "react";
import { AdminPageSkeleton } from "@/components/ui/admin-state-ui";

/**
 * Optional Suspense boundary for page content only.
 * Auth + AdminShell live in `app/(admin)/layout.tsx` so the chrome stays mounted.
 */
export function AdminPrivatePage({ children }: { children: ReactNode }) {
  return (
    <Suspense fallback={<AdminPageSkeleton kpiCount={5} />}>
      {children}
    </Suspense>
  );
}
