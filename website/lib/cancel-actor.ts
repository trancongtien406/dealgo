/** DEC-PROD-035: who cancelled a ride / food order (Nest `cancelledBy`). */
export type NestCancelActor = "CUSTOMER" | "DRIVER" | "MERCHANT" | "OPS" | "SYSTEM";

const CANCEL_ACTOR_LABELS: Record<NestCancelActor, string> = {
  CUSTOMER: "Khách hàng huỷ",
  DRIVER: "Tài xế huỷ",
  MERCHANT: "Quán huỷ / từ chối",
  OPS: "Ops huỷ",
  SYSTEM: "Hệ thống huỷ",
};

export function cancelActorLabel(actor: string | null | undefined): string | null {
  if (!actor) return null;
  return CANCEL_ACTOR_LABELS[actor as NestCancelActor] ?? null;
}
