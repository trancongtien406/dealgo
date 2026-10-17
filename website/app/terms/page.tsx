import type { Metadata } from "next";
import { TermsClient } from "./terms-client";

export const metadata: Metadata = {
  title: "Điều khoản & Điều kiện Sử dụng | DealGo",
  description:
    "Điều khoản sử dụng dịch vụ nền tảng công nghệ DealGo áp dụng cho Khách hàng, Tài xế và Đối tác Quán ăn.",
};

export default function TermsPage() {
  return <TermsClient />;
}
