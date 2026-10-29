/**
 * Partner policy (merchants + drivers). Grounded in product docs: one app for
 * customer/merchant/driver, KYC/KYB required, ride negotiation, CASH/MoMo/ZaloPay/VNPay/card,
 * wallet disabled, in-app chat/call, ratings. Commission rates: DEC-PROD-062 still DRAFT
 * (platform settings seeded at 0) → OPEN DECISION, so no numbers are published here.
 */
export type PolicyLocale = "vi" | "en";
export type PolicySection = { id: string; title: string; items: string[] };
export type PartnerPolicy = {
  title: string;
  summary: string;
  legalNotice: string;
  sections: PolicySection[];
};

export const PARTNER_POLICY: Record<PolicyLocale, PartnerPolicy> = {
  vi: {
    title: "Quy định đối tác DealGo",
    summary:
      "Quy định áp dụng cho quán ăn/cửa hàng (đối tác bán hàng) và tài xế (Bike, Car 4 chỗ, Car 7 chỗ) hoạt động trên DealGo tại Đà Nẵng. Khách hàng, đối tác và tài xế dùng chung một ứng dụng DealGo.",
    legalNotice:
      "Bản dự thảo đang được rà soát pháp lý. Nội dung có thể thay đổi trước khi chính thức áp dụng; khi có khác biệt, Điều khoản sử dụng và thông tin hiển thị trong ứng dụng được ưu tiên.",
    sections: [
      {
        id: "dang-ky",
        title: "1. Đăng ký và xác minh",
        items: [
          "Đối tác đăng ký trong ứng dụng DealGo bằng tài khoản của mình, sau đó gửi hồ sơ cửa hàng hoặc hồ sơ tài xế.",
          "Tài xế phải hoàn tất xác minh danh tính và phương tiện (giấy tờ tùy thân, giấy phép lái xe, đăng ký xe phù hợp loại dịch vụ) trước khi nhận chuyến.",
          "Cửa hàng phải hoàn tất xác minh thông tin kinh doanh và được DealGo duyệt trước khi hiển thị cho khách.",
          "Thông tin khai báo phải chính xác và được cập nhật khi thay đổi. DealGo có thể yêu cầu bổ sung giấy tờ bất cứ lúc nào.",
        ],
      },
      {
        id: "gia",
        title: "2. Giá và thương lượng",
        items: [
          "Chuyến xe: khách có thể đề xuất giá, tài xế chấp nhận hoặc trả giá trong ứng dụng. Giá đã được hai bên chấp nhận là giá của chuyến; tài xế không được thu thêm ngoài ứng dụng.",
          "Đồ ăn: không thương lượng giá. Cửa hàng chịu trách nhiệm về giá món, tình trạng còn/hết món và thông tin món trên ứng dụng.",
          "Phí giao hàng và các khoản phí hiển thị cho khách được tính theo cấu hình của nền tảng tại thời điểm đặt đơn.",
        ],
      },
      {
        id: "phi-nen-tang",
        title: "3. Phí nền tảng (hoa hồng)",
        items: [
          "DealGo có thể áp dụng phí nền tảng theo phần trăm giá trị chuyến xe hoặc đơn hàng, cấu hình riêng cho từng loại dịch vụ và hiển thị trong ứng dụng đối tác.",
          "Mức phí cụ thể và chu kỳ đối soát cho cửa hàng hiện CHƯA được công bố (đang chờ quyết định). DealGo sẽ thông báo trước khi áp dụng hoặc thay đổi mức phí.",
        ],
      },
      {
        id: "huy",
        title: "4. Hủy chuyến / hủy đơn",
        items: [
          "Đối tác chỉ hủy khi có lý do chính đáng (ví dụ: không liên hệ được khách, sự cố phương tiện, hết món) và phải chọn lý do trong ứng dụng.",
          "Hủy nhiều lần không lý do, nhận rồi bỏ chuyến/đơn hoặc yêu cầu khách tự hủy có thể dẫn đến hạn chế nhận việc.",
        ],
      },
      {
        id: "thanh-toan",
        title: "5. Thanh toán và đối soát",
        items: [
          "Khách có thể thanh toán bằng tiền mặt hoặc trực tuyến (MoMo, ZaloPay, VNPay, thẻ) khi phương thức được bật.",
          "Đơn tiền mặt: tài xế thu đúng số tiền hiển thị trong ứng dụng. Đơn trực tuyến: tài xế không thu thêm tiền của khách.",
          "Ví DealGo hiện chưa được sử dụng. Khoản tiền đối tác nhận từ đơn trực tuyến được đối soát theo kỳ do nền tảng công bố.",
        ],
      },
      {
        id: "ung-xu",
        title: "6. Ứng xử và an toàn",
        items: [
          "Lịch sự, đúng giờ, tuân thủ luật giao thông và quy định an toàn thực phẩm.",
          "Chỉ liên lạc với khách qua chat/gọi trong ứng dụng cho mục đích hoàn thành chuyến/đơn; không quấy rối, không lôi kéo khách giao dịch ngoài ứng dụng.",
          "Khách và đối tác có thể đánh giá lẫn nhau sau mỗi chuyến/đơn. Đánh giá được dùng để cải thiện chất lượng dịch vụ.",
        ],
      },
      {
        id: "tam-khoa",
        title: "7. Tạm khóa và chấm dứt",
        items: [
          "DealGo có thể tạm khóa hoặc chấm dứt tài khoản đối tác khi: thông tin xác minh sai hoặc hết hạn, gian lận giá hoặc thanh toán, vi phạm an toàn, nhiều khiếu nại đã được xác minh, hoặc vi phạm pháp luật.",
          "Đối tác được thông báo lý do và có thể liên hệ Hỗ trợ để giải trình.",
        ],
      },
      {
        id: "du-lieu",
        title: "8. Dữ liệu cá nhân",
        items: [
          "Đối tác chỉ sử dụng thông tin của khách (tên, số điện thoại ẩn qua ứng dụng, địa chỉ) để hoàn thành chuyến/đơn và không lưu giữ, chia sẻ cho mục đích khác.",
          "Dữ liệu của đối tác được xử lý theo Chính sách bảo mật của DealGo.",
        ],
      },
    ],
  },
  en: {
    title: "DealGo partner policy",
    summary:
      "Rules for restaurants/stores (merchants) and drivers (Bike, Car 4-seat, Car 7-seat) on DealGo in Da Nang. Customers, merchants and drivers use the same DealGo app.",
    legalNotice:
      "Draft under legal review. Content may change before it takes effect; where it differs, the Terms of use and the information shown in the app prevail.",
    sections: [
      { id: "dang-ky", title: "1. Registration and verification", items: [
        "Partners register in the DealGo app with their account, then submit a store or driver profile.",
        "Drivers must complete identity and vehicle verification (ID, driving licence, vehicle registration matching the service type) before accepting rides.",
        "Stores must complete business verification and be approved by DealGo before they are shown to customers.",
        "Information must be accurate and kept up to date. DealGo may request additional documents at any time.",
      ] },
      { id: "gia", title: "2. Pricing and negotiation", items: [
        "Rides: customers may propose a price; drivers accept or counter in the app. The agreed price is the ride price; drivers must not charge extra outside the app.",
        "Food: no negotiation. Stores are responsible for item prices, availability and item information in the app.",
        "Delivery fees and other customer-facing fees follow the platform configuration at the time of ordering.",
      ] },
      { id: "phi-nen-tang", title: "3. Platform fee (commission)", items: [
        "DealGo may charge a platform fee as a percentage of the ride or order value, configured per service and shown in the partner app.",
        "Exact rates and the store settlement cycle are NOT published yet (pending decision). DealGo will give notice before applying or changing any fee.",
      ] },
      { id: "huy", title: "4. Cancellations", items: [
        "Partners may cancel only for a valid reason (e.g. customer unreachable, vehicle issue, item sold out) selected in the app.",
        "Repeated unjustified cancellations, abandoning accepted jobs, or asking customers to cancel may restrict access to new jobs.",
      ] },
      { id: "thanh-toan", title: "5. Payment and settlement", items: [
        "Customers may pay in cash or online (MoMo, ZaloPay, VNPay, card) when the method is enabled.",
        "Cash orders: drivers collect exactly the amount shown in the app. Online orders: drivers collect nothing from the customer.",
        "The DealGo wallet is not in use. Partner earnings from online orders are settled on the cycle the platform publishes.",
      ] },
      { id: "ung-xu", title: "6. Conduct and safety", items: [
        "Be courteous and punctual, follow traffic law and food safety rules.",
        "Contact customers only through in-app chat/call to complete the job; no harassment and no moving transactions off the app.",
        "Customers and partners can rate each other after each job; ratings are used to improve service quality.",
      ] },
      { id: "tam-khoa", title: "7. Suspension and termination", items: [
        "DealGo may suspend or terminate a partner account for false or expired verification, price or payment fraud, safety violations, verified repeated complaints, or unlawful conduct.",
        "Partners are told the reason and may contact Support to respond.",
      ] },
      { id: "du-lieu", title: "8. Personal data", items: [
        "Partners use customer information only to complete the job and must not keep or share it for other purposes.",
        "Partner data is processed under the DealGo Privacy policy.",
      ] },
    ],
  },
};
