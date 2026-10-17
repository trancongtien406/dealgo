enum PartnerApplicationStatus { draft, pending, rejected, active }

class OnboardingRejection {
  const OnboardingRejection({
    required this.title,
    required this.reason,
    required this.code,
  });

  final String title;
  final String reason;
  final String code;
}

abstract final class DriverKycCopy {
  static const flowLabel = 'ĐĂNG KÝ ĐỐI TÁC TÀI XẾ';
  static const roleBadge = 'Tài xế';
  static const introTitle = 'Đăng ký đối tác tài xế';
  static const introHeadline = 'Trở thành tài xế đối tác DealGo';
  static const introBody =
      'Chủ động bật nhận chuyến chở khách hoặc giao món theo điều kiện dịch vụ đã được duyệt.';
  static const startCta = 'Bắt đầu đăng ký';
  static const existingCta = 'Tôi đã có hồ sơ';
  static const submitCta = 'Gửi hồ sơ';
  static const resubmitCta = 'Gửi bổ sung';
  static const trackCta = 'Theo dõi trạng thái';
  static const pendingTitle = 'Đang thẩm định';
  static const pendingBadge = 'PENDING_REVIEW';
  static const rejectedBanner =
      'Hồ sơ yêu cầu chỉnh sửa. Mỗi mục có lý do rõ ràng, không cần gửi lại toàn bộ hồ sơ không thay đổi.';
  static const activeTitle = 'Hồ sơ tài xế đã kích hoạt';
  static const activeBody =
      'Quyền nhận việc đang mở theo seed mock. Bạn vẫn có thể xem lại luồng xét duyệt demo.';
}

abstract final class MerchantKybCopy {
  static const flowLabel = 'ĐĂNG KÝ ĐỐI TÁC DEALGO';
  static const roleBadge = 'Shop';
  static const introTitle = 'Trở thành đối tác Shop';
  static const introHeadline = 'Bắt đầu kinh doanh cùng DealGo';
  static const introBody =
      'Bán đồ ăn, thực phẩm và hàng hóa ngay trên một ứng dụng.';
  static const startCta = 'Bắt đầu đăng ký Shop';
  static const submitCta = 'Gửi xét duyệt';
  static const resubmitCta = 'Gửi lại hồ sơ';
  static const trackCta = 'Theo dõi hồ sơ';
  static const pendingTitle = 'Đang thẩm định hồ sơ';
  static const pendingBadge = 'PENDING_REVIEW';
  static const rejectedBanner =
      'Cần bổ sung 2 mục trong hồ sơ để tiếp tục xét duyệt. Dữ liệu bản cũ vẫn giữ làm lịch sử.';
  static const activeTitle = 'Hồ sơ Shop đã kích hoạt';
  static const activeBody =
      'Quyền bán hàng đang mở theo seed mock. Bạn vẫn có thể xem lại luồng xét duyệt demo.';
}

const driverDemoRejections = <OnboardingRejection>[
  OnboardingRejection(
    title: 'Ảnh CCCD chưa rõ',
    reason: 'Chụp lại mặt trước đủ ánh sáng.',
    code: 'KYC-ID-BLUR',
  ),
  OnboardingRejection(
    title: 'Giấy phép không còn hiệu lực',
    reason: 'Cần bổ sung giấy phép còn hạn.',
    code: 'KYC-LICENSE-EXPIRED',
  ),
];

const merchantDemoRejections = <OnboardingRejection>[
  OnboardingRejection(
    title: 'Ảnh giấy tờ kinh doanh không rõ',
    reason: 'Vui lòng chụp lại đầy đủ các cạnh.',
    code: 'KYB-DOC-BLUR',
  ),
  OnboardingRejection(
    title: 'Địa chỉ không khớp',
    reason: 'Đối chiếu lại địa chỉ Shop với tài liệu.',
    code: 'KYB-ADDR-MISMATCH',
  ),
];
