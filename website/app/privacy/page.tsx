import type { Metadata } from "next";
import { PrivacyClient } from "./privacy-client";

export const metadata: Metadata = {
  title: "Chính sách Quyền riêng tư | DealGo",
  description:
    "Chính sách bảo mật dữ liệu cá nhân, vị trí GPS và thông tin giao dịch của nền tảng DealGo tuân thủ Nghị định 13/2023/NĐ-CP.",
};

export default function PrivacyPage() {
  return <PrivacyClient />;
}
