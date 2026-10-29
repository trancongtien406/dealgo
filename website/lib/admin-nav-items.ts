import type { OpsIconName } from "@/components/ui/ops-icons";

export type AdminNavHref =
  | "/overview"
  | "/monitor"
  | "/exceptions"
  | "/rides"
  | "/negotiations"
  | "/food-orders"
  | "/deliveries"
  | "/customers"
  | "/drivers"
  | "/stores"
  | "/transactions"
  | "/settlements"
  | "/refunds"
  | "/online-payments"
  | "/disputes"
  | "/support-tickets"
  | "/promotions"
  | "/catalog"
  | "/reports"
  | "/notifications"
  | "/zones"
  | "/staff"
  | "/audit-logs"
  | "/settings"
  | "/settings/platform"
  | "/settings/faqs"
  | "/settings/auth-methods"
  | "/settings/maps"
  | "/settings/payments"
  | "/settings/website"
  | "/settings/email"
  | "/settings/sentry"
  | "/system-errors"
  | "/settings/vehicle-classes"
  | "/settings/content"
  | "/settings/home-banners"
  | "/drivers/kyc"
  | "/stores/approvals"
  | "/catalog/moderation"
  | "/reviews"
  | "/support"
  | "/terms"
  | "/privacy";

export type AdminNavChildItem = {
  label: string;
  href: AdminNavHref;
  badge?: string;
  keywords?: readonly string[];
};

export type AdminNavItem = {
  label: string;
  icon: OpsIconName;
  href: AdminNavHref;
  badge?: string;
  children?: readonly AdminNavChildItem[];
  keywords?: readonly string[];
};

export type AdminNavSection = {
  title: string;
  items: readonly AdminNavItem[];
};

export const adminNavSections: readonly AdminNavSection[] = [
  {
    title: "VẬN HÀNH",
    items: [
      {
        label: "Tổng quan",
        icon: "overview",
        href: "/overview",
        keywords: ["overview", "dashboard"],
      },
      {
        label: "Giám sát live",
        icon: "monitor",
        href: "/monitor",
        keywords: ["live", "monitor", "bản đồ"],
      },
      {
        label: "Ngoại lệ",
        icon: "alert",
        href: "/exceptions",
        keywords: ["exceptions", "alerts"],
      },
      {
        label: "Chuyến xe Ride",
        icon: "car",
        href: "/rides",
        keywords: ["rides", "xe", "trả giá"],
        children: [
          { label: "Chuyến xe", href: "/rides" },
          { label: "Phiên trả giá", href: "/negotiations" },
        ],
      },
      {
        label: "Food & Giao hàng",
        icon: "utensils",
        href: "/food-orders",
        keywords: ["food", "orders", "giao hàng"],
        children: [
          { label: "Đơn món ăn", href: "/food-orders" },
          { label: "Giao hàng", href: "/deliveries" },
        ],
      },
    ],
  },
  {
    title: "ĐỐI TÁC & MENU",
    items: [
      {
        label: "Tài xế",
        icon: "driver",
        href: "/drivers",
        keywords: ["drivers", "partners"],
        children: [
          { label: "Danh sách", href: "/drivers" },
          { label: "Duyệt KYC", href: "/drivers/kyc", badge: "KYC" },
        ],
      },
      {
        label: "Cửa hàng",
        icon: "store",
        href: "/stores",
        keywords: ["stores", "merchants"],
        children: [
          { label: "Danh sách", href: "/stores" },
          { label: "Duyệt quán", href: "/stores/approvals", badge: "Duyệt" },
        ],
      },
      {
        label: "Khách hàng",
        icon: "users",
        href: "/customers",
        keywords: ["customers"],
      },
      {
        label: "Danh mục",
        icon: "categories",
        href: "/catalog",
        keywords: ["catalog", "ngành hàng", "menu"],
        children: [
          { label: "Ngành hàng đồ ăn", href: "/catalog" },
          {
            label: "Kiểm duyệt món",
            href: "/catalog/moderation",
            badge: "Kiểm duyệt",
          },
          { label: "Đánh giá quán", href: "/reviews" },
        ],
      },
    ],
  },
  {
    title: "TÀI CHÍNH",
    items: [
      {
        label: "Dòng tiền",
        icon: "wallet",
        href: "/transactions",
        keywords: ["transactions", "payments"],
        children: [
          { label: "Giao dịch", href: "/transactions" },
          { label: "Đối soát", href: "/settlements" },
          { label: "Hoàn tiền", href: "/refunds" },
          { label: "Thanh toán online", href: "/online-payments" },
        ],
      },
      {
        label: "Khiếu nại & KM",
        icon: "alert",
        href: "/disputes",
        keywords: ["disputes", "promotions", "support", "hỗ trợ", "ticket"],
        children: [
          { label: "Khiếu nại", href: "/disputes", badge: "Ưu tiên" },
          { label: "Yêu cầu hỗ trợ", href: "/support-tickets" },
          { label: "Khuyến mãi", href: "/promotions", badge: "Thử nghiệm" },
        ],
      },
    ],
  },
  {
    title: "HỆ THỐNG",
    items: [
      {
        label: "Kiểm toán",
        icon: "shield",
        href: "/audit-logs",
        badge: "Audit",
        keywords: ["audit", "logs", "kiểm toán"],
      },
      {
        label: "Lỗi hệ thống",
        icon: "alert",
        href: "/system-errors",
        keywords: ["sentry", "errors", "crash", "lỗi"],
      },
      {
        label: "Báo cáo",
        icon: "chart",
        href: "/reports",
        keywords: ["reports"],
      },
      {
        label: "Khu vực & Giá",
        icon: "pin",
        href: "/zones",
        keywords: ["zones", "pricing"],
      },
      {
        label: "Thông báo",
        icon: "bell",
        href: "/notifications",
        keywords: ["notifications", "cms"],
      },
      {
        label: "Nhân sự",
        icon: "staff",
        href: "/staff",
        keywords: ["staff"],
      },
      {
        label: "Cài đặt",
        icon: "settings",
        href: "/settings",
        keywords: ["settings"],
        children: [
          { label: "Tổng quan", href: "/settings" },
          { label: "Tham số", href: "/settings/platform" },
          { label: "Chính sách OPEN", href: "/settings/faqs" },
          { label: "Đăng nhập", href: "/settings/auth-methods" },
          { label: "Bản đồ", href: "/settings/maps" },
          { label: "Thanh toán", href: "/settings/payments" },
          { label: "Website & MXH", href: "/settings/website" },
          { label: "Email", href: "/settings/email" },
          { label: "Sentry", href: "/settings/sentry" },
          { label: "Loại xe", href: "/settings/vehicle-classes" },
          { label: "Nội dung & Pháp lý", href: "/settings/content" },
          { label: "Banner trang chủ", href: "/settings/home-banners" },
        ],
      },
    ],
  },
];

/** Compatibility flat groups */
export const adminNavGroups: readonly (readonly AdminNavItem[])[] =
  adminNavSections.map((s) => s.items);

/** Extra command-palette destinations */
export const adminCommandExtras: readonly AdminNavItem[] = [
  {
    label: "Nhật ký kiểm toán",
    icon: "shield",
    href: "/audit-logs",
    keywords: ["audit", "log", "kiểm toán"],
  },
  {
    label: "Cài đặt nền tảng",
    icon: "settings",
    href: "/settings/platform",
    keywords: ["platform settings"],
  },
  {
    label: "Câu hỏi thường gặp",
    icon: "headset",
    href: "/settings/faqs",
    keywords: ["faq", "faqs"],
  },
  {
    label: "Phương thức đăng nhập",
    icon: "lock",
    href: "/settings/auth-methods",
    keywords: ["auth methods", "login"],
  },
  {
    label: "Nhà cung cấp bản đồ",
    icon: "pin",
    href: "/settings/maps",
    keywords: ["maps", "bản đồ", "google", "mapbox", "địa chỉ"],
  },
  {
    label: "Thanh toán online & hoàn tiền",
    icon: "wallet",
    href: "/online-payments",
    keywords: ["payment intent", "thanh toán online", "hoàn tiền", "refund", "momo", "zalopay", "vnpay", "đối soát"],
  },
  {
    label: "Phương thức thanh toán",
    icon: "settings",
    href: "/settings/payments",
    keywords: ["payment", "thanh toán", "momo", "zalopay", "vnpay", "ví"],
  },
  {
    label: "Website: link ứng dụng & mạng xã hội",
    icon: "settings",
    href: "/settings/website",
    keywords: ["app store", "google play", "qr", "facebook", "tiktok", "zalo", "youtube", "instagram", "mạng xã hội", "website"],
  },
  {
    label: "Email (Gmail / SES)",
    icon: "mail",
    href: "/settings/email",
    keywords: ["email", "smtp", "gmail", "ses", "otp"],
  },
  {
    label: "Sentry (theo dõi lỗi)",
    icon: "alert",
    href: "/settings/sentry",
    keywords: ["sentry", "token", "errors"],
  },
  {
    label: "Loại xe",
    icon: "car",
    href: "/settings/vehicle-classes",
    keywords: ["vehicle", "xe", "giá"],
  },
  {
    label: "Banner trang chủ app",
    icon: "categories",
    href: "/settings/home-banners",
    keywords: ["banner", "home", "carousel", "khuyến mãi", "quảng cáo"],
  },
  {
    label: "Hàng đợi KYC tài xế",
    icon: "shield",
    href: "/drivers/kyc",
    keywords: ["kyc"],
  },
  {
    label: "Duyệt cửa hàng",
    icon: "store",
    href: "/stores/approvals",
    keywords: ["store approvals"],
  },
  {
    label: "Kiểm duyệt danh mục",
    icon: "categories",
    href: "/catalog/moderation",
    keywords: ["catalog moderation"],
  },
  {
    label: "Quản lý nội dung CMS",
    icon: "categories",
    href: "/settings/content",
    keywords: ["cms", "nội dung", "legal", "điều khoản", "support", "hỗ trợ"],
  },
  {
    label: "Trung tâm hỗ trợ",
    icon: "headset",
    href: "/support",
    keywords: ["support", "hỗ trợ", "help"],
  },
  {
    label: "Điều khoản sử dụng",
    icon: "shield",
    href: "/terms",
    keywords: ["terms", "điều khoản"],
  },
  {
    label: "Chính sách quyền riêng tư",
    icon: "shield",
    href: "/privacy",
    keywords: ["privacy", "quyền riêng tư", "bảo mật"],
  },
];

export function flattenAdminNavItems(): AdminNavItem[] {
  const result: AdminNavItem[] = [];
  for (const s of adminNavSections) {
    for (const item of s.items) {
      result.push(item);
      if (item.children) {
        for (const c of item.children) {
          result.push({
            label: c.label,
            icon: item.icon,
            href: c.href,
            badge: c.badge,
            keywords: c.keywords,
          });
        }
      }
    }
  }
  return result;
}

/** Palette entries unique by href; child label wins when parent shares the same path. */
export function flattenAdminNavItemsForPalette(): AdminNavItem[] {
  const byHref = new Map<string, AdminNavItem>();
  for (const item of flattenAdminNavItems()) {
    byHref.set(item.href, item);
  }
  return [...byHref.values()];
}

export function isAdminNavCurrent(pathname: string, href: AdminNavHref) {
  if (href === "/overview") {
    return pathname === "/" || pathname === "/overview";
  }
  if (href === "/settings") {
    return pathname === "/settings";
  }
  if (href === "/audit-logs") {
    return pathname === "/audit-logs" || pathname.startsWith("/audit-logs/");
  }
  if (href === "/transactions") {
    return pathname === "/transactions";
  }
  if (href === "/disputes") {
    return pathname === "/disputes" || pathname.startsWith("/disputes/");
  }
  if (href === "/rides") {
    return pathname === "/rides" || pathname.startsWith("/rides/");
  }
  if (href === "/food-orders") {
    return pathname === "/food-orders" || pathname.startsWith("/food-orders/");
  }
  if (href === "/drivers") {
    return pathname === "/drivers";
  }
  if (href === "/stores") {
    return pathname === "/stores";
  }
  if (href === "/catalog") {
    return pathname === "/catalog";
  }
  return pathname === href || pathname.startsWith(`${href}/`);
}
