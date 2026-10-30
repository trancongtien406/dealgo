"use client";

import { useState } from "react";
import { toast } from "sonner";
import { AdminBreadcrumb } from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import {
  useDeleteZoneTariffMutation,
  usePutZoneTariffMutation,
  useZoneTariffsQuery,
} from "@/features/ride-zone-tariffs/hooks";
import { validateZoneTariff, type ZoneTariffMatrix } from "@/features/ride-zone-tariffs/types";
import { isForbiddenError } from "@/lib/api/errors";

function vnd(value: number): string {
  return `${new Intl.NumberFormat("vi-VN").format(value)}đ`;
}

type Draft = { perKmVnd: string; minFareVnd: string; reason: string };

function ZoneRow({
  region,
  vehicle,
  override,
}: {
  region: ZoneTariffMatrix["regions"][number];
  vehicle: ZoneTariffMatrix["classes"][number];
  override: ZoneTariffMatrix["overrides"][number] | undefined;
}) {
  const put = usePutZoneTariffMutation();
  const remove = useDeleteZoneTariffMutation();
  const [draft, setDraft] = useState<Draft>({
    perKmVnd: String(override?.perKmVnd ?? vehicle.defaultPerKmVnd),
    minFareVnd: String(override?.minFareVnd ?? vehicle.defaultMinFareVnd),
    reason: "",
  });
  const busy = put.isPending || remove.isPending;

  const save = () => {
    const input = { perKmVnd: Number(draft.perKmVnd), minFareVnd: Number(draft.minFareVnd) };
    const error = validateZoneTariff(input, vehicle.maxFareVnd);
    if (error) {
      toast.error(error);
      return;
    }
    put.mutate(
      { regionCode: region.code, vehicleClassCode: vehicle.code, ...input, reason: draft.reason || undefined },
      {
        onSuccess: () => toast.success(`Đã lưu giá ${vehicle.name} – ${region.name}`),
        onError: (e) => toast.error(e instanceof Error ? e.message : "Không lưu được"),
      },
    );
  };

  return (
    <tr className="border-t border-border align-top">
      <td className="py-2 pr-3 text-sm">{vehicle.name}</td>
      <td className="py-2 pr-3 text-xs text-muted">
        {vnd(vehicle.defaultPerKmVnd)}/km · tối thiểu {vnd(vehicle.defaultMinFareVnd)}
      </td>
      <td className="py-2 pr-3">
        <input
          aria-label={`Giá/km ${vehicle.name} ${region.name}`}
          inputMode="numeric"
          className="h-9 w-28 rounded-xl border border-border bg-white px-2 text-sm"
          value={draft.perKmVnd}
          onChange={(e) => setDraft({ ...draft, perKmVnd: e.target.value })}
        />
      </td>
      <td className="py-2 pr-3">
        <input
          aria-label={`Giá tối thiểu ${vehicle.name} ${region.name}`}
          inputMode="numeric"
          className="h-9 w-28 rounded-xl border border-border bg-white px-2 text-sm"
          value={draft.minFareVnd}
          onChange={(e) => setDraft({ ...draft, minFareVnd: e.target.value })}
        />
      </td>
      <td className="py-2 pr-3">
        <input
          aria-label={`Lý do ${vehicle.name} ${region.name}`}
          placeholder="Lý do (ghi vào nhật ký)"
          className="h-9 w-48 rounded-xl border border-border bg-white px-2 text-sm"
          value={draft.reason}
          onChange={(e) => setDraft({ ...draft, reason: e.target.value })}
        />
      </td>
      <td className="py-2 pr-3 text-xs text-muted">
        {override ? `Riêng khu vực · v${override.version}` : "Dùng mặc định"}
      </td>
      <td className="flex gap-2 py-2">
        <button
          type="button"
          disabled={busy}
          onClick={save}
          className="inline-flex h-9 items-center rounded-xl bg-brand px-3 text-sm font-medium text-white disabled:opacity-60"
        >
          Lưu
        </button>
        {override ? (
          <button
            type="button"
            disabled={busy}
            onClick={() =>
              remove.mutate(
                { regionCode: region.code, vehicleClassCode: vehicle.code },
                {
                  onSuccess: () => toast.success("Đã về giá mặc định"),
                  onError: (e) => toast.error(e instanceof Error ? e.message : "Không xoá được"),
                },
              )
            }
            className="inline-flex h-9 items-center rounded-xl border border-border px-3 text-sm text-danger disabled:opacity-60"
          >
            Về mặc định
          </button>
        ) : null}
      </td>
    </tr>
  );
}

export function ZoneTariffsBoard() {
  const { data, isPending, isError, error, refetch } = useZoneTariffsQuery();
  const forbidden = isError && isForbiddenError(error);
  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Giá theo khu vực" },
        ]}
      />
      <div>
        <h1 className="text-xl font-semibold text-ink">Giá theo khu vực</h1>
        <p className="mt-1 max-w-3xl text-sm text-muted">
          Ghi đè giá/km và giá tối thiểu cho từng tỉnh/thành. Khu vực được xác định theo điểm đón
          ở máy chủ. Không ghi đè thì dùng giá mặc định của loại xe. Chuyến đã đặt giữ nguyên giá
          lúc đặt. Mọi thay đổi được ghi nhật ký.
        </p>
      </div>
      {forbidden ? <AdminForbiddenState /> : null}
      {isError && !forbidden ? (
        <AdminListErrorBanner message="Không tải được giá theo khu vực." onRetry={() => void refetch()} />
      ) : null}
      {isPending ? <p className="text-sm text-muted">Đang tải…</p> : null}
      {data
        ? data.regions.map((region) => (
            <section key={region.code} className="rounded-2xl border border-border bg-white p-4">
              <h2 className="text-base font-semibold text-ink">
                {region.name}{" "}
                <span className="text-xs font-normal text-muted">
                  ({region.code} · {region.status === "ACTIVE" ? "đang hoạt động" : "dự kiến"})
                </span>
              </h2>
              <div className="overflow-x-auto">
                <table className="mt-2 w-full text-left">
                  <thead>
                    <tr className="text-xs text-muted">
                      <th className="py-1 pr-3 font-medium">Loại xe</th>
                      <th className="py-1 pr-3 font-medium">Mặc định</th>
                      <th className="py-1 pr-3 font-medium">Giá/km</th>
                      <th className="py-1 pr-3 font-medium">Tối thiểu</th>
                      <th className="py-1 pr-3 font-medium">Lý do</th>
                      <th className="py-1 pr-3 font-medium">Trạng thái</th>
                      <th className="py-1 font-medium" />
                    </tr>
                  </thead>
                  <tbody>
                    {data.classes.map((vehicle) => (
                      <ZoneRow
                        key={`${region.code}-${vehicle.code}`}
                        region={region}
                        vehicle={vehicle}
                        override={data.overrides.find(
                          (o) => o.regionCode === region.code && o.vehicleClassCode === vehicle.code,
                        )}
                      />
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          ))
        : null}
    </div>
  );
}
