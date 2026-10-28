import { sparklinePoints } from "@/features/system-errors/mappers";

const W = 72;
const H = 20;

export function IssueSparkline({ values }: { values: readonly number[] }) {
  const total = values.reduce((sum, v) => sum + v, 0);
  return (
    <svg
      width={W}
      height={H}
      viewBox={`0 0 ${W} ${H}`}
      role="img"
      aria-label={`${total} sự kiện trong kỳ`}
      className="overflow-visible"
    >
      <polyline
        points={sparklinePoints(values, W, H)}
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        strokeLinejoin="round"
        className={total > 0 ? "text-danger" : "text-border"}
      />
    </svg>
  );
}
