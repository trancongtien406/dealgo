/** Row shape from `GROUP BY status` aggregates. */
export type StatusCountRow = {
  status: string;
  cnt: bigint | number;
};

export function statusCountMap(rows: StatusCountRow[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const row of rows) {
    map.set(row.status, Number(row.cnt));
  }
  return map;
}

export function sumStatusCounts(map: Map<string, number>): number {
  let total = 0;
  for (const value of map.values()) {
    total += value;
  }
  return total;
}

export function statusCount(map: Map<string, number>, status: string): number {
  return map.get(status) ?? 0;
}

export function sumStatuses(
  map: Map<string, number>,
  statuses: readonly string[],
): number {
  let total = 0;
  for (const status of statuses) {
    total += statusCount(map, status);
  }
  return total;
}
