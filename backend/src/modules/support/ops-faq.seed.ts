export type OpsFaqSeed = {
  openId: string;
  question: string;
  suggestedAnswer: string;
  category: 'POLICY' | 'OPS' | 'PRODUCT' | 'TECH';
  sortOrder: number;
};

/**
 * Seed FAQ drafts for OPEN-001..021 with concrete operational and technical recommendations.
 */
export const OPS_FAQ_SEEDS: readonly OpsFaqSeed[] = [
  {
    openId: 'OPEN-001',
    category: 'OPS',
    sortOrder: 1,
    question: 'Thành phố/vùng pilot, ranh giới phục vụ và tiêu chí mở rộng là gì?',
    suggestedAnswer: `**Khuyến nghị triển khai (PROPOSED):**
1. **Địa bàn Pilot Giai đoạn 1:** Triển khai độc quyền tại Thành phố **Đà Nẵng**, tập trung 4 quận trung tâm: Hải Châu, Thanh Khê, Sơn Trà và Ngũ Hành Sơn.
2. **Ranh giới phục vụ (Geofence):** Thiết lập Polygon lõi bán kính 15km tính từ cầu Rồng; các cuốc xe hoặc đơn giao đồ ăn ngoài toạ độ này sẽ nhận cảnh báo ngoài vùng phục vụ và áp dụng phụ phí ngoại vùng.
3. **Tiêu chí mở rộng Phase 2:** Xem xét mở rộng sang Hội An / Quảng Nam và TP. Huế khi đạt 3 chỉ số trong 60 ngày liên tục: (a) ≥ 500 tài xế hoạt động thường xuyên; (b) Tỷ lệ hoàn thành cuốc ≥ 92%; (c) Thời gian tài xế có mặt đón khách trung bình ≤ 7 phút.`,
  },
  {
    openId: 'OPEN-002',
    category: 'POLICY',
    sortOrder: 2,
    question: 'Kênh thu tiền đầu tiên, đơn vị nhận tiền, COD/online/refund?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Phương thức thanh toán:** Triển khai song song 3 kênh trong giai đoạn đầu: (a) **Tiền mặt (COD)** với hạn mức trần 500.000 VNĐ/giao dịch; (b) **Cổng thanh toán MoMo / VNPAY QR**; (c) **Ví nội bộ DealGo**.
2. **Quy trình hoàn tiền (Refund):** Đối với thanh toán online, hoàn tức thì về Ví DealGo hoặc hoàn về tài khoản nguồn (thẻ/ví) trong 24-48 giờ làm việc. Đối với đơn COD, hoàn qua ví DealGo hoặc chuyển khoản trực tiếp sau khi thẩm định khiếu nại.
3. **Đối soát & Thu hộ:** Tiền COD do tài xế thu được ghi nhận ngay vào tài khoản công nợ của tài xế trên hệ thống Ledger; tự động đối soát khấu trừ phí dịch vụ hàng ngày (T+1).`,
  },
  {
    openId: 'OPEN-003',
    category: 'PRODUCT',
    sortOrder: 3,
    question: 'Công thức giá tham chiếu Ride/Food, phụ phí, phí nền tảng, hủy, KM?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **DealGo Ride (Xe 2 bánh):**
   - Giá mở cửa: 15.000 VNĐ cho 2km đầu tiên.
   - Giá mỗi km tiếp theo: 5.500 VNĐ/km.
   - Hệ số giờ cao điểm (07:00–08:30 và 17:00–18:30) hoặc thời tiết xấu: nhân hệ số 1.2 – 1.4 dựa trên cung cầu thực tế.
   - Phí hủy chuyến: 10.000 VNĐ nếu khách hủy sau khi tài xế đã di chuyển đón quá 5 phút (toàn bộ tiền phí hủy chuyển cho tài xế).
   - Phí nền tảng (Platform Commission): Cố định 15% doanh thu cuốc xe.
2. **DealGo Food:**
   - Phí giao hàng: 16.000 VNĐ cho 3km đầu, 5.000 VNĐ/km tiếp theo.
   - Phí nền tảng thu từ Merchant: Chiết khấu 18% – 20% trên giá trị món ăn niêm yết.`,
  },
  {
    openId: 'OPEN-004',
    category: 'TECH',
    sortOrder: 4,
    question: 'Bán kính tìm tài xế, offer timeout, chiến lược dispatch/reassign?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Bán kính quét (Radius):** Mặc định 2.5km ở khu vực nội thành có mật độ cao; mở rộng lên 5.0km ở khu vực ngoại thành hoặc giờ thấp điểm.
2. **Offer Timeout:** 15 giây cho mỗi lượt mời tài xế nhận cuốc (TTL). Nếu tài xế bỏ qua hoặc từ chối, hệ thống chuyển sang tài xế kế tiếp.
3. **Chiến lược Dispatch (Điều phối):** Áp dụng thuật toán Broadcast có trọng số (Weighted Dispatch) kết hợp khoảng cách di chuyển thực tế (ETA) và điểm đánh giá tài xế (Rating ≥ 4.8 được ưu tiên). Tối đa 3 vòng phát sóng trước khi thông báo khách hàng điều chỉnh giá hoặc thử lại.
4. **Reassign (Điều phối lại):** Nếu tài xế gặp sự cố bất khả kháng trước khi đến điểm đón, hệ thống tự động gán tài xế khác trong bán kính 1.5km gần nhất mà không làm hủy đơn của khách.`,
  },
  {
    openId: 'OPEN-005',
    category: 'PRODUCT',
    sortOrder: 5,
    question: 'Kiêm nhiệm role và số job đồng thời mỗi tài xế?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Kiêm nhiệm:** Tài xế 2 bánh được phép đăng ký và bật cả hai chế độ Ride (chở khách) và Food (giao đồ ăn) trên cùng một tài khoản tài xế.
2. **Quy tắc Single Active Job (Chỉ 1 việc tại một thời điểm):** Khi đang nhận cuốc chở khách (Ride), tài xế tuyệt đối KHÔNG được nhận thêm đơn khác.
3. **Quy tắc gộp đơn Food (Batching):** Cho phép gộp tối đa 02 đơn đồ ăn cùng lúc VỚI ĐIỀU KIỆN: cùng một cửa hàng hoặc 2 quán cách nhau dưới 500m và điểm giao của 2 khách cùng trên một cung đường (độ lệch tuyến đường không quá 1.5km).`,
  },
  {
    openId: 'OPEN-006',
    category: 'POLICY',
    sortOrder: 6,
    question: 'Pháp nhân, mô hình vận tải/TMĐT, đối tác và điều kiện hoạt động?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Pháp lý:** Hoạt động dưới tư cách đơn vị cung cấp ứng dụng phần mềm kết nối vận tải (Nghị định 10/2020/NĐ-CP) và Sàn giao dịch thương mại điện tử dịch vụ giao đồ ăn (Nghị định 52/2013/NĐ-CP, Nghị định 85/2021/NĐ-CP).
2. **Hợp đồng đối tác:** Tài xế ký Hợp đồng Hợp tác Kinh doanh (BCC) điện tử; Quán ăn ký Hợp đồng Cung cấp Dịch vụ TMĐT.
3. **Hồ sơ KYC bắt buộc đối với Tài xế:** CCCD gắn chip (xác thực eKYC), Giấy phép lái xe hạng A1/A2 hợp lệ, Đăng ký xe (Cà vẹt), Bảo hiểm TNDS bắt buộc và Lý lịch tư pháp số 2 (hoặc giấy xác nhận không tiền án tiền sự cấp trong vòng 6 tháng).`,
  },
  {
    openId: 'OPEN-007',
    category: 'OPS',
    sortOrder: 7,
    question: 'Load mục tiêu, SLO/RTO/RPO, ngân sách và staffing hỗ trợ?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Tải mục tiêu (Target Load):** Thiết kế chịu tải tối thiểu 1.500 cuốc xe & đơn hàng/giờ trong giai đoạn pilot; đỉnh điểm 150 requests/giây (RPS) tại API Gateway.
2. **SLO / RTO / RPO:**
   - SLO: Tỷ lệ sẵn sàng hệ thống ≥ 99.9%; Latency tìm kiếm & điều phối cuốc P95 < 250ms.
   - RTO (Recovery Time Objective): ≤ 15 phút khi có sự cố hạ tầng.
   - RPO (Recovery Point Objective): ≤ 1 phút (đồng bộ dữ liệu liên tục với PostgreSQL Replication & WAL archiving).
3. **Staffing Vận hành & Hỗ trợ:** Duy trì đội ngũ trực 24/7 gồm 1 Trưởng ca Điều hành + 3 chuyên viên trực tổng đài và xử lý ngoại lệ theo ca 8 tiếng.`,
  },
  {
    openId: 'OPEN-008',
    category: 'TECH',
    sortOrder: 8,
    question: 'Provider OTP, KYC, maps, payment, notification và điều kiện tích hợp?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Bản đồ & Định vị:** Tích hợp Goong Maps API (dữ liệu giao thông và địa chỉ Việt Nam chính xác nhất) kết hợp Mapbox/OSM làm dự phòng.
2. **SMS & OTP:** Sử dụng dịch vụ SMS Brandname của Viettel/FPT Telecom; bổ sung kênh OTP qua Zalo Notification Service (ZNS) để tối ưu chi phí (tiết kiệm 40% so với SMS truyền thống).
3. **Thanh toán:** Cổng VNPAY và MoMo Merchant API với cơ chế Webhook Idempotency nghiêm ngặt.
4. **Push Notification:** Firebase Cloud Messaging (FCM) v1 kết hợp WebSockets cho realtime tracking.
5. **eKYC:** Sử dụng giải pháp FPT.AI eKYC hoặc VNPT eKYC để đối soát khuôn mặt và đọc thông tin CCCD gắn chip.`,
  },
  {
    openId: 'OPEN-009',
    category: 'PRODUCT',
    sortOrder: 9,
    question: 'Food: một cửa hàng/đơn hay giỏ nhiều cửa hàng?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Nguyên tắc MVP:** Mỗi đơn hàng chỉ áp dụng cho đúng **01 cửa hàng duy nhất (Single Merchant per Cart)**.
2. **Lý do vận hành:** Đảm bảo thời gian chuẩn bị món ăn nhanh nhất, tài xế không phải chờ đợi qua nhiều điểm lấy đồ, giữ trọn vẹn chất lượng món ăn nóng sốt và đơn giản hóa khâu đối soát tài chính/khiếu nại.
3. **Lộ trình tương lai:** Chỉ xem xét tính năng giỏ hàng đa quán (Multi-store) cho các thương hiệu nằm trong cùng một Tòa nhà ẩm thực / Food Court tại các trung tâm thương mại lớn ở Phase 3.`,
  },
  {
    openId: 'OPEN-010',
    category: 'POLICY',
    sortOrder: 10,
    question: 'Thời điểm Food authorize/capture/collect so với accept và assignment?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Đơn thanh toán Online:**
   - Bước 1 (Đặt đơn): Thực hiện **Pre-authorization (Tạm giữ tiền)** ngay khi khách hàng nhấn đặt đơn.
   - Bước 2 (Xác nhận): Khi quán ăn chấp nhận đơn (Merchant Accepted) và bắt đầu làm món, hệ thống mới tiến hành **Capture (Trừ tiền chính thức)**.
   - Bước 3 (Hủy/Sự cố): Nếu quán từ chối hoặc sau 10 phút không có tài xế nhận, lệnh tạm giữ sẽ tự động được giải phóng (Auto-void) hoàn trả 100% tiền ngay lập tức cho khách hàng.
2. **Đơn COD:** Tiền được thu trực tiếp khi tài xế giao món tận tay khách hàng; tài xế ứng tiền cho quán trước hoặc quán đối soát qua ví Merchant DealGo.`,
  },
  {
    openId: 'OPEN-011',
    category: 'OPS',
    sortOrder: 11,
    question: 'Bằng chứng pickup/delivery: app confirm, OTP, ảnh, chữ ký?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Cuốc xe (Ride):** Xác thực tự động bằng Geofence GPS của tài xế và khách hàng khi xe đến điểm đón và điểm trả (dung sai ≤ 30 mét).
2. **Giao đồ ăn (Food):**
   - Tài xế bắt buộc chụp ảnh gói hàng đã giao tại điểm đến kèm toạ độ GPS (Proof of Delivery Photo) hiển thị trên ứng dụng.
   - Với đơn hàng giá trị cao (từ 300.000 VNĐ trở lên) hoặc khách có tiền sử khiếu nại: Yêu cầu cung cấp **Mã OTP giao nhận 4 số** do khách hàng cung cấp cho tài xế trước khi bấm hoàn tất đơn.`,
  },
  {
    openId: 'OPEN-012',
    category: 'TECH',
    sortOrder: 12,
    question: 'Driver tracking nền: xin quyền khi nào, lưu đến đâu, degrade ra sao?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Thời điểm xin quyền:** Yêu cầu quyền vị trí nền (Always / Background Location) ngay khi tài xế bật trạng thái 'Sẵn sàng hoạt động' (Go Online), đi kèm giải thích rõ ràng về mục đích điều phối cuốc xe.
2. **Tần suất thu thập:** 5 giây/lần khi đang trong chuyến đi (In-trip); 15 giây/lần khi ở trạng thái chờ cuốc (Idle Online).
3. **Lưu trữ & Bảo mật:** Dữ liệu toạ độ GPS được nén và lưu trữ trong 90 ngày để phục vụ phân tích tuyến đường và tra soát khiếu nại tai nạn/thất lạc, sau đó chuyển sang kho lưu trữ lạnh (Cold Storage).
4. **Degrade khi mất mạng:** App tài xế lưu tạm bộ nhớ đệm (Local Buffer) tối đa 50 điểm toạ độ và tự động gửi bù về máy chủ khi có kết nối mạng trở lại.`,
  },
  {
    openId: 'OPEN-013',
    category: 'PRODUCT',
    sortOrder: 13,
    question: 'Merchant nhiều cửa hàng và nhân viên quản lý riêng ở release đầu?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Giai đoạn đầu (Release 1):** Mỗi cửa hàng gắn với 01 tài khoản Merchant Chủ quán (Store Owner).
2. **Phân quyền Quản trị Chuỗi (Chain Management):** Cung cấp cấu trúc 2 tầng:
   - **Tài khoản Chuỗi/Thương hiệu:** Quản lý danh mục món chung, phân bổ doanh thu và xem báo cáo tổng hợp.
   - **Tài khoản Chi nhánh:** Dành cho nhân viên thu ngân/bếp tại điểm bán, chỉ có quyền xác nhận đơn, báo hết món và theo dõi tài xế đến lấy đồ mà không xem được báo cáo doanh thu tài chính chuyên sâu.`,
  },
  {
    openId: 'OPEN-014',
    category: 'POLICY',
    sortOrder: 14,
    question: 'Participant pairs và cửa sổ chat/call mở/đóng theo trạng thái?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Các cặp liên lạc hợp lệ:**
   - Cuốc Ride: Khách hàng ↔ Tài xế.
   - Đơn Food: Khách hàng ↔ Tài xế; Tài xế ↔ Quán ăn; Khách hàng ↔ Hỗ trợ viên CSKH.
2. **Cửa sổ liên lạc:** Tự động kích hoạt ngay khi tài xế nhận đơn và **tự động đóng sau 30 phút** kể từ thời điểm cuốc xe hoặc đơn hàng hoàn tất (hoặc hủy).
3. **Bảo vệ quyền riêng tư:** Tất cả các cuộc gọi đều sử dụng VoIP in-app hoặc số điện thoại ảo (Masked Virtual Numbers), tuyệt đối không để lộ số điện thoại cá nhân thật của khách và tài xế.`,
  },
  {
    openId: 'OPEN-015',
    category: 'OPS',
    sortOrder: 15,
    question: 'Mức độ trực hỗ trợ, an toàn chuyến, escalation khẩn cấp?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Nút bấm khẩn cấp (SOS):** Tích hợp nút SOS nổi bật trên màn hình cuốc xe dành cho cả khách hàng và tài xế. Khi bấm:
   - Tự động kích hoạt còi báo động trên máy.
   - Gửi toạ độ GPS trực tiếp tới 3 số điện thoại người thân đã đăng ký trước.
   - Phát cảnh báo ưu tiên cao nhất lên màn hình giám sát trung tâm Ops (Pop-up cảnh báo đỏ + chuông báo động).
2. **Quy trình Escalate:** Nhân viên Ops phụ trách an toàn bắt buộc gọi kiểm tra người dùng trong vòng 60 giây và kết nối lực lượng chức năng/công an 113 nếu phát hiện dấu hiệu nguy hiểm hoặc không liên lạc được.`,
  },
  {
    openId: 'OPEN-016',
    category: 'POLICY',
    sortOrder: 16,
    question: 'Food đã làm món nhưng không có driver/hủy: ai chịu phí?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Trường hợp lỗi do khách hàng hủy sau khi quán đã xác nhận làm món:** Khách hàng chịu phí hủy tương đương 100% tiền món; DealGo bồi hoàn 100% giá vốn món ăn (75-80% giá niêm yết) cho nhà hàng.
2. **Trường hợp lỗi do hệ thống không tìm được tài xế giao hàng sau 20 phút:** DealGo bồi hoàn 80% giá trị món ăn cho quán từ Quỹ Vận hành Sự cố; khách hàng được hoàn 100% tiền đơn và tặng thêm voucher giảm giá 30.000 VNĐ xin lỗi.
3. **Yêu cầu bằng chứng:** Quán ăn chụp ảnh món ăn đã hoàn thành đóng gói sẵn để gửi yêu cầu đền bù tự động trên ứng dụng Merchant.`,
  },
  {
    openId: 'OPEN-017',
    category: 'OPS',
    sortOrder: 17,
    question: 'Ride bắt đầu/kết thúc bằng thao tác nào; tranh chấp điểm đón/trả?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Thao tác Bắt đầu/Kết thúc:**
   - Bắt đầu cuốc (Start Trip): Tài xế bấm 'Bắt đầu chuyến' chỉ khi toạ độ GPS của tài xế nằm trong bán kính 50m so với vị trí khách đặt đón.
   - Kết thúc cuốc (End Trip): Tài xế bấm 'Hoàn thành' tại điểm trả khách; ứng dụng yêu cầu khách hàng xác nhận hoặc tự động đóng sau 2 phút nếu không có khiếu nại.
2. **Xử lý tranh chấp điểm đón/trả:**
   - Nếu khách yêu cầu thay đổi điểm đến quá 500m: Ứng dụng tự động cập nhật lại lộ trình và cộng thêm cước phí chặng phát sinh theo đơn giá km thực tế.
   - Mọi khiếu nại về đón sai điểm hoặc cố tình đi đường vòng được hệ thống Ops tự động đối soát dựa trên lịch sử bản đồ GPS của cả 2 thiết bị.`,
  },
  {
    openId: 'OPEN-018',
    category: 'POLICY',
    sortOrder: 18,
    question: 'Driver thu hộ COD: hạn mức, ghi nợ, đối soát?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Hạn mức công nợ COD:**
   - Tài xế mới (dưới 30 ngày): Hạn mức tối đa 1.000.000 VNĐ.
   - Tài xế chuẩn (rating ≥ 4.85, > 50 chuyến): Hạn mức tối đa 3.000.000 VNĐ.
2. **Cơ chế khoá nhận đơn:** Khi số tiền COD đang giữ đạt 80% hạn mức, hệ thống gửi cảnh báo nhắc nộp tiền. Khi chạm 100% hạn mức, hệ thống tạm dừng gán đơn COD mới cho tài xế cho đến khi nạp tiền hoàn ứng qua Ví DealGo hoặc tài khoản ngân hàng.
3. **Chu kỳ đối soát:** Thực hiện tự động mỗi ngày vào 23:00; toàn bộ tiền thưởng và thu nhập ròng của tài xế được chuyển về tài khoản ngân hàng liên kết vào sáng ngày làm việc tiếp theo (T+1).`,
  },
  {
    openId: 'OPEN-019',
    category: 'PRODUCT',
    sortOrder: 19,
    question: 'Quy tắc thương lượng giá Ride: số vòng, hạn, bound, hết offer?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Biên độ thương lượng giá an toàn:**
   - Giá sàn (Floor Price): Không thấp hơn -15% so với giá tham chiếu gợi ý của DealGo (đảm bảo quyền lợi tài xế).
   - Giá trần (Ceiling Price): Không vượt quá +25% so với giá tham chiếu gợi ý (chống đầu cơ, ép giá khách).
2. **Số vòng thương lượng (Rounds):** Giới hạn tối đa 03 lượt trả giá qua lại giữa khách và các tài xế lân cận.
3. **Thời gian cân nhắc:** Mỗi lượt trả giá có thời hạn hiệu lực 15 giây. Sau 3 vòng không thống nhất được giá, hệ thống sẽ đề xuất quay về mức giá tham chiếu gốc hoặc mở rộng tìm kiếm tài xế khác.`,
  },
  {
    openId: 'OPEN-020',
    category: 'TECH',
    sortOrder: 20,
    question: 'Enrollment/recovery passkey/SMS/email và chính sách admin disable?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Phương thức xác thực ưu tiên:** Triển khai **Passkey (FIDO2 / WebAuthn)** làm phương thức xác thực không mật khẩu tiện lợi và bảo mật nhất cho cả ứng dụng Mobile và Admin Web.
2. **Kênh dự phòng:** Duy trì SMS OTP và Email OTP làm kênh xác thực thứ cấp khi đăng nhập từ thiết bị mới.
3. **Quy trình phục hồi tài khoản:** Khi mất điện thoại hoặc không nhận được SMS: Cho phép người dùng xác minh danh tính bằng nhận diện khuôn mặt (eKYC FaceMatch) đối chiếu với ảnh CCCD đã đăng ký ban đầu.
4. **Chính sách Admin:** Quản trị viên Ops có quyền tắt tạm thời một cổng xác thực nếu đối tác SMS/Email gặp sự cố nhưng hệ thống LUÔN khóa cứng không cho phép tắt đồng thời tất cả các phương thức đăng nhập.`,
  },
  {
    openId: 'OPEN-021',
    category: 'TECH',
    sortOrder: 21,
    question: 'Chat/call provider, retention, block/report, native call handling?',
    suggestedAnswer: `**Khuyến nghị triển khai:**
1. **Nhà cung cấp hạ tầng:** Sử dụng **LiveKit WebRTC** tự lưu trữ (Self-hosted) hoặc Cloud để phục vụ tính năng cuộc gọi thoại Audio-only nội bộ với độ trễ thấp và băng thông tối ưu trên mạng di động 4G/5G.
2. **Chính sách ghi âm & Lưu trữ:** KHÔNG ghi âm nội dung cuộc gọi thoại để tuân thủ quyền riêng tư của người dùng. Tin nhắn văn bản (Chat) được lưu trữ mã hóa trong 30 ngày để làm căn cứ xử lý tranh chấp khiếu nại, sau đó được xóa tự động vĩnh viễn (Auto-purge).
3. **Tính năng Báo cáo/Chặn (Block/Report):** Cho phép người dùng gắn cờ tin nhắn quấy rối hoặc thô tục; hệ thống tự động lọc từ ngữ phản cảm bằng bộ lọc từ khoá và AI tự động, đồng thời chuyển vụ việc cho đội ngũ Ops xử lý xử phạt khóa tài khoản vi phạm.`,
  },
];
