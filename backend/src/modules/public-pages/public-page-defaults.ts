import type {
  LegalContent,
  PublicPageContent,
  PublicPageLocale,
  PublicPageSlug,
  SupportContent,
} from './public-pages.types.js';

/**
 * Built-in default content (DEC-PROD-055). Served until an admin publishes a page and used by
 * "reset to default". Bracketed fields are company details the owner must fill before launch.
 */
export type PublicPageDefault = {
  title: string;
  summary: string;
  content: PublicPageContent;
};

const PRIVACY_VI: LegalContent = {
  badge: 'Tuân thủ Nghị định 13/2023/NĐ-CP',
  sections: [
    {
      id: 'controller',
      title: '1. Bên kiểm soát dữ liệu',
      content:
        'DealGo do [Tên pháp nhân], mã số doanh nghiệp [MST], địa chỉ [Địa chỉ trụ sở] vận hành ("DealGo", "chúng tôi"). Liên hệ về dữ liệu cá nhân: [Email bảo vệ dữ liệu].',
    },
    {
      id: 'collect',
      title: '2. Dữ liệu chúng tôi thu thập',
      content:
        '- Thông tin tài khoản: họ tên, số điện thoại và/hoặc email, ảnh đại diện, ngày sinh, giới tính (nếu bạn cung cấp).\n- Thông tin đăng nhập: mã OTP được gửi qua SMS/email, khoá passkey (chỉ lưu khoá công khai).\n- Vị trí: vị trí đón/trả, địa chỉ giao hàng; với tài xế, vị trí thời gian thực khi đang nhận chuyến hoặc đơn.\n- Giao dịch: chuyến đi, đơn hàng, giá cước, phương thức thanh toán, đánh giá, khiếu nại.\n- Tin nhắn trong chuyến/đơn giữa khách hàng và tài xế/cửa hàng.\n- Hồ sơ đối tác (tài xế, cửa hàng): CCCD, giấy phép lái xe, đăng ký xe, giấy phép kinh doanh và ảnh chụp liên quan để xác minh (KYC/KYB).\n- Thông tin thiết bị: mã thông báo đẩy, phiên bản ứng dụng, nhật ký lỗi kỹ thuật.',
    },
    {
      id: 'purpose',
      title: '3. Mục đích sử dụng',
      content:
        'Chúng tôi dùng dữ liệu để: tạo và bảo vệ tài khoản; ghép chuyến, điều phối đơn và tính giá; liên lạc giữa các bên trong chuyến/đơn; xác minh đối tác; xử lý thanh toán, đối soát và hoàn tiền; giải quyết khiếu nại, phòng chống gian lận; gửi thông báo dịch vụ; tuân thủ yêu cầu pháp luật.',
    },
    {
      id: 'chat',
      title: '4. Tin nhắn trong chuyến/đơn',
      content:
        'Tin nhắn được mã hoá khi lưu trữ và tự động xoá sau 90 ngày (thời hạn có thể được điều chỉnh và sẽ được công bố tại đây). Nhân viên hỗ trợ có thẩm quyền chỉ được xem tin nhắn của một chuyến/đơn khi xử lý khiếu nại, tranh chấp hoặc sự cố an toàn; mỗi lần xem đều được ghi nhật ký kèm lý do.',
    },
    {
      id: 'share',
      title: '5. Chia sẻ dữ liệu',
      content:
        '- Giữa các bên trong một chuyến/đơn: tên, ảnh, vị trí đón/giao, thông tin xe cần thiết để hoàn thành dịch vụ.\n- Nhà cung cấp dịch vụ xử lý dữ liệu thay chúng tôi: lưu trữ máy chủ, gửi SMS/email, thông báo đẩy, bản đồ và định tuyến, giám sát lỗi. Các bên này chỉ được xử lý dữ liệu theo chỉ dẫn của DealGo.\n- Cơ quan nhà nước có thẩm quyền khi pháp luật yêu cầu.\nChúng tôi không bán dữ liệu cá nhân.',
    },
    {
      id: 'retention',
      title: '6. Thời gian lưu trữ',
      content:
        '- Tin nhắn: 90 ngày.\n- Hồ sơ xác minh đối tác: trong thời gian hợp tác và thời hạn pháp luật yêu cầu sau đó.\n- Chứng từ giao dịch, kế toán: theo thời hạn của pháp luật kế toán, thuế.\n- Dữ liệu tài khoản: đến khi bạn xoá tài khoản; sau thời gian chờ, thông tin cá nhân được ẩn danh, trừ dữ liệu phải lưu theo luật.',
    },
    {
      id: 'rights',
      title: '7. Quyền của bạn',
      content:
        'Bạn có quyền được biết, đồng ý, truy cập, chỉnh sửa, rút lại sự đồng ý, phản đối, hạn chế xử lý, yêu cầu cung cấp và xoá dữ liệu theo Nghị định 13/2023/NĐ-CP. Bạn có thể sửa thông tin trong mục Tài khoản và xoá tài khoản tại Cài đặt → Xoá tài khoản trong ứng dụng. Các yêu cầu khác gửi tới [Email bảo vệ dữ liệu]; chúng tôi phản hồi trong thời hạn luật định.',
    },
    {
      id: 'security',
      title: '8. Bảo mật',
      content:
        'Dữ liệu được truyền qua kết nối mã hoá (TLS); tin nhắn được mã hoá khi lưu; quyền truy cập nội bộ được phân quyền theo vai trò và ghi nhật ký kiểm toán.',
    },
    {
      id: 'children',
      title: '9. Trẻ em',
      content: 'Dịch vụ dành cho người từ 16 tuổi trở lên. Chúng tôi không cố ý thu thập dữ liệu của trẻ em dưới 16 tuổi.',
    },
    {
      id: 'changes',
      title: '10. Thay đổi chính sách',
      content:
        'Khi có thay đổi quan trọng, chúng tôi cập nhật phiên bản và ngày hiệu lực trên trang này và thông báo trong ứng dụng.',
    },
  ],
};

const PRIVACY_EN: LegalContent = {
  badge: 'Compliant with Decree 13/2023/ND-CP',
  sections: [
    {
      id: 'controller',
      title: '1. Data controller',
      content:
        'DealGo is operated by [Legal entity name], enterprise code [Tax ID], registered at [Head office address] ("DealGo", "we"). Personal data contact: [Data protection email].',
    },
    {
      id: 'collect',
      title: '2. Data we collect',
      content:
        '- Account: name, phone number and/or email, avatar, date of birth, gender (if provided).\n- Sign-in: one-time codes sent by SMS/email, passkeys (public key only).\n- Location: pickup/drop-off and delivery addresses; for drivers, real-time location while taking rides or orders.\n- Transactions: rides, orders, fares, payment method, ratings, complaints.\n- In-trip/in-order messages between customers and drivers/stores.\n- Partner records (drivers, stores): ID card, driving licence, vehicle registration, business licence and related photos for verification (KYC/KYB).\n- Device: push token, app version, technical error logs.',
    },
    {
      id: 'purpose',
      title: '3. How we use data',
      content:
        'To create and protect accounts; match rides, dispatch orders and price them; let parties in a ride/order communicate; verify partners; process payments, settlements and refunds; resolve complaints and prevent fraud; send service notifications; comply with the law.',
    },
    {
      id: 'chat',
      title: '4. In-trip messages',
      content:
        'Messages are encrypted at rest and deleted automatically after 90 days (any change will be published here). Authorised support staff may view the messages of a single ride/order only to handle a complaint, dispute or safety incident; every access is logged with a reason.',
    },
    {
      id: 'share',
      title: '5. Sharing',
      content:
        '- Between parties of a ride/order: name, photo, pickup/delivery location and vehicle details needed to complete the service.\n- Processors acting for us: hosting, SMS/email delivery, push notifications, maps and routing, error monitoring, only under DealGo instructions.\n- Competent authorities when required by law.\nWe do not sell personal data.',
    },
    {
      id: 'retention',
      title: '6. Retention',
      content:
        '- Messages: 90 days.\n- Partner verification records: for the partnership and any legally required period after it.\n- Transaction and accounting records: as required by accounting and tax law.\n- Account data: until you delete your account; after the waiting period personal data is anonymised, except data the law requires us to keep.',
    },
    {
      id: 'rights',
      title: '7. Your rights',
      content:
        'Under Decree 13/2023/ND-CP you may be informed, consent, access, correct, withdraw consent, object, restrict processing, obtain and delete your data. Edit your details under Account and delete your account in Settings → Delete account in the app. Send other requests to [Data protection email]; we respond within the statutory time.',
    },
    {
      id: 'security',
      title: '8. Security',
      content:
        'Data travels over encrypted connections (TLS); messages are encrypted at rest; internal access is role-based and audited.',
    },
    {
      id: 'children',
      title: '9. Children',
      content: 'The service is for people aged 16 and over. We do not knowingly collect data from children under 16.',
    },
    {
      id: 'changes',
      title: '10. Changes',
      content: 'For material changes we update the version and effective date on this page and notify you in the app.',
    },
  ],
};

const TERMS_VI: LegalContent = {
  badge: 'Điều khoản sử dụng',
  sections: [
    {
      id: 'scope',
      title: '1. Phạm vi',
      content:
        'Điều khoản này áp dụng cho việc sử dụng ứng dụng và website DealGo do [Tên pháp nhân] (MST [MST]) vận hành, gồm dịch vụ đặt xe hai bánh (Ride) và đặt đồ ăn (Food). DealGo là nền tảng công nghệ kết nối khách hàng với tài xế và cửa hàng độc lập.',
    },
    {
      id: 'account',
      title: '2. Tài khoản',
      content:
        'Bạn đăng nhập bằng phương thức DealGo đang hỗ trợ và chịu trách nhiệm giữ an toàn thiết bị, thông tin đăng nhập của mình. Thông tin cung cấp phải chính xác. Một người chỉ sử dụng một tài khoản.',
    },
    {
      id: 'partners',
      title: '3. Tài xế và cửa hàng',
      content:
        'Tài xế và cửa hàng phải hoàn tất xác minh hồ sơ (giấy tờ tuỳ thân, giấy phép lái xe, đăng ký xe, giấy phép kinh doanh, an toàn thực phẩm khi áp dụng) và tuân thủ pháp luật liên quan. DealGo có thể từ chối hoặc tạm ngưng tài khoản đối tác không đáp ứng yêu cầu.',
    },
    {
      id: 'pricing',
      title: '4. Giá và thanh toán',
      content:
        'Giá cước, phí giao hàng và phụ phí được hiển thị trước khi bạn xác nhận. Giá cuối cùng do hệ thống DealGo xác định. Phương thức thanh toán khả dụng được hiển thị trong ứng dụng (hiện tại: tiền mặt).',
    },
    {
      id: 'cancel',
      title: '5. Huỷ chuyến/đơn và hoàn tiền',
      content:
        'Bạn có thể huỷ trong khoảng thời gian ứng dụng cho phép; phí huỷ (nếu có) được hiển thị trước khi huỷ. Khiếu nại về chuyến/đơn được gửi trong ứng dụng và được xử lý theo chính sách hỗ trợ.',
    },
    {
      id: 'conduct',
      title: '6. Quy tắc ứng xử',
      content:
        'Không quấy rối, đe doạ, gian lận, sử dụng sai mục đích kênh liên lạc hoặc vi phạm pháp luật. DealGo có thể tạm khoá hoặc chấm dứt tài khoản vi phạm.',
    },
    {
      id: 'liability',
      title: '7. Giới hạn trách nhiệm',
      content:
        'Trong phạm vi pháp luật cho phép, DealGo không chịu trách nhiệm cho thiệt hại gián tiếp phát sinh từ việc sử dụng dịch vụ. Quyền lợi của người tiêu dùng theo pháp luật Việt Nam không bị hạn chế.',
    },
    {
      id: 'privacy',
      title: '8. Dữ liệu cá nhân',
      content: 'Việc xử lý dữ liệu cá nhân tuân theo Chính sách quyền riêng tư của DealGo.',
    },
    {
      id: 'law',
      title: '9. Luật áp dụng và liên hệ',
      content:
        'Điều khoản được điều chỉnh bởi pháp luật Việt Nam. Liên hệ: [Email hỗ trợ], [Hotline], [Địa chỉ trụ sở].',
    },
  ],
};

const TERMS_EN: LegalContent = {
  badge: 'Terms of use',
  sections: [
    {
      id: 'scope',
      title: '1. Scope',
      content:
        'These terms govern the DealGo app and website operated by [Legal entity name] (Tax ID [Tax ID]), covering two-wheeler rides (Ride) and food delivery (Food). DealGo is a technology platform connecting customers with independent drivers and stores.',
    },
    {
      id: 'account',
      title: '2. Account',
      content:
        'You sign in with a method DealGo currently supports and are responsible for keeping your device and sign-in details safe. Information you provide must be accurate. One person, one account.',
    },
    {
      id: 'partners',
      title: '3. Drivers and stores',
      content:
        'Drivers and stores must complete verification (ID, driving licence, vehicle registration, business licence and food safety where applicable) and comply with applicable law. DealGo may decline or suspend partner accounts that do not meet requirements.',
    },
    {
      id: 'pricing',
      title: '4. Pricing and payment',
      content:
        'Fares, delivery fees and surcharges are shown before you confirm. The final price is determined by DealGo. Available payment methods are shown in the app (currently: cash).',
    },
    {
      id: 'cancel',
      title: '5. Cancellations and refunds',
      content:
        'You may cancel within the window the app allows; any cancellation fee is shown before you cancel. Complaints about a ride/order are submitted in the app and handled under the support policy.',
    },
    {
      id: 'conduct',
      title: '6. Conduct',
      content:
        'No harassment, threats, fraud, misuse of messaging or unlawful activity. DealGo may suspend or terminate accounts that violate these rules.',
    },
    {
      id: 'liability',
      title: '7. Limitation of liability',
      content:
        'To the extent permitted by law, DealGo is not liable for indirect damages arising from use of the service. Consumer rights under Vietnamese law are not limited.',
    },
    {
      id: 'privacy',
      title: '8. Personal data',
      content: 'Personal data is processed under the DealGo Privacy Policy.',
    },
    {
      id: 'law',
      title: '9. Governing law and contact',
      content: 'These terms are governed by Vietnamese law. Contact: [Support email], [Hotline], [Head office address].',
    },
  ],
};

const SUPPORT_VI: SupportContent = {
  systemStatusNotice: '',
  hotline: '[Hotline]',
  email: '[Email hỗ trợ]',
  address: '[Địa chỉ trụ sở]',
  hours: '8:00 – 22:00 hằng ngày',
  categories: [
    {
      id: 'ride',
      title: 'Chuyến xe',
      role: 'CUSTOMER',
      icon: 'motorcycle',
      tone: 'ride',
      items: ['Quên đồ trên xe', 'Khiếu nại lộ trình hoặc cước phí', 'Báo cáo sự cố an toàn hoặc thái độ tài xế'],
    },
    {
      id: 'food',
      title: 'Đơn đồ ăn',
      role: 'CUSTOMER',
      icon: 'utensils',
      tone: 'food',
      items: ['Giao sai hoặc thiếu món', 'Giao chậm hoặc không liên lạc được tài xế', 'Huỷ đơn và hoàn tiền'],
    },
    {
      id: 'account',
      title: 'Tài khoản',
      role: 'CUSTOMER',
      icon: 'user',
      tone: 'neutral',
      items: ['Không đăng nhập được', 'Đổi thông tin tài khoản', 'Xoá tài khoản (Cài đặt → Xoá tài khoản)'],
    },
    {
      id: 'partner',
      title: 'Tài xế & cửa hàng',
      role: 'DRIVER',
      icon: 'driver',
      tone: 'neutral',
      items: ['Hồ sơ xác minh', 'Đối soát và phí nền tảng', 'Tạm khoá tài khoản'],
    },
  ],
};

const SUPPORT_EN: SupportContent = {
  systemStatusNotice: '',
  hotline: '[Hotline]',
  email: '[Support email]',
  address: '[Head office address]',
  hours: '8:00 – 22:00 daily',
  categories: [
    {
      id: 'ride',
      title: 'Rides',
      role: 'CUSTOMER',
      icon: 'motorcycle',
      tone: 'ride',
      items: ['Lost item', 'Route or fare complaint', 'Safety incident or driver behaviour'],
    },
    {
      id: 'food',
      title: 'Food orders',
      role: 'CUSTOMER',
      icon: 'utensils',
      tone: 'food',
      items: ['Wrong or missing items', 'Late delivery or unreachable driver', 'Cancellation and refund'],
    },
    {
      id: 'account',
      title: 'Account',
      role: 'CUSTOMER',
      icon: 'user',
      tone: 'neutral',
      items: ['Cannot sign in', 'Change account details', 'Delete account (Settings → Delete account)'],
    },
    {
      id: 'partner',
      title: 'Drivers & stores',
      role: 'DRIVER',
      icon: 'driver',
      tone: 'neutral',
      items: ['Verification documents', 'Settlements and platform fees', 'Account suspension'],
    },
  ],
};


/** pt5u: "Quy chế sử dụng" for drivers and shops; seeded from the former static partner policy. */
const REGULATIONS_VI: LegalContent = {
  "badge": "Quy chế sử dụng",
  "sections": [
    {
      "id": "notice",
      "title": "Lưu ý",
      "content": "Bản dự thảo đang được rà soát pháp lý. Nội dung có thể thay đổi trước khi chính thức áp dụng; khi có khác biệt, Điều khoản sử dụng và thông tin hiển thị trong ứng dụng được ưu tiên."
    },
    {
      "id": "dang-ky",
      "title": "1. Đăng ký và xác minh",
      "content": "• Đối tác đăng ký trong ứng dụng DealGo bằng tài khoản của mình, sau đó gửi hồ sơ cửa hàng hoặc hồ sơ tài xế.\n• Tài xế phải hoàn tất xác minh danh tính và phương tiện (giấy tờ tùy thân, giấy phép lái xe, đăng ký xe phù hợp loại dịch vụ) trước khi nhận chuyến.\n• Cửa hàng phải hoàn tất xác minh thông tin kinh doanh và được DealGo duyệt trước khi hiển thị cho khách.\n• Thông tin khai báo phải chính xác và được cập nhật khi thay đổi. DealGo có thể yêu cầu bổ sung giấy tờ bất cứ lúc nào."
    },
    {
      "id": "gia",
      "title": "2. Giá và thương lượng",
      "content": "• Chuyến xe: khách có thể đề xuất giá, tài xế chấp nhận hoặc trả giá trong ứng dụng. Giá đã được hai bên chấp nhận là giá của chuyến; tài xế không được thu thêm ngoài ứng dụng.\n• Đồ ăn: không thương lượng giá. Cửa hàng chịu trách nhiệm về giá món, tình trạng còn/hết món và thông tin món trên ứng dụng.\n• Phí giao hàng và các khoản phí hiển thị cho khách được tính theo cấu hình của nền tảng tại thời điểm đặt đơn."
    },
    {
      "id": "phi-nen-tang",
      "title": "3. Phí nền tảng (hoa hồng)",
      "content": "• DealGo có thể áp dụng phí nền tảng theo phần trăm giá trị chuyến xe hoặc đơn hàng, cấu hình riêng cho từng loại dịch vụ và hiển thị trong ứng dụng đối tác.\n• Mức phí cụ thể và chu kỳ đối soát cho cửa hàng hiện CHƯA được công bố (đang chờ quyết định). DealGo sẽ thông báo trước khi áp dụng hoặc thay đổi mức phí."
    },
    {
      "id": "huy",
      "title": "4. Hủy chuyến / hủy đơn",
      "content": "• Đối tác chỉ hủy khi có lý do chính đáng (ví dụ: không liên hệ được khách, sự cố phương tiện, hết món) và phải chọn lý do trong ứng dụng.\n• Hủy nhiều lần không lý do, nhận rồi bỏ chuyến/đơn hoặc yêu cầu khách tự hủy có thể dẫn đến hạn chế nhận việc."
    },
    {
      "id": "thanh-toan",
      "title": "5. Thanh toán và đối soát",
      "content": "• Khách có thể thanh toán bằng tiền mặt hoặc trực tuyến (MoMo, ZaloPay, VNPay, thẻ) khi phương thức được bật.\n• Đơn tiền mặt: tài xế thu đúng số tiền hiển thị trong ứng dụng. Đơn trực tuyến: tài xế không thu thêm tiền của khách.\n• Ví DealGo hiện chưa được sử dụng. Khoản tiền đối tác nhận từ đơn trực tuyến được đối soát theo kỳ do nền tảng công bố."
    },
    {
      "id": "ung-xu",
      "title": "6. Ứng xử và an toàn",
      "content": "• Lịch sự, đúng giờ, tuân thủ luật giao thông và quy định an toàn thực phẩm.\n• Chỉ liên lạc với khách qua chat/gọi trong ứng dụng cho mục đích hoàn thành chuyến/đơn; không quấy rối, không lôi kéo khách giao dịch ngoài ứng dụng.\n• Khách và đối tác có thể đánh giá lẫn nhau sau mỗi chuyến/đơn. Đánh giá được dùng để cải thiện chất lượng dịch vụ."
    },
    {
      "id": "tam-khoa",
      "title": "7. Tạm khóa và chấm dứt",
      "content": "• DealGo có thể tạm khóa hoặc chấm dứt tài khoản đối tác khi: thông tin xác minh sai hoặc hết hạn, gian lận giá hoặc thanh toán, vi phạm an toàn, nhiều khiếu nại đã được xác minh, hoặc vi phạm pháp luật.\n• Đối tác được thông báo lý do và có thể liên hệ Hỗ trợ để giải trình."
    },
    {
      "id": "du-lieu",
      "title": "8. Dữ liệu cá nhân",
      "content": "• Đối tác chỉ sử dụng thông tin của khách (tên, số điện thoại ẩn qua ứng dụng, địa chỉ) để hoàn thành chuyến/đơn và không lưu giữ, chia sẻ cho mục đích khác.\n• Dữ liệu của đối tác được xử lý theo Chính sách bảo mật của DealGo."
    }
  ]
};
const REGULATIONS_EN: LegalContent = {
  "badge": "Regulations",
  "sections": [
    {
      "id": "notice",
      "title": "Notice",
      "content": "Draft under legal review. Content may change before it takes effect; where it differs, the Terms of use and the information shown in the app prevail."
    },
    {
      "id": "dang-ky",
      "title": "1. Registration and verification",
      "content": "• Partners register in the DealGo app with their account, then submit a store or driver profile.\n• Drivers must complete identity and vehicle verification (ID, driving licence, vehicle registration matching the service type) before accepting rides.\n• Stores must complete business verification and be approved by DealGo before they are shown to customers.\n• Information must be accurate and kept up to date. DealGo may request additional documents at any time."
    },
    {
      "id": "gia",
      "title": "2. Pricing and negotiation",
      "content": "• Rides: customers may propose a price; drivers accept or counter in the app. The agreed price is the ride price; drivers must not charge extra outside the app.\n• Food: no negotiation. Stores are responsible for item prices, availability and item information in the app.\n• Delivery fees and other customer-facing fees follow the platform configuration at the time of ordering."
    },
    {
      "id": "phi-nen-tang",
      "title": "3. Platform fee (commission)",
      "content": "• DealGo may charge a platform fee as a percentage of the ride or order value, configured per service and shown in the partner app.\n• Exact rates and the store settlement cycle are NOT published yet (pending decision). DealGo will give notice before applying or changing any fee."
    },
    {
      "id": "huy",
      "title": "4. Cancellations",
      "content": "• Partners may cancel only for a valid reason (e.g. customer unreachable, vehicle issue, item sold out) selected in the app.\n• Repeated unjustified cancellations, abandoning accepted jobs, or asking customers to cancel may restrict access to new jobs."
    },
    {
      "id": "thanh-toan",
      "title": "5. Payment and settlement",
      "content": "• Customers may pay in cash or online (MoMo, ZaloPay, VNPay, card) when the method is enabled.\n• Cash orders: drivers collect exactly the amount shown in the app. Online orders: drivers collect nothing from the customer.\n• The DealGo wallet is not in use. Partner earnings from online orders are settled on the cycle the platform publishes."
    },
    {
      "id": "ung-xu",
      "title": "6. Conduct and safety",
      "content": "• Be courteous and punctual, follow traffic law and food safety rules.\n• Contact customers only through in-app chat/call to complete the job; no harassment and no moving transactions off the app.\n• Customers and partners can rate each other after each job; ratings are used to improve service quality."
    },
    {
      "id": "tam-khoa",
      "title": "7. Suspension and termination",
      "content": "• DealGo may suspend or terminate a partner account for false or expired verification, price or payment fraud, safety violations, verified repeated complaints, or unlawful conduct.\n• Partners are told the reason and may contact Support to respond."
    },
    {
      "id": "du-lieu",
      "title": "8. Personal data",
      "content": "• Partners use customer information only to complete the job and must not keep or share it for other purposes.\n• Partner data is processed under the DealGo Privacy policy."
    }
  ]
};

export const REGULATIONS_META = {
  "vi": {
    "title": "Quy chế sử dụng dành cho tài xế và cửa hàng",
    "summary": "Quy định áp dụng cho quán ăn/cửa hàng (đối tác bán hàng) và tài xế (Bike, Car 4 chỗ, Car 7 chỗ) hoạt động trên DealGo trên toàn quốc. Khách hàng, đối tác và tài xế dùng chung một ứng dụng DealGo."
  },
  "en": {
    "title": "Driver and store regulations",
    "summary": "Rules for restaurants/stores (merchants) and drivers (Bike, Car 4-seat, Car 7-seat) on DealGo nationwide in Vietnam. Customers, merchants and drivers use the same DealGo app."
  }
};

export const PUBLIC_PAGE_DEFAULTS: Record<PublicPageSlug, Record<PublicPageLocale, PublicPageDefault>> = {
  privacy: {
    vi: {
      title: 'Chính sách quyền riêng tư',
      summary: 'Cách DealGo thu thập, sử dụng, lưu trữ và bảo vệ dữ liệu cá nhân của bạn.',
      content: PRIVACY_VI,
    },
    en: {
      title: 'Privacy Policy',
      summary: 'How DealGo collects, uses, stores and protects your personal data.',
      content: PRIVACY_EN,
    },
  },
  terms: {
    vi: {
      title: 'Điều khoản sử dụng',
      summary: 'Quy định khi sử dụng dịch vụ Ride và Food trên DealGo.',
      content: TERMS_VI,
    },
    en: {
      title: 'Terms of Use',
      summary: 'Rules for using DealGo Ride and Food.',
      content: TERMS_EN,
    },
  },
  regulations: {
    vi: { ...REGULATIONS_META.vi, content: REGULATIONS_VI },
    en: { ...REGULATIONS_META.en, content: REGULATIONS_EN },
  },
  support: {
    vi: { title: 'Trung tâm hỗ trợ', summary: 'Liên hệ DealGo khi bạn cần giúp đỡ.', content: SUPPORT_VI },
    en: { title: 'Support', summary: 'Contact DealGo when you need help.', content: SUPPORT_EN },
  },
};
