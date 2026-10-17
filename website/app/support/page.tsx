import type { Metadata } from "next";
import { SupportClient } from "./support-client";

export const metadata: Metadata = {
  title: "Trung tâm Hỗ trợ & Trợ giúp | DealGo",
  description:
    "Trung tâm trợ giúp 24/7 của DealGo dành cho Khách hàng, Tài xế đối tác và Đối tác Nhà hàng Quán ăn.",
};

export default function SupportPage() {
  return <SupportClient />;
}
