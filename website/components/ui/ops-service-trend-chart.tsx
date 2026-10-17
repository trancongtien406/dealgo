"use client";

import type { StatusTone } from "@/lib/admin-format";

export type OpsTrendSeries = {
  label: string;
  tone: StatusTone;
  values: readonly number[];
};

type OpsServiceTrendChartProps = {
  hours: readonly string[];
  series: readonly OpsTrendSeries[];
  maxY?: number;
  emptyMessage?: string;
};

const chart = {
  width: 720,
  height: 248,
  left: 44,
  top: 8,
  bottom: 28,
  right: 28,
};

const lineTone: Record<StatusTone, string> = {
  brand: "text-brand",
  food: "text-food",
  delivery: "text-delivery",
  success: "text-success",
  danger: "text-danger",
};

const dotTone: Record<StatusTone, string> = {
  brand: "bg-brand",
  food: "bg-food",
  delivery: "bg-delivery",
  success: "bg-success",
  danger: "bg-danger",
};

function niceMax(raw: number): number {
  if (raw <= 0) {
    return 50;
  }
  const padded = raw * 1.1;
  const magnitude = 10 ** Math.floor(Math.log10(padded));
  const normalized = padded / magnitude;
  const step = normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return step * magnitude;
}

export function OpsServiceTrendChart({
  hours,
  series,
  maxY,
  emptyMessage = "Chưa có chuỗi xu hướng theo giờ.",
}: OpsServiceTrendChartProps) {
  const hasPlot =
    hours.length > 0 && series.some((item) => item.values.length > 0);

  if (!hasPlot) {
    return (
      <div
        role="status"
        className="flex min-h-48 flex-col items-center justify-center rounded-xl border border-dashed border-border bg-canvas/40 px-4 py-8 text-center"
      >
        <p className="text-sm font-medium text-ink">Chưa có dữ liệu biểu đồ</p>
        <p className="mt-1 max-w-sm text-sm text-muted">{emptyMessage}</p>
      </div>
    );
  }

  const peak = Math.max(0, ...series.flatMap((item) => item.values));
  const chartMax = maxY ?? niceMax(peak);
  const plotWidth = chart.width - chart.left - chart.right;
  const plotHeight = chart.height - chart.top - chart.bottom;
  const baseline = chart.top + plotHeight;
  const tickCount = 5;
  const ticks = Array.from({ length: tickCount + 1 }, (_, index) =>
    Math.round((chartMax / tickCount) * index),
  );
  const pointCount = Math.max(hours.length, 2);

  return (
    <div className="min-w-0">
      {series.length > 0 ? (
        <ul className="flex flex-wrap gap-x-4 gap-y-2 text-sm text-muted">
          {series.map((item) => (
            <li key={item.label} className="inline-flex items-center gap-2">
              <span
                className={`size-2.5 shrink-0 rounded-full ${dotTone[item.tone]}`}
                aria-hidden="true"
              />
              {item.label}
            </li>
          ))}
        </ul>
      ) : null}
      <div className="mt-4 min-w-0 overflow-x-auto">
        <svg
          viewBox={`0 0 ${chart.width} ${chart.height}`}
          role="img"
          aria-label="Biểu đồ xu hướng dịch vụ theo giờ"
          className="h-auto w-full"
        >
          {ticks.map((tick) => {
            const y = yFor(tick, plotHeight, chartMax);
            return (
              <g key={tick}>
                <line
                  x1={chart.left}
                  x2={chart.width - chart.right}
                  y1={y}
                  y2={y}
                  className="stroke-border"
                  strokeWidth="1"
                />
                <text
                  x={chart.left - 8}
                  y={y + 4}
                  textAnchor="end"
                  className="fill-muted text-[11px]"
                >
                  {tick}
                </text>
              </g>
            );
          })}
          {hours.map((hour, index) => (
            <text
              key={`${hour}-${index}`}
              x={xFor(index, plotWidth, pointCount)}
              y={chart.height - 6}
              textAnchor="middle"
              className="fill-muted text-[11px]"
            >
              {hour}
            </text>
          ))}
          {series.map((item) => {
            if (item.values.length === 0) {
              return null;
            }
            const points = item.values.map((value, index) => ({
              x: xFor(index, plotWidth, pointCount),
              y: yFor(value, plotHeight, chartMax),
            }));
            return (
              <g key={item.label} className={lineTone[item.tone]}>
                <path
                  d={smoothArea(points, baseline)}
                  fill="currentColor"
                  fillOpacity="0.12"
                  stroke="none"
                />
                <path
                  d={smoothLine(points)}
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.5"
                  strokeLinejoin="round"
                  strokeLinecap="round"
                />
              </g>
            );
          })}
        </svg>
      </div>
    </div>
  );
}

function xFor(index: number, plotWidth: number, count: number) {
  return chart.left + (index / Math.max(1, count - 1)) * plotWidth;
}

function yFor(value: number, plotHeight: number, max: number) {
  return chart.top + (1 - value / max) * plotHeight;
}

function smoothLine(points: readonly { x: number; y: number }[]) {
  const [first, ...rest] = points;
  if (!first) {
    return "";
  }
  const commands = [`M ${round(first.x)} ${round(first.y)}`];
  let previous = first;
  for (const point of rest) {
    const controlX = (previous.x + point.x) / 2;
    commands.push(
      `C ${round(controlX)} ${round(previous.y)}, ${round(controlX)} ${round(point.y)}, ${round(point.x)} ${round(point.y)}`,
    );
    previous = point;
  }
  return commands.join(" ");
}

function smoothArea(
  points: readonly { x: number; y: number }[],
  baseline: number,
) {
  const line = smoothLine(points);
  const first = points[0];
  const last = points[points.length - 1];
  if (!line || !first || !last) {
    return "";
  }
  return `${line} L ${round(last.x)} ${round(baseline)} L ${round(first.x)} ${round(baseline)} Z`;
}

function round(value: number) {
  return value.toFixed(1);
}
