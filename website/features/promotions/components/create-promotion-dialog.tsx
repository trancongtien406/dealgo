"use client";

import { useEffect, useId, useRef, useState } from "react";
import { toast } from "sonner";
import { focusRing, formatCount, formatVnd } from "@/lib/admin-format";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  SearchSelect,
  type SearchSelectOption,
} from "@/components/ui/search-select";
import {
  DatePicker,
  addDaysIso,
  formatIso,
  todayIso,
} from "@/components/ui/date-picker";
import {
  createPromotion,
  type CreatePromotionPayload,
} from "@/features/promotions/api";

const serviceOptions: readonly SearchSelectOption[] = [
  {
    value: "ALL",
    label: "Toàn hệ thống (Ride & Food)",
    description: "Áp dụng cho cả chuyến đi xe máy và đơn giao đồ ăn",
  },
  {
    value: "RIDE",
    label: "Xe 2 bánh (DealGo Ride)",
    description: "Chỉ áp dụng cho các cuốc xe di chuyển",
  },
  {
    value: "FOOD",
    label: "Giao đồ ăn (DealGo Food)",
    description: "Chỉ áp dụng cho các đơn đặt món nhà hàng",
  },
];

const discountTypeOptions: readonly SearchSelectOption[] = [
  {
    value: "FIXED_AMOUNT",
    label: "Số tiền cố định (VNĐ)",
    description: "Khấu trừ một số tiền nhất định vào tổng hóa đơn",
  },
  {
    value: "PERCENTAGE",
    label: "Theo phần trăm (%)",
    description: "Giảm theo tỷ lệ % giá trị đơn (cho phép đặt trần tối đa)",
  },
  {
    value: "DELIVERY_DISCOUNT",
    label: "Giảm phí giao hàng (VNĐ)",
    description: "Khấu trừ trực tiếp vào phí vận chuyển của đơn Food",
  },
];

const audienceOptions: readonly SearchSelectOption[] = [
  {
    value: "CUSTOMER",
    label: "Khách hàng",
    description: "Người dùng đặt xe hoặc đặt món trên ứng dụng",
  },
  {
    value: "DRIVER",
    label: "Tài xế đối tác",
    description: "Chương trình thưởng hoặc trợ giá cho tài xế",
  },
  {
    value: "MERCHANT",
    label: "Cửa hàng đối tác",
    description: "Gói hỗ trợ cho nhà hàng, quán ăn liên kết",
  },
  {
    value: "ALL",
    label: "Tất cả đối tượng",
    description: "Áp dụng mở rộng cho mọi vai trò người dùng",
  },
];

const sponsorOptions: readonly SearchSelectOption[] = [
  {
    value: "PLATFORM",
    label: "Nền tảng DealGo tài trợ",
    description: "DealGo chi trả 100% ngân sách khuyến mãi",
  },
  {
    value: "SHARED",
    label: "Đồng tài trợ (Platform + Merchant)",
    description: "DealGo và quán ăn cùng chia sẻ chi phí; chỉ áp dụng cho đơn đồ ăn",
  },
  {
    value: "MERCHANT",
    label: "Đối tác quán ăn tài trợ",
    description: "Quán ăn tài trợ toàn bộ chi phí; chỉ áp dụng cho đơn đồ ăn",
  },
];

interface CreatePromotionDialogProps {
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function CreatePromotionDialog({
  open,
  onClose,
  onSuccess,
}: CreatePromotionDialogProps) {
  const titleId = useId();
  const codeInputRef = useRef<HTMLInputElement>(null);

  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [serviceType, setServiceType] = useState<"ALL" | "RIDE" | "FOOD">("ALL");
  const [discountType, setDiscountType] = useState<
    "FIXED_AMOUNT" | "PERCENTAGE" | "DELIVERY_DISCOUNT"
  >("FIXED_AMOUNT");
  const [discountValue, setDiscountValue] = useState<number>(20000);
  const [maxDiscountAmount, setMaxDiscountAmount] = useState<number | undefined>(
    undefined,
  );
  const [minOrderAmount, setMinOrderAmount] = useState<number>(50000);
  const [totalBudget, setTotalBudget] = useState<number>(10000000);
  const [usageLimit, setUsageLimit] = useState<number>(500);
  const [userLimit, setUserLimit] = useState<number>(1);
  const [targetAudience, setTargetAudience] = useState<
    "ALL" | "CUSTOMER" | "DRIVER" | "MERCHANT"
  >("CUSTOMER");
  const [sponsor, setSponsor] = useState<"PLATFORM" | "MERCHANT" | "SHARED">(
    "PLATFORM",
  );

  const [startDate, setStartDate] = useState(() => todayIso());
  const [endDate, setEndDate] = useState(() => addDaysIso(todayIso(), 30));

  const [prevOpen, setPrevOpen] = useState(open);
  if (open !== prevOpen) {
    setPrevOpen(open);
    if (open) {
      setFormError(null);
    }
  }

  // Focus input when dialog opens
  useEffect(() => {
    if (!open) return;
    const frame = window.requestAnimationFrame(() => {
      codeInputRef.current?.focus();
    });
    return () => window.cancelAnimationFrame(frame);
  }, [open]);

  // Handle ESC key
  useEffect(() => {
    if (!open) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !submitting) {
        onClose();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, submitting, onClose]);

  if (!open) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const cleanCode = code.trim().toUpperCase().replace(/\s+/g, "");

    if (!cleanCode) {
      const msg = "Vui lòng nhập mã voucher.";
      setFormError(msg);
      toast.error(msg);
      return;
    }
    if (!name.trim()) {
      const msg = "Vui lòng nhập tên chương trình khuyến mãi.";
      setFormError(msg);
      toast.error(msg);
      return;
    }
    if (discountValue <= 0) {
      const msg = "Giá trị giảm giá phải lớn hơn 0.";
      setFormError(msg);
      toast.error(msg);
      return;
    }
    if (discountType === "PERCENTAGE" && discountValue > 100) {
      const msg = "Tỷ lệ giảm giá theo phần trăm không được vượt quá 100%.";
      setFormError(msg);
      toast.error(msg);
      return;
    }
    // DEC-PROD-024: a ride has no merchant to co-fund and no delivery fee to discount.
    if (serviceType === "RIDE" && sponsor !== "PLATFORM") {
      const msg = "Ưu đãi chuyến xe chỉ do DealGo tài trợ.";
      setFormError(msg);
      toast.error(msg);
      return;
    }
    if (serviceType === "RIDE" && discountType === "DELIVERY_DISCOUNT") {
      const msg = "Chuyến xe không có phí giao hàng để giảm.";
      setFormError(msg);
      toast.error(msg);
      return;
    }
    if (startDate >= endDate) {
      const msg = "Thời gian kết thúc phải sau ngày bắt đầu.";
      setFormError(msg);
      toast.error(msg);
      return;
    }

    const payload: CreatePromotionPayload = {
      code: cleanCode,
      name: name.trim(),
      description: description.trim() || name.trim(),
      serviceType,
      discountType,
      discountValue: Number(discountValue),
      maxDiscountAmount:
        discountType === "PERCENTAGE" && maxDiscountAmount
          ? Number(maxDiscountAmount)
          : undefined,
      minOrderAmount: Number(minOrderAmount) || 0,
      totalBudget: Number(totalBudget) || 10000000,
      usageLimit: Number(usageLimit) || 100,
      userLimit: Number(userLimit) || 1,
      targetAudience,
      startDate: `${startDate}T00:00:00.000Z`,
      endDate: `${endDate}T23:59:59.000Z`,
      sponsor,
    };

    setSubmitting(true);
    try {
      await createPromotion(payload);
      toast.success(`Đã tạo chiến dịch voucher ${cleanCode} thành công!`);
      onSuccess();
      onClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Tạo khuyến mãi thất bại.";
      setFormError(msg);
      toast.error(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const discountSummary =
    discountType === "PERCENTAGE"
      ? `Giảm ${discountValue}%` +
        (maxDiscountAmount ? ` (tối đa ${formatVnd(maxDiscountAmount)})` : "")
      : `Giảm ${formatVnd(discountValue)}`;

  return (
    <div
      role="presentation"
      className="fixed inset-0 z-40 flex items-end justify-center bg-ink/40 backdrop-blur-xs p-4 sm:items-center"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget && !submitting) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="relative z-10 w-full max-w-2xl max-h-[92vh] overflow-y-auto rounded-2xl border border-border bg-white p-6 shadow-2xl sm:p-8"
      >
        {/* Header */}
        <div className="flex items-start justify-between gap-3 border-b border-border pb-4">
          <div className="flex items-center gap-3">
            <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-brand/10 text-brand ring-1 ring-brand/20">
              <OpsIcon name="receipt" className="size-5" />
            </span>
            <div>
              <h2 id={titleId} className="text-lg font-bold text-ink">
                Tạo chương trình khuyến mãi / Voucher mới
              </h2>
              <p className="text-xs text-muted">
                Cấu hình mã ưu đãi, điều kiện áp dụng và quản lý ngân sách độc lập
              </p>
            </div>
          </div>
          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            aria-label="Đóng"
            className={`rounded-lg p-1 text-muted hover:bg-canvas hover:text-ink cursor-pointer disabled:opacity-60 ${focusRing}`}
          >
            <OpsIcon name="close" className="size-5" />
          </button>
        </div>

        {/* Error alert banner */}
        {formError ? (
          <div
            role="alert"
            className="mt-4 flex items-center gap-2 rounded-xl border border-danger/20 bg-danger/10 px-3 py-2.5 text-sm text-danger"
          >
            <OpsIcon name="alert" className="size-4 shrink-0" />
            <span>{formError}</span>
          </div>
        ) : null}

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="mt-5 space-y-4">
          {/* Row 1: Code & Name */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label
                htmlFor="promo-code-input"
                className="text-xs font-medium text-muted"
              >
                Mã Voucher <span className="text-danger">*</span>
              </label>
              <div className="relative mt-1.5">
                <span className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted">
                  <OpsIcon name="receipt" className="size-4" />
                </span>
                <input
                  ref={codeInputRef}
                  id="promo-code-input"
                  type="text"
                  placeholder="VD: DEALGO50K, FREESHIP"
                  value={code}
                  onChange={(e) =>
                    setCode(e.target.value.toUpperCase().replace(/\s+/g, ""))
                  }
                  required
                  className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-9 font-mono text-sm font-semibold uppercase text-brand placeholder:font-sans placeholder:font-normal placeholder:text-muted/60 ${focusRing}`}
                />
              </div>
              <p className="mt-1 text-[11px] text-muted">
                Ký tự in hoa, viết liền không dấu
              </p>
            </div>

            <div>
              <label
                htmlFor="promo-name-input"
                className="text-xs font-medium text-muted"
              >
                Tên chiến dịch <span className="text-danger">*</span>
              </label>
              <div className="relative mt-1.5">
                <span className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted">
                  <OpsIcon name="gift" className="size-4" />
                </span>
                <input
                  id="promo-name-input"
                  type="text"
                  placeholder="VD: Ưu đãi cuốc xe giờ cao điểm"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-9 text-sm text-ink placeholder:text-muted/60 ${focusRing}`}
                />
              </div>
              <p className="mt-1 text-[11px] text-muted">
                Tiêu đề hiển thị cho người dùng và đối tác
              </p>
            </div>
          </div>

          {/* Row 2: Description */}
          <div>
            <label
              htmlFor="promo-desc-input"
              className="text-xs font-medium text-muted"
            >
              Mô tả chi tiết / Thể lệ áp dụng
            </label>
            <textarea
              id="promo-desc-input"
              rows={2}
              placeholder="VD: Giảm 20.000đ cho chuyến đi xe 2 bánh hoặc đơn đặt món từ 50.000đ tại khu vực Đà Nẵng..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className={`mt-1.5 w-full rounded-xl border border-border bg-white p-3 text-sm text-ink placeholder:text-muted/60 ${focusRing}`}
            />
          </div>

          {/* Row 3: Service Type & Discount Type (SearchSelect) */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <SearchSelect
              label="Dịch vụ áp dụng *"
              value={serviceType}
              options={serviceOptions}
              placeholder="Chọn dịch vụ…"
              clearLabel="Toàn hệ thống"
              icon="sliders"
              onChange={(val) => {
                const next = (val as "ALL" | "RIDE" | "FOOD") || "ALL";
                setServiceType(next);
                if (next === "RIDE") {
                  setSponsor("PLATFORM");
                  if (discountType === "DELIVERY_DISCOUNT") {
                    setDiscountType("FIXED_AMOUNT");
                  }
                }
              }}
            />

            <SearchSelect
              label="Hình thức giảm giá *"
              value={discountType}
              options={
                serviceType === "RIDE"
                  ? discountTypeOptions.filter(
                      (o) => o.value !== "DELIVERY_DISCOUNT",
                    )
                  : discountTypeOptions
              }
              placeholder="Chọn loại giảm giá…"
              clearLabel="Số tiền cố định"
              icon="receipt"
              onChange={(val) =>
                setDiscountType(
                  (val as
                    | "FIXED_AMOUNT"
                    | "PERCENTAGE"
                    | "DELIVERY_DISCOUNT") || "FIXED_AMOUNT",
                )
              }
            />
          </div>

          {/* Row 4: Discount value & Cap / Min order */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label
                htmlFor="promo-value-input"
                className="text-xs font-medium text-muted"
              >
                {discountType === "PERCENTAGE"
                  ? "Tỷ lệ giảm (%) *"
                  : "Mức giảm (VNĐ) *"}
              </label>
              <input
                id="promo-value-input"
                type="number"
                min={1}
                max={discountType === "PERCENTAGE" ? 100 : 10000000}
                step={discountType === "PERCENTAGE" ? 1 : 1000}
                value={discountValue}
                onChange={(e) => setDiscountValue(Number(e.target.value))}
                required
                className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              />
              <p className="mt-1 text-[11px] text-muted">
                {discountType === "PERCENTAGE"
                  ? `Giảm ${discountValue}% giá trị đơn hàng`
                  : `Tương đương: ${formatVnd(discountValue)}`}
              </p>
            </div>

            {discountType === "PERCENTAGE" ? (
              <div>
                <label
                  htmlFor="promo-max-input"
                  className="text-xs font-medium text-muted"
                >
                  Mức giảm tối đa (VNĐ)
                </label>
                <input
                  id="promo-max-input"
                  type="number"
                  min={1000}
                  step={1000}
                  placeholder="Để trống nếu không giới hạn"
                  value={maxDiscountAmount ?? ""}
                  onChange={(e) =>
                    setMaxDiscountAmount(
                      e.target.value ? Number(e.target.value) : undefined,
                    )
                  }
                  className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink placeholder:text-muted/60 ${focusRing}`}
                />
                <p className="mt-1 text-[11px] text-muted">
                  {maxDiscountAmount
                    ? `Trần tối đa: ${formatVnd(maxDiscountAmount)}`
                    : "Không áp trần tối đa"}
                </p>
              </div>
            ) : (
              <div>
                <label
                  htmlFor="promo-min-order-input"
                  className="text-xs font-medium text-muted"
                >
                  Giá trị đơn tối thiểu (VNĐ)
                </label>
                <input
                  id="promo-min-order-input"
                  type="number"
                  min={0}
                  step={5000}
                  value={minOrderAmount}
                  onChange={(e) => setMinOrderAmount(Number(e.target.value))}
                  required
                  className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
                />
                <p className="mt-1 text-[11px] text-muted">
                  {minOrderAmount > 0
                    ? `Áp dụng từ đơn ${formatVnd(minOrderAmount)}`
                    : "Không yêu cầu đơn tối thiểu"}
                </p>
              </div>
            )}
          </div>

          {/* Additional row for minOrderAmount when PERCENTAGE is chosen */}
          {discountType === "PERCENTAGE" ? (
            <div>
              <label
                htmlFor="promo-min-order-percent"
                className="text-xs font-medium text-muted"
              >
                Giá trị đơn tối thiểu (VNĐ)
              </label>
              <input
                id="promo-min-order-percent"
                type="number"
                min={0}
                step={5000}
                value={minOrderAmount}
                onChange={(e) => setMinOrderAmount(Number(e.target.value))}
                required
                className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              />
              <p className="mt-1 text-[11px] text-muted">
                {minOrderAmount > 0
                  ? `Áp dụng từ đơn ${formatVnd(minOrderAmount)}`
                  : "Không yêu cầu đơn tối thiểu"}
              </p>
            </div>
          ) : null}

          {/* Row 5: Budget & Limits */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor="promo-budget-input"
                className="text-xs font-medium text-muted"
              >
                Tổng ngân sách (VNĐ) *
              </label>
              <input
                id="promo-budget-input"
                type="number"
                min={10000}
                step={100000}
                value={totalBudget}
                onChange={(e) => setTotalBudget(Number(e.target.value))}
                required
                className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              />
              <p className="mt-1 text-[11px] text-muted">
                Quỹ dự chi: {formatVnd(totalBudget)}
              </p>
            </div>

            <div>
              <label
                htmlFor="promo-usage-limit-input"
                className="text-xs font-medium text-muted"
              >
                Số lượt dùng tối đa *
              </label>
              <input
                id="promo-usage-limit-input"
                type="number"
                min={1}
                value={usageLimit}
                onChange={(e) => setUsageLimit(Number(e.target.value))}
                required
                className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              />
              <p className="mt-1 text-[11px] text-muted">
                Tổng {formatCount(usageLimit)} lượt quy đổi
              </p>
            </div>

            <div>
              <label
                htmlFor="promo-user-limit-input"
                className="text-xs font-medium text-muted"
              >
                Lượt dùng / khách *
              </label>
              <input
                id="promo-user-limit-input"
                type="number"
                min={1}
                value={userLimit}
                onChange={(e) => setUserLimit(Number(e.target.value))}
                required
                className={`mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
              />
              <p className="mt-1 text-[11px] text-muted">
                Tối đa {userLimit} lần / tài khoản
              </p>
            </div>
          </div>

          {/* Row 6: Dates (DatePicker components) */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <DatePicker
              label="Ngày bắt đầu *"
              value={startDate}
              onChange={(val) => {
                if (val) setStartDate(val);
              }}
            />

            <DatePicker
              label="Ngày kết thúc *"
              value={endDate}
              onChange={(val) => {
                if (val) setEndDate(val);
              }}
            />
          </div>

          {/* Row 7: Audience & Sponsor (SearchSelect) */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <SearchSelect
              label="Đối tượng áp dụng *"
              value={targetAudience}
              options={audienceOptions}
              placeholder="Chọn đối tượng…"
              clearLabel="Khách hàng"
              icon="user"
              onChange={(val) =>
                setTargetAudience(
                  (val as "ALL" | "CUSTOMER" | "DRIVER" | "MERCHANT") ||
                    "CUSTOMER",
                )
              }
            />

            <SearchSelect
              label="Nguồn tài trợ *"
              value={sponsor}
              options={
                serviceType === "RIDE"
                  ? sponsorOptions.filter((o) => o.value === "PLATFORM")
                  : sponsorOptions
              }
              placeholder="Chọn nguồn tài trợ…"
              clearLabel="Nền tảng DealGo"
              icon="shield"
              onChange={(val) =>
                setSponsor(
                  (val as "PLATFORM" | "MERCHANT" | "SHARED") || "PLATFORM",
                )
              }
            />
          </div>

          {/* Live Preview Voucher Ticket Box */}
          <div className="rounded-xl border border-dashed border-border bg-canvas/40 p-4 transition-all">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[11px] font-semibold uppercase tracking-wider text-muted">
                Xem trước Voucher (Live Preview)
              </span>
              <span className="rounded-md bg-brand/10 px-2 py-0.5 font-mono text-xs font-bold text-brand">
                {code ? code.toUpperCase() : "MÃ_VOUCHER"}
              </span>
            </div>
            <div className="mt-2.5 flex flex-wrap items-center justify-between gap-3 border-t border-border/60 pt-2.5">
              <div>
                <p className="text-sm font-bold text-ink">
                  {name.trim() || "Tên chương trình ưu đãi"}
                </p>
                <p className="text-xs text-muted">
                  {discountSummary} •{" "}
                  {minOrderAmount > 0
                    ? `Đơn từ ${formatVnd(minOrderAmount)}`
                    : "Mọi đơn hàng"}
                </p>
              </div>
              <div className="text-right">
                <p className="text-xs font-medium text-ink">
                  {formatIso(startDate)} → {formatIso(endDate)}
                </p>
                <p className="text-[11px] text-muted">
                  Ngân sách: {formatVnd(totalBudget)}
                </p>
              </div>
            </div>
          </div>

          {/* Modal Actions */}
          <div className="flex items-center justify-end gap-3 border-t border-border pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className={`inline-flex h-10 items-center justify-center rounded-xl border border-border bg-white px-4 text-sm font-medium text-ink hover:bg-canvas transition-colors cursor-pointer disabled:opacity-50 ${focusRing}`}
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={submitting}
              className={`inline-flex h-10 items-center gap-2 rounded-xl border border-transparent bg-brand px-5 text-sm font-semibold text-white shadow-sm hover:bg-brand/90 transition-colors cursor-pointer disabled:opacity-50 ${focusRing}`}
            >
              {submitting ? (
                <>
                  <OpsIcon name="refresh" className="size-4 animate-spin" />
                  <span>Đang lưu...</span>
                </>
              ) : (
                <>
                  <OpsIcon name="check" className="size-4" />
                  <span>Tạo chiến dịch</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
