"use client";

import { useState } from "react";
import {
  AdminBreadcrumb,
  focusRing,
  PreviewButton,
  PreviewTabs,
  StatusChip,
} from "@/components/ui/admin-list-ui";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { OpsIcon } from "@/components/ui/ops-icons";
import { toast } from "@/components/ui/toast";
import { formatOpsDateTime } from "@/lib/ops-time";

import {
  useCmsDocumentQuery,
  useResetCmsDocumentMutation,
  useResetSupportConfigMutation,
  useSaveCmsDocumentMutation,
  useSaveSupportConfigMutation,
  useSupportConfigQuery,
} from "../hooks";
import type {
  ContentDocKey,
  LegalDocument,
  LegalSection,
  SupportConfig,
} from "../types";
import { CONTENT_CMS_TABS, CONTENT_CMS_DEFAULT_TAB } from "../constants";
import { isForbiddenError } from "@/lib/api/errors";

export function ContentCmsBoard() {
  const [activeTab, setActiveTab] = useState<string>(CONTENT_CMS_DEFAULT_TAB);

  const docKey: ContentDocKey =
    activeTab === "Chính sách riêng tư" ? "PRIVACY" : "TERMS";
  const isSupportTab = activeTab === "Kênh & Hỗ trợ";

  const {
    data: docData,
    isPending: isDocPending,
    isError: isDocError,
    error: docError,
    refetch: refetchDoc,
  } = useCmsDocumentQuery(docKey);
  const saveDocMutation = useSaveCmsDocumentMutation();
  const resetDocMutation = useResetCmsDocumentMutation();

  const {
    data: supportData,
    isPending: isSupportPending,
    isError: isSupportError,
    error: supportError,
    refetch: refetchSupport,
  } = useSupportConfigQuery();
  const saveSupportMutation = useSaveSupportConfigMutation();
  const resetSupportMutation = useResetSupportConfigMutation();

  const isPending = isSupportTab ? isSupportPending : isDocPending;
  const isError = isSupportTab ? isSupportError : isDocError;
  const error = isSupportTab ? supportError : docError;
  const refetch = isSupportTab ? refetchSupport : refetchDoc;
  const forbidden = isError && isForbiddenError(error);

  const [editedDoc, setEditedDoc] = useState<{
    key: ContentDocKey;
    doc: LegalDocument;
  } | null>(null);
  const [editedSupport, setEditedSupport] = useState<SupportConfig | null>(
    null,
  );
  const [reason, setReason] = useState("");
  const [confirmPublish, setConfirmPublish] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);

  const docDraft =
    editedDoc && editedDoc.key === docKey ? editedDoc.doc : (docData ?? null);
  const setDocDraft = (
    updater:
      | LegalDocument
      | null
      | ((prev: LegalDocument | null) => LegalDocument | null),
  ) => {
    if (typeof updater === "function") {
      setEditedDoc((prev) => {
        const current =
          prev && prev.key === docKey ? prev.doc : (docData ?? null);
        const next = updater(current);
        return next ? { key: docKey, doc: next } : null;
      });
    } else {
      setEditedDoc(updater ? { key: docKey, doc: updater } : null);
    }
  };

  const supportDraft = editedSupport ?? supportData ?? null;
  const setSupportDraft = (
    updater:
      | SupportConfig
      | null
      | ((prev: SupportConfig | null) => SupportConfig | null),
  ) => {
    if (typeof updater === "function") {
      setEditedSupport((prev) => updater(prev ?? supportData ?? null));
    } else {
      setEditedSupport(updater);
    }
  };

  const liveHref = isSupportTab
    ? "/support"
    : docKey === "TERMS"
      ? "/terms"
      : "/privacy";

  const handleUpdateSection = (
    id: string,
    field: "title" | "content",
    val: string,
  ) => {
    if (!docDraft) return;
    setDocDraft({
      ...docDraft,
      sections: docDraft.sections.map((s) =>
        s.id === id ? { ...s, [field]: val } : s,
      ),
    });
  };

  const handleAddSection = () => {
    if (!docDraft) return;
    const newSection: LegalSection = {
      id: `sec-${Date.now()}`,
      order: docDraft.sections.length + 1,
      title: `${docDraft.sections.length + 1}. Tiêu đề điều khoản mới`,
      content: "Nhập nội dung quy định chi tiết tại đây...",
    };
    setDocDraft({
      ...docDraft,
      sections: [...docDraft.sections, newSection],
    });
    toast.success("Đã thêm điều khoản mới.");
  };

  const handleDeleteSection = (id: string) => {
    if (!docDraft) return;
    setDocDraft({
      ...docDraft,
      sections: docDraft.sections.filter((s) => s.id !== id),
    });
    toast.success("Đã xóa điều khoản.");
  };

  const handleMoveSection = (index: number, direction: "up" | "down") => {
    if (!docDraft) return;
    const targetIndex = direction === "up" ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= docDraft.sections.length) return;
    const newSections = [...docDraft.sections];
    const temp = newSections[index];
    newSections[index] = newSections[targetIndex];
    newSections[targetIndex] = temp;
    setDocDraft({
      ...docDraft,
      sections: newSections,
    });
  };

  const handleSaveDoc = () => {
    if (!docDraft) return;
    saveDocMutation.mutate(
      { doc: docDraft, reason: reason.trim() || undefined },
      {
        onSuccess: () => {
          toast.success(`Đã xuất bản nội dung ${docDraft.title}!`);
          setConfirmPublish(false);
          setReason("");
        },
        onError: () => {
          toast.error("Không thể lưu văn bản.");
        },
      },
    );
  };

  const handleSaveSupport = () => {
    if (!supportDraft) return;
    saveSupportMutation.mutate(
      { config: supportDraft, reason: reason.trim() || undefined },
      {
        onSuccess: () => {
          toast.success("Đã xuất bản cấu hình Trung tâm hỗ trợ!");
          setConfirmPublish(false);
          setReason("");
        },
        onError: () => {
          toast.error("Không thể lưu cấu hình hỗ trợ.");
        },
      },
    );
  };

  const handleReset = () => {
    if (isSupportTab) {
      resetSupportMutation.mutate(undefined, {
        onSuccess: () => {
          toast.success("Đã khôi phục cấu hình hỗ trợ mặc định.");
          setConfirmReset(false);
        },
      });
    } else {
      resetDocMutation.mutate(docKey, {
        onSuccess: () => {
          toast.success("Đã khôi phục văn bản mặc định.");
          setConfirmReset(false);
        },
      });
    }
  };

  return (
    <div className="space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Quản lý nội dung & pháp lý" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Quản lý nội dung & pháp lý (CMS)
          </h1>
          <p className="mt-1 text-sm text-muted">
            Chỉnh sửa trực tiếp Điều khoản dịch vụ, Chính sách quyền riêng tư và
            Kênh hỗ trợ khách hàng/đối tác.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <a
            href={liveHref}
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex h-10 items-center gap-1.5 rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand hover:bg-brand/5 transition-colors ${focusRing}`}
          >
            <OpsIcon name="eye" className="size-4" />
            Xem trang công khai ↗
          </a>
          <PreviewButton tone="danger" onClick={() => setConfirmReset(true)}>
            <OpsIcon name="undo" className="size-4" />
            Khôi phục mặc định
          </PreviewButton>
        </div>
      </div>

      <PreviewTabs
        label="Phân hệ nội dung"
        current={activeTab}
        onChange={setActiveTab}
        tabs={CONTENT_CMS_TABS}
      />

      {isError &&
      !forbidden &&
      (isSupportTab ? Boolean(supportDraft) : Boolean(docDraft)) ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ nội dung văn bản hoặc cấu hình hỗ trợ. Vui lòng thử lại."
          onRetry={() => void refetch()}
        />
      ) : null}

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền chỉnh sửa nội dung pháp lý"
          description="Tài khoản của bạn không được phân quyền chỉnh sửa điều khoản dịch vụ và chính sách công khai."
        />
      ) : isError && (isSupportTab ? !supportDraft : !docDraft) ? (
        <AdminListErrorBanner
          message="Không thể tải nội dung văn bản hoặc cấu hình hỗ trợ. Vui lòng thử lại."
          onRetry={() => void refetch()}
        />
      ) : isPending ? (
        <div className="rounded-2xl border border-border bg-white p-6 shadow-sm animate-pulse space-y-4">
          <div className="h-6 w-1/3 rounded bg-canvas" />
          <div className="h-4 w-1/2 rounded bg-canvas/70" />
          <div className="h-40 rounded-xl bg-canvas" />
        </div>
      ) : isSupportTab && supportDraft ? (
        <div className="space-y-5">
          <section className="rounded-2xl border border-border bg-white p-5 shadow-sm space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border pb-4">
              <div>
                <h2 className="text-base font-bold text-ink">
                  Thông tin tiếp nhận & Đường dây nóng
                </h2>
                <p className="text-xs text-muted">
                  Các thông số hiển thị trên trang /support và các kênh ứng
                  dụng.
                </p>
              </div>
              <StatusChip tone="success">Đang trực tuyến 24/7</StatusChip>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-xs font-medium text-muted">
                  Thông báo trạng thái hệ thống:
                </label>
                <input
                  type="text"
                  value={supportDraft.systemStatusNotice}
                  onChange={(e) =>
                    setSupportDraft({
                      ...supportDraft,
                      systemStatusNotice: e.target.value,
                    })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-muted">
                  Hotline khẩn cấp 24/7:
                </label>
                <input
                  type="text"
                  value={supportDraft.hotline}
                  onChange={(e) =>
                    setSupportDraft({
                      ...supportDraft,
                      hotline: e.target.value,
                    })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none font-bold text-danger"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-muted">
                  Hòm thư điện tử tiếp nhận (Email CSKH):
                </label>
                <input
                  type="text"
                  value={supportDraft.email}
                  onChange={(e) =>
                    setSupportDraft({ ...supportDraft, email: e.target.value })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-muted">
                  Giờ làm việc & Phục vụ:
                </label>
                <input
                  type="text"
                  value={supportDraft.hours}
                  onChange={(e) =>
                    setSupportDraft({ ...supportDraft, hours: e.target.value })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-xs font-medium text-muted">
                  Địa chỉ trụ sở hỗ trợ:
                </label>
                <input
                  type="text"
                  value={supportDraft.address}
                  onChange={(e) =>
                    setSupportDraft({
                      ...supportDraft,
                      address: e.target.value,
                    })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                />
              </div>
            </div>
          </section>

          <section className="rounded-2xl border border-border bg-white p-5 shadow-sm space-y-4">
            <h2 className="text-base font-bold text-ink">
              Danh mục chủ đề hỗ trợ theo vai trò
            </h2>
            <div className="grid gap-4 md:grid-cols-3">
              {supportDraft.categories.map((cat, catIdx) => (
                <div
                  key={cat.id}
                  className="rounded-xl border border-border p-4 bg-canvas/30 space-y-3"
                >
                  <div className="flex items-center gap-2">
                    <span className="grid size-8 place-items-center rounded-lg bg-brand/10 text-brand">
                      <OpsIcon name={cat.icon} className="size-4" />
                    </span>
                    <input
                      type="text"
                      value={cat.title}
                      onChange={(e) => {
                        const newCats = [...supportDraft.categories];
                        newCats[catIdx].title = e.target.value;
                        setSupportDraft({
                          ...supportDraft,
                          categories: newCats,
                        });
                      }}
                      className="font-semibold text-sm text-ink bg-transparent border-b border-border/80 focus:border-brand focus:outline-none w-full"
                    />
                  </div>

                  <div className="space-y-2">
                    <p className="text-[11px] font-medium text-muted">
                      Các vấn đề gợi ý (mỗi dòng 1 mục):
                    </p>
                    <textarea
                      rows={5}
                      value={cat.items.join("\n")}
                      onChange={(e) => {
                        const newCats = [...supportDraft.categories];
                        newCats[catIdx].items = e.target.value
                          .split("\n")
                          .filter((l) => l.trim().length > 0);
                        setSupportDraft({
                          ...supportDraft,
                          categories: newCats,
                        });
                      }}
                      className="w-full rounded-lg border border-border bg-white p-2 text-xs text-ink focus:border-brand focus:outline-none"
                    />
                  </div>
                </div>
              ))}
            </div>
          </section>

          <div className="flex items-center justify-end gap-3 rounded-2xl border border-border bg-white p-4">
            <button
              type="button"
              onClick={() => setConfirmPublish(true)}
              className="inline-flex h-10 items-center justify-center rounded-xl bg-brand px-6 text-sm font-semibold text-white hover:bg-brand/90 transition-colors cursor-pointer"
            >
              Lưu & Xuất bản kênh hỗ trợ
            </button>
          </div>
        </div>
      ) : docDraft ? (
        <div className="space-y-5">
          <section className="rounded-2xl border border-border bg-white p-5 shadow-sm space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border pb-4">
              <div>
                <h2 className="text-base font-bold text-ink">
                  Thông tin văn bản & Phiên bản
                </h2>
                <p className="text-xs text-muted">
                  Cập nhật lần cuối: {formatOpsDateTime(docDraft.updatedAt)} bởi{" "}
                  {docDraft.updatedBy}
                </p>
              </div>
              <StatusChip tone="brand">{docDraft.version}</StatusChip>
            </div>

            <div className="grid gap-4 sm:grid-cols-3">
              <div>
                <label className="block text-xs font-medium text-muted">
                  Tiêu đề văn bản:
                </label>
                <input
                  type="text"
                  value={docDraft.title}
                  onChange={(e) =>
                    setDocDraft({ ...docDraft, title: e.target.value })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none font-semibold"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-muted">
                  Phiên bản văn bản:
                </label>
                <input
                  type="text"
                  value={docDraft.version}
                  onChange={(e) =>
                    setDocDraft({ ...docDraft, version: e.target.value })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none font-mono"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-muted">
                  Ngày hiệu lực:
                </label>
                <input
                  type="text"
                  value={docDraft.effectiveDate}
                  onChange={(e) =>
                    setDocDraft({ ...docDraft, effectiveDate: e.target.value })
                  }
                  className="mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none"
                />
              </div>
              <div className="sm:col-span-3">
                <label className="block text-xs font-medium text-muted">
                  Tóm tắt văn bản:
                </label>
                <textarea
                  rows={2}
                  value={docDraft.summary}
                  onChange={(e) =>
                    setDocDraft({ ...docDraft, summary: e.target.value })
                  }
                  className="mt-1.5 w-full rounded-xl border border-border bg-white p-3 text-sm text-ink focus:border-brand focus:outline-none"
                />
              </div>
            </div>
          </section>

          <section className="rounded-2xl border border-border bg-white p-5 shadow-sm space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-base font-bold text-ink">
                  Các điều khoản & Quy định ({docDraft.sections.length})
                </h2>
                <p className="text-xs text-muted">
                  Chỉnh sửa nội dung hoặc thay đổi thứ tự điều khoản.
                </p>
              </div>
              <button
                type="button"
                onClick={handleAddSection}
                className="inline-flex h-9 items-center gap-1.5 rounded-xl border border-brand/30 bg-brand/5 px-3 text-xs font-semibold text-brand hover:bg-brand/10 transition-colors cursor-pointer"
              >
                <OpsIcon name="plus" className="size-4" />
                Thêm điều khoản mới
              </button>
            </div>

            <div className="space-y-4 divide-y divide-border">
              {docDraft.sections.map((sec, idx) => (
                <div key={sec.id} className="pt-4 first:pt-0 space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex items-center gap-2 flex-1 min-w-[280px]">
                      <span className="grid size-6 place-items-center rounded-md bg-canvas text-xs font-mono font-bold text-muted border border-border shrink-0">
                        {idx + 1}
                      </span>
                      <input
                        type="text"
                        value={sec.title}
                        onChange={(e) =>
                          handleUpdateSection(sec.id, "title", e.target.value)
                        }
                        className="font-bold text-sm text-ink bg-transparent border-b border-border/80 focus:border-brand focus:outline-none w-full"
                      />
                    </div>
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        disabled={idx === 0}
                        onClick={() => handleMoveSection(idx, "up")}
                        title="Di chuyển lên"
                        className="grid size-8 place-items-center rounded-lg border border-border bg-white text-muted hover:text-ink hover:bg-canvas disabled:opacity-30 cursor-pointer"
                      >
                        <OpsIcon
                          name="chevron"
                          className="size-3.5 rotate-180"
                        />
                      </button>
                      <button
                        type="button"
                        disabled={idx === docDraft.sections.length - 1}
                        onClick={() => handleMoveSection(idx, "down")}
                        title="Di chuyển xuống"
                        className="grid size-8 place-items-center rounded-lg border border-border bg-white text-muted hover:text-ink hover:bg-canvas disabled:opacity-30 cursor-pointer"
                      >
                        <OpsIcon name="chevron" className="size-3.5" />
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteSection(sec.id)}
                        title="Xóa điều khoản này"
                        className="grid size-8 place-items-center rounded-lg border border-border bg-white text-danger hover:bg-danger/10 transition-colors cursor-pointer"
                      >
                        <OpsIcon name="close" className="size-4" />
                      </button>
                    </div>
                  </div>

                  <textarea
                    rows={4}
                    value={sec.content}
                    onChange={(e) =>
                      handleUpdateSection(sec.id, "content", e.target.value)
                    }
                    className="w-full rounded-xl border border-border bg-canvas/30 p-3 text-xs leading-relaxed text-ink focus:border-brand focus:bg-white focus:outline-none"
                  />
                </div>
              ))}
            </div>
          </section>

          <div className="flex items-center justify-between gap-3 rounded-2xl border border-border bg-white p-4">
            <span className="text-xs text-muted">
              Lưu thay đổi sẽ cập nhật tức thời giao diện tại trang công khai{" "}
              {liveHref}.
            </span>
            <button
              type="button"
              onClick={() => setConfirmPublish(true)}
              className="inline-flex h-10 items-center justify-center rounded-xl bg-brand px-6 text-sm font-semibold text-white hover:bg-brand/90 transition-colors cursor-pointer"
            >
              Lưu & Xuất bản văn bản
            </button>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={confirmPublish}
        title="Xác nhận lưu và xuất bản thay đổi"
        description={
          <div className="space-y-3">
            <p>
              Các điều khoản hoặc kênh hỗ trợ mới sẽ được cập nhật trực tiếp lên
              hệ thống công khai. Vui lòng ghi lý do cập nhật phục vụ kiểm toán.
            </p>
            <div>
              <label className="block text-xs font-medium text-muted">
                Lý do cập nhật (Ghi nhật ký kiểm toán):
              </label>
              <input
                type="text"
                required
                placeholder="Ví dụ: Cập nhật quy định phí hủy chuyến theo quyết định mới..."
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="mt-1 h-9 w-full rounded-lg border border-border bg-white px-3 text-xs text-ink focus:border-brand focus:outline-none"
              />
            </div>
          </div>
        }
        confirmLabel="Xác nhận xuất bản"
        tone="brand"
        onClose={() => {
          setConfirmPublish(false);
          setReason("");
        }}
        onConfirm={isSupportTab ? handleSaveSupport : handleSaveDoc}
      />

      <ConfirmDialog
        open={confirmReset}
        title="Khôi phục nội dung mặc định"
        description="Bạn có chắc chắn muốn khôi phục lại nội dung mẫu ban đầu? Tất cả các chỉnh sửa cục bộ sẽ bị hủy bỏ."
        confirmLabel="Khôi phục ngay"
        tone="danger"
        onClose={() => setConfirmReset(false)}
        onConfirm={handleReset}
      />
    </div>
  );
}
