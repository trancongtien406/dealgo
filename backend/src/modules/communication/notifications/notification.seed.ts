import type {
  CampaignStatusName,
  CmsKindName,
  CmsStatusName,
  NotificationAudienceName,
  NotificationChannelName,
} from './notification.repository.js';

export type CampaignSeed = {
  code: string;
  title: string;
  body: string;
  channels: readonly NotificationChannelName[];
  audience: NotificationAudienceName;
  audienceNote?: string;
  status: CampaignStatusName;
  isAutomatic?: boolean;
  /** ISO-8601 (Asia/Ho_Chi_Minh offset). */
  scheduledAt?: string;
  reachedCount?: number;
  createdAt: string;
};

export type CmsSeed = {
  kind: CmsKindName;
  title: string;
  body: string;
  status: CmsStatusName;
  createdAt: string;
};

/** Orders seeds so higher campaign numbers appear first when sorted by createdAt desc. */
function created(n: number): string {
  return new Date(Date.UTC(2024, 5, 10, 0, 0, 0) + n * 60_000).toISOString();
}

/**
 * Initial seed campaigns for notifications and campaigns overview.
 * Inserted once by code/title so Admin Web is populated on startup.
 */
export const OPS_CAMPAIGN_SEEDS: readonly CampaignSeed[] = [
  {
    code: 'TB-240610-028',
    title: 'Cập nhật hành trình',
    body: 'Tài xế đang đến điểm đón. Mở ứng dụng để xem vị trí và ETA mới.',
    channels: ['PUSH', 'IN_APP'],
    audience: 'CUSTOMER',
    audienceNote: 'Khách có chuyến hoạt động',
    status: 'SENDING',
    scheduledAt: '2024-06-10T14:00:00+07:00',
    reachedCount: 3240,
    createdAt: created(28),
  },
  {
    code: 'TB-240610-027',
    title: 'Voucher dành cho thành viên mới',
    body: 'Nhận ngay mã giảm 50% cho chuyến đi đầu tiên trong tuần này cùng DealGo!',
    channels: ['PUSH'],
    audience: 'CUSTOMER',
    audienceNote: 'Khách hàng hợp lệ',
    status: 'SENT',
    scheduledAt: '2024-06-10T09:00:00+07:00',
    reachedCount: 8200,
    createdAt: created(27),
  },
  {
    code: 'TB-240610-026',
    title: 'Nhắc hoàn tất KYC',
    body: 'Vui lòng cập nhật hình ảnh CCCD và bằng lái xe để kích hoạt nhận cuốc tự động.',
    channels: ['IN_APP'],
    audience: 'DRIVER',
    audienceNote: 'Tài xế chờ duyệt',
    status: 'RUNNING',
    scheduledAt: '2024-06-09T17:30:00+07:00',
    reachedCount: 186,
    createdAt: created(26),
  },
  {
    code: 'TB-240610-025',
    title: 'Ưu đãi Đồ ăn cuối tuần',
    body: 'Cuối tuần thảnh thơi với hàng ngàn món ngon giảm đến 40% tại khu vực Đà Nẵng.',
    channels: ['PUSH', 'IN_APP'],
    audience: 'CUSTOMER',
    audienceNote: 'Khách hàng Đà Nẵng',
    status: 'PENDING_APPROVAL',
    scheduledAt: '2024-06-11T08:00:00+07:00',
    createdAt: created(25),
  },
  {
    code: 'TB-240610-024',
    title: 'Cập nhật chính sách phí',
    body: 'Biểu phí chiết khấu và quy tắc phân bổ cuốc xe đã được cập nhật hiệu lực từ 15/06.',
    channels: ['IN_APP'],
    audience: 'MERCHANT',
    audienceNote: 'Đối tác cửa hàng',
    status: 'DRAFT',
    scheduledAt: '2024-06-12T09:00:00+07:00',
    createdAt: created(24),
  },
  {
    code: 'TB-240610-023',
    title: 'Cảnh báo đăng nhập mới',
    body: 'Hệ thống ghi nhận lượt đăng nhập mới từ thiết bị lạ. Vui lòng xác minh nếu không phải bạn.',
    channels: ['PUSH'],
    audience: 'ALL',
    audienceNote: 'Người dùng có sự kiện',
    status: 'RUNNING',
    isAutomatic: true,
    scheduledAt: '2024-06-10T08:00:00+07:00',
    createdAt: created(23),
  },
  {
    code: 'TB-240610-022',
    title: 'Bảo trì hệ thống',
    body: 'Hệ thống bảo trì định kỳ từ 22:00 đến 23:00. Vui lòng hoàn tất chuyến đang chạy trước giờ này.',
    channels: ['PUSH', 'EMAIL'],
    audience: 'ALL',
    audienceNote: 'Tài xế và cửa hàng',
    status: 'SENT',
    scheduledAt: '2024-06-08T22:00:00+07:00',
    reachedCount: 2860,
    createdAt: created(22),
  },
  {
    code: 'TB-240610-021',
    title: 'Thưởng cuốc giờ cao điểm',
    body: 'Hoàn thành 3 chuyến từ 17h–19h nhận ngay thưởng nóng 50.000đ vào ví tài xế.',
    channels: ['PUSH', 'IN_APP'],
    audience: 'DRIVER',
    audienceNote: 'Tài xế đang trực tuyến',
    status: 'RUNNING',
    isAutomatic: true,
    scheduledAt: '2024-06-10T17:00:00+07:00',
    reachedCount: 450,
    createdAt: created(21),
  },
  {
    code: 'TB-240610-020',
    title: 'Khảo sát trải nghiệm DealGo Food',
    body: 'Bạn hài lòng với món ăn vừa giao? Hãy dành 1 phút đánh giá để nhận voucher 20k.',
    channels: ['IN_APP'],
    audience: 'CUSTOMER',
    audienceNote: 'Khách đặt đơn hôm nay',
    status: 'SENT',
    scheduledAt: '2024-06-09T20:00:00+07:00',
    reachedCount: 1420,
    createdAt: created(20),
  },
  {
    code: 'TB-240610-019',
    title: 'Khuyến mãi DealExpress hỏa tốc',
    body: 'Giao tài liệu hỏa tốc nội thành giảm ngay 25% cho 5 đơn đầu tiên trong tháng.',
    channels: ['PUSH'],
    audience: 'CUSTOMER',
    audienceNote: 'Khách hàng doanh nghiệp',
    status: 'SENT',
    scheduledAt: '2024-06-08T10:00:00+07:00',
    reachedCount: 620,
    createdAt: created(19),
  },
  {
    code: 'TB-240610-018',
    title: 'Chính sách bồi hoàn đơn trễ',
    body: 'Quy định hỗ trợ bồi thường khi thời gian giao hàng vượt quá cam kết 30 phút.',
    channels: ['EMAIL'],
    audience: 'ALL',
    audienceNote: 'Toàn hệ thống',
    status: 'DRAFT',
    scheduledAt: '2024-06-15T09:00:00+07:00',
    createdAt: created(18),
  },
  {
    code: 'TB-240610-017',
    title: 'Chào đón đối tác quán ăn mới',
    body: 'Khám phá 20+ quán ngon mới gia nhập DealFood tại quận Hải Châu với ưu đãi mua 1 tặng 1.',
    channels: ['PUSH', 'IN_APP'],
    audience: 'CUSTOMER',
    audienceNote: 'Khách hàng khu vực Hải Châu',
    status: 'PENDING_APPROVAL',
    scheduledAt: '2024-06-12T11:00:00+07:00',
    createdAt: created(17),
  },
];

export const OPS_CMS_SEEDS: readonly CmsSeed[] = [
  {
    kind: 'ARTICLE',
    title: 'Hướng dẫn đặt xe DealGo',
    body: 'Hướng dẫn từng bước đặt xe hai bánh trên DealGo: chọn điểm đón, điểm đến, đề xuất giá và theo dõi tài xế.',
    status: 'PUBLISHED',
    createdAt: '2024-06-10T09:00:00+07:00',
  },
  {
    kind: 'BANNER',
    title: 'Ưu đãi tháng 6',
    body: 'Banner ưu đãi tháng 6 hiển thị ở trang chủ ứng dụng khách hàng.',
    status: 'PUBLISHED',
    createdAt: '2024-06-09T09:00:00+07:00',
  },
  {
    kind: 'POLICY',
    title: 'Chính sách hoàn tiền',
    body: 'Điều kiện và thời gian xử lý hoàn tiền cho đơn bị hủy hoặc giao thất bại. Đang chờ phê duyệt nội dung.',
    status: 'IN_REVIEW',
    createdAt: '2024-06-08T09:00:00+07:00',
  },
  {
    kind: 'ARTICLE',
    title: 'Cẩm nang đối tác tài xế',
    body: 'Quy trình đăng ký, xác minh hồ sơ và nhận cuốc dành cho đối tác tài xế.',
    status: 'DRAFT',
    createdAt: '2024-06-07T09:00:00+07:00',
  },
  {
    kind: 'ARTICLE',
    title: 'Kinh nghiệm mở quán thành công trên DealFood',
    body: 'Mẹo tối ưu thực đơn, hình ảnh món và thời gian chuẩn bị để tăng đơn trên DealFood.',
    status: 'PUBLISHED',
    createdAt: '2024-06-06T09:00:00+07:00',
  },
  {
    kind: 'BANNER',
    title: 'Freeship đơn đồ ăn từ 50K',
    body: 'Banner miễn phí giao hàng cho đơn đồ ăn từ 50.000đ.',
    status: 'PUBLISHED',
    createdAt: '2024-06-05T09:00:00+07:00',
  },
  {
    kind: 'POLICY',
    title: 'Điều khoản & Điều kiện Sử dụng (TERMS)',
    body: JSON.stringify({
      key: 'TERMS',
      title: 'Điều khoản & Điều kiện Sử dụng',
      badge: 'Thỏa thuận dịch vụ DealGo',
      version: 'v2.4 (2026)',
      effectiveDate: 'Áp dụng từ 01/01/2026',
      summary:
        'Quy định quyền lợi, nghĩa vụ của khách hàng, đối tác tài xế và đối tác nhà hàng khi tham gia nền tảng DealGo.',
      updatedAt: '2026-03-15T08:00:00.000Z',
      updatedBy: 'Ban Pháp chế DealGo',
      sections: [
        {
          id: 'sec-intro',
          order: 1,
          title: '1. Định nghĩa & Phạm vi áp dụng',
          content:
            'DealGo là nền tảng công nghệ kết nối nhu cầu di chuyển (DealRide) và giao nhận thực phẩm (DealFood). Bằng việc truy cập ứng dụng, người dùng đồng ý tuân thủ toàn bộ điều khoản này.',
        },
        {
          id: 'sec-accounts',
          order: 2,
          title: '2. Đăng ký & Bảo mật tài khoản',
          content:
            'Người dùng phải cung cấp số điện thoại chính chủ để xác thực OTP. Mọi hoạt động phát sinh từ tài khoản đã xác thực thuộc trách nhiệm của chủ tài khoản.',
        },
        {
          id: 'sec-negotiation',
          order: 3,
          title: '3. Cơ chế đề xuất giá & Thỏa thuận chuyến',
          content:
            'DealGo áp dụng cơ chế đề xuất giá hai chiều trong biên độ an toàn được tính toán tự động dựa trên cự ly, thời tiết và nhu cầu khu vực theo thời gian thực.',
        },
        {
          id: 'sec-payment',
          order: 4,
          title: '4. Thanh toán & Phí dịch vụ',
          content:
            'Hỗ trợ thanh toán tiền mặt trực tiếp cho tài xế, thanh toán qua ví DealGo hoặc cổng thanh toán điện tử đã liên kết. Phí nền tảng được trích xuất minh bạch theo bảng phí công bố.',
        },
        {
          id: 'sec-dispute',
          order: 5,
          title: '5. Giải quyết khiếu nại & Tranh chấp',
          content:
            'Bộ phận DealGo Operations tiếp nhận khiếu nại qua Trung tâm Hỗ trợ trong vòng 72 giờ kể từ thời điểm phát sinh giao dịch để xử lý hoàn tiền hoặc bồi hoàn phù hợp.',
        },
      ],
    }),
    status: 'PUBLISHED',
    createdAt: '2024-06-01T08:00:00+07:00',
  },
  {
    kind: 'POLICY',
    title: 'Chính sách Quyền riêng tư & Bảo mật (PRIVACY)',
    body: JSON.stringify({
      key: 'PRIVACY',
      title: 'Chính sách Quyền riêng tư & Bảo mật Dữ liệu',
      badge: 'Bảo vệ dữ liệu người dùng',
      version: 'v2.2 (2026)',
      effectiveDate: 'Áp dụng từ 01/01/2026',
      summary:
        'Cam kết bảo vệ dữ liệu cá nhân, tọa độ GPS và lịch sử giao dịch của mọi thành viên tham gia hệ sinh thái DealGo.',
      updatedAt: '2026-03-15T08:00:00.000Z',
      updatedBy: 'Ban An toàn Thông tin DealGo',
      sections: [
        {
          id: 'sec-collection',
          order: 1,
          title: '1. Thu thập dữ liệu cá nhân',
          content:
            'Hệ thống thu thập họ tên, số điện thoại, tọa độ GPS vị trí đón/trả và thông tin phương tiện để phục vụ kết nối chuyến và an toàn hành trình.',
        },
        {
          id: 'sec-usage',
          order: 2,
          title: '2. Mục đích sử dụng dữ liệu',
          content:
            'Dữ liệu vị trí được chia sẻ theo thời gian thực giữa hành khách và tài xế trong suốt thời gian chuyến đi diễn ra, phục vụ điều phối và bảo vệ hành khách.',
        },
        {
          id: 'sec-security',
          order: 3,
          title: '3. Bảo mật & Lưu trữ',
          content:
            'Dữ liệu được mã hóa chuẩn TLS/SSL khi truyền tải và lưu trữ trên cơ sở dữ liệu có kiểm soát truy cập nghiêm ngặt của DealGo Cloud Infrastructure.',
        },
        {
          id: 'sec-rights',
          order: 4,
          title: '4. Quyền của chủ thể dữ liệu',
          content:
            'Người dùng có quyền yêu cầu trích xuất dữ liệu cá nhân, chỉnh sửa thông tin hoặc xóa vĩnh viễn tài khoản thông qua cổng hỗ trợ trực tuyến.',
        },
      ],
    }),
    status: 'PUBLISHED',
    createdAt: '2024-06-01T09:00:00+07:00',
  },
  {
    kind: 'ARTICLE',
    title: 'Cấu hình kênh hỗ trợ khách hàng (SUPPORT)',
    body: JSON.stringify({
      systemStatusNotice: 'Hệ thống hỗ trợ DealGo trực tuyến 24/7',
      hotline: '1900 6868',
      email: 'hotro@dealgo.vn',
      address: 'Tòa nhà Công nghệ DealGo, Quận Hải Châu, TP. Đà Nẵng',
      hours: '24/7 toàn bộ các ngày trong tuần (kể cả lễ tết)',
      updatedAt: '2026-03-01T00:00:00.000Z',
      updatedBy: 'Trưởng phòng Vận hành CSKH',
      categories: [
        {
          id: 'cat-cust',
          title: 'Dành cho Khách hàng',
          role: 'CUSTOMER',
          icon: 'motorcycle',
          tone: 'bg-brand/10 text-brand border-brand/20',
          items: [
            'Quên đồ trên xe hoặc thất lạc hành lý',
            'Khiếu nại thái độ phục vụ hoặc cước phí chuyến',
            'Đơn đồ ăn thiếu món, giao trễ hoặc đổ vỡ',
            'Yêu cầu hoàn tiền giao dịch qua ví / ngân hàng',
          ],
        },
        {
          id: 'cat-driver',
          title: 'Dành cho Tài xế đối tác',
          role: 'DRIVER',
          icon: 'driver',
          tone: 'bg-success/10 text-success border-success/20',
          items: [
            'Hướng dẫn bổ sung giấy tờ và xác thực KYC xe máy',
            'Thắc mắc về đối soát thu nhập & rút tiền ví đối tác',
            'Khắc phục sự cố không nhận được tín hiệu định vị GPS',
            'Báo cáo khách hàng không nhận cuốc hoặc bom hàng',
          ],
        },
        {
          id: 'cat-store',
          title: 'Dành cho Quán ăn & Cửa hàng',
          role: 'MERCHANT',
          icon: 'store',
          tone: 'bg-food/10 text-food border-food/20',
          items: [
            'Đăng ký mở gian hàng mới trên DealFood',
            'Cập nhật thực đơn, giá bán và hình ảnh món ăn',
            'Kiểm tra chu kỳ đối soát và thanh toán định kỳ',
            'Sự cố ứng dụng tiếp nhận đơn hàng tại quán',
          ],
        },
      ],
    }),
    status: 'PUBLISHED',
    createdAt: '2024-06-01T07:00:00+07:00',
  },
];
