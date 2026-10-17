import { NextResponse } from "next/server";

function maskPii(contact: string): string {
  if (contact.includes("@")) {
    const [name, domain] = contact.split("@");
    const maskedName =
      name.length <= 2
        ? `${name[0]}*`
        : `${name.slice(0, 2)}${"*".repeat(Math.max(1, name.length - 2))}`;
    return `${maskedName}@${domain || "unknown"}`;
  }
  const digits = contact.replace(/\D/g, "");
  if (digits.length >= 7) {
    return `${digits.slice(0, 3)}****${digits.slice(-3)}`;
  }
  return "***";
}

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      {
        success: false,
        message: "Dữ liệu yêu cầu không hợp lệ (JSON invalid).",
      },
      { status: 400 },
    );
  }

  if (!body || typeof body !== "object") {
    return NextResponse.json(
      { success: false, message: "Nội dung phản hồi không hợp lệ." },
      { status: 400 },
    );
  }

  const { role, topic, content, contact, refCode } = body as Record<
    string,
    unknown
  >;

  if (typeof content !== "string" || content.trim().length < 10) {
    return NextResponse.json(
      {
        success: false,
        message: "Nội dung phản hồi cần tối thiểu 10 ký tự mô tả cụ thể.",
      },
      { status: 400 },
    );
  }

  if (content.length > 2_000) {
    return NextResponse.json(
      {
        success: false,
        message: "Nội dung phản hồi không được vượt quá 2000 ký tự.",
      },
      { status: 400 },
    );
  }

  if (typeof contact !== "string" || contact.trim().length < 5) {
    return NextResponse.json(
      {
        success: false,
        message:
          "Vui lòng cung cấp số điện thoại hoặc email hợp lệ để liên hệ đối soát.",
      },
      { status: 400 },
    );
  }

  const sanitizedRole =
    typeof role === "string" ? role.trim().slice(0, 30) : "CUSTOMER";
  const sanitizedTopic =
    typeof topic === "string" ? topic.trim().slice(0, 50) : "GENERAL";
  const sanitizedRef =
    typeof refCode === "string" ? refCode.trim().slice(0, 50) : "";
  const sanitizedContact = contact.trim().slice(0, 100);

  // Generate deterministic timestamp-based reference for inquiry audit
  const inquiryId = `INQ-${Date.now().toString(36).toUpperCase()}-${Math.floor(
    Math.random() * 1000,
  )
    .toString(36)
    .toUpperCase()}`;

  // Log inquiry with PII masked to avoid privacy leaks in log aggregators
  console.log(
    `[PublicSupportInquiry] id=${inquiryId} role=${sanitizedRole} topic=${sanitizedTopic} contact=${maskPii(sanitizedContact)} ref=${sanitizedRef}`,
  );

  return NextResponse.json({
    success: true,
    data: {
      inquiryId,
      role: sanitizedRole,
      topic: sanitizedTopic,
      receivedAt: new Date().toISOString(),
      message:
        "Mã tra soát phản ánh đã được hệ thống DealGo ghi nhận thành công. Vui lòng lưu mã này để đối chiếu khi liên hệ tổng đài hoặc gửi kèm qua hòm thư hỗ trợ.",
    },
  });
}
