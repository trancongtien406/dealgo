"use client";

import { useMemo, useState } from "react";
import { AdminBreadcrumb, focusRing } from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import { usePatchSiteConfigMutation, useSiteConfigQuery } from "@/features/site-config/hooks";
import { SOCIAL_KEYS, SOCIAL_LABELS, type PublicSiteConfig, type SocialKey } from "@/features/site-config/types";
import { linkError } from "@/features/site-config/validate";
import { isForbiddenError } from "@/lib/api/errors";

type Draft = {
  appStoreUrl: string;
  googlePlayUrl: string;
  socials: Record<SocialKey, string>;
  contactEmail: string;
  hotline: string;
  comingSoonCities: string;
};

function toDraft(c: PublicSiteConfig): Draft {
  return {
    appStoreUrl: c.appStoreUrl ?? "",
    googlePlayUrl: c.googlePlayUrl ?? "",
    socials: Object.fromEntries(SOCIAL_KEYS.map((k) => [k, c.socials?.[k] ?? ""])) as Record<SocialKey, string>,
    contactEmail: c.contactEmail ?? "",
    hotline: c.hotline ?? "",
    comingSoonCities: (c.comingSoonCities ?? []).join(", "),
  };
}

export function draftToConfig(d: Draft): PublicSiteConfig {
  const socials = Object.fromEntries(
    SOCIAL_KEYS.map((k) => [k, d.socials[k].trim()]).filter(([, v]) => v),
  ) as PublicSiteConfig["socials"];
  const cities = d.comingSoonCities.split(",").map((c) => c.trim()).filter(Boolean);
  return {
    ...(d.appStoreUrl.trim() ? { appStoreUrl: d.appStoreUrl.trim() } : {}),
    ...(d.googlePlayUrl.trim() ? { googlePlayUrl: d.googlePlayUrl.trim() } : {}),
    ...(socials && Object.keys(socials).length > 0 ? { socials } : {}),
    ...(d.contactEmail.trim() ? { contactEmail: d.contactEmail.trim() } : {}),
    ...(d.hotline.trim() ? { hotline: d.hotline.trim() } : {}),
    ...(cities.length > 0 ? { comingSoonCities: cities } : {}),
  };
}

const inputCls = `mt-1 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`;

function Field({ label, value, onChange, error, placeholder }: {
  label: string; value: string; onChange: (v: string) => void; error?: string | null; placeholder?: string;
}) {
  return (
    <label className="block text-sm font-medium text-ink">
      {label}
      <input className={inputCls} value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} aria-invalid={Boolean(error)} />
      {error ? <span className="mt-1 block text-xs text-danger">{error}</span> : null}
    </label>
  );
}

export function SiteConfigBoard() {
  const { data, isPending, isError, error, refetch } = useSiteConfigQuery();
  const forbidden = isError && isForbiddenError(error);
  const mutation = usePatchSiteConfigMutation();
  const [draft, setDraft] = useState<Draft | null>(null);
  const [confirming, setConfirming] = useState(false);

  const base = useMemo(() => toDraft(data ?? {}), [data]);
  const d = draft ?? base;
  const errors = {
    appStoreUrl: linkError("appStoreUrl", d.appStoreUrl),
    googlePlayUrl: linkError("googlePlayUrl", d.googlePlayUrl),
    ...Object.fromEntries(SOCIAL_KEYS.map((k) => [k, linkError(k, d.socials[k])])),
  } as Record<string, string | null>;
  const hasErrors = Object.values(errors).some(Boolean);
  const dirty = JSON.stringify(draftToConfig(d)) !== JSON.stringify(draftToConfig(base));
  const set = (next: Partial<Draft>) => setDraft({ ...d, ...next });

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb items={[{ label: "Trang chủ", href: "/overview" }, { label: "Cài đặt & Nhật ký", href: "/settings" }, { label: "Website & MXH" }]} />
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Website: link ứng dụng & mạng xã hội</h1>
        <p className="mt-1 text-sm text-muted">
          Landing page chỉ hiển thị mục đã điền (để trống = ẩn). Link phải dùng https và đúng tên miền của từng nền tảng.
          Mã QR được tạo tự động từ link cửa hàng. Thay đổi được ghi nhật ký kiểm toán và hiện trên website sau khoảng 1 phút.
        </p>
      </div>
      {forbidden ? (
        <AdminForbiddenState title="Không có quyền quản lý website" description="Cần quyền settings.write." />
      ) : isError ? (
        <AdminListErrorBanner message="Không thể tải cấu hình website." onRetry={() => { void refetch(); }} />
      ) : isPending ? (
        <p className="text-sm text-muted">Đang tải…</p>
      ) : (
        <>
          <section className="space-y-4 rounded-2xl border border-border bg-white p-4 shadow-sm">
            <h2 className="text-base font-bold text-ink">Tải ứng dụng</h2>
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="App Store" placeholder="https://apps.apple.com/vn/app/…" value={d.appStoreUrl} error={errors.appStoreUrl} onChange={(v) => set({ appStoreUrl: v })} />
              <Field label="Google Play" placeholder="https://play.google.com/store/apps/details?id=…" value={d.googlePlayUrl} error={errors.googlePlayUrl} onChange={(v) => set({ googlePlayUrl: v })} />
            </div>
          </section>
          <section className="space-y-4 rounded-2xl border border-border bg-white p-4 shadow-sm">
            <h2 className="text-base font-bold text-ink">Mạng xã hội</h2>
            <div className="grid gap-4 md:grid-cols-2">
              {SOCIAL_KEYS.map((k) => (
                <Field key={k} label={SOCIAL_LABELS[k]} placeholder={k === "messenger" ? "https://m.me/…" : "https://…"} value={d.socials[k]} error={errors[k]} onChange={(v) => set({ socials: { ...d.socials, [k]: v } })} />
              ))}
            </div>
          </section>
          <section className="space-y-4 rounded-2xl border border-border bg-white p-4 shadow-sm">
            <h2 className="text-base font-bold text-ink">Liên hệ & khu vực</h2>
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Email liên hệ (tuỳ chọn)" value={d.contactEmail} onChange={(v) => set({ contactEmail: v })} />
              <Field label="Hotline (tuỳ chọn)" value={d.hotline} onChange={(v) => set({ hotline: v })} />
              <Field label="Thành phố sắp mở (phân tách bằng dấu phẩy)" placeholder="Huế, Hội An" value={d.comingSoonCities} onChange={(v) => set({ comingSoonCities: v })} />
            </div>
          </section>
          <div className="flex flex-wrap justify-end gap-3">
            <button type="button" disabled={!dirty} onClick={() => setDraft(null)} className={`rounded-xl border border-border px-4 py-2 text-sm font-semibold text-ink disabled:opacity-50 ${focusRing}`}>
              Hoàn tác
            </button>
            <button type="button" disabled={!dirty || hasErrors} onClick={() => setConfirming(true)} className={`rounded-xl bg-brand px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 ${focusRing}`}>
              Lưu thay đổi
            </button>
          </div>
        </>
      )}
      {confirming ? (
        <OpsInterveneDialog
          open
          labels={{ title: "Lưu cấu hình website", confirm: "Xác nhận lưu", hint: "Lý do được ghi vào nhật ký kiểm toán.", success: "Đã cập nhật cấu hình website." }}
          confirmTone="brand"
          entityLabel="Link ứng dụng & mạng xã hội"
          pending={mutation.isPending}
          onClose={() => setConfirming(false)}
          onConfirm={async (reason) => {
            await mutation.mutateAsync({ config: draftToConfig(d), reason });
            setDraft(null);
          }}
        />
      ) : null}
    </div>
  );
}
