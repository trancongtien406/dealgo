"use client";

import { useState } from "react";
import { AdminBreadcrumb, focusRing } from "@/components/ui/admin-list-ui";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminPageSkeleton,
} from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import { SearchSelect, type SearchSelectOption } from "@/components/ui/search-select";
import { toast } from "@/components/ui/toast";
import {
  Card,
  Field,
  inputClass,
  primaryButton,
  secondaryButton,
  SecretField,
  StatusLine,
} from "@/features/integrations/components/integration-ui";
import {
  useEmailSettingsQuery,
  useSaveEmailSettingsMutation,
  useSendTestEmailMutation,
} from "@/features/integrations/hooks";
import {
  EMAIL_PROVIDER_LABELS,
  emailDraftFromView,
  emailPatch,
  emailTestErrorLabel,
  secretIsSet,
} from "@/features/integrations/mappers";
import {
  EMAIL_PROVIDER_CHOICES,
  type EmailConfigField,
  type EmailProviderChoice,
  type EmailDraft,
  type EmailSecretEdits,
  type EmailSecretField,
  type EmailSettingsView,
} from "@/features/integrations/types";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";

const SMTP_SECURE_OPTIONS: readonly SearchSelectOption[] = [
  { value: "false", label: "STARTTLS" },
  { value: "true", label: "SSL (465)" },
];

export function EmailSettingsBoard() {
  const { data, isPending, isError, error, refetch } = useEmailSettingsQuery();
  const forbidden = isError && isForbiddenError(error);

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Email" },
        ]}
      />
      <div className="flex min-w-0 flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Email</h1>
          <p className="mt-1 text-sm text-muted">
            Gửi mã OTP và thông báo. Mặc định Gmail SMTP, có thể chuyển sang Amazon SES.
          </p>
        </div>
        {data ? <StatusLine configured={data.status.configured} verified={data.status.verified} /> : null}
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem cấu hình email"
          description="Cần quyền settings.write."
        />
      ) : isError ? (
        <AdminListErrorBanner
          message="Không thể tải cấu hình email."
          onRetry={() => void refetch()}
        />
      ) : isPending || !data ? (
        <AdminPageSkeleton />
      ) : (
        <EmailForm key={data.updatedAt ?? "env"} view={data} />
      )}
    </div>
  );
}

type PendingAction = { kind: "save"; patch: Record<string, string | null> } | { kind: "test"; to: string };

function EmailForm({ view }: { view: EmailSettingsView }) {
  const [draft, setDraft] = useState<EmailDraft>(() => emailDraftFromView(view));
  const [secrets, setSecrets] = useState<EmailSecretEdits>({});
  const [testTo, setTestTo] = useState("");
  const [pending, setPending] = useState<PendingAction | null>(null);
  const save = useSaveEmailSettingsMutation();
  const test = useSendTestEmailMutation();
  const locked = !view.canStoreSecrets;
  const busy = save.isPending || test.isPending;

  const set = (field: EmailConfigField, value: string) => setDraft((d) => ({ ...d, [field]: value }));
  const setSecret = (field: EmailSecretField, value: string | null) =>
    setSecrets((s) => ({ ...s, [field]: value }));
  const patch = emailPatch(view, draft, secrets);
  const dirty = Object.keys(patch).length > 0;
  const provider = (draft.provider || view.provider) as EmailProviderChoice | "mock";

  const secretProps = (field: EmailSecretField) => ({
    isSet: secretIsSet(view, field),
    source: view.sources[field],
    value: secrets[field] ?? "",
    cleared: secrets[field] === null,
    disabled: locked || busy,
    onChange: (value: string) => setSecret(field, value),
    onClear: () => setSecret(field, null),
  });

  return (
    <>
      {locked ? (
        <p role="alert" className="rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger">
          Server chưa có SECRETS_ENCRYPTION_KEY nên không lưu được mật khẩu/khoá. Đang dùng cấu hình env.
        </p>
      ) : view.secretsUnreadable ? (
        <p role="alert" className="rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger">
          Không giải mã được khoá đã lưu (SECRETS_ENCRYPTION_KEY đã đổi). Nhập lại mật khẩu/khoá.
        </p>
      ) : null}

      <Card title="Nhà cung cấp">
        <div role="radiogroup" aria-label="Nhà cung cấp email" className="inline-flex flex-wrap rounded-xl border border-border bg-canvas p-1">
          {EMAIL_PROVIDER_CHOICES.map((value) => {
            const selected = provider === value;
            return (
              <button
                key={value}
                type="button"
                role="radio"
                aria-checked={selected}
                disabled={busy}
                onClick={() => set("provider", value)}
                className={`h-10 min-w-24 rounded-lg px-4 text-sm font-medium transition-colors cursor-pointer ${
                  selected ? "bg-white text-brand shadow-xs" : "text-ink hover:bg-white/70"
                } ${focusRing}`}
              >
                {EMAIL_PROVIDER_LABELS[value]}
              </button>
            );
          })}
        </div>
        {view.provider === "mock" && !draft.provider ? (
          <p className="mt-2 text-xs text-muted">Đang dùng {EMAIL_PROVIDER_LABELS.mock}: email chỉ ghi log.</p>
        ) : null}

        <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Field label="Tên người gửi" source={view.sources.fromName}>
            <input className={inputClass} value={draft.fromName} disabled={busy} onChange={(e) => set("fromName", e.target.value)} />
          </Field>
          <Field label="Địa chỉ gửi" source={view.sources.fromAddress}>
            <input type="email" className={inputClass} value={draft.fromAddress} disabled={busy} onChange={(e) => set("fromAddress", e.target.value)} />
          </Field>
        </div>
      </Card>

      {provider === "smtp" ? (
        <Card title="Gmail SMTP">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-[1fr_8rem_8rem]">
            <Field label="Máy chủ" source={view.sources.smtpHost}>
              <input className={inputClass} value={draft.smtpHost} disabled={busy} onChange={(e) => set("smtpHost", e.target.value)} />
            </Field>
            <Field label="Cổng" source={view.sources.smtpPort}>
              <input inputMode="numeric" className={inputClass} value={draft.smtpPort} disabled={busy} onChange={(e) => set("smtpPort", e.target.value)} />
            </Field>
            <Field label="TLS" source={view.sources.smtpSecure}>
              <SearchSelect
                label="TLS"
                icon="sliders"
                value={draft.smtpSecure}
                disabled={busy}
                options={SMTP_SECURE_OPTIONS}
                placeholder="Chọn TLS"
                onChange={(val) => {
                  if (val) set("smtpSecure", val);
                }}
              />
            </Field>
          </div>
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label="Tài khoản" source={view.sources.smtpUser}>
              <input type="email" autoComplete="off" className={inputClass} value={draft.smtpUser} disabled={busy} onChange={(e) => set("smtpUser", e.target.value)} />
            </Field>
            <SecretField label="Mật khẩu ứng dụng" {...secretProps("smtpPassword")} />
          </div>
        </Card>
      ) : null}

      {provider === "ses" ? (
        <Card title="Amazon SES">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label="Region" source={view.sources.sesRegion}>
              <input className={inputClass} placeholder="ap-southeast-1" value={draft.sesRegion} disabled={busy} onChange={(e) => set("sesRegion", e.target.value)} />
            </Field>
            <Field label="Configuration set" source={view.sources.sesConfigurationSet}>
              <input className={inputClass} value={draft.sesConfigurationSet} disabled={busy} onChange={(e) => set("sesConfigurationSet", e.target.value)} />
            </Field>
            <SecretField label="Access key ID" {...secretProps("sesAccessKeyId")} />
            <SecretField label="Secret access key" {...secretProps("sesSecretAccessKey")} />
            <Field label="SNS topic ARN" source={view.sources.sesSnsTopicArn}>
              <input className={inputClass} value={draft.sesSnsTopicArn} disabled={busy} onChange={(e) => set("sesSnsTopicArn", e.target.value)} />
            </Field>
            <Field label="Webhook bounce/complaint">
              <input readOnly className={`${inputClass} bg-canvas text-muted`} value={view.webhookPath} />
            </Field>
          </div>
        </Card>
      ) : null}

      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-muted">
          {view.updatedAt ? `Cập nhật ${formatOpsDateTime(view.updatedAt)}` : "Đang dùng cấu hình env"}
          {view.status.testedAt ? ` · gửi thử OK ${formatOpsDateTime(view.status.testedAt)}` : ""}
        </p>
        <div className="flex gap-2">
          <button
            type="button"
            className={secondaryButton}
            disabled={!dirty || busy}
            onClick={() => {
              setDraft(emailDraftFromView(view));
              setSecrets({});
            }}
          >
            Huỷ
          </button>
          <button
            type="button"
            className={primaryButton}
            disabled={!dirty || busy}
            onClick={() => setPending({ kind: "save", patch })}
          >
            Lưu
          </button>
        </div>
      </div>

      <Card title="Gửi email thử">
        <form
          className="flex flex-col gap-2 sm:flex-row"
          onSubmit={(e) => {
            e.preventDefault();
            if (testTo.trim()) setPending({ kind: "test", to: testTo.trim() });
          }}
        >
          <input
            type="email"
            required
            aria-label="Email nhận"
            placeholder="email nhận"
            className={`${inputClass} mt-0 sm:flex-1`}
            value={testTo}
            disabled={busy}
            onChange={(e) => setTestTo(e.target.value)}
          />
          <button
            type="submit"
            className={primaryButton}
            title={dirty ? "Lưu thay đổi trước" : undefined}
            disabled={busy || dirty || !view.status.configured}
          >
            {test.isPending ? "Đang gửi…" : "Gửi thử"}
          </button>
        </form>
        {test.data && !test.data.ok ? (
          <p role="alert" className="mt-2 text-sm text-danger">
            Gửi thất bại: {emailTestErrorLabel(test.data.error)}
          </p>
        ) : null}
      </Card>

      {pending ? (
        <OpsInterveneDialog
          open
          labels={
            pending.kind === "save"
              ? { title: "Lưu cấu hình email", confirm: "Lưu", hint: "Lý do được ghi vào nhật ký kiểm toán.", success: "Đã lưu cấu hình email." }
              : { title: "Gửi email thử", confirm: "Gửi", hint: "Lý do được ghi vào nhật ký kiểm toán." }
          }
          confirmTone="brand"
          entityLabel={pending.kind === "save" ? EMAIL_PROVIDER_LABELS[provider as EmailProviderChoice] : pending.to}
          pending={busy}
          onClose={() => setPending(null)}
          onConfirm={async (reason) => {
            if (pending.kind === "save") {
              await save.mutateAsync({ ...pending.patch, reason });
              setSecrets({});
            } else {
              const result = await test.mutateAsync({ to: pending.to, reason });
              if (result.ok) toast.success("Đã gửi email thử.");
              else toast.error(`Gửi thất bại: ${emailTestErrorLabel(result.error)}`);
            }
          }}
        />
      ) : null}
    </>
  );
}
