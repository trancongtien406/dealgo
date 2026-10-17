"use client";

import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import { useIsMounted } from "@/lib/use-is-mounted";

const features = [
  {
    title: "Theo dõi realtime",
    detail: "Cập nhật đơn hàng và hoạt động tức thì",
    icon: "chart",
    tone: "bg-brand/10 text-brand",
  },
  {
    title: "Quản lý tập trung",
    detail: "Nhân sự, tài xế, đối tác trên một nền tảng",
    icon: "users",
    tone: "bg-success/10 text-success",
  },
  {
    title: "Bảo mật an toàn",
    detail: "Xác thực đa lớp, bảo vệ dữ liệu doanh nghiệp",
    icon: "shield",
    tone: "bg-delivery/10 text-delivery",
  },
] as const;

export function LoginShowcase() {
  const artReady = useIsMounted();

  return (
    <div className="relative hidden flex-col overflow-hidden bg-brand/5 px-8 py-10 lg:flex xl:px-10">
      <BrandMark />
      <p className="mt-8 max-w-sm text-3xl leading-tight font-bold tracking-tight text-ink">
        Quản lý dễ dàng, vận hành hiệu quả
      </p>
      <p className="mt-3 max-w-sm text-sm leading-6 text-muted">
        Nền tảng quản trị DealGo giúp bạn kiểm soát toàn bộ hoạt động giao hàng,
        đơn hàng, nhân sự và doanh thu chỉ trong một nơi.
      </p>
      <ul className="mt-8 space-y-5">
        {features.map((feature) => (
          <li key={feature.title} className="flex items-start gap-3">
            <span
              className={`grid size-10 shrink-0 place-items-center rounded-xl ${feature.tone}`}
            >
              <OpsIcon name={feature.icon} className="size-5" />
            </span>
            <span>
              <span className="block text-sm font-semibold text-ink">
                {feature.title}
              </span>
              <span className="mt-0.5 block text-sm leading-5 text-muted">
                {feature.detail}
              </span>
            </span>
          </li>
        ))}
      </ul>
      <div className="relative mt-8 min-h-64 flex-1" aria-hidden="true">
        {artReady ? <ShowcaseArt /> : null}
      </div>
    </div>
  );
}

function ShowcaseArt() {
  return (
    <>
      <svg
        viewBox="0 0 520 280"
        className="absolute inset-x-0 bottom-0 h-56 w-full"
      >
        <g className="text-brand/15" fill="currentColor">
          <rect x="18" y="78" width="46" height="110" rx="8" />
          <rect x="74" y="48" width="54" height="140" rx="8" />
          <rect x="138" y="96" width="40" height="92" rx="8" />
          <rect x="360" y="70" width="48" height="118" rx="8" />
          <rect x="418" y="98" width="70" height="90" rx="8" />
        </g>
        <g className="text-success/50" fill="currentColor">
          <circle cx="128" cy="168" r="16" />
          <rect x="124" y="168" width="8" height="22" rx="2" />
          <circle cx="400" cy="164" r="18" />
          <rect x="396" y="164" width="8" height="24" rx="2" />
        </g>
        <rect
          x="16"
          y="196"
          width="488"
          height="28"
          rx="14"
          className="fill-brand/10"
        />
        <rect
          x="150"
          y="86"
          width="150"
          height="120"
          rx="18"
          className="fill-white stroke-border"
          strokeWidth="2"
        />
        <path
          d="M214 168s28-24 28-46a28 28 0 1 0-56 0c0 22 28 46 28 46Z"
          className="fill-brand"
        />
        <circle cx="214" cy="120" r="8" className="fill-white" />
        <g className="text-brand" fill="currentColor">
          <circle cx="92" cy="176" r="16" />
          <circle cx="168" cy="176" r="16" />
          <path d="M78 156h78l14 20H70l8-20Z" />
          <rect x="118" y="132" width="36" height="24" rx="6" />
        </g>
        <circle cx="92" cy="176" r="7" className="fill-ink" />
        <circle cx="168" cy="176" r="7" className="fill-ink" />
        <circle cx="104" cy="128" r="10" className="fill-brand" />
        <path
          d="M96 146c2 10 8 16 18 18"
          className="stroke-brand"
          fill="none"
          strokeWidth="6"
          strokeLinecap="round"
        />
      </svg>
      <div className="absolute top-2 right-0 w-44 rounded-2xl border border-border bg-white p-3 shadow-sm">
        <div className="flex items-center gap-2">
          <span className="grid size-8 place-items-center rounded-lg bg-success/10 text-success">
            <OpsIcon name="package" className="size-4" />
          </span>
          <p className="text-xs font-semibold text-ink">Đơn hàng đang giao</p>
        </div>
        <div className="mt-3 h-1.5 rounded-full bg-canvas">
          <div className="h-full w-2/3 rounded-full bg-success" />
        </div>
      </div>
      <div className="absolute right-2 bottom-6 w-44 rounded-2xl border border-border bg-white p-3 shadow-sm">
        <p className="text-xs font-medium text-muted">Hiệu suất tăng trưởng</p>
        <svg viewBox="0 0 120 36" className="mt-2 h-8 w-full text-success">
          <polyline
            fill="none"
            stroke="currentColor"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
            points="2,28 24,24 42,26 62,16 82,18 118,6"
          />
        </svg>
      </div>
    </>
  );
}
