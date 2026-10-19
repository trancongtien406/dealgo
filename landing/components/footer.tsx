import Link from "next/link";
import { BrandMark } from "./brand-mark";

export function Footer() {
  return (
    <footer className="border-t border-[var(--color-border)] bg-[var(--color-canvas)] text-[var(--color-ink)]">
      <div className="mx-auto max-w-7xl px-4 pt-16 pb-12 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4 lg:grid-cols-5">
          {/* Brand info */}
          <div className="col-span-2">
            <Link href="/" className="inline-block transition-transform hover:scale-102">
              <BrandMark size="md" showWordmark={true} showTagline={true} />
            </Link>

            <p className="mt-4 text-xs text-[var(--color-muted)] max-w-sm leading-relaxed">
              DealGo là nền tảng công nghệ kết nối di chuyển xe hai bánh và giao đồ ăn chặng cuối với tính năng Deal Giá độc quyền, hướng tới lợi ích công bằng và bền vững cho cộng đồng.
            </p>
            <div className="mt-6 flex items-center gap-3 text-xs text-[var(--color-muted)]">
              <span>Đà Nẵng</span>
              <span>•</span>
              <span>Hồ Chí Minh</span>
              <span>•</span>
              <span>Hà Nội</span>
            </div>
          </div>

          {/* Col 1: Dịch vụ */}
          <div>
            <h4 className="text-xs font-bold uppercase tracking-wider text-[var(--color-brand)]">Dịch vụ</h4>
            <ul className="mt-4 space-y-2.5 text-xs text-[var(--color-muted)]">
              <li><a href="#services" className="hover:text-[var(--color-brand)]">DealGo Ride</a></li>
              <li><a href="#services" className="hover:text-[var(--color-brand)]">DealGo Food</a></li>
              <li><a href="#services" className="hover:text-[var(--color-brand)]">DealGo Delivery</a></li>
              <li><a href="#deal-feature" className="hover:text-[var(--color-brand)]">Tính năng Deal Giá</a></li>
            </ul>
          </div>

          {/* Col 2: Dành cho Đối tác */}
          <div>
            <h4 className="text-xs font-bold uppercase tracking-wider text-[var(--color-brand)]">Đối tác</h4>
            <ul className="mt-4 space-y-2.5 text-xs text-[var(--color-muted)]">
              <li><a href="#partners" className="hover:text-[var(--color-brand)]">Đăng ký Tài xế</a></li>
              <li><a href="#partners" className="hover:text-[var(--color-brand)]">Mở quán DealGo Food</a></li>
              <li><a href="#partners" className="hover:text-[var(--color-brand)]">Quy chế Đối tác</a></li>


            </ul>
          </div>

          {/* Col 3: Pháp lý & Hỗ trợ */}
          <div>
            <h4 className="text-xs font-bold uppercase tracking-wider text-[var(--color-brand)]">Pháp lý & Hỗ trợ</h4>
            <ul className="mt-4 space-y-2.5 text-xs text-[var(--color-muted)]">
              <li><a href="http://localhost:3000/terms" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--color-brand)]">Điều khoản sử dụng</a></li>
              <li><a href="http://localhost:3000/privacy" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--color-brand)]">Chính sách riêng tư</a></li>
              <li><a href="http://localhost:3000/support" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--color-brand)]">Trung tâm trợ giúp</a></li>
              <li><a href="#faq" className="hover:text-[var(--color-brand)]">Câu hỏi thường gặp</a></li>
            </ul>
          </div>
        </div>

        {/* Bottom copyright line */}
        <div className="mt-12 flex flex-col items-center justify-between border-t border-[var(--color-border)] pt-8 sm:flex-row gap-4">
          <p className="text-xs text-[var(--color-muted)]">
            © 2026 DealGo Platform. Mọi quyền được bảo lưu.
          </p>
          <div className="flex items-center gap-4 text-xs text-[var(--color-muted)]">
            <span>Phiên bản 1.0 (MVP)</span>
            <span>•</span>
            <span className="flex items-center gap-1.5 text-emerald-600 font-medium">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
              Hệ thống vận hành ổn định
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
}
