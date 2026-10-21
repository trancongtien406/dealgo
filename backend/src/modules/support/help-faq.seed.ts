import type { OpsFaqSeed } from './ops-faq.seed.js';

/**
 * Starter in-app help (DEC-PROD-021). Answers describe only behaviour the app implements today;
 * ops edit, archive or add entries in Admin › FAQ. Keyed by `openId` (HELP-*) so re-seeding never
 * duplicates or overwrites an edited entry.
 */
export const HELP_FAQ_SEEDS: readonly OpsFaqSeed[] = [
  {
    openId: 'HELP-C01',
    audience: 'CUSTOMER',
    status: 'PUBLISHED',
    category: 'PRODUCT',
    sortOrder: 10,
    question: 'Tôi có thể huỷ đơn đồ ăn không?',
    suggestedAnswer:
      'Bạn huỷ được khi quán chưa nhận đơn. Khi quán đã bắt đầu chuẩn bị, hãy gửi yêu cầu hỗ trợ trong Tài khoản › Trung tâm hỗ trợ để được xử lý.',
  },
  {
    openId: 'HELP-C02',
    audience: 'CUSTOMER',
    status: 'PUBLISHED',
    category: 'PRODUCT',
    sortOrder: 20,
    question: 'Vì sao quán từ chối đơn của tôi?',
    suggestedAnswer:
      'Quán chọn lý do khi từ chối (ví dụ hết món hoặc quá tải) và lý do hiện trong chi tiết đơn. Voucher đã áp cho đơn bị từ chối được trả lại để bạn dùng cho đơn sau.',
  },
  {
    openId: 'HELP-C03',
    audience: 'CUSTOMER',
    status: 'PUBLISHED',
    category: 'PRODUCT',
    sortOrder: 30,
    question: 'Dùng mã khuyến mãi như thế nào?',
    suggestedAnswer:
      'Mở Tài khoản › Ưu đãi của tôi để xem các mã bạn còn dùng được, kèm đơn tối thiểu và hạn dùng. Hiện mã áp dụng cho đơn đồ ăn: bấm "Dùng khi đặt món" hoặc nhập mã ở bước thanh toán; hệ thống kiểm tra mã trước khi bạn đặt.',
  },
  {
    openId: 'HELP-C04',
    audience: 'CUSTOMER',
    status: 'PUBLISHED',
    category: 'PRODUCT',
    sortOrder: 40,
    question: 'Làm sao liên hệ hỗ trợ?',
    suggestedAnswer:
      'Vào Tài khoản › Trung tâm hỗ trợ và tạo yêu cầu. Bạn có thể đính kèm tối đa 3 ảnh mỗi tin nhắn. DealGo trả lời ngay trong yêu cầu đó.',
  },
  {
    openId: 'HELP-C05',
    audience: 'CUSTOMER',
    status: 'PUBLISHED',
    category: 'PRODUCT',
    sortOrder: 50,
    question: 'Tôi muốn trở thành tài xế hoặc mở quán trên DealGo?',
    suggestedAnswer:
      'Vào Tài khoản và chọn đăng ký đối tác tài xế hoặc Shop, điền thông tin và chụp giấy tờ. Nếu hồ sơ cần bổ sung, ứng dụng hiện đúng mục cần sửa; bạn chỉ chụp lại giấy tờ được yêu cầu.',
  },
];
