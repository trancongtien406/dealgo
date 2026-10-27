/** Why a ride ended cancelled (driver reason, worker timeout or customer no-show). */
const RIDE_CANCEL_REASON_LABELS: Record<string, string> = {
  CUSTOMER_UNREACHABLE: "Không liên lạc được khách",
  PICKUP_TOO_FAR: "Điểm đón quá xa",
  VEHICLE_PROBLEM: "Xe gặp sự cố",
  SAFETY_CONCERN: "Lo ngại an toàn",
  CUSTOMER_ASKED: "Khách yêu cầu huỷ",
  ASSIGNED_TIMEOUT: "Tài xế không bắt đầu kịp (hệ thống)",
  EN_ROUTE_TIMEOUT: "Tài xế đến đón quá lâu (hệ thống)",
  NO_SHOW: "Khách không ra điểm đón",
  OTHER: "Lý do khác",
};

export function rideCancelReasonLabel(
  code: string | null | undefined,
  noShow?: boolean,
): string | null {
  if (noShow) return RIDE_CANCEL_REASON_LABELS.NO_SHOW;
  if (!code) return null;
  return RIDE_CANCEL_REASON_LABELS[code] ?? code;
}
