"use client";

import { useState } from "react";
import { StatusChip } from "@/components/ui/admin-list-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import { toast } from "@/components/ui/toast";
import {
  Card,
  primaryButton,
  secondaryButton,
  SecretField,
} from "@/features/integrations/components/integration-ui";
import {
  useMapKeysQuery,
  useSaveMapKeysMutation,
  useTestMapKeysMutation,
} from "@/features/integrations/hooks";
import { MAP_KEY_LABELS, mapKeyTestLabel } from "@/features/integrations/mappers";
import type { MapKeyField, MapKeysView } from "@/features/integrations/types";
import { formatOpsDateTime } from "@/lib/ops-time";

type Edits = Partial<Record<MapKeyField, string | null>>;

function keysPatch(edits: Edits): Edits {
  const out: Edits = {};
  for (const [field, value] of Object.entries(edits) as Array<[MapKeyField, string | null]>) {
    if (value === null) out[field] = null;
    else if (value.trim()) out[field] = value.trim();
  }
  return out;
}

export function MapKeysSection() {
  const { data } = useMapKeysQuery();
  if (!data) return null;
  return <MapKeysForm key={data.updatedAt ?? "env"} view={data} />;
}

function MapKeysForm({ view }: { view: MapKeysView }) {
  const [edits, setEdits] = useState<Edits>({});
  const [action, setAction] = useState<"save" | "test" | null>(null);
  const save = useSaveMapKeysMutation();
  const test = useTestMapKeysMutation();
  const busy = save.isPending || test.isPending;
  const patch = keysPatch(edits);
  const dirty = Object.keys(patch).length > 0;
  const results = new Map((test.data?.results ?? []).map((r) => [r.field, r]));

  return (
    <Card
      title="API key"
      aside={
        view.testedAt ? (
          <span className="text-xs text-muted">Kiểm tra {formatOpsDateTime(view.testedAt)}</span>
        ) : null
      }
    >
      {!view.canStoreSecrets ? (
        <p role="alert" className="mb-3 text-sm text-danger">
          Server chưa có SECRETS_ENCRYPTION_KEY: chỉ dùng key trong env.
        </p>
      ) : null}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
        {view.keys.map((key) => {
          const result = results.get(key.field);
          return (
            <div key={key.field} className="min-w-0">
              <SecretField
                label={MAP_KEY_LABELS[key.field]}
                isSet={key.set}
                source={key.source}
                value={edits[key.field] ?? ""}
                cleared={edits[key.field] === null}
                disabled={!view.canStoreSecrets || busy}
                onChange={(value) => setEdits((e) => ({ ...e, [key.field]: value }))}
                onClear={() => setEdits((e) => ({ ...e, [key.field]: null }))}
              />
              <div className="mt-1 flex min-h-6 flex-wrap items-center gap-2 text-xs text-muted">
                {key.hint ? <span className="font-mono">{key.hint}</span> : <span>Chưa có</span>}
                {result ? (
                  <StatusChip tone={result.ok ? "success" : "danger"}>
                    {mapKeyTestLabel(result.ok, result.detail)}
                  </StatusChip>
                ) : null}
              </div>
            </div>
          );
        })}
      </div>
      <div className="mt-4 flex flex-wrap justify-end gap-2">
        <button type="button" className={secondaryButton} disabled={busy || dirty} onClick={() => setAction("test")}>
          {test.isPending ? "Đang kiểm tra…" : "Kiểm tra key"}
        </button>
        <button type="button" className={primaryButton} disabled={busy || !dirty} onClick={() => setAction("save")}>
          Lưu
        </button>
      </div>

      {action ? (
        <OpsInterveneDialog
          open
          labels={
            action === "save"
              ? { title: "Lưu API key bản đồ", confirm: "Lưu", hint: "Lý do được ghi vào nhật ký kiểm toán.", success: "Đã lưu key." }
              : { title: "Kiểm tra API key", confirm: "Kiểm tra", hint: "Gọi thử Mapbox và Google, ghi kết quả vào nhật ký." }
          }
          confirmTone="brand"
          entityLabel="Bản đồ"
          pending={busy}
          onClose={() => setAction(null)}
          onConfirm={async (reason) => {
            if (action === "save") {
              await save.mutateAsync({ ...patch, reason });
              setEdits({});
            } else {
              const out = await test.mutateAsync(reason);
              const failed = out.results.filter((r) => r.detail !== "unset" && !r.ok);
              if (failed.length) toast.error(`${failed.length} key lỗi`);
              else toast.success("Key hoạt động.");
            }
          }}
        />
      ) : null}
    </Card>
  );
}
