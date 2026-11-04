/**
 * Landing FAQ copy. Shared by the visible accordion and the FAQPage JSON-LD in
 * `app/(landing)/page.tsx`, so structured data never drifts from the page.
 */
export const LANDING_FAQS = [
  {
    q: "DealGo là gì?",
    a: "DealGo là nền tảng ứng dụng đa dịch vụ gồm đặt xe máy (Bike), ô tô (Car) và đặt đồ ăn (Food). Khi đặt xe, khách hàng và tài xế thương lượng giá trực tiếp. Một ứng dụng dùng chung cho khách hàng, quán ăn/cửa hàng và tài xế.",
  },
  {
    q: "DealGo hoạt động ở khu vực nào?",
    a: "DealGo phục vụ khách hàng, quán ăn và tài xế trên toàn quốc và liên tục mở rộng. Khu vực đã mở và khu vực sắp mở được hiển thị trong ứng dụng cũng như trong mục Khu vực hoạt động trên trang này.",
  },
  {
    q: "Làm sao để thương lượng giá khi đặt xe?",
    a: "Sau khi nhập điểm đón và điểm đến, bạn có thể tự chọn hoặc điều chỉnh mức giá mong muốn. Tài xế gần bạn có thể chấp nhận hoặc trả giá lại để bạn lựa chọn chuyến xe phù hợp nhất.",
  },
  {
    q: "Thời gian giao đồ ăn thường mất bao lâu?",
    a: "Thời gian giao phụ thuộc khoảng cách và thời gian chuẩn bị của quán; ứng dụng hiển thị thời gian dự kiến cho từng đơn. Bạn có thể theo dõi lộ trình di chuyển của tài xế theo thời gian thực trên bản đồ ứng dụng.",
  },
  {
    q: "Tôi có thể thanh toán bằng những phương thức nào?",
    a: "Bạn có thể trả tiền mặt hoặc thanh toán trực tuyến (ví điện tử như MoMo, ZaloPay, VNPay hoặc thẻ) — các phương thức khả dụng được hiển thị khi đặt chuyến hoặc đơn hàng.",
  },
  {
    q: "Làm sao để trở thành đối tác quán ăn hoặc tài xế?",
    a: "Trong ứng dụng DealGo, chọn đăng ký làm đối tác quán ăn hoặc tài xế, điền thông tin và tải lên giấy tờ cần thiết. Đội ngũ DealGo sẽ xét duyệt hồ sơ trước khi kích hoạt vai trò mới.",
  },
] as const;
