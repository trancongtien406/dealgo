import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { code } = await context.params;
  if (!code || typeof code !== "string" || code.trim().length === 0) {
    return NextResponse.json(
      { success: false, message: "Mã khiếu nại không hợp lệ." },
      { status: 400 },
    );
  }

  let bodyJson: Record<string, unknown>;
  try {
    bodyJson = (await request.json()) as Record<string, unknown>;
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu gửi lên không đúng định dạng JSON." },
      { status: 400 },
    );
  }

  const { remedy, reason, note, amount } = bodyJson;

  if (
    !remedy ||
    (remedy !== "evidence" &&
      remedy !== "partial" &&
      remedy !== "full" &&
      remedy !== "reject")
  ) {
    return NextResponse.json(
      { success: false, message: "Phương án xử lý không hợp lệ." },
      { status: 400 },
    );
  }

  if (!reason || typeof reason !== "string" || reason.trim().length === 0) {
    return NextResponse.json(
      {
        success: false,
        message:
          "Lý do và căn cứ xử lý là bắt buộc để ghi nhận nhật ký kiểm toán.",
      },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/disputes/${encodeURIComponent(code)}/resolve`,
    body: {
      remedy,
      reason: reason.trim(),
      note: typeof note === "string" ? note.trim() : undefined,
      amount: typeof amount === "number" ? amount : undefined,
    },
  });

  return jsonFromOpsUpstream(result);
}
