"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { OpsIcon } from "@/components/ui/ops-icons";
import { adminNavSections, isAdminNavCurrent } from "@/lib/admin-nav-items";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

export function AdminNav({
  onNavigate,
  collapsed = false,
}: {
  onNavigate?: () => void;
  /** Desktop icon rail — mobile drawer always shows labels. */
  collapsed?: boolean;
}) {
  const pathname = usePathname();
  const [openMegaMenu, setOpenMegaMenu] = useState(false);
  const [megaSearch, setMegaSearch] = useState("");
  const [expandedItems, setExpandedItems] = useState<Record<string, boolean>>(
    () => {
      const initial: Record<string, boolean> = {};
      for (const section of adminNavSections) {
        for (const item of section.items) {
          if (item.children && item.children.length > 0) {
            initial[item.href] = true;
          }
        }
      }
      return initial;
    },
  );

  function toggleExpand(href: string, fallbackDefault = true) {
    setExpandedItems((prev) => ({
      ...prev,
      [href]: !(prev[href] !== undefined ? prev[href] : fallbackDefault),
    }));
  }

  // Filter items in Mega Menu modal
  const filteredSections = adminNavSections
    .map((sec) => ({
      ...sec,
      items: sec.items.filter((item) => {
        if (!megaSearch.trim()) return true;
        const q = megaSearch.trim().toLowerCase();
        const inLabel = item.label.toLowerCase().includes(q);
        const inChildren = item.children?.some((c) =>
          c.label.toLowerCase().includes(q),
        );
        const inKeywords = item.keywords?.some((k) =>
          k.toLowerCase().includes(q),
        );
        return inLabel || inChildren || inKeywords;
      }),
    }))
    .filter((sec) => sec.items.length > 0);

  return (
    <nav
      aria-label="Phân hệ quản trị"
      className={collapsed ? "px-2 pb-4" : "px-3 pb-6 space-y-4"}
    >
      {/* Sections and Hierarchical Tree Items */}
      {adminNavSections.map((section, sIndex) => (
        <div key={section.title} className={sIndex > 0 ? "pt-3" : ""}>
          {!collapsed && (
            <div className="px-3 pb-1.5">
              <h2 className="text-[11px] font-bold tracking-wider uppercase text-muted">
                {section.title}
              </h2>
            </div>
          )}

          <ul className="flex flex-col gap-1">
            {section.items.map((item) => {
              const current = isAdminNavCurrent(pathname, item.href);
              const isAudit = item.href === "/audit-logs";
              const hasChildren = Boolean(
                item.children && item.children.length > 0,
              );
              const isChildActive = Boolean(
                item.children?.some(
                  (c) =>
                    pathname === c.href || pathname.startsWith(`${c.href}/`),
                ),
              );
              const isExpanded =
                expandedItems[item.href] !== undefined
                  ? expandedItems[item.href]
                  : isChildActive;

              return (
                <li key={item.href} className="group/item">
                  {hasChildren ? (
                    <button
                      type="button"
                      onClick={() => toggleExpand(item.href, isChildActive)}
                      title={item.label}
                      className={
                        collapsed
                          ? `flex size-10 items-center justify-center rounded-xl mx-auto transition-colors ${
                              current || isChildActive
                                ? "bg-brand/10 font-semibold text-brand shadow-xs"
                                : "text-ink hover:bg-canvas"
                            } ${focusRing}`
                          : `flex w-full items-center justify-between gap-2.5 rounded-xl px-3 py-2 text-sm transition-colors cursor-pointer ${
                              current || isChildActive
                                ? "bg-brand/10 font-semibold text-brand shadow-xs"
                                : "text-ink hover:bg-canvas"
                            } ${focusRing}`
                      }
                    >
                      <span className="flex items-center gap-3 min-w-0">
                        <OpsIcon
                          name={item.icon}
                          className={`size-4.5 shrink-0 ${
                            current || isChildActive
                              ? "text-brand"
                              : "text-muted group-hover/item:text-ink"
                          }`}
                        />
                        {!collapsed && (
                          <span className="truncate">{item.label}</span>
                        )}
                      </span>
                      {!collapsed && (
                        <span className="flex items-center gap-1.5 shrink-0">
                          {item.badge && (
                            <span className="rounded-full bg-brand/15 px-2 py-0.5 text-[10px] font-semibold text-brand">
                              {item.badge}
                            </span>
                          )}
                          <OpsIcon
                            name="chevron"
                            className={`size-3.5 text-muted transition-transform duration-200 ${
                              isExpanded ? "rotate-180" : ""
                            }`}
                          />
                        </span>
                      )}
                    </button>
                  ) : (
                    <Link
                      href={item.href}
                      aria-current={current ? "page" : undefined}
                      title={item.label}
                      onClick={onNavigate}
                      className={
                        collapsed
                          ? `flex size-10 items-center justify-center rounded-xl mx-auto transition-colors ${
                              current
                                ? "bg-brand/10 font-semibold text-brand shadow-xs"
                                : isAudit
                                  ? "text-brand hover:bg-brand/5"
                                  : "text-ink hover:bg-canvas"
                            } ${focusRing}`
                          : `flex w-full items-center justify-between gap-2.5 rounded-xl px-3 py-2 text-sm transition-colors ${
                              current
                                ? "bg-brand/10 font-bold text-brand shadow-xs"
                                : isAudit
                                  ? "bg-brand/5 font-semibold text-brand hover:bg-brand/10"
                                  : "text-ink hover:bg-canvas"
                            } ${focusRing}`
                      }
                    >
                      <span className="flex items-center gap-3 min-w-0">
                        <OpsIcon
                          name={item.icon}
                          className={`size-4.5 shrink-0 ${
                            current
                              ? "text-brand"
                              : isAudit
                                ? "text-brand"
                                : "text-muted group-hover/item:text-ink"
                          }`}
                        />
                        {!collapsed && (
                          <span className="truncate">{item.label}</span>
                        )}
                      </span>
                      {!collapsed && item.badge && (
                        <span className="rounded-full bg-brand/15 px-2 py-0.5 text-[10px] font-semibold text-brand shrink-0">
                          {item.badge}
                        </span>
                      )}
                    </Link>
                  )}

                  {/* Hierarchical Sub-Navigation Tree */}
                  {!collapsed && hasChildren && isExpanded && (
                    <ul className="mt-1 ml-4 pl-3 border-l-2 border-brand/20 flex flex-col gap-1 py-1">
                      {item.children!.map((child) => {
                        const childCurrent = pathname === child.href;
                        return (
                          <li key={child.href}>
                            <Link
                              href={child.href}
                              onClick={onNavigate}
                              aria-current={childCurrent ? "page" : undefined}
                              className={`flex items-center justify-between rounded-lg px-2.5 py-1.5 text-xs transition-colors ${
                                childCurrent
                                  ? "bg-brand/10 font-bold text-brand"
                                  : "text-muted font-medium hover:text-ink hover:bg-canvas"
                              } ${focusRing}`}
                            >
                              <span className="flex items-center gap-2 truncate">
                                <span
                                  className={`size-1.5 rounded-full shrink-0 ${
                                    childCurrent
                                      ? "bg-brand scale-125"
                                      : "bg-muted/40"
                                  }`}
                                />
                                <span className="truncate">{child.label}</span>
                              </span>
                              {child.badge && (
                                <span
                                  className={`shrink-0 rounded px-1.5 py-0.2 text-[9px] font-semibold ${
                                    childCurrent
                                      ? "bg-brand text-white"
                                      : "bg-canvas text-muted border border-border"
                                  }`}
                                >
                                  {child.badge}
                                </span>
                              )}
                            </Link>
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      ))}

      {!collapsed && (
        <div className="mt-4 border-t border-border pt-3 pb-2 px-1">
          <div className="flex items-center justify-between text-[11px] text-muted">
            <Link
              href="/support"
              onClick={onNavigate}
              className="hover:text-brand transition-colors inline-flex items-center gap-1"
            >
              <OpsIcon name="headset" className="size-3 text-muted" />
              Hỗ trợ
            </Link>
            <span>·</span>
            <Link
              href="/terms"
              onClick={onNavigate}
              className="hover:text-brand transition-colors"
            >
              Điều khoản
            </Link>
            <span>·</span>
            <Link
              href="/privacy"
              onClick={onNavigate}
              className="hover:text-brand transition-colors"
            >
              Bảo mật
            </Link>
          </div>
        </div>
      )}

      {/* Mega Menu Modal / Backdrop */}
      {openMegaMenu && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Mega Menu Toàn bộ Phân hệ"
          className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 md:p-10 bg-ink/40 backdrop-blur-xs animate-in fade-in duration-200"
          onClick={() => setOpenMegaMenu(false)}
        >
          <div
            className="w-full max-w-5xl max-h-[85vh] overflow-hidden rounded-3xl border border-border bg-white shadow-2xl flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between border-b border-border px-6 py-4 bg-canvas/40">
              <div className="flex items-center gap-3">
                <div className="grid size-9 place-items-center rounded-xl bg-brand/10 text-brand font-bold">
                  <OpsIcon name="menu" className="size-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-ink">
                    Mega Menu Điều Hành DealGo
                  </h3>
                  <p className="text-xs text-muted">
                    Truy cập nhanh mọi phân hệ, hàng đợi KYC, duyệt quán, kiểm
                    toán và cấu hình.
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setOpenMegaMenu(false)}
                className={`rounded-xl p-2 text-muted hover:bg-canvas hover:text-ink ${focusRing}`}
                aria-label="Đóng Mega Menu"
              >
                <OpsIcon name="close" className="size-5" />
              </button>
            </div>

            {/* Quick Search in Mega Menu */}
            <div className="px-6 py-3 border-b border-border/60 bg-white">
              <div className="relative">
                <input
                  type="search"
                  autoFocus
                  placeholder="Tìm nhanh phân hệ (ví dụ: audit, kyc, đối soát, khiếu nại, chuyến xe)..."
                  value={megaSearch}
                  onChange={(e) => setMegaSearch(e.target.value)}
                  className={`w-full rounded-xl border border-border bg-canvas/50 px-3 py-2 pl-9 text-sm text-ink placeholder:text-muted ${focusRing}`}
                />
                <OpsIcon
                  name="search"
                  className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
                />
              </div>
            </div>

            {/* Content: 4 Columns Grid */}
            <div className="flex-1 overflow-y-auto p-6">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {filteredSections.map((sec) => (
                  <div key={sec.title} className="space-y-3">
                    <div className="border-b border-brand/20 pb-1.5">
                      <span className="text-xs font-bold tracking-wider uppercase text-brand">
                        {sec.title}
                      </span>
                    </div>
                    <ul className="space-y-1">
                      {sec.items.map((item) => {
                        const isAudit = item.href === "/audit-logs";
                        return (
                          <li key={item.href} className="space-y-1">
                            <Link
                              href={item.href}
                              onClick={() => {
                                setOpenMegaMenu(false);
                                onNavigate?.();
                              }}
                              className={`flex items-center justify-between gap-2 rounded-xl px-2.5 py-2 text-xs font-medium transition-colors ${
                                isAudit
                                  ? "bg-brand/10 text-brand font-semibold hover:bg-brand/20"
                                  : "text-ink hover:bg-canvas"
                              } ${focusRing}`}
                            >
                              <span className="flex items-center gap-2">
                                <OpsIcon
                                  name={item.icon}
                                  className={`size-4 ${isAudit ? "text-brand" : "text-muted"}`}
                                />
                                <span>{item.label}</span>
                              </span>
                              {item.badge && (
                                <span className="rounded-full bg-brand/10 px-1.5 py-0.2 text-[9px] font-bold text-brand">
                                  {item.badge}
                                </span>
                              )}
                            </Link>

                            {/* Render child links in mega menu */}
                            {item.children && (
                              <ul className="ml-4 pl-2 border-l border-border/80 space-y-0.5">
                                {item.children.map((c) => (
                                  <li key={c.href}>
                                    <Link
                                      href={c.href}
                                      onClick={() => {
                                        setOpenMegaMenu(false);
                                        onNavigate?.();
                                      }}
                                      className={`flex items-center justify-between rounded-lg px-2 py-1 text-[11px] text-muted hover:text-ink hover:bg-canvas transition-colors ${focusRing}`}
                                    >
                                      <span>{c.label}</span>
                                      {c.badge && (
                                        <span className="rounded bg-canvas px-1 text-[9px] font-mono border border-border">
                                          {c.badge}
                                        </span>
                                      )}
                                    </Link>
                                  </li>
                                ))}
                              </ul>
                            )}
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                ))}
              </div>
            </div>

            {/* Footer */}
            <div className="border-t border-border px-6 py-3 bg-canvas/40 flex items-center justify-between text-xs text-muted">
              <div className="flex items-center gap-3">
                <span>DealGo Admin Operations Platform · 2026</span>
                <span>·</span>
                <Link
                  href="/support"
                  onClick={() => {
                    setOpenMegaMenu(false);
                    onNavigate?.();
                  }}
                  className="hover:text-brand transition-colors"
                >
                  Trung tâm hỗ trợ
                </Link>
                <span>·</span>
                <Link
                  href="/terms"
                  onClick={() => {
                    setOpenMegaMenu(false);
                    onNavigate?.();
                  }}
                  className="hover:text-brand transition-colors"
                >
                  Điều khoản
                </Link>
                <span>·</span>
                <Link
                  href="/privacy"
                  onClick={() => {
                    setOpenMegaMenu(false);
                    onNavigate?.();
                  }}
                  className="hover:text-brand transition-colors"
                >
                  Quyền riêng tư
                </Link>
              </div>
              <span className="font-mono text-[11px]">
                Bấm ESC hoặc nhấn ra ngoài để đóng
              </span>
            </div>
          </div>
        </div>
      )}
    </nav>
  );
}
