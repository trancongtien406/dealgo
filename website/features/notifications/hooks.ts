"use client";

import { useQuery } from "@tanstack/react-query";
import {
  fetchNotifications,
  fetchCmsItems,
  type FetchNotificationsParams,
  type FetchCmsParams,
} from "@/features/notifications/api";

export function useNotificationsQuery(params: FetchNotificationsParams) {
  return useQuery({
    queryKey: [
      "ops",
      "notifications",
      params.page ?? 1,
      params.limit ?? 10,
      params.q ?? "",
      params.tab ?? "Tất cả",
      params.channel ?? "ALL",
      params.audience ?? "ALL",
    ],
    queryFn: () => fetchNotifications(params),
  });
}

export function useCmsItemsQuery(params: FetchCmsParams = {}) {
  const targetKind = params.kind ?? params.tab ?? "Tất cả";
  return useQuery({
    queryKey: ["ops", "notifications", "cms", targetKind, params.q ?? ""],
    queryFn: () => fetchCmsItems(params),
  });
}
