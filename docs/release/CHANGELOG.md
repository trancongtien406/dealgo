# Changelog

Thay đổi đáng chú ý cho người vận hành, mới nhất ở trên.

## 2026-11-04

### Thêm
- **Bộ hồ sơ Google Play.** `docs/release/play-store/` gồm khai báo Tính năng tài chính, metadata vi/en, App content,
  Data safety, review notes và checklist compliance. Khai báo tài chính chọn `Other` cho khoản trả trước phí nền tảng
  của tài xế (closed-loop, không phải ví), kèm câu trả lời dán sẵn và template nếu Google hỏi lại.
- **Chặn nộp đã ghi nhận.** Thiếu URL xoá tài khoản công khai, `READ_MEDIA_IMAGES` chưa bỏ/khai báo, và thẻ nạp phí
  vẫn hiện khi `DRIVER_TOP_UP_ENABLED=false`.
- **Env payOS.** `backend/.env.example` có `DRIVER_TOP_UP_PROVIDER` và `PAYOS_*`; catalog secret ghi rõ chúng và
  các khóa `DRIVER_TOP_UP_*` là cài đặt Admin.

### Sửa
- **Trang xoá tài khoản công khai `/account-deletion`.** Trang web mới (vi + `?lang=en`, không cần đăng nhập) mô tả
  cách xoá trong app, dữ liệu bị xoá/giữ lại, thời hạn 7 ngày (cấu hình 0–90) và điều kiện chặn; form gửi yêu cầu
  thành phiếu hỗ trợ (`category=ACCOUNT`) để người đã gỡ app vẫn xoá được. Dùng làm URL **Data deletion** của Google Play.
- **Bỏ quyền ảnh khỏi Android.** Manifest không còn `READ_MEDIA_IMAGES`/`READ_EXTERNAL_STORAGE`; luồng chọn avatar
  không xin quyền thư viện ảnh nữa (picker hệ thống chỉ cấp file được chọn). Merged release manifest đã kiểm tra.
- **Thẻ nạp phí chỉ hiện khi bật.** Màn Thu nhập tài xế ẩn thẻ "Phí nền tảng" khi `DRIVER_TOP_UP_ENABLED=false`
  thay vì dẫn vào màn hình chưa khả dụng.

## 2026-10-28

### Thêm
- **Giỏ hàng nổi.** Trang quán, tuỳ chọn món, Đồ ăn, tìm kiếm và danh mục có thanh giỏ hàng nổi khi giỏ có món: số món,
  tổng tiền, "Còn thiếu …" cho đơn tối thiểu hoặc "Tiết kiệm …", nút "Xem giỏ hàng".
- **Ảnh bìa và giới thiệu quán.** Cửa hàng tự đặt ảnh bìa và đoạn giới thiệu ở Hồ sơ quán; trang quán chỉ hiện thông tin
  quán đã cài hoặc hệ thống tính được. Cần migration `20261121090000_food_store_cover_description`.

### Đổi
- **Ưu đãi dạng vé.** Ưu đãi ở trang quán (dải + "Xem tất cả"), "Ưu đãi của tôi" khi thanh toán và "Ưu đãi của quán" phía
  cửa hàng hiện như vé: mức giảm lớn, điều kiện đầy đủ (đơn từ, tối đa, HSD, số lượt còn), nút "Dùng" / "Đã dùng".
- **iOS chỉ dùng Swift Package Manager.** Bỏ CocoaPods (`Podfile`, `Pods`); mở `ios/Runner.xcworkspace` hoặc
  `Runner.xcodeproj` đều build được scheme `dev` / `prod`.
- **Âm báo trong app dùng `audioplayers`** (thay `flutter_ringtone_player`, vốn không có Swift Package Manager). Cuộc gọi đổ
  chuông trong app phát tiếng chuông riêng `dealgo_call_ring.mp3` (lặp) kèm rung; khi tắt âm báo cuốc mới thì phát
  `dealgo_notify.mp3`. Đang gọi thoại thì báo cuốc mới chỉ rung. Chuông CallKit / ConnectionService và âm push không đổi.
- **Đặt xe: điểm đón ở trên, điểm đến ở dưới.** Màn đặt xe xếp ô theo đúng thứ tự các màn sau (chấm xanh điểm đón, ghim
  đỏ điểm đến, nút đảo ở ô điểm đến); vào tab Đặt vẫn mở chọn điểm đến trước.
- **Giá chuyến xe tròn 1.000đ.** Giá gợi ý, giá tối thiểu, giá khách đưa/nâng và giá tài xế trả lại đều làm tròn lên
  1.000đ trên máy chủ (vd. 58.036đ → 59.000đ); trần giá trả lại làm tròn xuống. Cần deploy backend, không cần migration.
- **Voucher giảm theo % làm tròn xuống 1.000đ.** Áp cho chuyến xe và đồ ăn, sau khi áp trần giảm tối đa (vd. 10% của
  58.036đ → giảm 5.000đ thay cho 5.804đ); mức giảm dưới 1.000đ thì mã bị từ chối. Ước tính trên app khớp với máy chủ.
- **Thẻ hạng xe và nút giá gợi ý bỏ dấu tích.** Lựa chọn đang chọn chỉ dùng viền đậm; trình đọc màn hình vẫn đọc là đã
  chọn.

## 2026-10-27

### Thêm
- **Ưu đãi của quán.** Cửa hàng tự tạo ưu đãi giảm % hoặc giảm tiền (đơn tối thiểu, tổng lượt, lượt mỗi khách, thời gian),
  tạm dừng, chạy tiếp hoặc kết thúc ở "Ưu đãi của quán". Khách thấy ưu đãi trên thẻ quán và trang quán, bấm "Dùng" để gắn
  mã vào giỏ. Quán chịu tiền giảm; hoa hồng Food không đổi. Admin lọc khuyến mãi theo nguồn (nền tảng / quán), đổi trạng
  thái phải ghi lý do.
- **Đánh giá quán đầy đủ.** Tab Đánh giá có phân bố sao, lọc theo số sao, tải thêm và phản hồi của quán. Cửa hàng trả lời
  công khai ở "Đánh giá của khách"; Admin ẩn/hiện đánh giá ở "Đánh giá quán" (có lý do, ghi audit). App mời đánh giá ngay
  khi đơn giao xong.
- **Trang quán mới.** Ảnh bìa + logo, điểm, khoảng cách, thời gian giao, nhóm "Món bán chạy", chip nhảy tới nhóm món và ô
  tìm món trong quán. Thẻ quán hiện khoảng cách, thời gian giao, phí giao từ và nhãn ưu đãi; tìm quán khớp cả tên món.

- **Giá gốc gạch ngang và đơn tối thiểu.** Cửa hàng nhập "Giá gốc" cho món (chỉ hiện gạch ngang khi cao hơn giá bán) và
  "Đơn tối thiểu" ở Hồ sơ quán. Khách thấy đơn tối thiểu trên thẻ và trang quán; giỏ hàng báo còn thiếu bao nhiêu và khoá
  nút thanh toán, máy chủ cũng chặn đơn dưới mức (`FOOD_MIN_ORDER_NOT_MET`).
- **Chọn ưu đãi ngay khi thanh toán.** "Ưu đãi của tôi" mở danh sách mã dùng được cho đơn, mỗi mã hiện số tiền ước tính tiết
  kiệm (máy chủ tính lại khi đặt).

### Đổi
- **Giao diện Đồ ăn đầy đủ thông tin hơn** (đối chiếu ShopeeFood, GrabFood, Xanh SM):
  - thẻ quán: điểm kèm số đánh giá, khoảng cách, thời gian giao, phí giao hoặc "Miễn phí giao" màu xanh, nhãn ưu đãi, đơn
    tối thiểu, món nổi bật kèm giá gốc gạch ngang;
  - trang quán: giờ mở hôm nay, địa chỉ, lượt bán, "Khách khen" (gom từ thẻ đánh giá), nhãn "Bán chạy" (3 món bán nhiều nhất)
    và "Mới" (thêm trong 14 ngày), sao đặc;
  - giỏ hàng và thanh toán: thời gian giao dự kiến (thời gian chuẩn bị + 3 phút/km), số tiền canh phải, địa chỉ không bị cắt;
  - cửa hàng: thẻ món có ảnh và giá gốc, đơn hàng có ảnh món, trang tổng quan có logo, điểm và biểu tượng số liệu, nút cuối
    trang nằm cạnh nhau;
  - bỏ chữ gợi ý và dấu "..." ở các ô tìm kiếm; trong trang tuỳ chọn món, giá hiện là "Giá bán".
- **Chuyển động nhẹ, nhất quán trên app.** Thời lượng 150–280 ms, tắt hết khi máy bật "Giảm chuyển động":
  - danh sách quán (trang Đồ ăn, trang danh mục) hiện lần lượt từng thẻ, chậm tối đa 6 thẻ đầu;
  - ảnh món bay từ thực đơn sang trang chọn tuỳ chọn;
  - thẻ quán thu nhẹ khi nhấn và rung nhẹ khi mở;
  - "Đang tìm tài xế" có vòng sóng lan quanh xe;
  - theo dõi đơn: tiêu đề trạng thái chuyển mờ dần, thanh tiến trình tô dần sang bước mới và bước đang chạy có vòng sóng.

### Sửa
- **Bản đồ hiện đúng ngay khi mở app, không cần cấu hình ở mobile.** Trước đây app chọn bản đồ một lần lúc khởi động theo token
  đã cache, token mới từ Admin chỉ dùng được ở lần mở sau nên lần đầu (và sau khi đổi token) các trang bản đồ hiện bản đồ minh
  hoạ. Nay token Mapbox public lấy dưới màn hình splash (có cache thì dùng ngay, làm mới ngầm; chưa có thì chờ tối đa 3 s),
  token đến muộn hoặc đổi thì mọi bản đồ đang mở tự dựng lại; không có token thì hiện khung bản đồ minh hoạ gọn.
- **Nút quay lại ở "Tìm tài xế".** Trang đề xuất giá và trang tìm tài xế luôn có nút tròn quay lại kiểu bản đồ ở mọi trạng
  thái; quay lại không huỷ chuyến.
- **Mục cuối danh sách không còn bị thanh điều hướng che.** Ở cả 3 vai trò (khách, tài xế, cửa hàng) nội dung cuộn ra sau
  thanh điều hướng nổi và mục cuối dừng ngay trên thanh, kể cả iPhone SE và máy có thanh home.
- **Tab "Đặt" không còn giữ hành trình cũ.** Điểm đón/đến xoá ngay khi đã tạo chuyến từ đó hoặc khi bấm quay lại rời tab,
  nên sau khi huỷ hay hoàn thành chuyến tab mở ra trống (điểm đón lấy lại từ GPS). Chuyến đang chờ báo giá vẫn mở lại được
  bằng nút "Xem đề xuất đang chờ"; địa điểm gần đây chỉ hiện làm gợi ý, chạm mới điền. Quay lại từ trang đề xuất giá vẫn giữ
  hành trình để sửa.
- **Chạm ra ngoài để ẩn bàn phím** ở mọi trang; kéo danh sách cũng ẩn bàn phím. Nút được bấm vẫn chạy, kéo bản đồ và nút gửi
  tin nhắn không làm mất bàn phím.
- **Chữ không còn bị cắt trên máy hẹp (iPhone SE, 320 pt).** Rà toàn bộ màn hình ở 320 và 390 pt:
  - nhãn thanh điều hướng ("Tổng quan", "Đơn hàng", "Việc nhận", "Thông báo") và nút lọc ("Ẩn / nháp (1)") thu nhỏ vừa ô
    thay vì bị cắt;
  - dòng "điểm · loại · khoảng cách" của quán, tên khách ở chuyến đang chạy, tiêu đề ưu đãi trang chủ xuống dòng thay vì
    mất chữ cuối;
  - chip trạng thái theo dõi chuyến, mã chuyến và chip ở thẻ việc, số tiền ở bảng thu nhập tự xuống dòng khi chật (hết
    lỗi tràn khung);
  - thẻ dịch vụ trang chủ ẩn dòng phụ khi quá hẹp thay vì thu chữ quá nhỏ;
  - rút gọn chữ gợi ý: "Tìm điểm đến, món ăn", "Tìm câu trả lời", chip "Chưa đăng ký".

  Địa chỉ dài vẫn rút gọn bằng "…" như cũ.

### Thêm
- **Admin › Lỗi hệ thống (`/system-errors`).** Xem lỗi Sentry của app (Mobile), backend và web ngay trong Admin:
  - tab theo nguồn, lọc trạng thái / môi trường / khoảng thời gian / tìm kiếm, sắp xếp theo mới nhất, số sự kiện hoặc số
    người dùng; bảng có biểu đồ xu hướng, số sự kiện, số người dùng; phân trang;
  - bấm một lỗi mở ngăn chi tiết: culprit, lần đầu / gần nhất, stack trace của sự kiện mới nhất, tags và nút
    "Mở trong Sentry";
  - menu hiện số lỗi chưa xử lý (ẩn khi bằng 0), làm mới mỗi 2 phút; dữ liệu Sentry cache 30 s, khi Sentry giới hạn tần suất
    thì trả bản cache gần nhất.
  - Chỉ Quản trị viên (quyền mới `errors.read`, `errors.write`). Nút "Đã xử lý / Bỏ qua / Mở lại" chỉ hiện khi token có quyền
    ghi (`event:write`), mỗi lần đổi ghi nhật ký kiểm toán; token hiện tại chỉ đọc nên các nút này ẩn.
- **Cài đặt › Sentry (`/settings/sentry`).** Nhập org, region, danh sách project và auth token; token lưu mã hoá trên máy chủ,
  không bao giờ gửi xuống trình duyệt (chỉ hiện 4 ký tự cuối). Nút "Kiểm tra kết nối" báo thiếu quyền hoặc project không tồn
  tại. Cần migration `20261118090000_sentry_integration` (thêm loại tích hợp `SENTRY` và hành động kiểm toán).
- **Sentry cho backend và web trên prod.** API + worker gửi về project `dealgo-backend`, web về `dealgo-web`
  (mobile vẫn `flutter`):
  - gắn môi trường `production` và release theo tag deploy; traces 10%;
  - chỉ gửi user id, lọc token/OTP/mật khẩu/email/SĐT/query, bỏ lỗi 4xx dự kiến;
  - web upload source map lúc build (Docker secret, map bị xoá sau upload);
  - mobile: `sentry_dart_plugin` upload debug symbol/obfuscation map sau build release.
- **Tài khoản cho App Review.** `npm run seed:app-review` (backend, chạy lại an toàn) tạo/cập nhật tài khoản
  `appreview@dealgo.laptrinhapp.com`:
  - đủ 3 vai trò: khách, tài xế xe máy ở Đà Nẵng, cửa hàng;
  - KYC/KYB giả đã duyệt;
  - quán "DealGo Demo Đà Nẵng" mở 24h, 2 nhóm món, 6 món có ảnh;
  - bật `APP_REVIEW_LOGIN_ENABLED`/`APP_REVIEW_EMAIL`.
- **Danh mục quán đồ ăn quản lý ở Admin** (`DEC-PROD-067`). Trang **Danh mục** thay danh sách chỉ đổi tên:
  - thêm/sửa/xoá danh mục, tải ảnh hoặc chọn icon và màu, kéo-thả để sắp xếp, bật/tắt; mã tự tạo từ tên;
  - không xoá được danh mục còn quán dùng (tắt thay vì xoá); mọi thay đổi có nhật ký.

  Nâng cấp tạo sẵn 9 danh mục (Phở, Bún/mì, Cơm, Bánh mì, Trà sữa, Cà phê, Ăn nhanh, Ăn vặt, Siêu thị) và chuyển loại quán cũ
  về danh mục tương ứng. Chủ quán chọn danh mục ở **Hồ sơ quán** và khi đăng ký cửa hàng. App lấy danh mục từ máy chủ cho chip
  trang Đồ ăn, ô danh mục trang chủ, tìm kiếm và nhãn quán; sửa ở Admin thì app cập nhật trong vài phút, không cần ra bản mới.

  Tài xế mặc định offline. Không tạo banner. `npm run seed:app-review:cleanup` xoá toàn bộ dữ liệu demo, kể cả tài khoản, và
  tắt đăng nhập review. Trên production cần `SEED_ALLOW_PRODUCTION=true` cho lần chạy đó. Mật khẩu và mã review nằm ở
  `/opt/dealgo/env/app-review.txt` (`DEC-PROD-052`).

- **Chia sẻ chuyến đi qua Zalo, Messenger, SMS…** Nút "Chia sẻ liên kết" ở Trung tâm an toàn mở bảng chia sẻ của hệ thống
  với lời nhắn kèm liên kết theo dõi; máy không có bảng chia sẻ thì tự sao chép. Thêm nút "Sao chép liên kết". Liên kết được
  dùng lại cho các lần chia sẻ sau trong cùng chuyến (đến khi gần hết hạn) thay vì tạo mới mỗi lần. Trang theo dõi
  `dealgo.laptrinhapp.com/chia-se-chuyen/…` không cần đăng nhập, không hiện số điện thoại, hết hạn sau 12 giờ hoặc 30 phút
  sau khi chuyến kết thúc.
- **Báo lỗi app về Sentry.** Bản dev/prod (flavor hoặc scheme Xcode) và bản release tự gửi crash Flutter, lỗi nền (async),
  crash native iOS/Android, lỗi server 5xx và phản hồi hỏng về project Sentry mobile, môi trường `dev`/`prod`, release
  `<version>+<build>`. Mỗi báo cáo chỉ kèm user id, đường dẫn đã ẩn id/token (không header, body, query), kèm lịch sử chuyển
  màn hình. Người dùng chỉ thấy câu thông báo thân thiện; trang thiết lập hồ sơ không còn hiện lỗi kỹ thuật thô. Lỗi 4xx
  (quy tắc nghiệp vụ) và mất mạng không gửi. Tắt cho một bản build bằng `--dart-define=SENTRY_DSN=`.

### Đổi
- **Xoá tài khoản bằng passkey.** Tài khoản chỉ có passkey nay tự xoá được trong app: bấm "Tiếp tục xóa" là hộp thoại
  passkey của hệ thống (Face ID/Touch ID/vân tay) mở ngay, xác minh xong thì lên lịch xoá. Huỷ hộp thoại không báo lỗi, bấm
  "Xác minh passkey" để thử lại. Server chỉ chấp nhận passkey của chính tài khoản, cho challenge của đúng yêu cầu, dùng một
  lần và hết hạn sau 5 phút; sai 5 lần thì khoá. Cách xác minh chỉ chọn trong phương thức đăng nhập đang bật (ưu tiên passkey,
  rồi SMS, rồi mật khẩu) nên không còn gửi SMS khi đăng nhập SĐT đang tắt; không có cách nào thì báo liên hệ hỗ trợ, không
  nhắc phương thức bị tắt. Hai nút ở cuối trang xoá tài khoản xếp ngang (`DEC-PROD-037`).
- **Phương thức đăng nhập đang tắt không còn lộ ra ngoài.** `GET /v1/auth/methods` chỉ trả tên các phương thức đang bật
  (bỏ trạng thái tắt, thời điểm và người sửa). Gọi endpoint của phương thức tắt (SĐT, email, passkey, đổi mật khẩu khi email
  tắt) nhận 404 giống hệt đường dẫn không tồn tại, trước cả giới hạn tần suất và kiểm tra dữ liệu, không gửi SMS/email.
  App đưa các trang/deep link của phương thức tắt (đăng nhập SĐT/email, quên mật khẩu, mã OTP, đổi mật khẩu) về trang đăng
  nhập hoặc trang Bảo mật; hồ sơ, sửa hồ sơ, Bảo mật và các thông báo lỗi không còn nhắc tới phương thức tắt. Tài khoản chỉ
  có passkey thêm được passkey mới. Trang Admin vẫn liệt kê đủ để bật/tắt (`DEC-PROD-052`).
- **Bảng chọn Passkey xếp ngang.** "Đăng nhập" và "Tạo tài khoản" nằm cạnh nhau trên một hàng.
- **Trang đăng nhập không còn hiện 3 cách rồi lọc bớt.** App chỉ vẽ các phương thức Admin đang bật: lấy cấu hình ngay lúc
  mở app (sau màn khởi động), nhớ lần gần nhất để lần mở sau hiện đúng ngay, rồi cập nhật ngầm. Lần đầu chưa có dữ liệu thì
  hiện một ô chờ cùng kích thước; mất mạng thì báo lỗi kèm nút "Thử lại"; Admin đổi cấu hình thì danh sách đổi mượt. Dòng
  Passkey ở trang Bảo mật cũng theo cùng nguồn (`DEC-PROD-066`).
- **Màn hoàn thiện hồ sơ gọn hơn.** Ảnh đại diện, họ tên, email, ngày sinh và giới tính nằm gọn trong một màn; "Bổ sung sau"
  chuyển lên thanh tiêu đề, chỉ còn một nút "Hoàn tất" ở dưới, bỏ chữ gợi ý.
- **Nút đôi xếp ngang.** Các cặp nút trước xếp dọc (huỷ chuyến/huỷ đơn, hoá đơn chuyến, đặt xe có chuyến đang chờ, sửa món,
  trạng thái trống/lỗi) nay nằm trên một hàng; "Gửi lại mã" OTP là nút chữ. Vùng chạm vẫn tối thiểu 48pt.
- **Chuông thông báo hiện số thật.** Chấm/badge chỉ hiện khi còn thông báo chưa đọc (khách: chuông trang chủ và Trang cá nhân;
  tài xế: tab Thông báo; cửa hàng: tab Tài khoản). Số lấy từ `GET /v1/me/notifications` (`unreadCount`), tăng ngay khi server
  phát sự kiện socket `inbox` lúc có thông báo mới, đọc lại khi kết nối lại, về 0 khi đọc hết.
- **Banner trang Mua chạm được.** Trang Mua hiện banner Admin nhắm dịch vụ Đồ ăn (chạm mở liên kết của banner); chưa có banner
  thì banner mặc định chạm vào bất kỳ đâu cũng cuộn tới danh sách quán. Thẻ ưu đãi trang chủ chạm cả thẻ để mở Ưu đãi.
- **iOS có scheme `dev` và `prod`** bên cạnh `Runner`. Mở `ios/Runner.xcworkspace`, chọn scheme rồi Run/Archive: `dev`
  (tên "DealGo Dev", API local khi Debug), `prod` (API VPS kể cả Debug). Cùng bundle id `com.trancongtien.dealgo`; Debug dùng
  APNs development, Profile/Release dùng production. `flutter build ipa` (không `--flavor`) vẫn như cũ. Hướng dẫn ở `mobile/README.md`.

- **Mở app không còn màn trắng.** Từ lúc chạm biểu tượng đến trang đầu tiên chỉ có một màn: nền tím DealGo (máy để chế độ tối thì tím đậm)
  với biểu tượng DealGo ở giữa, trên cả iOS và Android (kể cả Android 12+). Bỏ màn chào thứ hai có ảnh minh hoạ và thanh chạy
  cùng thời gian chờ tối thiểu 1,5 giây: app vào thẳng trang chủ / đăng nhập ngay khi khôi phục phiên xong (`DEC-PROD-066`).
- **Banner trang chủ chỉ còn ảnh.** Bỏ tiêu đề/mô tả/nút chữ: banner là một ảnh 2:1 (khuyên dùng 1200×600, tối đa 2 MB),
  chữ nếu cần thì thiết kế sẵn trong ảnh. Form báo khi ảnh lệch tỉ lệ 2:1. Migration
  `20261114090000_home_banner_image_only_region_fk` xoá các cột chữ. App bản cũ bỏ qua banner không có tiêu đề, nên cần cập nhật app để thấy banner.
- **Banner chọn khu vực từ Quản lý khu vực.** Ô "Khu vực" của banner lấy từ danh sách vùng phục vụ (`service_regions`, khoá ngoại),
  không còn danh sách cứng riêng. Một banner nhắm một khu vực hoặc mọi khu vực.
- **Form thêm/sửa khu vực thông minh hơn** (Admin › Khu vực & Giá). Chọn tỉnh/thành → tự điền tên, mã gợi ý (bỏ dấu, không trùng),
  tâm và khung mặc định; hoặc tìm địa điểm để đặt tâm. Kéo góc/kéo giữa khung trên bản đồ để chỉnh vùng, hoặc "Vẽ lại vùng".
  Báo chồng lấn với vùng khác (chỉ cảnh báo). Thêm nút "Sửa tên / vùng trên bản đồ" cho vùng đã có. Kiểm tra cuối cùng vẫn ở backend.
  Endpoint mới `GET /v1/ops/places/search` (quyền `zones.write`) cho ô tìm địa điểm.
- **Vào thẳng trang chủ, không chọn vai trò.** Đăng ký/đăng nhập xong là vào trang chủ khách hàng, kể cả tài khoản
  vừa là tài xế hay cửa hàng. Đổi vai trò ở Trang cá nhân › Vai trò; đăng ký làm tài xế / mở cửa hàng cũng ở Trang cá nhân
  (`DEC-PROD-065`).

### Sửa
- **Trang tìm tài xế có nút quay lại.** Quay lại không huỷ yêu cầu; vào lại từ trang chủ để tiếp tục xem chào giá.
- **Bản đồ Admin không còn báo "API KEY REQUIRED".** Nút đổi kiểu bản đồ không còn dùng nền CARTO (CARTO giờ đòi API key)
  mà chỉ dùng Mapbox: Tự động (sáng/tối theo giao diện), Đường phố, Vệ tinh, Tối, cùng OpenStreetMap. Kiểu đã chọn được
  nhớ giữa các trang bản đồ. Thiếu `NEXT_PUBLIC_MAPBOX_TOKEN` thì bản đồ dùng OpenStreetMap và nút đổi kiểu bị khoá.

### Thêm
- **Admin quản lý email gửi đi** (Cài đặt › Email, `/settings/email`). Chọn Gmail SMTP (mặc định) hoặc Amazon SES, tên và
  địa chỉ người gửi, thông tin đăng nhập (lưu mã hoá, chỉ hiện "đã lưu", nhập mới để thay). "Gửi email thử" ghi lại thời điểm
  gửi thành công; đăng nhập bằng email chỉ nên bật khi đã gửi thử được. Mọi thay đổi cần lý do và vào nhật ký. Giá trị trong
  env chỉ là khởi tạo, giá trị lưu trong Admin được ưu tiên. SES: bounce/complaint qua SNS vào `/v1/webhooks/ses`, địa chỉ bị
  bounce cứng/khiếu nại không được gửi nữa. Cần env mới `SECRETS_ENCRYPTION_KEY` và migration `20261115090000_integration_settings`.
- **Đổi key bản đồ trong Admin** (Cài đặt › Bản đồ › API key): token Mapbox public, token Mapbox server, Google Maps API key,
  lưu mã hoá, có "Kiểm tra key". Server dùng key mới sau khoảng 15 giây; web và app lấy token public qua
  `GET /v1/public/client-config` (web sau tối đa 5 phút, app từ lần mở sau). Token public nằm trong app/web nên cần giới hạn
  URL/bundle trên Mapbox. Trống → dùng giá trị env/build như trước.
- **Google Maps là nhà cung cấp bản đồ thứ hai.** Admin › Cài đặt › Bản đồ (`/settings/maps`) chọn Mapbox hoặc Google
  cho tìm địa chỉ, địa chỉ từ vị trí, và lộ trình/quãng đường tính cước (khoá `MAPS_SEARCH_PROVIDER`,
  `MAPS_REVERSE_PROVIDER`, `MAPS_ROUTE_PROVIDER`, mặc định `mapbox`, có audit).
  Cần `GOOGLE_MAPS_API_KEY` (Places API (New), Geocoding API, Routes API) trong `backend.env`; trống thì Google bị khoá trong Admin.
  Google lỗi → tự dùng Mapbox. App hiện ghi chú "Google Maps" dưới kết quả tìm từ Google.
  Chi phí, đánh đổi và lưu ý điều khoản: [places-search.md](../05-architecture/places-search.md).
