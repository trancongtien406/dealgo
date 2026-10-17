import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import {
  publicPrivacyDocument,
  publicSupportConfig,
  publicTermsDocument,
} from "./public-documents";
import type { ContentDocKey, LegalDocument, SupportConfig } from "./types";

type CmsApiItem = {
  id: string;
  kind: string;
  title: string;
  body: string;
  status: string;
  createdAt: string;
  updatedAt?: string;
};

const cmsItemCache = new Map<string, string>();

export async function fetchCmsDocument(
  key: ContentDocKey,
): Promise<LegalDocument> {
  const isPublicPage =
    typeof window !== "undefined" &&
    (window.location.pathname.startsWith("/terms") ||
      window.location.pathname.startsWith("/privacy") ||
      window.location.pathname.startsWith("/support"));

  if (isPublicPage) {
    try {
      const res = await apiFetch<{ success: boolean; data: LegalDocument }>(
        `/api/public/content?key=${encodeURIComponent(key)}`,
        { redirectOn401: false },
      );
      if (res?.data) {
        return res.data;
      }
    } catch {
      // Fail-soft to authoritative default
    }
    return key === "TERMS"
      ? { ...publicTermsDocument }
      : { ...publicPrivacyDocument };
  }

  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: { items: CmsApiItem[] };
    }>(`${apiPaths.opsNotificationsCms()}?kind=POLICY`, {
      redirectOn401: false,
    });

    const items = envelope.data?.items ?? [];
    const targetKey = key.toUpperCase();

    const match = items.find(
      (item) =>
        item.title.toUpperCase().includes(targetKey) ||
        (targetKey === "TERMS" &&
          item.title.toLowerCase().includes("điều khoản")) ||
        (targetKey === "PRIVACY" &&
          item.title.toLowerCase().includes("quyền riêng tư")) ||
        (targetKey === "PRIVACY" &&
          item.title.toLowerCase().includes("bảo mật")),
    );

    if (match) {
      cmsItemCache.set(key, match.id);
      try {
        const parsed = JSON.parse(match.body) as LegalDocument;
        if (parsed && parsed.sections) {
          return {
            ...parsed,
            updatedAt: match.updatedAt || match.createdAt || parsed.updatedAt,
          };
        }
      } catch {
        // Body was plain text markdown, map to section
        return {
          key,
          title: match.title,
          badge: "Chính sách DealGo",
          version: "v2.5",
          effectiveDate: "Áp dụng từ 2026",
          summary: "Tài liệu chính sách được cập nhật trực tiếp từ hệ thống.",
          updatedAt: match.updatedAt || match.createdAt,
          updatedBy: "Ban Quản trị DealGo Ops",
          sections: [
            {
              id: "sec-body",
              order: 1,
              title: "Nội dung chính sách",
              content: match.body,
            },
          ],
        };
      }
    }
  } catch {
    // Fail-soft to default document if network / backend is unreachable
  }

  return key === "TERMS"
    ? { ...publicTermsDocument }
    : { ...publicPrivacyDocument };
}

export async function saveCmsDocument(
  doc: LegalDocument,
  reason = "Cập nhật nội dung văn bản pháp lý",
): Promise<LegalDocument> {
  const updated: LegalDocument = {
    ...doc,
    updatedAt: new Date().toISOString(),
    updatedBy: "Admin Quản trị viên (DealGo Ops)",
  };

  const cachedId = cmsItemCache.get(doc.key);

  if (cachedId) {
    await apiFetch(apiPaths.opsNotificationCmsItem(cachedId), {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        body: JSON.stringify(updated),
        reason,
      }),
    });
  } else {
    const res = await apiFetch<{ success: boolean; data: CmsApiItem }>(
      apiPaths.opsNotificationsCms(),
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          kind: "POLICY",
          title: `${doc.title} (${doc.key})`,
          body: JSON.stringify(updated),
          reason,
        }),
      },
    );
    if (res.data?.id) {
      cmsItemCache.set(doc.key, res.data.id);
    }
  }

  return updated;
}

export async function resetCmsDocument(
  key: ContentDocKey,
): Promise<LegalDocument> {
  const fallback =
    key === "TERMS" ? { ...publicTermsDocument } : { ...publicPrivacyDocument };

  return await saveCmsDocument(fallback, "Khôi phục văn bản mẫu mặc định");
}

export async function fetchSupportConfig(): Promise<SupportConfig> {
  const isPublicPage =
    typeof window !== "undefined" &&
    window.location.pathname.startsWith("/support");

  if (isPublicPage) {
    try {
      const res = await apiFetch<{ success: boolean; data: SupportConfig }>(
        "/api/public/content?key=SUPPORT",
        { redirectOn401: false },
      );
      if (res?.data) {
        return res.data;
      }
    } catch {
      // Fallback below
    }
    return { ...publicSupportConfig };
  }

  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: { items: CmsApiItem[] };
    }>(`${apiPaths.opsNotificationsCms()}?kind=ARTICLE&q=support`, {
      redirectOn401: false,
    });

    const items = envelope.data?.items ?? [];
    const match = items.find(
      (item) =>
        item.title.toUpperCase().includes("SUPPORT") ||
        item.title.toLowerCase().includes("hỗ trợ"),
    );
    if (match) {
      cmsItemCache.set("SUPPORT", match.id);
      try {
        const parsed = JSON.parse(match.body) as SupportConfig;
        if (parsed && parsed.categories) {
          return parsed;
        }
      } catch {
        // ignore
      }
    }
  } catch {
    // fallback
  }

  return { ...publicSupportConfig };
}

export async function saveSupportConfig(
  config: SupportConfig,
  reason = "Cập nhật cấu hình kênh hỗ trợ",
): Promise<SupportConfig> {
  const updated: SupportConfig = {
    ...config,
    updatedAt: new Date().toISOString(),
    updatedBy: "Admin Quản trị viên (DealGo Ops)",
  };

  const cachedId = cmsItemCache.get("SUPPORT");

  if (cachedId) {
    await apiFetch(apiPaths.opsNotificationCmsItem(cachedId), {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        body: JSON.stringify(updated),
        reason,
      }),
    });
  } else {
    const res = await apiFetch<{ success: boolean; data: CmsApiItem }>(
      apiPaths.opsNotificationsCms(),
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          kind: "ARTICLE",
          title: "Cấu hình kênh hỗ trợ khách hàng (SUPPORT)",
          body: JSON.stringify(updated),
          reason,
        }),
      },
    );
    if (res.data?.id) {
      cmsItemCache.set("SUPPORT", res.data.id);
    }
  }

  return updated;
}

export async function resetSupportConfig(): Promise<SupportConfig> {
  return await saveSupportConfig(
    publicSupportConfig,
    "Khôi phục cấu hình hỗ trợ mặc định",
  );
}
