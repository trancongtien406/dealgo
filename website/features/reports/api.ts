import { fetchOverview } from "@/features/overview/api";
import type { ReportsFilterParams, ReportsSnapshotView } from "./types";

export async function fetchReportsData(
  params?: ReportsFilterParams,
): Promise<ReportsSnapshotView> {
  void params;
  return fetchOverview();
}
