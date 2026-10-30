"use client";

import { useState } from "react";

import Link from "next/link";
import { usePlatformSettingsQuery } from "@/features/platform-settings/hooks";
import { featureFlagRows as pickFeatureFlags } from "@/features/platform-settings/mappers";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  focusRing,
  PreviewLink,
  PreviewTabs,
  StatusChip,
  TextKpi,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { isForbiddenError } from "@/lib/api/errors";
import { SETTINGS_TABS, SETTINGS_SECURITY_TOGGLES } from "../constants";
import { ConfigRow, ConfigValue, InteractiveSwitch } from "./settings-widgets";

export function SettingsBoard() {
  const [activeTab, setActiveTab] = useState("Cấu hình chung");
  const [switches, setSwitches] = useState<Record<string, boolean>>({
    "setting-mfa-admin": true,
    "setting-hide-pii": true,
    "setting-dual-approval": true,
  });

  const handleToggleSwitch = (id: string, value: boolean) => {
    setSwitches((prev) => ({ ...prev, [id]: value }));
  };

  const {
    data: platformRows = [],
    isPending: platformPending,
    isError: platformError,
    error: platformErr,
    refetch: refetchPlatform,
  } = usePlatformSettingsQuery();
  const forbidden = platformError && isForbiddenError(platformErr);
  const featureFlagRows = pickFeatureFlags(platformRows);

  return (
    <div className="min-w-0 space-y-5">
      {platformError && !forbidden && platformRows.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể cập nhật cấu hình nền tảng từ máy chủ."
          onRetry={() => void refetchPlatform()}
        />
      ) : null}

      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Cấu hình & nhật ký hệ thống
          </h1>
          <p className="mt-1 text-sm text-muted">
            Theo dõi cấu hình hiện hành, cờ tính năng và lịch sử thay đổi có thể
            kiểm toán.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/settings/platform" tone="neutral">
            Cấu hình nền tảng
          </PreviewLink>
          <PreviewLink href="/settings/content" tone="brand">
            Nội dung & Pháp lý
          </PreviewLink>
          <PreviewLink href="/settings/faqs" tone="ghost">
            Soạn FAQ
          </PreviewLink>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <li>
          <TextKpi
            label="Môi trường vận hành"
            value={
              process.env.NEXT_PUBLIC_APP_ENV?.toUpperCase() || "DEVELOPMENT"
            }
            note="Hệ thống đang hoạt động"
            icon="settings"
            tone="brand"
          />
        </li>
        <li>
          <TextKpi
            label="Cấu hình nền tảng"
            value={platformPending ? "..." : `${platformRows.length} tham số`}
            note="Đồng bộ từ NestJS Backend"
            noteTone="success"
            icon="check"
            tone="success"
          />
        </li>
        <li>
          <TextKpi
            label="Chính sách bảo mật"
            value="Auth Methods"
            note="Xem tại /settings/auth-methods"
            noteTone="food"
            icon="shield"
            tone="food"
          />
        </li>
        <li>
          <TextKpi
            label="Nhật ký kiểm toán"
            value="Audit Logs"
            note="Xem tại /audit-logs"
            icon="receipt"
            tone="delivery"
          />
        </li>
      </ul>

      <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(0,1.4fr)_minmax(16rem,22rem)]">
        <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
          <PreviewTabs
            label="Nhóm cấu hình"
            current={activeTab}
            onChange={setActiveTab}
            tabs={SETTINGS_TABS}
          />

          {activeTab === "Cấu hình chung" && (
            <div role="tabpanel" className="mt-4">
              <h2 className="text-xs font-semibold tracking-wide text-muted">
                CẤU HÌNH NỀN TẢNG
              </h2>
              {forbidden ? (
                <div className="mt-3">
                  <AdminForbiddenState
                    title="Không có quyền xem cấu hình nền tảng"
                    description="Tài khoản quản trị của bạn không có quyền xem danh sách tham số hệ thống."
                  />
                </div>
              ) : platformError && platformRows.length === 0 ? (
                <div className="mt-3">
                  <AdminListErrorBanner
                    message="Không thể đồng bộ cấu hình nền tảng từ máy chủ."
                    onRetry={() => void refetchPlatform()}
                  />
                </div>
              ) : platformPending ? (
                <div className="mt-3 space-y-3 animate-pulse">
                  {Array.from({ length: 4 }).map((_, idx) => (
                    <div
                      key={idx}
                      className="flex justify-between py-2 border-b border-border/50"
                    >
                      <div className="h-4 w-32 rounded bg-canvas" />
                      <div className="h-4 w-24 rounded bg-canvas" />
                    </div>
                  ))}
                </div>
              ) : platformRows.length === 0 ? (
                <div className="mt-3">
                  <AdminEmptyState
                    icon="settings"
                    title="Chưa có cấu hình nền tảng"
                    description="Máy chủ chưa trả về danh sách tham số cấu hình."
                  />
                </div>
              ) : (
                <dl className="mt-2">
                  {platformRows.slice(0, 12).map((row) => (
                    <ConfigRow key={row.key} label={row.label || row.key}>
                      <ConfigValue value={row.value || "—"} />
                    </ConfigRow>
                  ))}
                </dl>
              )}
              <p className="mt-3 text-xs text-muted">
                Chỉnh sửa đầy đủ tại trang Cấu hình nền tảng.
              </p>
            </div>
          )}

          {activeTab === "Bảo mật" && (
            <div role="tabpanel" className="mt-4 space-y-4">
              <div>
                <h2 className="text-xs font-semibold tracking-wide text-muted">
                  TÙY CHỌN HIỂN THỊ OPS CỤC BỘ (TRÌNH DUYỆT)
                </h2>
                <p className="mt-0.5 text-xs text-muted">
                  Áp dụng cho phiên làm việc hiện tại trên trình duyệt. Chính
                  sách bảo mật hệ thống toàn diện được kiểm soát tại phân hệ bên
                  dưới.
                </p>
              </div>
              <div className="mt-1">
                {SETTINGS_SECURITY_TOGGLES.map((toggle) => (
                  <InteractiveSwitch
                    key={toggle.id}
                    id={toggle.id}
                    label={toggle.label}
                    checked={switches[toggle.id] ?? true}
                    onChange={(val) => handleToggleSwitch(toggle.id, val)}
                  />
                ))}
              </div>
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink">
                    Phương thức xác thực (Passkey / SMS / Email)
                  </p>
                  <p className="mt-0.5 text-sm text-muted">
                    Bật/tắt toàn hệ thống kèm nhật ký bảo mật chi tiết.
                  </p>
                </div>
                <Link
                  href="/settings/auth-methods"
                  className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
                >
                  <OpsIcon name="shield" className="size-4" />
                  Quản lý
                </Link>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink">
                    Loại xe và giá tham chiếu
                  </p>
                  <p className="mt-0.5 text-sm text-muted">
                    Xe máy, xe 4 chỗ, xe 7 chỗ: giá mở cửa, theo km, theo phút
                    và khoảng báo giá.
                  </p>
                </div>
                <Link
                  href="/settings/vehicle-classes"
                  className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
                >
                  <OpsIcon name="car" className="size-4" />
                  Quản lý
                </Link>
                <Link
                  href="/settings/zone-tariffs"
                  className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
                >
                  <OpsIcon name="car" className="size-4" />
                  Giá theo khu vực
                </Link>
              </div>
            </div>
          )}

          {activeTab === "Tích hợp" && (
            <div role="tabpanel" className="mt-4 space-y-3">
              <h2 className="text-xs font-semibold tracking-wide text-muted">
                DỊCH VỤ & CỔNG KẾT NỐI
              </h2>
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink">
                    Bản đồ (Mapbox / Google Maps)
                  </p>
                  <p className="mt-0.5 text-sm text-muted">
                    Chọn nhà cung cấp cho tìm địa chỉ, địa chỉ từ vị trí và lộ
                    trình.
                  </p>
                </div>
                <Link
                  href="/settings/maps"
                  className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
                >
                  <OpsIcon name="pin" className="size-4" />
                  Quản lý
                </Link>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink">
                    Email (Gmail SMTP / Amazon SES)
                  </p>
                  <p className="mt-0.5 text-sm text-muted">
                    Gửi mã OTP và thông báo qua email.
                  </p>
                </div>
                <Link
                  href="/settings/email"
                  className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
                >
                  <OpsIcon name="mail" className="size-4" />
                  Quản lý
                </Link>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-ink">
                    Sentry (theo dõi lỗi)
                  </p>
                  <p className="mt-0.5 text-sm text-muted">
                    Token đọc lỗi cho trang Lỗi hệ thống.
                  </p>
                </div>
                <Link
                  href="/settings/sentry"
                  className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
                >
                  <OpsIcon name="alert" className="size-4" />
                  Quản lý
                </Link>
              </div>
            </div>
          )}

          {activeTab === "Feature flags" && (
            <div role="tabpanel" className="mt-4 space-y-3">
              <h2 className="text-xs font-semibold tracking-wide text-muted">
                CÔNG TẮC VẬN HÀNH (TỪ MÁY CHỦ)
              </h2>
              {featureFlagRows.length === 0 ? (
                <p className="text-sm text-muted" data-testid="feature-flags-empty">
                  {platformPending
                    ? "Đang tải công tắc vận hành…"
                    : "Máy chủ chưa trả về công tắc vận hành nào."}
                </p>
              ) : (
                <div className="divide-y divide-border" data-testid="feature-flags-list">
                  {featureFlagRows.map((row) => (
                    <div
                      key={row.key}
                      className="flex items-center justify-between gap-3 py-3"
                    >
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-ink">
                          {row.label || row.key}
                        </p>
                        {row.hint ? (
                          <p className="text-xs text-muted">{row.hint}</p>
                        ) : null}
                      </div>
                      <StatusChip tone={row.value === "true" ? "success" : "food"}>
                        {row.value === "true" ? "Bật" : "Tắt"}
                      </StatusChip>
                    </div>
                  ))}
                </div>
              )}
              <p className="text-xs text-muted">
                Bật/tắt tại{" "}
                <Link href="/settings/platform" className="text-brand underline">
                  Cấu hình nền tảng
                </Link>{" "}
                (có nhật ký kiểm toán).
              </p>
            </div>
          )}

          <div className="mt-6 space-y-3 border-t border-border pt-4">
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
              <div className="min-w-0">
                <p className="text-sm font-semibold text-ink">
                  Tham số vận hành nền tảng (Bán kính định vị, TTL, cấu hình
                  giá)
                </p>
                <p className="mt-0.5 text-sm text-muted">
                  Tùy chỉnh thông số thuật toán điều phối trực tiếp trên giao
                  diện quản trị.
                </p>
              </div>
              <Link
                href="/settings/platform"
                className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
              >
                <OpsIcon name="settings" className="size-4" />
                Cấu hình
              </Link>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
              <div className="min-w-0">
                <p className="text-sm font-semibold text-ink">
                  Trung tâm trợ giúp & Câu hỏi thường gặp (FAQ)
                </p>
                <p className="mt-0.5 text-sm text-muted">
                  Quản lý nội dung hướng dẫn khách hàng, tài xế và đối tác cửa
                  hàng.
                </p>
              </div>
              <Link
                href="/settings/faqs"
                className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
              >
                <OpsIcon name="headset" className="size-4" />
                Soạn FAQ
              </Link>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border bg-canvas/60 p-3">
              <div className="min-w-0">
                <p className="text-sm font-semibold text-ink">
                  Quản lý nội dung & Văn bản pháp lý (CMS)
                </p>
                <p className="mt-0.5 text-sm text-muted">
                  Soạn thảo và xuất bản Điều khoản dịch vụ, Chính sách quyền
                  riêng tư và Kênh hỗ trợ.
                </p>
              </div>
              <Link
                href="/settings/content"
                className={`inline-flex h-10 shrink-0 items-center gap-2 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 cursor-pointer ${focusRing}`}
              >
                <OpsIcon name="categories" className="size-4" />
                Quản lý CMS
              </Link>
            </div>
          </div>
          <p className="mt-4 rounded-2xl bg-brand/5 p-3 text-sm leading-6 text-muted">
            Các thay đổi cấu hình hệ thống sẽ được lưu vết kiểm toán tự động.
            Khóa bí mật và thông tin xác thực cấp cao được mã hóa bảo vệ an
            toàn.
          </p>
        </section>

        <div className="min-w-0 space-y-4">
          <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
            <h2 className="text-base font-semibold text-ink">
              Platform settings
            </h2>
            <p className="mt-1 text-sm text-muted">
              {platformPending
                ? "Đang tải…"
                : `${platformRows.length} khóa cấu hình từ máy chủ`}
            </p>
            <ul className="mt-2 divide-y divide-border">
              {platformRows.slice(0, 5).map((row) => (
                <li
                  key={row.key}
                  className="flex items-center justify-between gap-3 py-3"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-ink">
                      {row.label || row.key}
                    </p>
                    <p className="truncate text-xs text-muted">{row.key}</p>
                  </div>
                  <StatusChip tone={row.source === "db" ? "success" : "brand"}>
                    {row.source}
                  </StatusChip>
                </li>
              ))}
            </ul>
            <div className="mt-3">
              <PreviewLink href="/settings/platform" tone="neutral">
                Mở cấu hình nền tảng
              </PreviewLink>
            </div>
          </section>

          <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
            <h2 className="text-base font-semibold text-ink">
              Thay đổi cần phê duyệt
            </h2>
            <p className="mt-1 text-sm text-muted">
              Chưa có hàng đợi phê duyệt cấu hình riêng. Xem nhật ký kiểm toán
              để theo dõi thay đổi.
            </p>
          </section>
        </div>
      </div>

      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 className="text-base font-semibold text-ink">
              Nhật ký kiểm toán
            </h2>
            <p className="mt-1 text-sm text-muted">
              Lưu vết thay đổi phân quyền, cấu hình và truy cập dữ liệu.
            </p>
          </div>
          <PreviewLink href="/audit-logs" tone="brand">
            Mở nhật ký kiểm toán
            <OpsIcon name="arrowRight" className="size-4" />
          </PreviewLink>
        </div>
      </section>
    </div>
  );
}
