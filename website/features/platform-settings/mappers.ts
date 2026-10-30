import type { OpsIconName } from "@/components/ui/ops-icons";
import type {
  CategoryKey,
  PlatformSettingRow,
} from "@/features/platform-settings/types";

const LABELS: Record<string, { label: string; hint: string }> = {
  MAPS_SEARCH_PROVIDER: {
    label: "Bản đồ — tìm địa chỉ (mapbox | google)",
    hint: "DEC-PROD-045 — nên đổi ở Cài đặt › Bản đồ",
  },
  MAPS_REVERSE_PROVIDER: {
    label: "Bản đồ — địa chỉ từ vị trí (mapbox | google)",
    hint: "DEC-PROD-045 — nên đổi ở Cài đặt › Bản đồ",
  },
  MAPS_ROUTE_PROVIDER: {
    label: "Bản đồ — lộ trình & quãng đường (mapbox | google)",
    hint: "DEC-PROD-045 — nên đổi ở Cài đặt › Bản đồ",
  },
  RIDE_MIN_FARE_VND: {
    label: "Giá Ride tối thiểu (VND) — chỉ để tạo hạng xe lần đầu",
    hint: "không phải giá đang áp dụng. Giá sàn/trần/km thật sửa ở Cấu hình › Loại xe (từng hạng)",
  },
  RIDE_MAX_FARE_VND: {
    label: "Giá Ride tối đa (VND) — chỉ để tạo hạng xe lần đầu",
    hint: "không phải giá đang áp dụng. Sửa giá trần ở Cấu hình › Loại xe",
  },
  RIDE_REFERENCE_VND_PER_KM: {
    label: "Giá tham chiếu Ride / km (VND) — chỉ để tạo hạng xe lần đầu",
    hint: "không phải giá đang áp dụng. Sửa giá/km ở Cấu hình › Loại xe",
  },
  FOOD_MIN_DELIVERY_VND: {
    label: "Phí giao Food tối thiểu (VND)",
    hint: "OPEN-003 — TEST_ONLY",
  },
  FOOD_MAX_DELIVERY_VND: {
    label: "Phí giao Food tối đa (VND)",
    hint: "OPEN-003 — TEST_ONLY",
  },
  PARCEL_SIZE_CLASSES: {
    label: "Hạng kích thước giao hàng (JSON)",
    hint: "DEC-PROD-071 DRAFT — S/M/L/XL: cân tối đa, kích thước, phụ phí, loại xe",
  },
  PARCEL_SERVICE_FEE_VND: {
    label: "Phí dịch vụ giao hàng (VND / đơn)",
    hint: "DEC-PROD-071 DRAFT — cộng vào cước tham chiếu mỗi đơn, chốt lúc đặt (0 = tắt)",
  },
  PARCEL_RETURN_FEE_VND: {
    label: "Phí hoàn hàng khi giao thất bại (VND)",
    hint: "DEC-PROD-071 DRAFT — mặc định 10.000; tính khi tài xế trả hàng về người gửi, trả cho tài xế, cộng vào chuyến tiền mặt kế tiếp",
  },
  PARCEL_RECIPIENT_CODE_REQUIRED: {
    label: "Bắt buộc mã người nhận khi giao hàng",
    hint: "DEC-PROD-071 DRAFT — mặc định tắt",
  },
  DRIVER_SEARCH_RADIUS_KM: {
    label: "Bán kính tìm tài xế (km)",
    hint: "OPEN-004 — TEST_ONLY dispatch",
  },
  RIDE_OFFER_TTL_SECONDS: {
    label: "Hiệu lực mỗi đề nghị giá của tài xế (giây)",
    hint: "OPEN-004/019 — không vượt quá thời gian mở yêu cầu chuyến",
  },
  RIDE_MAX_LIVE_OFFERS_PER_RIDE: {
    label: "Số đề nghị giá đang mở tối đa / chuyến",
    hint: "0 = không giới hạn (inDrive hiện mọi đề nghị cho khách chọn); 0–100",
  },
  RIDE_MAX_FARE_RAISES_PER_RIDE: {
    label: "Số lần khách được tăng giá / chuyến (số vòng)",
    hint: "Mặc định 3 — mỗi lần tăng giá mở vòng mới, tài xế được sửa giá lại; 0 = không giới hạn (0–20)",
  },
  CUSTOMER_CANCEL_LIMIT_COUNT: {
    label: "Số chuyến khách hủy sau khi có tài xế trước khi bị tạm chặn",
    hint: "Mặc định 3 — inDrive/Grab tạm khóa khi hủy nhiều; 0 = tắt (0–20)",
  },
  CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS: {
    label: "Khoảng tính số lần khách hủy (giờ)",
    hint: "Mặc định 24 (1–168)",
  },
  CUSTOMER_CANCEL_COOLDOWN_MINUTES: {
    label: "Thời gian khách bị tạm chặn đặt chuyến (phút)",
    hint: "Mặc định 30 — tính từ lần hủy gần nhất; 0 = tắt (0–1440)",
  },
  DRIVER_CANCEL_RATE_WINDOW_DAYS: {
    label: "Khoảng tính tỷ lệ hủy của tài xế (ngày)",
    hint: "Mặc định 7 — Grab tính tỷ lệ hủy theo chu kỳ (1–90)",
  },
  DRIVER_CANCEL_RATE_WARN_PERCENT: {
    label: "Ngưỡng cảnh báo tỷ lệ hủy của tài xế (%)",
    hint: "Mặc định 20 — chỉ cảnh báo cho admin, chưa tự khóa (0–100)",
  },
  VOICE_CALLS_ENABLED: {
    label: "Cho phép gọi thoại trong app",
    hint: "DEC-PROD-007 — bật: khách và tài xế đang trong chuyến/đơn gọi nhau qua app (chỉ âm thanh, không ghi âm); tắt: ẩn nút gọi",
  },
  RIDE_MULTI_STOP_BIKE_ENABLED: {
    label: "Cho phép đặt xe máy nhiều điểm dừng",
    hint: "DEC-PROD-MULTISTOP — tắt: app ẩn nút \"Thêm điểm dừng\" và chuyến xe máy chỉ có 1 điểm đến (chuyến đang chạy không bị ảnh hưởng)",
  },
  RIDE_MULTI_STOP_CAR_ENABLED: {
    label: "Cho phép đặt ô tô nhiều điểm dừng",
    hint: "DEC-PROD-MULTISTOP — tắt: app ẩn nút \"Thêm điểm dừng\" và chuyến ô tô chỉ có 1 điểm đến",
  },
  RIDE_MAX_STOPS_BIKE: {
    label: "Số điểm dừng tối đa — xe máy",
    hint: "Mặc định 1 — không tính điểm đón và điểm đến cuối (0–5)",
  },
  RIDE_MAX_STOPS_CAR: {
    label: "Số điểm dừng tối đa — ô tô",
    hint: "Mặc định 2 — không tính điểm đón và điểm đến cuối (0–5)",
  },
  RIDE_STOP_FEE_BIKE_VND: {
    label: "Phí mỗi điểm dừng — xe máy (VND)",
    hint: "Mặc định 5.000 — cộng vào giá gợi ý; khách vẫn trả giá (0–200.000)",
  },
  RIDE_STOP_FEE_CAR_VND: {
    label: "Phí mỗi điểm dừng — ô tô (VND)",
    hint: "Mặc định 10.000 — cộng vào giá gợi ý; khách vẫn trả giá (0–500.000)",
  },
  RIDE_STOP_FREE_WAIT_MINUTES: {
    label: "Thời gian chờ miễn phí tại mỗi điểm dừng (phút)",
    hint: "Mặc định 5 — tính từ lúc tài xế bấm \"Đã đến\" đến \"Rời điểm dừng\" (0–60)",
  },
  RIDE_STOP_WAIT_FEE_VND_PER_MINUTE: {
    label: "Phí chờ tại điểm dừng (VND / phút)",
    hint: "Mặc định 1.000 — mỗi phút trọn quá thời gian miễn phí, cộng vào tiền mặt khi hoàn tất; 0 = không thu (0–50.000)",
  },
  RIDE_REQUEST_PUSH_ENABLED: {
    label: "Gửi push chuyến mới cho tài xế khi app ở nền/tắt",
    hint: "bật — FCM qua outbox, không gửi lại cho tài xế đang nhận socket",
  },
  NEW_JOB_CUSTOM_SOUND_ENABLED: {
    label: "Âm báo giọng nói khi có cuốc/đơn mới",
    hint: "bật — push cuốc mới, đơn giao mới (tài xế) và đơn mới (quán) phát \"DealGo, có cuốc mới…\"; tắt: âm mặc định của máy. Người dùng vẫn tự tắt được trong Cài đặt thông báo",
  },
  RIDE_REQUEST_PUSH_MAX_DRIVERS: {
    label: "Số tài xế tối đa nhận push / chuyến mới",
    hint: "Mặc định 30 — gần nhất trước; 0 = không gửi (0–200)",
  },
  FOOD_FAIL_MIN_WAIT_MINUTES: {
    label: "Chờ tối thiểu trước khi báo giao thất bại vì không liên lạc được khách (phút)",
    hint: "Mặc định 10 — ShopeeFood: gọi ≥3 lần trong 10 phút (0–60)",
  },
  FOOD_MERCHANT_COMMISSION_PERCENT: {
    label: "Chiết khấu quán trả DealGo (% tiền món)",
    hint: "Mặc định 20 — GrabFood/ShopeeFood thu chiết khấu quán; ghi vào bảng đối soát quán (0–50)",
  },
  FOOD_ORDER_CHANGE_RESPONSE_MINUTES: {
    label: "Khách phải xác nhận đơn bị sửa / hết món trong (phút)",
    hint: "Mặc định 5 — quá hạn đơn tự hủy, không phí (1–30)",
  },
  RIDE_REPOST_RAISE_HINT_PERCENT: {
    label: "Gợi ý tăng giá khi đăng lại chuyến hết hạn (%)",
    hint: "Mặc định 10 — inDrive gợi ý tăng giá khi không có tài xế (0–50)",
  },
  RIDE_REQUEST_WINDOW_SECONDS: {
    label: "Thời gian mở yêu cầu chuyến (giây)",
    hint: "Mặc định 300 — khách chờ tài xế chào giá; tăng giá sẽ gia hạn (60–1800)",
  },
  RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: {
    label: "Giá khách đặt tối thiểu (% giá tham khảo)",
    hint: "Mặc định 70 (= −30%) — 0 = chỉ dùng giá sàn của hạng xe (0–100)",
  },
  RIDE_BID_CEILING_PERCENT_OF_REFERENCE: {
    label: "Giá khách đặt / tài xế trả giá tối đa (% giá app)",
    hint: "Mặc định 130 (= +30%) — áp dụng cho cả khách và tài xế (100–300)",
  },
  RIDE_COUNTER_MAX_PERCENT_OF_OFFER: {
    label: "Giá tài xế trả giá tối đa (% giá khách đưa)",
    hint: "Mặc định 150 (100–300)",
  },
  RIDE_MAX_OFFER_EDITS_PER_DRIVER: {
    label: "Số lần tài xế được sửa giá / chuyến",
    hint: "Mặc định 2 (0–10)",
  },
  RIDE_ASSIGNED_START_TIMEOUT_MINUTES: {
    label: "Tài xế phải bắt đầu đi đón trong (phút)",
    hint: "Mặc định 5 — quá hạn chuyến quay lại tìm tài xế; 0 = tắt (0–60)",
  },
  RIDE_EN_ROUTE_TIMEOUT_MINUTES: {
    label: "Tài xế phải tới điểm đón trong (phút)",
    hint: "Mặc định 30 — quá hạn chuyến quay lại tìm tài xế; 0 = tắt (0–180)",
  },
  ROUTE_OFF_ROUTE_THRESHOLD_M: {
    label: "Lệch khỏi tuyến bao xa thì tính lại đường (m)",
    hint: "Mặc định 150 — dưới mức này giữ tuyến đã lưu, không gọi Mapbox (30–2000)",
  },
  ROUTE_REROUTE_MIN_INTERVAL_SECONDS: {
    label: "Khoảng tối thiểu giữa 2 lần tính lại đường / chuyến (giây)",
    hint: "Mặc định 120 — giới hạn số request Mapbox mỗi chuyến/đơn (30–1800)",
  },
  RIDE_NO_SHOW_WAIT_MINUTES: {
    label: "Chờ khách tối thiểu trước khi báo không gặp (phút)",
    hint: "Mặc định 5 — inDrive/Grab dùng 5 phút (1–30)",
  },
  RIDE_FREE_CANCEL_MINUTES: {
    label: "Khách huỷ miễn phí trong (phút sau khi có tài xế)",
    hint: "Mặc định 5 — sau đó hoặc khi tài xế đã tới thì tính phí huỷ (0–30)",
  },
  RIDE_CANCEL_FEE_BIKE_VND: {
    label: "Phí huỷ muộn / không gặp — xe máy (VND)",
    hint: "Mặc định 3.000 — cộng vào chuyến sau của khách, trả cho tài xế bị huỷ",
  },
  RIDE_CANCEL_FEE_CAR_VND: {
    label: "Phí huỷ muộn / không gặp — ô tô (VND)",
    hint: "Mặc định 10.000 — cộng vào chuyến sau của khách, trả cho tài xế bị huỷ",
  },
  FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES: {
    label: "Quán phải nhận đơn trong (phút)",
    hint: "Mặc định 5 — quá hạn đơn tự huỷ (MERCHANT_TIMEOUT); 0 = tắt (0–60)",
  },
  FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES: {
    label: "Huỷ đơn đã xong mà không có tài xế sau (phút)",
    hint: "Mặc định 30 — lý do NO_DRIVER; 0 = tắt (0–240)",
  },
  FOOD_EARLY_ASSIGN_LEAD_MINUTES: {
    label: "Cho tài xế nhận đơn trước khi món xong (phút)",
    hint: "Mặc định 10 — 0 = chỉ nhận khi quán báo xong (0–60)",
  },
  FOOD_MAX_DELIVERY_KM: {
    label: "Khoảng cách giao tối đa (km)",
    hint: "Mặc định 15 (1–50)",
  },
  SERVICE_ZONE_ENFORCED: {
    label: "Chỉ nhận chuyến/đơn trong khu vực đang hoạt động",
    hint: "bật — điểm đón (Ride) và quán (Food) phải nằm trong khu vực ACTIVE",
  },
  DRIVER_DEBT_LIMIT_VND: {
    label: "Hạn mức nợ phí của tài xế (VND)",
    hint: "Mặc định 200.000 — nợ vượt mức này thì không nhận việc mới cho tới khi Admin ghi nhận đã thu; 0 = tắt",
  },
  DISPATCH_REQUIRE_FRESH_PRESENCE: {
    label: "Bắt buộc tài xế online và có vị trí mới (≤ 2 phút)",
    hint: "bật — tắt chỉ dùng cho môi trường thử nghiệm",
  },
  MAX_CONCURRENT_JOBS_PER_DRIVER: {
    label: "Job đồng thời / tài xế",
    hint: "OPEN-005 — lưu cấu hình; enforce dần",
  },
  RIDE_COMMISSION_BIKE_PERCENT: {
    label: "Hoa hồng chuyến xe máy (%)",
    hint: "Mặc định 0 — DealGo thu trên giá đã chốt của chuyến xe máy, chốt % lúc hoàn thành; tài xế nợ khoản này (trả tiền mặt). Tham khảo: inDrive ~10%, GrabBike 20% + 3.000đ (danviet.vn 28/4/2026), Be 23,9–30,3%. Gợi ý thả giá: 10 (0–100, tối đa 2 số lẻ)",
  },
  RIDE_COMMISSION_CAR_PERCENT: {
    label: "Hoa hồng chuyến ô tô (%)",
    hint: "Mặc định 0 — DealGo thu trên giá đã chốt của chuyến ô tô, chốt % lúc hoàn thành. Tham khảo: GrabCar 20–27% (vnexpress 5119283), inDrive ~10%. Gợi ý: 10 (0–100, tối đa 2 số lẻ)",
  },
  FOOD_DRIVER_COMMISSION_PERCENT: {
    label: "Hoa hồng tài xế giao đồ ăn (%)",
    hint: "Mặc định 0 — DealGo thu trên phí giao của tài xế (không phải tiền món), chốt % lúc giao xong. Tham khảo: ShopeeFood để tài xế giữ 100% phí giao từ 23/05/2023 (0–100, tối đa 2 số lẻ)",
  },
  MERCHANT_SETTLEMENT_CYCLE_DAYS: {
    label: "Chu kỳ đối soát hoa hồng quán (ngày)",
    hint: "Mặc định 7 — sao kê quán mặc định gom N ngày gần nhất; quán trả hoa hồng theo chu kỳ, Admin ghi nhận đã thu. Tham khảo: GrabFood đối soát theo tuần/ngày (help.grab.com/merchant) (1–31)",
  },
  VOUCHER_SHARED_PLATFORM_PERCENT: {
    label: "Phần DealGo chịu với voucher đồng tài trợ (%)",
    hint: "DEC-PROD-015 — áp cho chiến dịch nhà tài trợ SHARED; phần còn lại trừ vào tiền trả quán (0–100)",
  },
  RATING_WINDOW_DAYS: {
    label: "Thời hạn đánh giá (ngày)",
    hint: "DEC-PROD-013 — khách đánh giá được trong số ngày này sau khi hoàn thành (1–365)",
  },
  RIDE_PICKUP_CODE_MAX_ATTEMPTS: {
    label: "Số lần nhập sai mã đón tối đa",
    hint: "DEC-PROD-017 — quá số lần này mã đón của chuyến bị khóa, ops huỷ/điều phối lại (1–20)",
  },
  FOOD_DELIVERY_CODE_REQUIRED: {
    label: "Bắt buộc mã giao hàng (Food)",
    hint: "DEC-PROD-036 — true: tài xế phải nhập mã 4 số khách đọc trên app mới hoàn tất giao; false: giao không cần mã",
  },
  FOOD_DELIVERY_CODE_MAX_ATTEMPTS: {
    label: "Số lần nhập sai mã giao / mã bàn giao tối đa",
    hint: "DEC-PROD-036 — quá số lần này mã của đơn bị khóa, ops xử lý (1–20)",
  },
  FOOD_HANDOVER_CODE_REQUIRED: {
    label: "Bắt buộc mã bàn giao quán ↔ tài xế",
    hint: "DEC-PROD-036 — true: tài xế phải nhập mã quán hiển thị khi lấy món (mặc định false)",
  },
  ONBOARDING_DRIVER_KYC_REQUIRED: {
    label: "Bắt buộc hồ sơ KYC khi đăng ký tài xế",
    hint: "DEC-PROD-048 (DRAFT) — Tắt: app bỏ bước giấy tờ, tài xế vẫn chọn hạng xe và chờ admin duyệt (mặc định Bật)",
  },
  ONBOARDING_MERCHANT_KYB_REQUIRED: {
    label: "Bắt buộc hồ sơ KYB khi đăng ký cửa hàng",
    hint: "DEC-PROD-048 (DRAFT) — Tắt: app bỏ bước giấy tờ, cửa hàng vẫn chờ admin duyệt (mặc định Bật)",
  },
  KYC_AUTO_APPROVE_DRIVER: {
    label: "Tự động duyệt KYC tài xế",
    hint: "DEC-PROD-070 (t61u) — Bật: hồ sơ đủ giấy tờ hợp lệ, đủ thông tin và hạng bằng khớp xe được hệ thống duyệt ngay (audit SYSTEM); thiếu/sai vào hàng chờ duyệt tay (mặc định Tắt)",
  },
  KYC_AUTO_APPROVE_MERCHANT: {
    label: "Tự động duyệt KYB cửa hàng",
    hint: "DEC-PROD-070 (t61u) — Bật: hồ sơ đủ giấy tờ hợp lệ, đủ thông tin và có ghim vị trí quán được hệ thống duyệt ngay; thiếu/sai vào hàng chờ duyệt tay (mặc định Tắt)",
  },
  RATING_STORE_MIN_COUNT: {
    label: "Số đánh giá tối thiểu để hiện điểm quán",
    hint: "DEC-PROD-019 — dưới số này app chỉ hiện \"Quán mới\"/số lượt, không lộ số sao của từng khách (1–50)",
  },
  SUPPORT_TICKET_MAX_OPEN_PER_USER: {
    label: "Yêu cầu hỗ trợ đang mở tối đa / người dùng",
    hint: "DEC-PROD-018 — quá số này app báo chờ phản hồi hoặc bổ sung vào yêu cầu cũ (1–50)",
  },
  SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY: {
    label: "Yêu cầu từ website / SĐT hoặc email / 24 giờ",
    hint: "DEC-PROD-018 — chống spam form hỗ trợ công khai (1–50)",
  },
  SUPPORT_TICKET_TEXT_MAX_CHARS: {
    label: "Độ dài tối đa nội dung hỗ trợ (ký tự)",
    hint: "DEC-PROD-018 — áp cho mô tả và mỗi tin trao đổi (200–5000)",
  },
  UPLOAD_MAX_FILE_KB: {
    label: "Dung lượng tối đa mỗi tệp tải lên (KB)",
    hint: "DEC-PROD-020 — áp cho giấy tờ KYC/KYB và tệp đính kèm hỗ trợ (100–5120)",
  },
  UPLOAD_ORPHAN_MAX_AGE_HOURS: {
    label: "Xoá tệp tải lên không dùng sau (giờ)",
    hint: "DEC-PROD-022 — tệp không còn gắn với hồ sơ, ticket hay ảnh đại diện nào sẽ bị worker xoá khi cũ hơn số giờ này (24–2160)",
  },
  ACCOUNT_DELETION_GRACE_DAYS: {
    label: "Thời gian chờ trước khi xoá vĩnh viễn tài khoản (ngày)",
    hint: "DEC-PROD-037 — sau khi người dùng xác nhận xoá (S027), tài khoản bị khoá ngay; hết số ngày này worker ẩn danh hoá dữ liệu cá nhân. Trong thời gian chờ Admin khôi phục được (0–90; 0 = xoá ở lượt worker kế tiếp)",
  },
  UPLOAD_ALLOWED_TYPES: {
    label: "Định dạng tệp được phép tải lên",
    hint: "DEC-PROD-020 — mảng JSON, chọn trong image/jpeg, image/png, image/webp, application/pdf",
  },
  AUTH_PASSWORD_RESET_CODE_TTL_MINUTES: {
    label: "Hiệu lực mã quên mật khẩu (phút)",
    hint: "DEC-PROD-045 — mã 6 số gửi qua email để đặt lại mật khẩu khách hàng (5–60)",
  },
  AUTH_PASSWORD_RESET_MAX_ATTEMPTS: {
    label: "Số lần nhập sai mã quên mật khẩu",
    hint: "DEC-PROD-045 — vượt quá thì mã bị khoá, phải gửi lại mã mới (3–10)",
  },
  AUTH_PASSWORD_RESET_MAX_PER_HOUR: {
    label: "Số yêu cầu quên mật khẩu mỗi email / giờ",
    hint: "DEC-PROD-045 — giới hạn theo địa chỉ email, ngoài giới hạn theo IP (1–20)",
  },
  CONTACT_WINDOW_MINUTES: {
    label: "Cửa sổ chat/voice (phút)",
    hint: "OPEN-014/021 — heuristic TEST_ONLY, chưa retention policy",
  },
};

const PERCENT_KEYS = new Set([
  "RIDE_COMMISSION_BIKE_PERCENT",
  "RIDE_COMMISSION_CAR_PERCENT",
  "FOOD_DRIVER_COMMISSION_PERCENT",
  "VOUCHER_SHARED_PLATFORM_PERCENT",
]);

/** Integer settings: [min, max, Vietnamese error]. Mirrors the backend catalog. */
const INTEGER_RANGES: Record<string, [number, number, string]> = {
  RATING_WINDOW_DAYS: [1, 365, "Thời hạn đánh giá phải là số nguyên từ 1 đến 365 ngày."],
  RIDE_PICKUP_CODE_MAX_ATTEMPTS: [1, 20, "Số lần nhập sai phải là số nguyên từ 1 đến 20."],
  FOOD_DELIVERY_CODE_MAX_ATTEMPTS: [1, 20, "Số lần nhập sai phải là số nguyên từ 1 đến 20."],
  RATING_STORE_MIN_COUNT: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50."],
  SUPPORT_TICKET_MAX_OPEN_PER_USER: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50."],
  SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50."],
  SUPPORT_TICKET_TEXT_MAX_CHARS: [200, 5000, "Giá trị phải là số nguyên từ 200 đến 5000."],
  UPLOAD_MAX_FILE_KB: [100, 5120, "Giá trị phải là số nguyên từ 100 đến 5120 KB."],
  UPLOAD_ORPHAN_MAX_AGE_HOURS: [24, 2160, "Giá trị phải là số nguyên từ 24 đến 2160 giờ (90 ngày)."],
  ACCOUNT_DELETION_GRACE_DAYS: [0, 90, "Giá trị phải là số nguyên từ 0 đến 90 ngày."],
  AUTH_PASSWORD_RESET_CODE_TTL_MINUTES: [5, 60, "Giá trị phải là số nguyên từ 5 đến 60 phút."],
  AUTH_PASSWORD_RESET_MAX_ATTEMPTS: [3, 10, "Giá trị phải là số nguyên từ 3 đến 10."],
  AUTH_PASSWORD_RESET_MAX_PER_HOUR: [1, 20, "Giá trị phải là số nguyên từ 1 đến 20."],
  RIDE_REQUEST_WINDOW_SECONDS: [60, 1800, "Giá trị phải là số nguyên từ 60 đến 1800 giây."],
  RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: [0, 100, "Giá trị phải là số nguyên từ 0 đến 100."],
  RIDE_COUNTER_MAX_PERCENT_OF_OFFER: [100, 300, "Giá trị phải là số nguyên từ 100 đến 300."],
  RIDE_BID_CEILING_PERCENT_OF_REFERENCE: [100, 300, "Giá trị phải là số nguyên từ 100 đến 300."],
  RIDE_MAX_OFFER_EDITS_PER_DRIVER: [0, 10, "Giá trị phải là số nguyên từ 0 đến 10."],
  RIDE_ASSIGNED_START_TIMEOUT_MINUTES: [0, 60, "Giá trị phải là số nguyên từ 0 đến 60 phút."],
  RIDE_EN_ROUTE_TIMEOUT_MINUTES: [0, 180, "Giá trị phải là số nguyên từ 0 đến 180 phút."],
  ROUTE_OFF_ROUTE_THRESHOLD_M: [30, 2000, "Giá trị phải là số nguyên từ 30 đến 2000 m."],
  ROUTE_REROUTE_MIN_INTERVAL_SECONDS: [30, 1800, "Giá trị phải là số nguyên từ 30 đến 1800 giây."],
  RIDE_NO_SHOW_WAIT_MINUTES: [1, 30, "Giá trị phải là số nguyên từ 1 đến 30 phút."],
  RIDE_FREE_CANCEL_MINUTES: [0, 30, "Giá trị phải là số nguyên từ 0 đến 30 phút."],
  RIDE_CANCEL_FEE_BIKE_VND: [0, 200000, "Giá trị phải là số nguyên từ 0 đến 200000."],
  PARCEL_SERVICE_FEE_VND: [0, 200000, "Giá trị phải là số nguyên từ 0 đến 200000."],
  PARCEL_RETURN_FEE_VND: [0, 500000, "Giá trị phải là số nguyên từ 0 đến 500000."],
  RIDE_CANCEL_FEE_CAR_VND: [0, 500000, "Giá trị phải là số nguyên từ 0 đến 500000."],
  FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES: [0, 60, "Giá trị phải là số nguyên từ 0 đến 60 phút."],
  FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES: [0, 240, "Giá trị phải là số nguyên từ 0 đến 240 phút."],
  FOOD_EARLY_ASSIGN_LEAD_MINUTES: [0, 60, "Giá trị phải là số nguyên từ 0 đến 60 phút."],
  FOOD_MAX_DELIVERY_KM: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50 km."],
  DRIVER_DEBT_LIMIT_VND: [0, 10000000, "Giá trị phải là số nguyên từ 0 đến 10000000."],
  RIDE_MAX_LIVE_OFFERS_PER_RIDE: [0, 100, "Giá trị phải là số nguyên từ 0 đến 100."],
  RIDE_MAX_FARE_RAISES_PER_RIDE: [0, 20, "Giá trị phải là số nguyên từ 0 đến 20."],
  CUSTOMER_CANCEL_LIMIT_COUNT: [0, 20, "Giá trị phải là số nguyên từ 0 đến 20."],
  CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS: [1, 168, "Giá trị phải là số nguyên từ 1 đến 168."],
  CUSTOMER_CANCEL_COOLDOWN_MINUTES: [0, 1440, "Giá trị phải là số nguyên từ 0 đến 1440."],
  DRIVER_CANCEL_RATE_WINDOW_DAYS: [1, 90, "Giá trị phải là số nguyên từ 1 đến 90."],
  DRIVER_CANCEL_RATE_WARN_PERCENT: [0, 100, "Giá trị phải là số nguyên từ 0 đến 100."],
  RIDE_REQUEST_PUSH_MAX_DRIVERS: [0, 200, "Giá trị phải là số nguyên từ 0 đến 200."],
  FOOD_FAIL_MIN_WAIT_MINUTES: [0, 60, "Giá trị phải là số nguyên từ 0 đến 60."],
  FOOD_MERCHANT_COMMISSION_PERCENT: [0, 50, "Giá trị phải là số nguyên từ 0 đến 50."],
  FOOD_ORDER_CHANGE_RESPONSE_MINUTES: [1, 30, "Giá trị phải là số nguyên từ 1 đến 30."],
  RIDE_REPOST_RAISE_HINT_PERCENT: [0, 50, "Giá trị phải là số nguyên từ 0 đến 50."],
  RIDE_MAX_STOPS_BIKE: [0, 5, "Giá trị phải là số nguyên từ 0 đến 5."],
  RIDE_MAX_STOPS_CAR: [0, 5, "Giá trị phải là số nguyên từ 0 đến 5."],
  RIDE_STOP_FEE_BIKE_VND: [0, 200000, "Giá trị phải là số nguyên từ 0 đến 200000."],
  RIDE_STOP_FEE_CAR_VND: [0, 500000, "Giá trị phải là số nguyên từ 0 đến 500000."],
  RIDE_STOP_FREE_WAIT_MINUTES: [0, 60, "Giá trị phải là số nguyên từ 0 đến 60 phút."],
  RIDE_STOP_WAIT_FEE_VND_PER_MINUTE: [0, 50000, "Giá trị phải là số nguyên từ 0 đến 50000."],
  MERCHANT_SETTLEMENT_CYCLE_DAYS: [1, 31, "Chu kỳ đối soát phải là số nguyên từ 1 đến 31 ngày."],
};

/** JSON boolean settings (backend spec.boolean): the editor offers Bật / Tắt. */
export const BOOLEAN_SETTING_KEYS: ReadonlySet<string> = new Set([
  "FOOD_DELIVERY_CODE_REQUIRED",
  "FOOD_HANDOVER_CODE_REQUIRED",
  "ONBOARDING_DRIVER_KYC_REQUIRED",
  "ONBOARDING_MERCHANT_KYB_REQUIRED",
  "KYC_AUTO_APPROVE_DRIVER",
  "KYC_AUTO_APPROVE_MERCHANT",
  "SERVICE_ZONE_ENFORCED",
  "DISPATCH_REQUIRE_FRESH_PRESENCE",
  "RIDE_REQUEST_PUSH_ENABLED",
  "NEW_JOB_CUSTOM_SOUND_ENABLED",
  "VOICE_CALLS_ENABLED",
  "RIDE_MULTI_STOP_BIKE_ENABLED",
  "RIDE_MULTI_STOP_CAR_ENABLED",
]);

export const UPLOAD_SNIFFABLE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
] as const;

function validateUploadTypes(value: string): string | null {
  const message =
    "Nhập mảng JSON các định dạng không trùng nhau, ví dụ [\"image/jpeg\",\"application/pdf\"].";
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    return message;
  }
  if (
    !Array.isArray(parsed) ||
    parsed.length === 0 ||
    new Set(parsed).size !== parsed.length ||
    !parsed.every(
      (item) =>
        typeof item === "string" &&
        (UPLOAD_SNIFFABLE_TYPES as readonly string[]).includes(item),
    )
  ) {
    return message;
  }
  return null;
}

/**
 * Client-side check mirroring the backend rules (the backend stays the authority).
 * Returns a Vietnamese error message, or null when the value can be sent.
 */
export function validateSettingValue(key: string, value: string): string | null {
  const trimmed = value.trim();
  if (PERCENT_KEYS.has(key)) {
    if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) {
      return "Giá trị phải là số từ 0 đến 100, tối đa 2 chữ số thập phân (ví dụ 12.5).";
    }
    if (Number(trimmed) > 100) {
      return "Giá trị không được vượt quá 100%.";
    }
    return null;
  }
  if (key === "UPLOAD_ALLOWED_TYPES") {
    return validateUploadTypes(trimmed);
  }
  if (key.startsWith("MAPS_") && key.endsWith("_PROVIDER")) {
    return /^(mapbox|google)$/i.test(trimmed)
      ? null
      : "Giá trị phải là mapbox hoặc google.";
  }
  if (BOOLEAN_SETTING_KEYS.has(key)) {
    return trimmed === "true" || trimmed === "false"
      ? null
      : "Giá trị phải là true (bật) hoặc false (tắt).";
  }
  const range = INTEGER_RANGES[key];
  if (range) {
    const [min, max, message] = range;
    if (!/^\d+$/.test(trimmed) || Number(trimmed) < min || Number(trimmed) > max) {
      return message;
    }
  }
  return null;
}

export function categorizeSetting(key: string): CategoryKey {
  if (key.startsWith("SUPPORT_") || key.startsWith("MAPS_") || key.startsWith("UPLOAD_") || key.startsWith("ACCOUNT_") || key.startsWith("VOICE_")) {
    return "SUPPORT";
  }
  if (
    key === "RIDE_COMMISSION_BIKE_PERCENT" ||
    key === "RIDE_COMMISSION_CAR_PERCENT" ||
    key === "FOOD_DRIVER_COMMISSION_PERCENT" ||
    key === "FOOD_MERCHANT_COMMISSION_PERCENT" ||
    key === "MERCHANT_SETTLEMENT_CYCLE_DAYS" ||
    key === "VOUCHER_SHARED_PLATFORM_PERCENT" ||
    key.startsWith("RIDE_CANCEL_FEE") ||
    key === "RIDE_FREE_CANCEL_MINUTES" ||
    key === "RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE" ||
    key === "RIDE_COUNTER_MAX_PERCENT_OF_OFFER" ||
    key === "RIDE_BID_CEILING_PERCENT_OF_REFERENCE"
  ) {
    return "FARE";
  }
  // Same grouping as the backend SETTING_CATEGORY_OVERRIDES map (platform-settings.service.ts).
  if (
    key === "SERVICE_ZONE_ENFORCED" ||
    key === "FOOD_MAX_DELIVERY_KM" ||
    key === "DRIVER_DEBT_LIMIT_VND"
  ) {
    return "ZONE_PAYMENT";
  }
  if (
    key.startsWith("RIDE_MIN") ||
    (key.startsWith("RIDE_MAX") && !key.startsWith("RIDE_MAX_OFFER")) ||
    key.startsWith("RIDE_REF") ||
    key.startsWith("FOOD_MIN") ||
    key.startsWith("FOOD_MAX")
  ) {
    return "FARE";
  }
  if (
    key.includes("RADIUS") ||
    key.includes("TTL") ||
    key.includes("ROUNDS") ||
    key.includes("JOBS") ||
    key.includes("WINDOW") ||
    key.includes("ATTEMPTS") ||
    key.includes("TIMEOUT") ||
    key.includes("MINUTES") ||
    key.startsWith("RIDE_MAX_OFFER") ||
    key.startsWith("DISPATCH_") ||
    key.endsWith("_CODE_REQUIRED") ||
    key.startsWith("RATING_")
  ) {
    return "DISPATCH";
  }
  return "ZONE_PAYMENT";
}

export function getSettingIcon(category: CategoryKey): OpsIconName {
  switch (category) {
    case "MONEY":
      return "wallet";
    case "FARE":
      return "receipt";
    case "DISPATCH":
      return "car";
    case "ZONE_PAYMENT":
      return "pin";
    case "SUPPORT":
      return "headset";
    default:
      return "settings";
  }
}

export function enrichPlatformSetting(row: {
  key: string;
  value: string;
  valueType: PlatformSettingRow["valueType"];
  source: "db" | "env";
  openIds: string[];
  updatedAt: string | null;
  updatedByUserId: string | null;
}): PlatformSettingRow {
  const meta = LABELS[row.key] ?? {
    label: row.key,
    hint: row.openIds.join(", ") || "Platform setting",
  };
  return { ...row, ...meta };
}

/** Real on/off switches for the Settings "Feature flags" tab (no hard-coded demo flags). */
export function featureFlagRows<T extends { key: string }>(rows: readonly T[]): T[] {
  return rows.filter((row) => BOOLEAN_SETTING_KEYS.has(row.key));
}
