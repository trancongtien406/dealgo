import type { Metadata } from "next";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import { ShareAutoRefresh } from "@/features/ride-share/share-auto-refresh";
import {
  fetchRideShare,
  isRideShareFinished,
  nextRideShareRefreshMs,
  RIDE_SHARE_POLL_MS,
  rideShareStatusLabel,
  rideShareVehicleLabel,
} from "@/features/ride-share/share-view";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Theo dõi chuyến đi | DealGo",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

function formatTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("vi-VN", {
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(date);
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-canvas text-ink">
      <header className="border-b border-border bg-white/90">
        <div className="mx-auto flex h-14 max-w-xl items-center px-4">
          <BrandMark />
        </div>
      </header>
      <main className="mx-auto max-w-xl px-4 py-8">{children}</main>
    </div>
  );
}

function Notice({
  title,
  body,
  children,
}: {
  title: string;
  body: string;
  children?: React.ReactNode;
}) {
  return (
    <Shell>
      {children}
      <div className="rounded-2xl border border-border bg-white p-6 text-center">
        <OpsIcon name="alert" className="mx-auto mb-3 size-8 text-muted" />
        <h1 className="text-lg font-bold">{title}</h1>
        <p className="mt-2 text-sm text-muted">{body}</p>
      </div>
    </Shell>
  );
}

export default async function RideSharePage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const result = await fetchRideShare(token);
  const refreshMs = nextRideShareRefreshMs(result);
  const refresher =
    refreshMs !== null ? <ShareAutoRefresh delayMs={refreshMs} /> : null;
  if (result.kind === "not-found") {
    return (
      <Notice
        title="Không tìm thấy chuyến đi"
        body="Liên kết không đúng hoặc đã bị thay thế. Hãy nhờ người gửi chia sẻ lại."
      />
    );
  }
  if (result.kind === "expired") {
    return (
      <Notice
        title="Liên kết đã hết hạn"
        body="Liên kết theo dõi chỉ dùng được trong thời gian chuyến đi diễn ra."
      />
    );
  }
  if (result.kind === "unavailable") {
    return (
      <Notice
        title="Chưa tải được chuyến đi"
        body="Máy chủ DealGo đang bận. Trang sẽ tự thử lại sau ít giây."
      >
        {refresher}
      </Notice>
    );
  }
  const { view } = result;
  const finished = isRideShareFinished(view.status);
  const vehicle = rideShareVehicleLabel(view.driver?.vehicleType ?? null);
  return (
    <Shell>
      {refresher}
      <p className="text-xs font-medium uppercase tracking-wide text-muted">
        Chuyến đi được chia sẻ với bạn
      </p>
      <h1 className="mt-1 text-2xl font-extrabold" data-testid="share-status">
        {rideShareStatusLabel(view.status)}
      </h1>
      <p className="mt-1 text-xs text-muted" data-testid="share-refresh-note">
        Cập nhật lúc {formatTime(view.updatedAt)} ·{" "}
        {finished
          ? "Chuyến đi đã kết thúc, trang ngừng tự cập nhật"
          : refreshMs !== null
            ? `Tự cập nhật mỗi ${Math.round(RIDE_SHARE_POLL_MS / 1000)} giây`
            : "Liên kết đã hết hạn"}
      </p>

      <section className="mt-6 space-y-3 rounded-2xl border border-border bg-white p-5">
        <div className="flex gap-3">
          <OpsIcon name="pin" className="mt-0.5 size-4 text-success" />
          <div>
            <p className="text-xs text-muted">Điểm đón</p>
            <p className="text-sm font-semibold">{view.pickupLabel}</p>
          </div>
        </div>
        <div className="flex gap-3">
          <OpsIcon name="pin" className="mt-0.5 size-4 text-brand" />
          <div>
            <p className="text-xs text-muted">Điểm đến</p>
            <p className="text-sm font-semibold">{view.dropoffLabel}</p>
          </div>
        </div>
      </section>

      {view.driver ? (
        <section className="mt-4 flex items-center gap-4 rounded-2xl border border-border bg-white p-5">
          <OpsIcon name="motorcycle" className="size-8 text-brand" />
          <div className="flex-1">
            <p className="text-sm font-bold">{view.driver.name}</p>
            <p className="text-xs text-muted">
              {[vehicle, view.driver.vehiclePlate]
                .filter(Boolean)
                .join(" · ") || "Đang cập nhật phương tiện"}
            </p>
          </div>
          {view.driver.ratingAverage !== null ? (
            <span className="inline-flex items-center gap-1 text-sm font-semibold">
              <OpsIcon name="star" className="size-4 text-food" />
              {view.driver.ratingAverage.toFixed(1)}
            </span>
          ) : null}
        </section>
      ) : null}

      <p className="mt-6 text-xs text-muted">
        Liên kết hết hạn lúc {formatTime(view.expiresAt)}. DealGo không hiển thị
        số điện thoại hay vị trí trực tiếp của hành khách trên trang này. Nếu lo
        ngại về an toàn, hãy gọi 113.
      </p>
    </Shell>
  );
}
