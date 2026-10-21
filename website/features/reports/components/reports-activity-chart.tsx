import React from "react";
import { countFormat } from "@/lib/admin-format";
import {
  type Accent,
  barTone,
  lineTone,
  strokeTone,
  type ServiceActivity,
} from "../types";

const CHART_CONFIG = {
  width: 720,
  height: 248,
  left: 40,
  top: 8,
  bottom: 28,
  right: 16,
  max: 240,
} as const;

interface ReportsActivityChartProps {
  services: readonly ServiceActivity[];
  activityTotal: number;
  trendHours: readonly string[];
  trendSeries: readonly {
    label: string;
    tone: string;
    values: readonly number[];
  }[];
  isError: boolean;
  isPending: boolean;
}

export function ReportsActivityChart({
  services,
  activityTotal,
  trendHours,
  trendSeries,
  isError,
  isPending,
}: ReportsActivityChartProps) {
  return (
    <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1.6fr)_minmax(16rem,22rem)]">
      <section className="min-w-0 overflow-hidden rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 className="text-base font-semibold text-ink">
              Xu hướng hoạt động theo khung giờ
            </h2>
            <p className="mt-1 text-sm text-muted">
              {isError
                ? "Không thể tải dữ liệu"
                : isPending
                  ? "Đang đồng bộ snapshot…"
                  : "Số lượng mới phát sinh · snapshot overview"}
            </p>
          </div>
        </div>

        {isError ? (
          <div className="mt-8 flex flex-col items-center justify-center py-10 text-center text-muted">
            <span className="size-3 rounded-full bg-danger mb-2" />
            <p className="font-medium text-danger">
              Không thể tải dữ liệu xu hướng hoạt động
            </p>
            <p className="mt-1 text-xs text-muted">
              Máy chủ phản hồi lỗi hoặc không thể kết nối. Vui lòng thử lại.
            </p>
          </div>
        ) : (
          <>
            <ul className="mt-4 flex flex-wrap gap-x-4 gap-y-2 text-sm">
              {services.map((service) => (
                <li
                  key={service.label}
                  className="inline-flex items-center gap-2"
                >
                  <span
                    className={`size-2.5 rounded-full ${barTone[service.accent]}`}
                    aria-hidden="true"
                  />
                  <span className="text-muted">{service.label}</span>
                  <span className="font-semibold text-ink tabular-nums">
                    {countFormat.format(service.value)}
                  </span>
                </li>
              ))}
            </ul>
            <HourlyTrend
              hours={trendHours}
              series={trendSeries.map((seriesItem) => ({
                label: seriesItem.label,
                accent:
                  seriesItem.tone === "food"
                    ? ("food" as Accent)
                    : seriesItem.tone === "success"
                      ? ("success" as Accent)
                      : seriesItem.tone === "delivery"
                        ? ("delivery" as Accent)
                        : ("brand" as Accent),
                shape: [...seriesItem.values],
              }))}
              multiplier={1}
            />
          </>
        )}
      </section>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5">
        <div className="flex items-center justify-between gap-3">
          <h2 className="text-base font-semibold text-ink">Cơ cấu hoạt động</h2>
          <p className="shrink-0 text-sm font-medium text-brand">Snapshot</p>
        </div>
        <p className="mt-1 text-sm text-muted">
          Tỷ trọng trên {countFormat.format(activityTotal)} hoạt động
        </p>
        {isError ? (
          <div className="mt-8 flex flex-col items-center justify-center py-10 text-center text-muted">
            <p className="font-medium text-danger">
              Dữ liệu phân bổ không khả dụng
            </p>
          </div>
        ) : (
          <div className="mt-4 flex flex-col items-center gap-5 sm:flex-row xl:flex-col">
            <ActivityDonut services={services} total={activityTotal} />
            <ul className="w-full min-w-0 space-y-3 text-sm">
              {services.map((service) => (
                <li key={service.label} className="flex items-center gap-2">
                  <span
                    className={`size-2.5 shrink-0 rounded-full ${barTone[service.accent]}`}
                    aria-hidden="true"
                  />
                  <span className="min-w-0 flex-1 truncate text-muted">
                    {service.label}
                  </span>
                  <span className="shrink-0 font-semibold text-ink tabular-nums">
                    {countFormat.format(service.value)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>
    </div>
  );
}

function ActivityDonut({
  services,
  total,
}: {
  services: readonly ServiceActivity[];
  total: number;
}) {
  const radius = 52;
  const circumference = 2 * Math.PI * radius;
  const arcs = services.reduce<
    { label: string; accent: Accent; length: number; offset: number }[]
  >((segments, service) => {
    const consumed = segments.reduce(
      (sum, segment) => sum + segment.length + 2.5,
      0,
    );
    const portion = total > 0 ? (service.value / total) * circumference : 0;
    return [
      ...segments,
      {
        label: service.label,
        accent: service.accent,
        length: Math.max(portion - 2.5, 0),
        offset: -consumed,
      },
    ];
  }, []);

  return (
    <svg
      viewBox="0 0 160 160"
      role="img"
      aria-label={`Cơ cấu ${countFormat.format(total)} hoạt động`}
      className="size-40 shrink-0"
    >
      <g transform="rotate(-90 80 80)">
        {arcs.map((arc) => (
          <circle
            key={arc.label}
            cx="80"
            cy="80"
            r={radius}
            fill="none"
            strokeWidth="16"
            strokeLinecap="butt"
            strokeDasharray={`${arc.length} ${circumference - arc.length}`}
            strokeDashoffset={arc.offset}
            className={strokeTone[arc.accent]}
          />
        ))}
      </g>
      <text
        x="80"
        y="78"
        textAnchor="middle"
        className="fill-ink text-[20px] font-bold"
      >
        {countFormat.format(total)}
      </text>
      <text
        x="80"
        y="96"
        textAnchor="middle"
        className="fill-muted text-[11px]"
      >
        Hoạt động
      </text>
    </svg>
  );
}

function HourlyTrend({
  hours,
  series,
  multiplier = 1,
}: {
  hours: readonly string[];
  series: readonly { label: string; accent: Accent; shape: number[] }[];
  multiplier?: number;
}) {
  const plotWidth = CHART_CONFIG.width - CHART_CONFIG.left - CHART_CONFIG.right;
  const plotHeight =
    CHART_CONFIG.height - CHART_CONFIG.top - CHART_CONFIG.bottom;
  const baseline = CHART_CONFIG.top + plotHeight;
  const ticks = [0, 60, 120, 180, 240];
  const hourLabels = hours.length > 0 ? hours : ["—"];
  const chartSeries =
    series.length > 0
      ? series
      : [{ label: "Không có dữ liệu", accent: "brand" as Accent, shape: [0] }];

  return (
    <div className="mt-4 min-w-0 overflow-x-auto">
      {hours.length === 0 ? (
        <p className="py-8 text-center text-sm text-muted">
          Chưa có xu hướng theo giờ từ tổng quan vận hành.
        </p>
      ) : null}
      <svg
        viewBox={`0 0 ${CHART_CONFIG.width} ${CHART_CONFIG.height}`}
        role="img"
        aria-label="Biểu đồ hoạt động theo giờ"
        className="h-auto min-w-[36rem] w-full"
      >
        {ticks.map((tick) => {
          const yCoordinate = calculateYCoordinate(tick, plotHeight);
          return (
            <g key={tick}>
              <line
                x1={CHART_CONFIG.left}
                x2={CHART_CONFIG.width - CHART_CONFIG.right}
                y1={yCoordinate}
                y2={yCoordinate}
                className="stroke-border"
                strokeWidth="1"
              />
              <text
                x={CHART_CONFIG.left - 8}
                y={yCoordinate + 4}
                textAnchor="end"
                className="fill-muted text-[11px]"
              >
                {tick}
              </text>
            </g>
          );
        })}
        {hourLabels.map((hour, index) => {
          const x = calculateXCoordinate(index, plotWidth, hourLabels.length);
          const step = Math.max(1, Math.ceil(hourLabels.length / 7));
          const isVisible =
            hourLabels.length <= 8 ||
            index % step === 0 ||
            index === hourLabels.length - 1;
          return (
            <g key={`${hour}-${index}`}>
              <line
                x1={x}
                x2={x}
                y1={baseline}
                y2={baseline + 4}
                className="stroke-border"
                strokeWidth="1"
              />
              {isVisible ? (
                <text
                  x={x}
                  y={CHART_CONFIG.height - 6}
                  textAnchor="middle"
                  className="fill-muted text-[11px] font-medium tabular-nums"
                >
                  {hour}
                </text>
              ) : null}
            </g>
          );
        })}
        {chartSeries.map((seriesItem) => {
          const points = seriesItem.shape.map((value, index) => ({
            x: calculateXCoordinate(index, plotWidth, hourLabels.length),
            y: calculateYCoordinate(
              Math.min(240, Math.round(value * Math.min(multiplier, 1.2))),
              plotHeight,
            ),
          }));
          return (
            <g key={seriesItem.label} className={lineTone[seriesItem.accent]}>
              <path
                d={generateSmoothAreaPath(points, baseline)}
                fill="currentColor"
                fillOpacity="0.12"
                stroke="none"
              />
              <path
                d={generateSmoothLinePath(points)}
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
  );
}

function calculateXCoordinate(
  index: number,
  plotWidth: number,
  count = 2,
): number {
  const denominator = Math.max(count - 1, 1);
  return CHART_CONFIG.left + (index / denominator) * plotWidth;
}

function calculateYCoordinate(value: number, plotHeight: number): number {
  return (
    CHART_CONFIG.top +
    (1 - Math.min(value, CHART_CONFIG.max) / CHART_CONFIG.max) * plotHeight
  );
}

function generateSmoothLinePath(
  points: readonly { x: number; y: number }[],
): string {
  const [firstPoint, ...remainingPoints] = points;
  if (!firstPoint) {
    return "";
  }
  const commands = [
    `M ${formatDecimal(firstPoint.x)} ${formatDecimal(firstPoint.y)}`,
  ];
  let previousPoint = firstPoint;
  for (const currentPoint of remainingPoints) {
    const controlX = (previousPoint.x + currentPoint.x) / 2;
    commands.push(
      `C ${formatDecimal(controlX)} ${formatDecimal(previousPoint.y)}, ${formatDecimal(controlX)} ${formatDecimal(currentPoint.y)}, ${formatDecimal(currentPoint.x)} ${formatDecimal(currentPoint.y)}`,
    );
    previousPoint = currentPoint;
  }
  return commands.join(" ");
}

function generateSmoothAreaPath(
  points: readonly { x: number; y: number }[],
  baseline: number,
): string {
  const linePath = generateSmoothLinePath(points);
  const firstPoint = points[0];
  const lastPoint = points[points.length - 1];
  if (!linePath || !firstPoint || !lastPoint) {
    return "";
  }
  return `${linePath} L ${formatDecimal(lastPoint.x)} ${formatDecimal(baseline)} L ${formatDecimal(firstPoint.x)} ${formatDecimal(baseline)} Z`;
}

function formatDecimal(value: number): string {
  return value.toFixed(1);
}
