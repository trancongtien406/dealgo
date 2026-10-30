"use client";

import Link from "next/link";
import { AdminBreadcrumb, StatusChip, vnd } from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { useParcelQuery } from "@/features/parcels/hooks";
import {
  contactLabel,
  parcelFailReasonLabel,
  parcelOutcomeTone,
  parcelPhotoLabel,
  parcelPhotoPath,
  parcelStageLabel,
} from "@/features/parcels/mappers";
import { PARCEL_PHOTO_KINDS } from "@/features/parcels/types";
import { isForbiddenError } from "@/lib/api/errors";

/** DEC-PROD-071: parcel detail. Cancel/reassign stay on the ride page (rides.intervene). */
export function ParcelDetail({ id }: { id: string }) {
  const query = useParcelQuery(id);
  if (query.isError && isForbiddenError(query.error)) return <AdminForbiddenState />;
  if (query.isError) return <AdminListErrorBanner message="Không tải được đơn hàng." onRetry={() => void query.refetch()} />;
  const ride = query.data;
  if (!ride) return <p className="text-sm text-muted-foreground">Đang tải…</p>;
  const p = ride.parcel;
  const fare = ride.agreedFareVnd ?? ride.offeredFareVnd;
  const rows: [string, string][] = [
    ["Tuyến", `${ride.pickupLabel ?? "?"} → ${ride.dropoffLabel ?? "?"}`],
    ["Trạng thái chuyến", ride.status],
    ["Loại xe", ride.vehicleClassCode ?? "—"],
    ["Giá", fare == null ? "—" : vnd(fare)],
    ["Phụ phí hạng", vnd(p.surchargeVnd)],
    ["Hạng / cân nặng", `${p.sizeClass} · ${p.weightKg == null ? "—" : `${p.weightKg} kg`}`],
    ["Người trả", p.payer === "RECIPIENT" ? "Người nhận (tiền mặt)" : "Người gửi"],
    ["Người gửi", contactLabel(p.sender)],
    ["Người nhận", contactLabel(p.recipient)],
    ["Ghi chú", p.note ?? "—"],
    ["Lấy hàng lúc", p.pickedUpAt ? new Date(p.pickedUpAt).toLocaleString("vi-VN") : "—"],
    ["Giao lúc", p.deliveredAt ? new Date(p.deliveredAt).toLocaleString("vi-VN") : "—"],
  ];
  if (p.failReason) {
    rows.push(["Giao thất bại", `${parcelFailReasonLabel[p.failReason] ?? p.failReason}${p.failNote ? ` — ${p.failNote}` : ""}`]);
  }
  return (
    <div className="space-y-4">
      <AdminBreadcrumb items={[{ label: "Giao hàng", href: "/parcels" }, { label: id.slice(0, 8) }]} />
      <div className="flex items-center gap-3">
        <h1 className="text-2xl font-bold">Đơn hàng {id.slice(0, 8)}</h1>
        <StatusChip tone={parcelOutcomeTone[p.outcome]}>{parcelStageLabel(p)}</StatusChip>
        <Link className="text-sm text-brand underline" href={`/rides/${id}`}>
          Mở chuyến (huỷ / điều phối lại)
        </Link>
      </div>
      <dl className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {rows.map(([k, v]) => (
          <div key={k} className="rounded-md border p-3">
            <dt className="text-xs text-muted-foreground">{k}</dt>
            <dd className="text-sm font-medium">{v}</dd>
          </div>
        ))}
      </dl>
      <h2 className="text-lg font-semibold">Ảnh bằng chứng</h2>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {PARCEL_PHOTO_KINDS.filter((k) => p.photos[k]).map((k) => (
          <figure key={k} className="rounded-md border p-2">
            {/* eslint-disable-next-line @next/next/no-img-element -- private BFF stream */}
            <img src={parcelPhotoPath(id, k)} alt={parcelPhotoLabel[k]} className="h-40 w-full rounded object-cover" />
            <figcaption className="mt-1 text-xs">{parcelPhotoLabel[k]}</figcaption>
          </figure>
        ))}
      </div>
    </div>
  );
}
