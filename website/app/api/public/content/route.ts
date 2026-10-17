import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";
import {
  publicPrivacyDocument,
  publicSupportConfig,
  publicTermsDocument,
} from "@/features/content-cms/public-documents";

type BackendCmsItem = {
  id: string;
  kind: string;
  title: string;
  body: string;
  status: string;
  createdAt: string;
  updatedAt?: string;
};

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const key = searchParams.get("key")?.toUpperCase();

  if (key !== "TERMS" && key !== "PRIVACY" && key !== "SUPPORT") {
    return NextResponse.json(
      {
        success: false,
        message: "Tài liệu công khai không tồn tại.",
      },
      { status: 404 },
    );
  }

  // Attempt to fetch latest live CMS document from Nest backend
  const baseUrl = nestApiBaseUrl();
  if (baseUrl) {
    try {
      const kind = key === "SUPPORT" ? "ARTICLE" : "POLICY";
      const q = key === "SUPPORT" ? "SUPPORT" : key;
      const res = await fetch(
        `${baseUrl}/v1/public/cms?kind=${kind}&q=${encodeURIComponent(q)}`,
        {
          cache: "no-store",
          signal: AbortSignal.timeout(4_000),
        },
      );

      if (res.ok) {
        const envelope: unknown = await res.json().catch(() => null);
        if (
          envelope &&
          typeof envelope === "object" &&
          "data" in envelope &&
          envelope.data &&
          typeof envelope.data === "object" &&
          "items" in envelope.data &&
          Array.isArray(envelope.data.items)
        ) {
          const items = envelope.data.items as BackendCmsItem[];
          const match = items.find((item) => {
            const upper = item.title.toUpperCase();
            if (key === "TERMS") {
              return (
                upper.includes("TERMS") || item.title.includes("Điều khoản")
              );
            }
            if (key === "PRIVACY") {
              return (
                upper.includes("PRIVACY") ||
                item.title.toLowerCase().includes("riêng tư") ||
                item.title.toLowerCase().includes("bảo mật")
              );
            }
            if (key === "SUPPORT") {
              return (
                upper.includes("SUPPORT") ||
                item.title.toLowerCase().includes("hỗ trợ")
              );
            }
            return false;
          });

          if (match?.body) {
            try {
              const parsed = JSON.parse(match.body);
              if (parsed && typeof parsed === "object") {
                return NextResponse.json({
                  success: true,
                  data: {
                    ...parsed,
                    updatedAt:
                      match.updatedAt || match.createdAt || parsed.updatedAt,
                  },
                });
              }
            } catch {
              // Body was not JSON; fallback below
            }
          }
        }
      }
    } catch {
      // Backend is unreachable, timeout, or restarting — fail-soft to authoritative default
    }
  }

  // Fallback to authoritative defaults
  if (key === "TERMS") {
    return NextResponse.json({
      success: true,
      data: publicTermsDocument,
    });
  }

  if (key === "PRIVACY") {
    return NextResponse.json({
      success: true,
      data: publicPrivacyDocument,
    });
  }

  return NextResponse.json({
    success: true,
    data: publicSupportConfig,
  });
}
