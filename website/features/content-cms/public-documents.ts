import type { LegalDocument, SupportConfig } from "./types";

/**
 * Baseline authoritative public documents for DealGo.
 * Used for public pages (/terms, /privacy, /support) and as fallback.
 * Reflects DEC-PROD-001 (Ride xe hai bánh & Food giao đồ ăn).
 */
export const publicTermsDocument: LegalDocument = {
  key: "TERMS",
  title: "Điều khoản & Điều kiện Sử dụng Dịch vụ DealGo",
  badge: "Văn bản pháp lý nền tảng DealGo",
  version: "v2.1",
  effectiveDate: "01/01/2026",
  summary:
    "Quy định chung áp dụng cho mọi cá nhân, tổ chức tham gia sử dụng dịch vụ đặt xe hai bánh (Ride) và đặt đồ ăn trực tuyến (Food) trên nền tảng ứng dụng đa vai trò DealGo.",
  updatedAt: "2026-01-01T00:00:00.000Z",
  updatedBy: "Ban Pháp chế & Vận hành DealGo",
  sections: [
    {
      id: "sec-1",
      order: 1,
      title: "1. Định nghĩa và Phạm vi dịch vụ",
      content:
        "DealGo cung cấp nền tảng công nghệ kết nối trực tuyến bao gồm dịch vụ di chuyển xe hai bánh (DealGo Ride) và dịch vụ giao đồ ăn (DealGo Food). Khách hàng, Tài xế (Driver) và Đối tác Nhà hàng (Merchant) tương tác thông qua một ứng dụng di động hợp nhất duy nhất.",
    },
    {
      id: "sec-2",
      order: 2,
      title: "2. Tài khoản và Xác thực vai trò",
      content:
        "Mỗi người dùng sở hữu một tài khoản định danh duy nhất bằng số điện thoại. Việc kích hoạt vai trò Tài xế hoặc Đối tác Quán ăn phải tuân thủ quy trình thẩm định hồ sơ, giấy phép hành nghề và vệ sinh an toàn thực phẩm được phê duyệt bởi Ban Vận hành DealGo.",
    },
    {
      id: "sec-3",
      order: 3,
      title: "3. Giá cước, Phí dịch vụ và Thanh toán",
      content:
        "Giá cước chuyến xe và đơn đồ ăn được tính toán theo thời gian thực dựa trên quãng đường, phụ phí thời gian cao điểm và phí nền tảng đã được công bố minh bạch trên ứng dụng trước khi xác nhận đặt cuốc. Máy chủ DealGo là nguồn sự thật duy nhất xác định giá cuối cùng và ghi nhận giao dịch.",
    },
    {
      id: "sec-4",
      order: 4,
      title: "4. Chính sách Hủy cuốc và Bồi hoàn",
      content:
        "Khách hàng hoặc tài xế có thể hủy cuốc theo quy định thời gian cho phép. Trường hợp phát sinh sự cố giao hàng không thành công hoặc sai sót món ăn, các bên có quyền gửi yêu cầu khiếu nại qua ứng dụng để Ban Vận hành đối soát và xử lý theo chính sách bảo vệ người dùng.",
    },
    {
      id: "sec-5",
      order: 5,
      title: "5. Tiêu chuẩn An toàn và Quy tắc Ứng xử",
      content:
        "Tất cả các bên tham gia cam kết tuân thủ Luật Giao thông đường bộ, quy chuẩn an toàn thực phẩm, và văn hóa giao tiếp văn minh. DealGo có quyền tạm khóa hoặc đình chỉ vĩnh viễn các tài khoản vi phạm chuẩn mực an toàn hoặc gian lận.",
    },
  ],
};

export const publicPrivacyDocument: LegalDocument = {
  key: "PRIVACY",
  title: "Chính sách Quyền riêng tư & Bảo mật Dữ liệu",
  badge: "Bảo vệ dữ liệu người dùng DealGo",
  version: "v2.0",
  effectiveDate: "01/01/2026",
  summary:
    "DealGo cam kết bảo vệ dữ liệu cá nhân, thông tin định vị thời gian thực và lịch sử giao dịch của Khách hàng, Đối tác Tài xế và Nhà hàng.",
  updatedAt: "2026-01-01T00:00:00.000Z",
  updatedBy: "Ban An toàn Thông tin DealGo",
  sections: [
    {
      id: "sec-p1",
      order: 1,
      title: "1. Thu thập Thông tin Cá nhân",
      content:
        "Chúng tôi chỉ thu thập các thông tin cần thiết phục vụ cho việc vận hành dịch vụ: Họ tên, số điện thoại, vị trí GPS thời gian thực (khi ứng dụng đang mở hoặc chạy ngầm để điều phối cuốc xe), thông tin phương tiện và lịch sử thanh toán.",
    },
    {
      id: "sec-p2",
      order: 2,
      title: "2. Mục đích Sử dụng Dữ liệu",
      content:
        "Dữ liệu được sử dụng để khớp cuốc xe tối ưu giữa Khách hàng và Tài xế, điều hướng đơn giao thức ăn, gửi thông báo trạng thái đơn hàng, đối soát thu chi và nâng cao an toàn hành trình.",
    },
    {
      id: "sec-p3",
      order: 3,
      title: "3. Bảo mật Thông tin và Lưu trữ",
      content:
        "Dữ liệu được mã hóa đường truyền bằng chuẩn TLS 1.3 và lưu trữ an toàn tại trung tâm dữ liệu tuân thủ chuẩn an toàn thông tin. Chúng tôi không bao giờ bán hoặc chia sẻ trái phép dữ liệu cá nhân cho bên thứ ba vì mục đích tiếp thị ngoài hệ sinh thái DealGo.",
    },
    {
      id: "sec-p4",
      order: 4,
      title: "4. Quyền của Chủ thể Dữ liệu",
      content:
        "Người dùng có toàn quyền tra cứu, cập nhật thông tin cá nhân, yêu cầu trích xuất lịch sử cuốc xe, hoặc gửi yêu cầu xóa tài khoản thông qua phần Cài đặt trong ứng dụng di động DealGo.",
    },
  ],
};

export const publicSupportConfig: SupportConfig = {
  systemStatusNotice:
    "Hệ thống tổng đài và trung tâm hỗ trợ DealGo sẵn sàng phục vụ 24/7.",
  hotline: "1900 6868",
  email: "hotro@dealgo.vn",
  address: "Tòa nhà Công nghệ DealGo, Quận Hải Châu, TP. Đà Nẵng",
  hours: "24/7 — Thứ Hai đến Chủ Nhật",
  updatedAt: "2026-01-01T00:00:00.000Z",
  updatedBy: "Ban Dịch vụ Khách hàng DealGo",
  categories: [
    {
      id: "cat-ride",
      title: "Hỗ trợ Chuyến đi (Ride)",
      role: "CUSTOMER",
      icon: "motorcycle",
      tone: "ride",
      items: [
        "Quên đồ đạc trên phương tiện của tài xế",
        "Khiếu nại lộ trình hoặc cước phí chuyến xe",
        "Báo cáo sự cố an toàn hoặc thái độ tài xế",
        "Hướng dẫn thay đổi điểm đón / điểm trả",
      ],
    },
    {
      id: "cat-food",
      title: "Hỗ trợ Đơn hàng Đồ ăn (Food)",
      role: "CUSTOMER",
      icon: "utensils",
      tone: "food",
      items: [
        "Món ăn giao sai, thiếu món hoặc không đảm bảo chất lượng",
        "Tài xế giao hàng chậm trễ hoặc không liên lạc được",
        "Hủy đơn hàng và đối soát hoàn tiền",
        "Hóa đơn điện tử cho đơn hàng doanh nghiệp",
      ],
    },
    {
      id: "cat-account",
      title: "Tài khoản & Thanh toán",
      role: "CUSTOMER",
      icon: "wallet",
      tone: "neutral",
      items: [
        "Hướng dẫn nạp/rút tiền ví điện tử DealGo Pay",
        "Xác thực danh tính (eKYC) tài xế và quán ăn",
        "Thay đổi số điện thoại đăng ký",
        "Yêu cầu khóa hoặc xóa vĩnh viễn tài khoản",
      ],
    },
  ],
};
