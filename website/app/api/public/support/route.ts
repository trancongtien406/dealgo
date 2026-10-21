import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";

const ROLES = new Set(["CUSTOMER", "DRIVER", "MERCHANT", "OTHER"]);
const CATEGORIES = new Set(["RIDE", "FOOD", "PAYMENT", "ACCOUNT", "SAFETY", "OTHER"]);

function fail(status: number, message: string) {
  return NextResponse.json({ success: false, message }, { status });
}

/** Vietnamese copy for the backend's support error codes. */
function upstreamMessage(status: number, errorCode: unknown): string {
  if (errorCode === "SUPPORT_CONTACT_LIMIT_REACHED" || status === 429) {
    return "Số điện thoại/email này đã gửi nhiều yêu cầu trong 24 giờ qua. Vui lòng chờ phản hồi hoặc gọi tổng đài.";
  }
  if (errorCode === "SUPPORT_CONTACT_INVALID") {
    return "Vui lòng nhập số điện thoại Việt Nam (10 số) hoặc email hợp lệ.";
  }
  if (errorCode === "SUPPORT_TEXT_TOO_LONG") {
    return "Nội dung quá dài. Vui lòng rút gọn mô tả.";
  }
  if (status === 400) {
    return "Thông tin yêu cầu chưa hợp lệ. Vui lòng kiểm tra lại các trường bắt buộc.";
  }
  return "Không thể gửi yêu cầu hỗ trợ lúc này. Vui lòng thử lại hoặc gọi tổng đài.";
}

/**
 * Public support form → Nest `POST /v1/public/support/tickets`. The ticket is stored and shows
 * up in Admin → Hỗ trợ; the visitor only gets the ticket code back.
 */
export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return fail(400, "Dữ liệu yêu cầu không hợp lệ (JSON invalid).");
  }
  if (!body || typeof body !== "object") {
    return fail(400, "Nội dung phản hồi không hợp lệ.");
  }

  const { role, category, content, contact, refCode, contactName } = body as Record<
    string,
    unknown
  >;

  if (typeof content !== "string" || content.trim().length < 10) {
    return fail(400, "Nội dung phản hồi cần tối thiểu 10 ký tự mô tả cụ thể.");
  }
  if (typeof contact !== "string" || contact.trim().length < 5) {
    return fail(400, "Vui lòng cung cấp số điện thoại hoặc email hợp lệ để DealGo liên hệ lại.");
  }
  if (typeof role !== "string" || !ROLES.has(role)) {
    return fail(400, "Vui lòng chọn vai trò của bạn.");
  }
  if (typeof category !== "string" || !CATEGORIES.has(category)) {
    return fail(400, "Vui lòng chọn nhóm vấn đề.");
  }

  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return fail(503, "Máy chủ hỗ trợ chưa được cấu hình. Vui lòng gọi tổng đài.");
  }

  let res: Response;
  try {
    res = await fetch(`${baseUrl}/v1/public/support/tickets`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      cache: "no-store",
      signal: AbortSignal.timeout(8_000),
      body: JSON.stringify({
        role,
        category,
        description: content.trim(),
        contact: contact.trim(),
        ...(typeof refCode === "string" && refCode.trim()
          ? { externalRef: refCode.trim().slice(0, 50) }
          : {}),
        ...(typeof contactName === "string" && contactName.trim()
          ? { contactName: contactName.trim().slice(0, 80) }
          : {}),
      }),
    });
  } catch {
    return fail(503, "Mất kết nối máy chủ hỗ trợ. Vui lòng thử lại hoặc gọi tổng đài.");
  }

  const envelope = (await res.json().catch(() => null)) as {
    errorCode?: string;
    data?: { code?: string; createdAt?: string };
  } | null;

  if (!res.ok || !envelope?.data?.code) {
    const status = res.status >= 400 && res.status < 500 ? res.status : 502;
    return fail(status, upstreamMessage(res.status, envelope?.errorCode));
  }

  return NextResponse.json(
    {
      success: true,
      data: { ticketCode: envelope.data.code, createdAt: envelope.data.createdAt },
    },
    { status: 201 },
  );
}
