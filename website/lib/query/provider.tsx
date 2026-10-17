"use client";

import { QueryClientProvider } from "@tanstack/react-query";
import { NuqsAdapter } from "nuqs/adapters/react";
import { useState, type ReactNode } from "react";
import { createQueryClient } from "@/lib/query/client";
import { ThemeProvider } from "@/components/theme/theme-provider";

/**
 * Use the plain React nuqs adapter (history API) instead of `nuqs/adapters/next/app`.
 * Next 16 cacheComponents + `useSearchParams` can suspend forever in dev via
 * NavigationPromisesContext, leaving private pages stuck on "Đang tải nội dung…"
 * and list tables on SSR shimmer with an empty React Query cache.
 */
export function AppProviders({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => createQueryClient());

  return (
    <ThemeProvider>
      <NuqsAdapter>
        <QueryClientProvider client={queryClient}>
          {children}
        </QueryClientProvider>
      </NuqsAdapter>
    </ThemeProvider>
  );
}
