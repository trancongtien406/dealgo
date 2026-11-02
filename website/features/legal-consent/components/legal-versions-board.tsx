"use client";

import Link from "next/link";
import { useState } from "react";
import { AdminBreadcrumb, focusRing } from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { toast } from "@/components/ui/toast";
import { emailStep, publishErrors } from "@/features/legal-consent/email-step";
import {
  useLegalVersionsQuery,
  usePreviewLegalEmailMutation,
  usePublishLegalVersionMutation,
  useSendLegalEmailMutation,
} from "@/features/legal-consent/hooks";
import {
  EMAIL_STATUS_LABELS,
  LEGAL_ROLE_LABELS,
  LEGAL_SLUG_LABELS,
  type LegalPolicyVersion,
  type LegalRole,
  type LegalSlug,
} from "@/features/legal-consent/types";
import { isForbiddenError } from "@/lib/api/errors";

const inputCls = `mt-1 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`;
const ROLES: LegalRole[] = ["CUSTOMER", "DRIVER", "MERCHANT"];
const fmt = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" }) : "—");
const errMsg = (e: unknown) => (e instanceof Error ? e.message : "Có lỗi xảy ra.");

function PublishForm() {
  const mutation = usePublishLegalVersionMutation();
  const [slug, setSlug] = useState<LegalSlug>("terms");
  const [changelog, setChangelog] = useState("");
  const [effectiveAt, setEffectiveAt] = useState("");
  const [roles, setRoles] = useState<LegalRole[]>(["CUSTOMER", "DRIVER", "MERCHANT"]);
  const [confirming, setConfirming] = useState(false);
  const error = publishErrors({ changelog, audienceRoles: roles });

  const submit = async () => {
    try {
      const v = await mutation.mutateAsync({
        slug,
        changelog: changelog.trim(),
        audienceRoles: roles,
        ...(effectiveAt ? { effectiveAt: new Date(`${effectiveAt}T00:00:00+07:00`).toISOString() } : {}),
      });
      toast.success(`Đã yêu cầu đồng ý ${v.title} v${v.version}.`);
      setChangelog("");
      setConfirming(false);
    } catch (e) {
      toast.error(errMsg(e));
      setConfirming(false);
    }
  };

  return (
    <section className="space-y-4 rounded-2xl border border-border bg-white p-4 shadow-sm">
      <div>
        <h2 className="text-base font-bold text-ink">Yêu cầu đồng ý phiên bản mới</h2>
        <p className="mt-1 text-xs text-muted">
          Dùng nội dung <b>đã xuất bản</b> trong{" "}
          <Link href="/settings/content" className="font-semibold text-brand underline">Nội dung & Pháp lý</Link>. Hãy xuất bản văn bản ở đó
          trước; trang này chỉ đánh dấu phiên bản hiện hành là bắt buộc đồng ý (ứng dụng sẽ chặn đến khi người dùng bấm “Tôi đồng ý”).
        </p>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block text-sm font-medium text-ink">
          Văn bản
          <select className={inputCls} value={slug} onChange={(e) => setSlug(e.target.value as LegalSlug)}>
            {(Object.keys(LEGAL_SLUG_LABELS) as LegalSlug[]).map((s) => (
              <option key={s} value={s}>{LEGAL_SLUG_LABELS[s]}</option>
            ))}
          </select>
        </label>
        <label className="block text-sm font-medium text-ink">
          Ngày hiệu lực (tuỳ chọn)
          <input type="date" className={inputCls} value={effectiveAt} onChange={(e) => setEffectiveAt(e.target.value)} />
        </label>
      </div>
      <label className="block text-sm font-medium text-ink">
        Tóm tắt thay đổi (hiện trong ứng dụng và email)
        <textarea className={`${inputCls} min-h-20`} maxLength={2000} value={changelog} onChange={(e) => setChangelog(e.target.value)} />
      </label>
      <fieldset className="flex flex-wrap gap-4 text-sm text-ink">
        <legend className="mb-1 font-medium">Áp dụng cho</legend>
        {ROLES.map((r) => (
          <label key={r} className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={roles.includes(r)}
              onChange={(e) => setRoles(e.target.checked ? [...roles, r] : roles.filter((x) => x !== r))}
            />
            {LEGAL_ROLE_LABELS[r]}
          </label>
        ))}
      </fieldset>
      {changelog && error ? <p className="text-xs text-danger">{error}</p> : null}
      <div className="flex flex-wrap justify-end gap-3">
        {confirming ? (
          <>
            <button type="button" onClick={() => setConfirming(false)} className={`rounded-xl border border-border px-4 py-2 text-sm font-semibold text-ink ${focusRing}`}>
              Huỷ
            </button>
            <button type="button" disabled={mutation.isPending} onClick={() => { void submit(); }} className={`rounded-xl bg-danger px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 ${focusRing}`}>
              Xác nhận: bắt buộc đồng ý
            </button>
          </>
        ) : (
          <button type="button" disabled={Boolean(error)} onClick={() => setConfirming(true)} className={`rounded-xl bg-brand px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 ${focusRing}`}>
            Yêu cầu đồng ý
          </button>
        )}
      </div>
    </section>
  );
}

function EmailCell({ v }: { v: LegalPolicyVersion }) {
  const preview = usePreviewLegalEmailMutation();
  const send = useSendLegalEmailMutation();
  const [count, setCount] = useState<number | null>(null);
  const step = emailStep(v, count);
  const btn = `rounded-lg px-3 py-1.5 text-xs font-semibold disabled:opacity-50 ${focusRing}`;

  if (step.kind === "done") {
    return (
      <span className="text-xs text-muted">
        {EMAIL_STATUS_LABELS[v.emailStatus] ?? v.emailStatus} · {step.label}
        {v.emailFailedCount > 0 ? ` · ${v.emailFailedCount} lỗi` : ""}
      </span>
    );
  }
  if (step.kind === "preview") {
    return (
      <button
        type="button"
        disabled={preview.isPending}
        className={`${btn} border border-border text-ink`}
        onClick={async () => {
          try {
            setCount((await preview.mutateAsync(v.id)).recipients);
          } catch (e) {
            toast.error(errMsg(e));
          }
        }}
      >
        Xem trước người nhận
      </button>
    );
  }
  if (step.kind === "empty") return <span className="text-xs text-muted">Không có người nhận (có email).</span>;
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="text-xs text-ink">{step.count.toLocaleString("vi-VN")} người nhận</span>
      <button type="button" className={`${btn} border border-border text-ink`} onClick={() => setCount(null)}>Huỷ</button>
      <button
        type="button"
        disabled={send.isPending}
        className={`${btn} bg-brand text-white`}
        onClick={async () => {
          try {
            await send.mutateAsync({ id: v.id, confirmCount: step.count });
            toast.success("Đã xếp hàng gửi email (gửi theo lô).");
          } catch (e) {
            toast.error(errMsg(e));
            setCount(null);
          }
        }}
      >
        Gửi email
      </button>
    </div>
  );
}

export function LegalVersionsBoard() {
  const { data, isPending, isError, error, refetch } = useLegalVersionsQuery();
  const forbidden = isError && isForbiddenError(error);
  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb items={[{ label: "Trang chủ", href: "/overview" }, { label: "Cài đặt & Nhật ký", href: "/settings" }, { label: "Đồng ý điều khoản" }]} />
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Phiên bản điều khoản & đồng ý</h1>
        <p className="mt-1 text-sm text-muted">
          Khi điều khoản hoặc chính sách thay đổi, người dùng thuộc nhóm áp dụng phải bấm “Tôi đồng ý” trong ứng dụng mới dùng tiếp
          (lưu thời điểm, IP, thiết bị). Email thông báo gửi qua hàng đợi theo lô, chỉ gửi một lần và cần xem trước số người nhận.
        </p>
      </div>
      {forbidden ? (
        <AdminForbiddenState title="Không có quyền quản lý nội dung" description="Cần quyền content.write." />
      ) : isError ? (
        <AdminListErrorBanner message="Không thể tải danh sách phiên bản." onRetry={() => { void refetch(); }} />
      ) : (
        <>
          <PublishForm />
          <section className="overflow-x-auto rounded-2xl border border-border bg-white shadow-sm">
            <table className="min-w-full text-sm">
              <thead className="bg-surface text-left text-xs uppercase text-muted">
                <tr>
                  <th className="px-4 py-3">Văn bản</th>
                  <th className="px-4 py-3">Hiệu lực</th>
                  <th className="px-4 py-3">Áp dụng</th>
                  <th className="px-4 py-3">Đã đồng ý</th>
                  <th className="px-4 py-3">Email</th>
                </tr>
              </thead>
              <tbody>
                {isPending ? (
                  <tr><td className="px-4 py-3 text-muted" colSpan={5}>Đang tải…</td></tr>
                ) : (data ?? []).length === 0 ? (
                  <tr><td className="px-4 py-3 text-muted" colSpan={5}>Chưa có phiên bản nào yêu cầu đồng ý.</td></tr>
                ) : (
                  (data ?? []).map((v) => (
                    <tr key={v.id} className="border-t border-border align-top">
                      <td className="px-4 py-3">
                        <div className="font-semibold text-ink">{v.title} · v{v.version}</div>
                        <div className="mt-1 max-w-md text-xs text-muted">{v.changelog}</div>
                      </td>
                      <td className="px-4 py-3 text-ink">{fmt(v.effectiveAt)}</td>
                      <td className="px-4 py-3 text-ink">{v.audienceRoles.map((r) => LEGAL_ROLE_LABELS[r as LegalRole] ?? r).join(", ")}</td>
                      <td className="px-4 py-3 text-ink">{(v.consentCount ?? 0).toLocaleString("vi-VN")}</td>
                      <td className="px-4 py-3"><EmailCell v={v} /></td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </section>
        </>
      )}
    </div>
  );
}
