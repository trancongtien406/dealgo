"use client";

import { useId, useState } from "react";
import { countFormat, type StatusTone } from "@/lib/admin-format";

export type OpsTrendSeries = {
  label: string;
  tone: StatusTone;
  values: readonly number[];
  /** Optional override for total count in legend. Defaults to sum of values. */
  total?: number;
};

type OpsServiceTrendChartProps = {
  hours: readonly string[];
  series: readonly OpsTrendSeries[];
  maxY?: number;
  emptyMessage?: string;
};

const chart = {
  width: 760,
  height: 250,
  left: 48,
  top: 14,
  bottom: 32,
  right: 28,
};

const lineTone: Record<StatusTone, string> = {
  brand: "text-brand stroke-brand",
  food: "text-food stroke-food",
  delivery: "text-delivery stroke-delivery",
  success: "text-success stroke-success",
  danger: "text-danger stroke-danger",
};

const dotTone: Record<StatusTone, string> = {
  brand: "bg-brand",
  food: "bg-food",
  delivery: "bg-delivery",
  success: "bg-success",
  danger: "bg-danger",
};

const hexTone: Record<StatusTone, string> = {
  brand: "#8b5cf6",
  food: "#f97316",
  delivery: "#3b82f6",
  success: "#10b981",
  danger: "#ef4444",
};

function niceMax(raw: number): number {
  if (raw <= 0) {
    return 50;
  }
  const padded = raw * 1.15;
  const magnitude = 10 ** Math.floor(Math.log10(padded));
  const normalized = padded / magnitude;
  const step = normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return Math.max(step * magnitude, 10);
}

export function OpsServiceTrendChart({
  hours,
  series,
  maxY,
  emptyMessage = "Chưa có chuỗi xu hướng theo giờ.",
}: OpsServiceTrendChartProps) {
  const chartId = useId();
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);

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

  // Filter X-axis labels to avoid horizontal text overlap (e.g. 24 hours colliding)
  const labelStep = Math.max(1, Math.ceil(hours.length / 7));
  const shouldRenderLabel = (index: number) => {
    if (hours.length <= 8) return true;
    return index % labelStep === 0 || index === hours.length - 1;
  };

  const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const svgRect = e.currentTarget.getBoundingClientRect();
    const mouseX = e.clientX - svgRect.left;
    const svgScale = chart.width / svgRect.width;
    const scaledX = mouseX * svgScale;

    // Check if mouse is within the plot area
    if (scaledX < chart.left - 10 || scaledX > chart.left + plotWidth + 10) {
      setHoverIndex(null);
      return;
    }

    // Find nearest point index
    let closestIndex = 0;
    let minDistance = Number.POSITIVE_INFINITY;
    for (let i = 0; i < pointCount; i++) {
      const pointX = xFor(i, plotWidth, pointCount);
      const dist = Math.abs(scaledX - pointX);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    setHoverIndex(closestIndex);
  };

  const hoveredHour =
    hoverIndex !== null && hoverIndex < hours.length
      ? hours[hoverIndex]
      : null;

  return (
    <div className="min-w-0">
      {/* Legend with color dots and live counts (matches /reports standard) */}
      {series.length > 0 ? (
        <ul className="flex flex-wrap gap-x-5 gap-y-2 text-sm">
          {series.map((item) => {
            const seriesSum =
              item.total ??
              item.values.reduce((sum, v) => sum + (Number.isFinite(v) ? v : 0), 0);
            return (
              <li
                key={item.label}
                className="inline-flex items-center gap-2"
              >
                <span
                  className={`size-2.5 shrink-0 rounded-full ${dotTone[item.tone]}`}
                  aria-hidden="true"
                />
                <span className="text-muted">{item.label}</span>
                <span className="font-semibold text-ink tabular-nums">
                  {countFormat.format(seriesSum)}
                </span>
              </li>
            );
          })}
        </ul>
      ) : null}

      {/* SVG Chart Container */}
      <div className="relative mt-4 min-w-0 overflow-x-auto">
        <svg
          viewBox={`0 0 ${chart.width} ${chart.height}`}
          role="img"
          aria-label="Biểu đồ xu hướng dịch vụ theo giờ"
          className="h-auto min-w-[36rem] w-full select-none"
          onMouseMove={handleMouseMove}
          onMouseLeave={() => setHoverIndex(null)}
        >
          <defs>
            {series.map((item) => {
              const hex = hexTone[item.tone];
              return (
                <linearGradient
                  key={item.label}
                  id={`area-grad-${chartId}-${item.tone}`}
                  x1="0"
                  y1="0"
                  x2="0"
                  y2="1"
                >
                  <stop offset="0%" stopColor={hex} stopOpacity="0.28" />
                  <stop offset="85%" stopColor={hex} stopOpacity="0.03" />
                  <stop offset="100%" stopColor={hex} stopOpacity="0.00" />
                </linearGradient>
              );
            })}
          </defs>

          {/* Grid lines and Y-axis ticks */}
          {ticks.map((tick) => {
            const y = yFor(tick, plotHeight, chartMax);
            return (
              <g key={tick}>
                <line
                  x1={chart.left}
                  x2={chart.width - chart.right}
                  y1={y}
                  y2={y}
                  className="stroke-border/70"
                  strokeWidth="1"
                  strokeDasharray={tick === 0 ? undefined : "3 3"}
                />
                <text
                  x={chart.left - 10}
                  y={y + 4}
                  textAnchor="end"
                  className="fill-muted text-[11px] font-medium tabular-nums"
                >
                  {countFormat.format(tick)}
                </text>
              </g>
            );
          })}

          {/* X-axis tick notches and spaced-out hour labels */}
          {hours.map((hour, index) => {
            const x = xFor(index, plotWidth, pointCount);
            const isLabelVisible = shouldRenderLabel(index);
            return (
              <g key={`${hour}-${index}`}>
                {/* Small tick tick mark */}
                <line
                  x1={x}
                  x2={x}
                  y1={baseline}
                  y2={baseline + 4}
                  className="stroke-border"
                  strokeWidth="1"
                />
                {isLabelVisible ? (
                  <text
                    x={x}
                    y={chart.height - 8}
                    textAnchor="middle"
                    className="fill-muted text-[11px] font-medium tabular-nums"
                  >
                    {hour}
                  </text>
                ) : null}
              </g>
            );
          })}

          {/* Line & Area series */}
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
                  fill={`url(#area-grad-${chartId}-${item.tone})`}
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

          {/* Interactive Hover Vertical Guide and Focus Dots */}
          {hoverIndex !== null && hoverIndex < hours.length ? (
            <g>
              {/* Vertical guideline */}
              <line
                x1={xFor(hoverIndex, plotWidth, pointCount)}
                x2={xFor(hoverIndex, plotWidth, pointCount)}
                y1={chart.top}
                y2={baseline}
                stroke="#64748b"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                className="opacity-70"
              />

              {/* Data point dots on series */}
              {series.map((item) => {
                const val = item.values[hoverIndex] ?? 0;
                const x = xFor(hoverIndex, plotWidth, pointCount);
                const y = yFor(val, plotHeight, chartMax);
                const hex = hexTone[item.tone];

                return (
                  <g key={`dot-${item.label}`}>
                    <circle
                      cx={x}
                      cy={y}
                      r="6"
                      fill={hex}
                      fillOpacity="0.25"
                    />
                    <circle
                      cx={x}
                      cy={y}
                      r="4"
                      fill="#ffffff"
                      stroke={hex}
                      strokeWidth="2.5"
                    />
                  </g>
                );
              })}
            </g>
          ) : null}
        </svg>

        {/* Floating Tooltip Box on Hover */}
        {hoverIndex !== null && hoveredHour ? (
          <div
            className="pointer-events-none absolute z-20 rounded-xl border border-border bg-white/95 px-3 py-2 text-xs shadow-xl backdrop-blur-xs transition-transform"
            style={{
              left: `${Math.min(
                Math.max(
                  (xFor(hoverIndex, plotWidth, pointCount) / chart.width) * 100,
                  14,
                ),
                86,
              )}%`,
              top: "16px",
              transform: "translateX(-50%)",
            }}
          >
            <p className="font-bold text-ink">
              Khung giờ: <span className="font-mono">{hoveredHour}</span>
            </p>
            <div className="mt-1.5 space-y-1">
              {series.map((item) => {
                const val = item.values[hoverIndex] ?? 0;
                return (
                  <div
                    key={`tip-${item.label}`}
                    className="flex items-center justify-between gap-4"
                  >
                    <div className="flex items-center gap-1.5">
                      <span
                        className={`size-2 rounded-full ${dotTone[item.tone]}`}
                      />
                      <span className="text-muted">{item.label}</span>
                    </div>
                    <span className="font-semibold text-ink tabular-nums">
                      {countFormat.format(val)}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function xFor(index: number, plotWidth: number, count: number) {
  return chart.left + (index / Math.max(1, count - 1)) * plotWidth;
}

function yFor(value: number, plotHeight: number, max: number) {
  const safeMax = Math.max(max, 1);
  const clamped = Math.max(0, Math.min(value, safeMax));
  return chart.top + (1 - clamped / safeMax) * plotHeight;
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
