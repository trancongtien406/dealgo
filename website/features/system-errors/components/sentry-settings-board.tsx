"use client";

import Link from "next/link";
import { useState } from "react";
import {
  AdminBreadcrumb,
  StatusChip,
  focusRing,
} from "@/components/ui/admin-list-ui";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminPageSkeleton,
} from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
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
  useSaveSentrySettingsMutation,
  useSentrySettingsQuery,
  useTestSentrySettingsMutation,
} from "@/features/system-errors/hooks";
import type { SentrySettingsView } from "@/features/system-errors/types";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";

export function SentrySettingsBoard() {
  const { data, isPending, isError, error, refetch } = useSentrySettingsQuery();
  const forbidden = isError && isForbiddenError(error);

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Sentry" },
        ]}
      />
      <div className="flex min-w-0 flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Sentry
          </h1>
          <p className="mt-1 text-sm text-muted">
            Token chỉ lưu mã hoá trên máy chủ để đọc lỗi cho trang{" "}
            <Link
              href="/system-errors"
              className={`font-medium text-brand underline ${focusRing}`}
            >
              Lỗi hệ thống
            </Link>
            .
          </p>
        </div>
        {data ? (
          <StatusLine
            configured={data.status.configured}
            verified={data.status.verified}
          />
        ) : null}
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem cấu hình Sentry"
          description="Cần quyền settings.write."
        />
      ) : isError ? (
        <AdminListErrorBanner
          message="Không thể tải cấu hình Sentry."
          onRetry={() => void refetch()}
        />
      ) : isPending || !data ? (
        <AdminPageSkeleton />
      ) : (
        <SentryForm key={data.updatedAt ?? "unset"} view={data} />
      )}
    </div>
  );
}

type Draft = { org: string; region: string; projects: string };

function sentryPatch(
  view: SentrySettingsView,
  draft: Draft,
  token: string | null | undefined,
) {
  const patch: Record<string, string | null> = {};
  if (draft.org.trim() !== view.org) patch.org = draft.org.trim();
  if (draft.region.trim() !== view.region) patch.region = draft.region.trim();
  const projects = draft.projects
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean)
    .join(",");
  if (projects !== view.projects.join(",")) patch.projects = projects;
  if (token === null) patch.authToken = null;
  else if (token?.trim()) patch.authToken = token.trim();
  return patch;
}

function SentryForm({ view }: { view: SentrySettingsView }) {
  const [draft, setDraft] = useState<Draft>({
    org: view.org,
    region: view.region,
    projects: view.projects.join(", "),
  });
  const [token, setToken] = useState<string | null | undefined>(undefined);
  const [action, setAction] = useState<"save" | "test" | null>(null);
  const save = useSaveSentrySettingsMutation();
  const test = useTestSentrySettingsMutation();
  const busy = save.isPending || test.isPending;
  const locked = !view.canStoreSecrets;
  const patch = sentryPatch(view, draft, token);
  const dirty = Object.keys(patch).length > 0;
  const set = (field: keyof Draft, value: string) =>
    setDraft((d) => ({ ...d, [field]: value }));

  return (
    <>
      {locked ? (
        <p
          role="alert"
          className="rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger"
        >
          Server chưa có SECRETS_ENCRYPTION_KEY nên không lưu được token.
        </p>
      ) : view.secretsUnreadable ? (
        <p
          role="alert"
          className="rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger"
        >
          Không giải mã được token đã lưu (SECRETS_ENCRYPTION_KEY đã đổi). Nhập
          lại token.
        </p>
      ) : null}

      <Card
        title="Kết nối"
        aside={
          view.status.testedAt ? (
            <span className="text-xs text-muted">
              Kiểm tra {formatOpsDateTime(view.status.testedAt)}
            </span>
          ) : null
        }
      >
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Field label="Organization slug">
            <input
              className={inputClass}
              value={draft.org}
              placeholder="nguyen-ngoc-tien"
              disabled={busy || locked}
              onChange={(e) => set("org", e.target.value)}
            />
          </Field>
          <Field label="Region URL">
            <input
              className={inputClass}
              value={draft.region}
              placeholder="https://us.sentry.io"
              disabled={busy || locked}
              onChange={(e) => set("region", e.target.value)}
            />
          </Field>
          <Field label="Projects (phân tách bằng dấu phẩy)">
            <input
              className={inputClass}
              value={draft.projects}
              placeholder="flutter, dealgo-backend, dealgo-web"
              disabled={busy || locked}
              onChange={(e) => set("projects", e.target.value)}
            />
          </Field>
          <div className="min-w-0">
            <SecretField
              label="Auth token"
              isSet={view.token.set}
              source={view.token.set ? "admin" : "unset"}
              value={token ?? ""}
              cleared={token === null}
              disabled={busy || locked}
              onChange={(value) => setToken(value)}
              onClear={() => setToken(null)}
            />
            <p className="mt-1 text-xs text-muted">
              {view.token.hint ? (
                <span className="font-mono">{view.token.hint}</span>
              ) : (
                "Chưa có"
              )}
            </p>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-2 text-xs text-muted">
          <span>Quyền token:</span>
          {view.scopes === null ? (
            <span>—</span>
          ) : (
            view.scopes.map((scope) => (
              <StatusChip key={scope} tone="brand">
                {scope}
              </StatusChip>
            ))
          )}
        </div>
        {view.token.set && !view.canWrite ? (
          <p className="mt-2 text-xs text-muted">
            Token chỉ đọc: trang Lỗi hệ thống ẩn các nút Đã xử lý / Bỏ qua. Cần
            event:write để bật.
          </p>
        ) : null}
        {test.data ? (
          <p
            className={`mt-2 text-sm ${test.data.ok ? "text-success" : "text-danger"}`}
          >
            {test.data.detail}
          </p>
        ) : null}

        <div className="mt-4 flex flex-wrap justify-end gap-2">
          <button
            type="button"
            className={secondaryButton}
            disabled={busy || dirty || !view.status.configured}
            onClick={() => setAction("test")}
          >
            {test.isPending ? "Đang kiểm tra…" : "Kiểm tra kết nối"}
          </button>
          <button
            type="button"
            className={primaryButton}
            disabled={busy || !dirty || locked}
            onClick={() => setAction("save")}
          >
            Lưu
          </button>
        </div>
      </Card>

      {action ? (
        <OpsInterveneDialog
          open
          labels={
            action === "save"
              ? {
                  title: "Lưu cấu hình Sentry",
                  confirm: "Lưu",
                  hint: "Lý do được ghi vào nhật ký kiểm toán.",
                  success: "Đã lưu cấu hình.",
                }
              : {
                  title: "Kiểm tra Sentry",
                  confirm: "Kiểm tra",
                  hint: "Gọi thử Sentry API bằng token đã lưu, ghi kết quả vào nhật ký.",
                }
          }
          confirmTone="brand"
          entityLabel="Sentry"
          pending={busy}
          onClose={() => setAction(null)}
          onConfirm={async (reason) => {
            if (action === "save") {
              await save.mutateAsync({ ...patch, reason });
              setToken(undefined);
            } else {
              const out = await test.mutateAsync(reason);
              if (out.ok) toast.success("Kết nối Sentry OK.");
              else toast.error(out.detail);
            }
          }}
        />
      ) : null}
    </>
  );
}
