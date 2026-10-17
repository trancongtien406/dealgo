"use client";

import type {
  HTMLAttributes,
  ReactNode,
  TdHTMLAttributes,
  ThHTMLAttributes,
} from "react";
import { focusRing } from "@/lib/admin-format";

const DEFAULT_HEAD_CLASS =
  "px-3.5 py-3 font-semibold text-xs uppercase tracking-wider text-muted whitespace-nowrap text-left";
const DEFAULT_CELL_CLASS =
  "px-3.5 py-3 text-sm text-ink whitespace-nowrap align-middle";

export interface AdminTableContainerProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  minWidth?: number | string;
  className?: string;
}

export function AdminTableContainer({
  children,
  minWidth,
  className = "",
  ...props
}: AdminTableContainerProps) {
  const minWidthStyle = minWidth
    ? typeof minWidth === "number"
      ? `${minWidth}px`
      : minWidth
    : undefined;
  return (
    <section
      className={`min-w-0 overflow-hidden rounded-2xl border border-border bg-white shadow-xs ${className}`}
      {...props}
    >
      <div
        className="min-w-0 overflow-x-auto"
        style={minWidthStyle ? { minWidth: minWidthStyle } : undefined}
      >
        {children}
      </div>
    </section>
  );
}

export interface AdminTableProps extends HTMLAttributes<HTMLTableElement> {
  children: ReactNode;
  caption?: string;
  minWidth?: number | string;
  ariaBusy?: boolean;
  className?: string;
}

export function AdminTable({
  children,
  caption,
  minWidth = 860,
  ariaBusy,
  className = "",
  ...props
}: AdminTableProps) {
  const minWidthStyle =
    typeof minWidth === "number" ? `${minWidth}px` : minWidth;
  return (
    <table
      className={`w-full border-collapse text-sm ${className}`}
      style={{ minWidth: minWidthStyle }}
      aria-busy={ariaBusy ? true : undefined}
      {...props}
    >
      {caption ? <caption className="sr-only">{caption}</caption> : null}
      {children}
    </table>
  );
}

export interface AdminTableHeaderProps extends HTMLAttributes<HTMLTableSectionElement> {
  children: ReactNode;
  className?: string;
}

export function AdminTableHeader({
  children,
  className = "",
  ...props
}: AdminTableHeaderProps) {
  return (
    <thead
      className={`border-b border-border bg-canvas/80 text-left ${className}`}
      {...props}
    >
      {children}
    </thead>
  );
}

export interface AdminTableBodyProps extends HTMLAttributes<HTMLTableSectionElement> {
  children: ReactNode;
  className?: string;
}

export function AdminTableBody({
  children,
  className = "",
  ...props
}: AdminTableBodyProps) {
  return (
    <tbody className={`divide-y divide-border/80 ${className}`} {...props}>
      {children}
    </tbody>
  );
}

export interface AdminTableRowProps extends HTMLAttributes<HTMLTableRowElement> {
  children: ReactNode;
  selected?: boolean;
  clickable?: boolean;
  className?: string;
}

export function AdminTableRow({
  children,
  selected = false,
  clickable = false,
  className = "",
  ...props
}: AdminTableRowProps) {
  const interactiveStyles = clickable
    ? `cursor-pointer transition-colors hover:bg-canvas/70 ${focusRing}`
    : "";
  const selectedStyles = selected ? "bg-brand/5" : "";

  return (
    <tr
      className={`border-b border-border/60 transition-colors last:border-b-0 ${interactiveStyles} ${selectedStyles} ${className}`}
      {...props}
    >
      {children}
    </tr>
  );
}

export interface AdminTableHeadProps extends Omit<
  ThHTMLAttributes<HTMLTableCellElement>,
  "align"
> {
  children?: ReactNode;
  align?: "left" | "center" | "right" | string;
  className?: string;
}

export function AdminTableHead({
  children,
  align = "left",
  className = "",
  ...props
}: AdminTableHeadProps) {
  const alignClass =
    align === "right"
      ? "text-right"
      : align === "center"
        ? "text-center"
        : "text-left";

  return (
    <th
      scope="col"
      className={`${DEFAULT_HEAD_CLASS} ${alignClass} ${className}`}
      {...props}
    >
      {children}
    </th>
  );
}

export interface AdminTableCellProps extends Omit<
  TdHTMLAttributes<HTMLTableCellElement>,
  "align"
> {
  children?: ReactNode;
  align?: "left" | "center" | "right" | string;
  wrap?: boolean;
  className?: string;
}

export function AdminTableCell({
  children,
  align = "left",
  wrap = false,
  className = "",
  ...props
}: AdminTableCellProps) {
  const alignClass =
    align === "right"
      ? "text-right"
      : align === "center"
        ? "text-center"
        : "text-left";
  const wrapClass = wrap
    ? "whitespace-normal break-words"
    : "whitespace-nowrap";

  return (
    <td
      className={`${DEFAULT_CELL_CLASS} ${alignClass} ${wrapClass} ${className}`}
      {...props}
    >
      {children}
    </td>
  );
}
