"use client";

import { useMemo, useState } from "react";
import type { FormEvent, KeyboardEvent } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/components/ui/admin-list-ui";
import { SearchSelect, type SearchSelectOption } from "@/components/ui/search-select";
import {
  LazyRealMapView,
  type MapMarker,
  type MapPolygon,
} from "@/components/ui/lazy-real-map-view";
import { recenterBox, type GeoBox } from "@/components/ui/map-box-edit";
import { searchZonePlaces, type ZonePlaceHit } from "@/features/zones/api";
import type {
  CreateZoneInput,
  PatchZoneInput,
  ZoneItem,
} from "@/features/zones/types";
import {
  bboxCenter,
  defaultZoneBbox,
  fitZoneBox,
  matchProvinces,
  normalizeZoneCodeInput,
  overlappingZones,
  suggestZoneCode,
  zoneBboxProblem,
  zoneCodeProblem,
  type ProvincePreset,
} from "@/features/zones/zone-form";

const MAP_W = 620;
const MAP_H = 300;

const ZONE_FORM_STATUS_OPTIONS: readonly SearchSelectOption[] = [
  { value: "PLANNED", label: "Sắp mở" },
  { value: "ACTIVE", label: "Đang phục vụ" },
];

export type ZoneFormSubmit =
  | { kind: "create"; input: CreateZoneInput }
  | { kind: "edit"; code: string; input: PatchZoneInput };

type Center = { lat: number; lng: number };

function boxOf(zone?: ZoneItem): GeoBox | null {
  return zone?.bbox ? { ...zone.bbox } : null;
}

function centerOf(zone?: ZoneItem): Center | null {
  return zone?.centerLat != null && zone.centerLng != null
    ? { lat: zone.centerLat, lng: zone.centerLng }
    : null;
}

function inside(c: Center, b: GeoBox) {
  return c.lat >= b.minLat && c.lat <= b.maxLat && c.lng >= b.minLng && c.lng <= b.maxLng;
}

/** ≈ km size of a box, for the summary line. */
function boxKm(b: GeoBox) {
  const h = (b.maxLat - b.minLat) * 111;
  const w = (b.maxLng - b.minLng) * 111 * Math.cos((((b.minLat + b.maxLat) / 2) * Math.PI) / 180);
  return `${Math.round(w)} × ${Math.round(h)} km`;
}

/**
 * Create / edit a service zone with as little typing as possible: pick a
 * province or search a place, then drag the box on the map. Code is
 * suggested (diacritics folded, unique); the backend re-validates everything.
 */
export function ZoneFormModal({
  zone,
  zones,
  onClose,
  onSubmit,
  isSubmitting,
}: {
  /** Present → edit mode (code is fixed). */
  zone?: ZoneItem;
  /** Every zone (ALL) for code uniqueness and overlap hints. */
  zones: readonly ZoneItem[];
  onClose: () => void;
  onSubmit: (submit: ZoneFormSubmit) => Promise<void>;
  isSubmitting: boolean;
}) {
  const editing = zone != null;
  const takenCodes = useMemo(
    () => zones.map((z) => z.code).filter((c) => c !== zone?.code),
    [zones, zone?.code],
  );

  const [label, setLabel] = useState(zone?.label ?? "");
  const [code, setCode] = useState(zone?.code ?? "");
  const [codeTouched, setCodeTouched] = useState(editing);
  const [center, setCenter] = useState<Center | null>(centerOf(zone));
  const [bbox, setBbox] = useState<GeoBox | null>(boxOf(zone));
  const [status, setStatus] = useState<"ACTIVE" | "PLANNED">("PLANNED");
  const [reason, setReason] = useState("");
  const [reasonTouched, setReasonTouched] = useState(false);
  const [drawing, setDrawing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [view, setView] = useState(() => {
    const b = boxOf(zone);
    return b ? fitZoneBox(b, MAP_W, MAP_H) : { center: [16.0, 106.5] as [number, number], zoom: 5 };
  });

  const [provinceQuery, setProvinceQuery] = useState("");
  const [provinceOpen, setProvinceOpen] = useState(false);
  const provinceHits = useMemo(() => matchProvinces(provinceQuery, 8), [provinceQuery]);

  const [placeQuery, setPlaceQuery] = useState("");
  const [placeHits, setPlaceHits] = useState<ZonePlaceHit[] | null>(null);
  const [placeBusy, setPlaceBusy] = useState(false);
  const [placeError, setPlaceError] = useState<string | null>(null);

  const effectiveReason = reasonTouched
    ? reason
    : label.trim()
      ? `${editing ? "Cập nhật" : "Tạo"} khu vực ${label.trim()}`
      : "";

  const applyLabel = (next: string, preferred?: string) => {
    setLabel(next);
    if (!codeTouched) setCode(suggestZoneCode(next, takenCodes, preferred));
  };

  const focusOn = (c: Center, b: GeoBox) => {
    setCenter(c);
    setBbox(b);
    setView(fitZoneBox(b, MAP_W, MAP_H));
    setError(null);
  };

  const pickProvince = (p: ProvincePreset) => {
    applyLabel(p.name, p.code);
    focusOn({ lat: p.lat, lng: p.lng }, defaultZoneBbox(p.lat, p.lng));
    setProvinceQuery(p.name);
    setProvinceOpen(false);
  };

  const pickPlace = (hit: ZonePlaceHit) => {
    const c = { lat: hit.lat, lng: hit.lng };
    const b = bbox ? recenterBox(bbox, [c.lat, c.lng]) : defaultZoneBbox(c.lat, c.lng);
    if (!label.trim()) applyLabel(hit.name);
    focusOn(c, b);
    setPlaceHits(null);
  };

  const runPlaceSearch = async () => {
    const q = placeQuery.trim();
    if (q.length < 2) {
      setPlaceError("Nhập ít nhất 2 ký tự.");
      return;
    }
    setPlaceBusy(true);
    setPlaceError(null);
    try {
      const hits = await searchZonePlaces(q, center ?? undefined);
      setPlaceHits(hits);
      if (hits.length === 0) setPlaceError("Không tìm thấy địa điểm.");
    } catch (err: unknown) {
      setPlaceHits(null);
      setPlaceError(err instanceof Error ? err.message : "Không tìm được địa điểm.");
    } finally {
      setPlaceBusy(false);
    }
  };

  const onBoxChange = (next: GeoBox) => {
    setBbox(next);
    setCenter((c) => {
      if (c && inside(c, next)) return c;
      const [lat, lng] = bboxCenter(next);
      return { lat, lng };
    });
  };

  const codeProblem = editing ? null : zoneCodeProblem(code, takenCodes);
  const bboxProblem = center && bbox ? zoneBboxProblem(center, bbox) : null;
  const overlaps = bbox ? overlappingZones(bbox, zones, zone?.code) : [];

  const otherPolygons: MapPolygon[] = useMemo(
    () =>
      zones
        .filter((z) => z.code !== zone?.code && z.bbox)
        .map((z) => {
          const b = z.bbox!;
          return {
            id: `zone-${z.code}`,
            name: z.label,
            coords: [
              [b.maxLat, b.minLng],
              [b.maxLat, b.maxLng],
              [b.minLat, b.maxLng],
              [b.minLat, b.minLng],
            ],
            color: "#64748b",
            fillColor: "rgba(100, 116, 139, 0.10)",
          } satisfies MapPolygon;
        }),
    [zones, zone?.code],
  );
  const markers: MapMarker[] = center
    ? [{ id: "zone-center", lat: center.lat, lng: center.lng, type: "pickup", label: "Tâm" }]
    : [];

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    const trimmed = label.trim();
    if (trimmed.length < 2 || trimmed.length > 80) {
      setError("Tên hiển thị 2–80 ký tự.");
      return;
    }
    if (codeProblem) {
      setError(codeProblem);
      return;
    }
    if (!center || !bbox) {
      setError("Chọn tỉnh/thành hoặc tìm địa điểm, rồi kéo vùng trên bản đồ.");
      return;
    }
    if (bboxProblem) {
      setError(bboxProblem);
      return;
    }
    const why = effectiveReason.trim();
    if (why.length < 3) {
      setError("Nhập lý do (ít nhất 3 ký tự).");
      return;
    }
    try {
      if (!editing) {
        await onSubmit({
          kind: "create",
          input: {
            code,
            label: trimmed,
            centerLat: center.lat,
            centerLng: center.lng,
            bbox,
            status,
            reason: why,
          },
        });
        return;
      }
      const input: PatchZoneInput = { reason: why };
      if (trimmed !== zone.label) input.label = trimmed;
      if (center.lat !== zone.centerLat || center.lng !== zone.centerLng) {
        input.centerLat = center.lat;
        input.centerLng = center.lng;
      }
      const old = zone.bbox;
      if (
        !old ||
        old.minLat !== bbox.minLat ||
        old.maxLat !== bbox.maxLat ||
        old.minLng !== bbox.minLng ||
        old.maxLng !== bbox.maxLng
      ) {
        input.bbox = bbox;
      }
      if (Object.keys(input).length === 1) {
        setError("Chưa có thay đổi nào.");
        return;
      }
      await onSubmit({ kind: "edit", code: zone.code, input });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Không thể lưu khu vực.");
    }
  };

  const noEnterSubmit = (e: KeyboardEvent<HTMLInputElement>, run?: () => void) => {
    if (e.key === "Enter") {
      e.preventDefault();
      run?.();
    }
  };

  const inputCls = `mt-1 h-9 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted ${focusRing}`;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="zone-form-title"
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-4"
    >
      <div className="fixed inset-0 bg-ink/40 backdrop-blur-xs" onClick={onClose} />
      <div className="relative z-10 my-6 w-full max-w-2xl rounded-2xl border border-border bg-white p-5 shadow-2xl">
        <div className="flex items-start justify-between gap-3 border-b border-border pb-3">
          <div className="min-w-0">
            <h3 id="zone-form-title" className="text-lg font-bold text-ink">
              {editing ? `Sửa khu vực ${zone.code}` : "Thêm khu vực"}
            </h3>
            <p className="mt-0.5 text-sm text-muted">
              Chọn tỉnh/thành hoặc tìm địa điểm, rồi kéo khung trên bản đồ.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Đóng"
            className="cursor-pointer rounded-lg p-1 text-muted hover:bg-canvas hover:text-ink"
          >
            <OpsIcon name="close" className="size-5" />
          </button>
        </div>

        <form onSubmit={(e) => void handleSubmit(e)} className="mt-4 space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="relative">
              <label htmlFor="zone-province" className="block text-xs font-semibold text-ink">
                Tỉnh / thành phố
              </label>
              <input
                id="zone-province"
                type="text"
                role="combobox"
                aria-expanded={provinceOpen}
                aria-controls="zone-province-list"
                autoComplete="off"
                value={provinceQuery}
                onChange={(e) => {
                  setProvinceQuery(e.target.value);
                  setProvinceOpen(true);
                }}
                onFocus={() => setProvinceOpen(true)}
                onBlur={() => setTimeout(() => setProvinceOpen(false), 150)}
                onKeyDown={(e) =>
                  noEnterSubmit(e, () => {
                    if (provinceHits[0]) pickProvince(provinceHits[0]);
                  })
                }
                placeholder="Gõ để chọn, VD: da nang"
                className={inputCls}
              />
              {provinceOpen && provinceHits.length > 0 ? (
                <ul
                  id="zone-province-list"
                  role="listbox"
                  className="absolute z-20 mt-1 max-h-56 w-full overflow-y-auto rounded-xl border border-border bg-white py-1 shadow-lg"
                >
                  {provinceHits.map((p) => (
                    <li key={p.code} role="option" aria-selected={false}>
                      <button
                        type="button"
                        onMouseDown={(e) => e.preventDefault()}
                        onClick={() => pickProvince(p)}
                        className="flex w-full cursor-pointer items-center justify-between px-3 py-1.5 text-left text-sm text-ink hover:bg-canvas"
                      >
                        <span>{p.name}</span>
                        <span className="text-xs text-muted">{p.code}</span>
                      </button>
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
            <div className="relative">
              <label htmlFor="zone-place" className="block text-xs font-semibold text-ink">
                Tìm địa điểm
              </label>
              <div className="mt-1 flex gap-2">
                <input
                  id="zone-place"
                  type="search"
                  autoComplete="off"
                  value={placeQuery}
                  onChange={(e) => setPlaceQuery(e.target.value)}
                  onKeyDown={(e) => noEnterSubmit(e, () => void runPlaceSearch())}
                  placeholder="Quận, phường, địa danh…"
                  className={`h-9 min-w-0 flex-1 rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
                />
                <button
                  type="button"
                  onClick={() => void runPlaceSearch()}
                  disabled={placeBusy}
                  className="h-9 shrink-0 cursor-pointer rounded-xl bg-canvas px-3 text-xs font-semibold text-ink hover:bg-border/60 disabled:opacity-50"
                >
                  {placeBusy ? "…" : "Tìm"}
                </button>
              </div>
              {placeError ? <p className="mt-1 text-xs text-red-600">{placeError}</p> : null}
              {placeHits && placeHits.length > 0 ? (
                <ul className="absolute z-20 mt-1 max-h-56 w-full overflow-y-auto rounded-xl border border-border bg-white py-1 shadow-lg">
                  {placeHits.map((hit, i) => (
                    <li key={`${hit.lat},${hit.lng},${i}`}>
                      <button
                        type="button"
                        onClick={() => pickPlace(hit)}
                        className="block w-full cursor-pointer px-3 py-1.5 text-left hover:bg-canvas"
                      >
                        <span className="block text-sm text-ink">{hit.name}</span>
                        {hit.address ? (
                          <span className="block truncate text-xs text-muted">{hit.address}</span>
                        ) : null}
                      </button>
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
          </div>

          <div>
            <div className="mb-1.5 flex flex-wrap items-center justify-between gap-2">
              <span className="text-xs font-semibold text-ink">Vùng phục vụ</span>
              <div className="flex gap-1.5">
                <button
                  type="button"
                  aria-pressed={drawing}
                  onClick={() => setDrawing((d) => !d)}
                  className={`cursor-pointer rounded-lg px-2.5 py-1 text-xs font-semibold ${
                    drawing ? "bg-orange-600 text-white" : "bg-canvas text-ink hover:bg-border/60"
                  }`}
                >
                  {drawing ? "Kéo trên bản đồ để vẽ…" : bbox ? "Vẽ lại vùng" : "Vẽ vùng"}
                </button>
                {bbox ? (
                  <button
                    type="button"
                    onClick={() => setView(fitZoneBox(bbox, MAP_W, MAP_H))}
                    className="cursor-pointer rounded-lg bg-canvas px-2.5 py-1 text-xs font-semibold text-ink hover:bg-border/60"
                  >
                    Vừa khung
                  </button>
                ) : null}
              </div>
            </div>
            <LazyRealMapView
              center={view.center}
              zoom={view.zoom}
              minZoom={5}
              height={MAP_H}
              markers={markers}
              polygons={otherPolygons}
              badgeLabel={label.trim() || "Khu vực mới"}
              showDriverProgress={false}
              editBox={{
                value: bbox,
                onChange: onBoxChange,
                drawing,
                onDrawEnd: () => setDrawing(false),
              }}
            />
            <p className="mt-1.5 text-xs text-muted" data-testid="zone-form-summary">
              {center && bbox
                ? `Tâm ${center.lat.toFixed(4)}, ${center.lng.toFixed(4)} · khung ${boxKm(bbox)} · kéo góc để đổi cỡ, kéo giữa để di chuyển`
                : "Chưa có vùng: chọn tỉnh/thành, tìm địa điểm hoặc kéo trên bản đồ để vẽ."}
            </p>
            {bboxProblem ? <p className="mt-1 text-xs text-red-600">{bboxProblem}</p> : null}
            {overlaps.length > 0 ? (
              <p className="mt-1 text-xs text-amber-700">
                Chồng lên: {overlaps.map((z) => `${z.label} (${z.code})`).join(", ")}. Vẫn lưu
                được nếu cố ý.
              </p>
            ) : null}
          </div>

          <div className="grid gap-3 sm:grid-cols-[1fr_9rem]">
            <div>
              <label htmlFor="zone-label" className="block text-xs font-semibold text-ink">
                Tên hiển thị *
              </label>
              <input
                id="zone-label"
                type="text"
                maxLength={80}
                value={label}
                onChange={(e) => applyLabel(e.target.value)}
                onKeyDown={(e) => noEnterSubmit(e)}
                placeholder="Tự điền khi chọn tỉnh"
                className={inputCls}
              />
            </div>
            <div>
              <label htmlFor="zone-code" className="block text-xs font-semibold text-ink">
                Mã {editing ? "" : "(tự gợi ý)"}
              </label>
              <input
                id="zone-code"
                type="text"
                maxLength={8}
                readOnly={editing}
                value={code}
                onChange={(e) => {
                  setCodeTouched(true);
                  setCode(normalizeZoneCodeInput(e.target.value));
                }}
                onKeyDown={(e) => noEnterSubmit(e)}
                className={`${inputCls} font-semibold uppercase text-brand ${editing ? "bg-canvas" : ""}`}
              />
              {codeProblem && code ? (
                <p className="mt-1 text-xs text-red-600">{codeProblem}</p>
              ) : null}
            </div>
          </div>

          <div className={`grid gap-3 ${editing ? "" : "sm:grid-cols-[12rem_1fr]"}`}>
            {editing ? null : (
              <div>
                <SearchSelect
                  label="Trạng thái"
                  icon="sliders"
                  value={status}
                  options={ZONE_FORM_STATUS_OPTIONS}
                  placeholder="Chọn trạng thái"
                  onChange={(val) => {
                    if (val) setStatus(val as "ACTIVE" | "PLANNED");
                  }}
                />
              </div>
            )}
            <div>
              <label htmlFor="zone-reason" className="block text-xs font-semibold text-ink">
                Lý do (nhật ký kiểm toán)
              </label>
              <input
                id="zone-reason"
                type="text"
                value={effectiveReason}
                onChange={(e) => {
                  setReasonTouched(true);
                  setReason(e.target.value);
                }}
                onKeyDown={(e) => noEnterSubmit(e)}
                className={inputCls}
              />
            </div>
          </div>

          {error ? (
            <div role="alert" className="rounded-xl bg-red-500/10 p-3 text-sm text-red-600">
              {error}
            </div>
          ) : null}

          <div className="flex items-center justify-end gap-2 border-t border-border pt-3">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="cursor-pointer rounded-xl bg-canvas px-4 py-2 text-xs font-semibold text-ink hover:bg-border/60"
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="cursor-pointer rounded-xl bg-brand px-4 py-2 text-xs font-semibold text-white hover:bg-brand/90 disabled:opacity-50"
            >
              {isSubmitting ? "Đang lưu…" : editing ? "Lưu thay đổi" : "Tạo khu vực"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
