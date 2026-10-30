import {
  PAYMENT_SERVICES,
  type OpsPaymentMethod,
  type PaymentMethodDraft,
  type PaymentMethodPatch,
} from "@/features/payment-methods/types";

export const SERVICE_LABELS = { BIKE: "Xe máy", CAR: "Ô tô", FOOD: "Đồ ăn", PARCEL: "Giao hàng" } as const;

export const GROUP_LABELS: Record<OpsPaymentMethod["group"], string> = {
  WALLET: "Ví điện tử",
  CARD: "Thẻ tín dụng/ghi nợ",
  RECOMMENDED: "Phương thức đề xuất",
  ADD_MORE: "Thêm phương thức",
};

export function draftFromMethod(m: OpsPaymentMethod): PaymentMethodDraft {
  return {
    services: { ...m.services },
    sortOrder: m.sortOrder,
    unsupportedReason: m.unsupportedReason ?? "",
  };
}

/** Only fields that actually changed are sent; CASH is never patched (always on). */
export function diffPatches(
  methods: OpsPaymentMethod[],
  drafts: Record<string, PaymentMethodDraft>,
): PaymentMethodPatch[] {
  const out: PaymentMethodPatch[] = [];
  for (const m of methods) {
    const d = drafts[m.code];
    if (!d || m.locked) continue;
    const patch: PaymentMethodPatch = { code: m.code };
    const services: Partial<Record<(typeof PAYMENT_SERVICES)[number], boolean>> = {};
    for (const s of PAYMENT_SERVICES) {
      if (d.services[s] !== m.services[s]) services[s] = d.services[s];
    }
    if (Object.keys(services).length > 0) patch.services = services;
    if (d.sortOrder !== m.sortOrder) patch.sortOrder = d.sortOrder;
    const reason = d.unsupportedReason.trim();
    if (reason !== (m.unsupportedReason ?? "")) patch.unsupportedReason = reason || null;
    if (Object.keys(patch).length > 1) out.push(patch);
  }
  return out;
}

export type ConfigStatus = { tone: "success" | "food" | "danger" | "brand"; label: string };

export function configStatus(m: OpsPaymentMethod, publicBaseUrlConfigured: boolean): ConfigStatus {
  if (m.adapterKind === "NONE") return { tone: "success", label: "Không cần cấu hình" };
  if (m.adapterKind === "STUB") return { tone: "brand", label: "Chưa tích hợp (stub)" };
  if (!publicBaseUrlConfigured) return { tone: "danger", label: "Thiếu PAYMENT_PUBLIC_BASE_URL" };
  return m.configured
    ? { tone: "success", label: "Đã cấu hình" }
    : { tone: "food", label: "Thiếu biến môi trường" };
}
