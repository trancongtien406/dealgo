// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get actionRetry => 'Thử lại';

  @override
  String get actionCancel => 'Hủy';

  @override
  String get actionContinue => 'Tiếp tục';

  @override
  String get actionSeeAll => 'Xem tất cả';

  @override
  String get actionBookRideNow => 'Đặt xe ngay';

  @override
  String get actionBack => 'Quay lại';

  @override
  String get actionChangePhone => 'Đổi số điện thoại';

  @override
  String get actionKeepEnteringCode => 'Tiếp tục nhập mã';

  @override
  String get errorNetwork =>
      'Không kết nối được DealGo. Kiểm tra mạng rồi thử lại.';

  @override
  String get errorSessionExpired => 'Phiên đăng nhập không còn hiệu lực';

  @override
  String get errorGeneric => 'Đã xảy ra lỗi';

  @override
  String get errorLoadFailed => 'Không tải được dữ liệu';

  @override
  String get errorOffline =>
      'Bạn đang ngoại tuyến. Kiểm tra kết nối và thử lại.';

  @override
  String get errorUnauthorized => 'Vui lòng đăng nhập lại';

  @override
  String get emptyStoresNearby => 'Chưa có cửa hàng gần bạn';

  @override
  String get emptyOffers => 'Chưa có đề nghị từ tài xế';

  @override
  String get statusPending => 'Đang chờ';

  @override
  String get statusCompleted => 'Hoàn tất';

  @override
  String get statusCancelled => 'Đã hủy';

  @override
  String get tabHome => 'Trang';

  @override
  String get tabTrips => 'Chuyến';

  @override
  String get tabBook => 'Đặt';

  @override
  String get tabShop => 'Mua';

  @override
  String get tabAccount => 'Tôi';

  @override
  String get tabOverview => 'Tổng quan';

  @override
  String get tabOrders => 'Đơn hàng';

  @override
  String get tabProducts => 'Thực đơn';

  @override
  String get tabStats => 'Thống kê';

  @override
  String get tabJobs => 'Việc nhận';

  @override
  String get tabEarnings => 'Thu nhập';

  @override
  String get tabNotifications => 'Thông báo';

  @override
  String get filterAll => 'Tất cả';

  @override
  String get filterRides => 'Xe';

  @override
  String get filterFood => 'Đồ ăn';

  @override
  String get filterShopping => 'Mua';

  @override
  String get filterOrders => 'Đơn hàng';

  @override
  String get authPhoneLabel => 'Số điện thoại';

  @override
  String get authTermsAnd => ' và ';

  @override
  String get authPrivacyPolicy => 'Chính sách quyền riêng tư';

  @override
  String get otpHeading => 'Xác minh SĐT';

  @override
  String get otpSending => 'Đang gửi';

  @override
  String get otpInvalidTitle => 'Mã không đúng';

  @override
  String get otpExpiredTitle => 'Mã đã hết hạn';

  @override
  String get otpLockedBody => 'Sai quá số lần. Thử lại sau.';

  @override
  String get otpInvalidBody => 'Mã không đúng hoặc đã dùng.';

  @override
  String get otpInvalidShort => 'Mã OTP không hợp lệ.';

  @override
  String get otpCannotResendTitle => 'Chưa thể gửi mã mới';

  @override
  String get otpCannotResendBody => 'Chờ hết thời gian để gửi lại.';

  @override
  String get otpResendLabel => 'Gửi lại mã';

  @override
  String get otpResendCooldown => 'Gửi lại sau';

  @override
  String get otpServerGateHint => 'Chờ hết thời gian để lấy mã mới.';

  @override
  String get otpPrivacyNote =>
      'Vì lý do bảo mật, số lần nhập mã sai bị giới hạn.';

  @override
  String get otpFieldLabel => 'Mã xác minh';

  @override
  String get actionChangeEmail => 'Đổi email';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get otpEmailHeadingPrefix => 'Xác minh ';

  @override
  String get otpEmailHeadingAccent => 'email';

  @override
  String get otpEmailBodyPrefix => 'Nhập mã 6 số đã gửi đến ';

  @override
  String get emailErrorNotVerified =>
      'Email này chưa được xác minh. Hãy đăng nhập lại để nhận mã xác minh, hoặc đặt lại mật khẩu qua email.';

  @override
  String get emailErrorTooManyAttempts =>
      'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';

  @override
  String get emailErrorDeliveryFailed =>
      'Không gửi được email xác minh. Vui lòng thử lại sau.';

  @override
  String get otpEmailLockedBody =>
      'Bạn đã nhập sai quá số lần cho phép. Hãy quay lại và bắt đầu lại để nhận mã mới.';

  @override
  String get ridePickup => 'Điểm đón';

  @override
  String get rideDropoff => 'Điểm đến';

  @override
  String get homeTagline => 'Đi muôn nơi · Mua vạn món';

  @override
  String get homeCitySample => 'Đà Nẵng';

  @override
  String get chatEmpty => 'Chưa có tin nhắn';

  @override
  String get chatInputHint => 'Nhập tin nhắn';

  @override
  String get chatContact => 'Nhắn tin';

  @override
  String get chatContactShop => 'Nhắn quán';

  @override
  String get chatContactCustomer => 'Nhắn khách';

  @override
  String get voiceCall => 'Gọi thoại';

  @override
  String get voiceCalling => 'Đang gọi…';

  @override
  String get voiceConnecting => 'Đang kết nối…';

  @override
  String get voiceIncoming => 'Cuộc gọi đến';

  @override
  String get voiceReconnecting => 'Sóng yếu, đang kết nối lại…';

  @override
  String get voicePeerCustomer => 'Khách hàng';

  @override
  String get voicePeerDriver => 'Tài xế';

  @override
  String get voiceAccept => 'Nghe máy';

  @override
  String get voiceDecline => 'Từ chối';

  @override
  String get voiceHangUp => 'Kết thúc';

  @override
  String get voiceMute => 'Tắt mic';

  @override
  String get voiceUnmute => 'Bật mic';

  @override
  String get voiceSpeaker => 'Loa ngoài';

  @override
  String get voiceEndedHungUp => 'Cuộc gọi đã kết thúc';

  @override
  String get voiceEndedDeclined => 'Cuộc gọi bị từ chối';

  @override
  String get voiceEndedNoAnswer => 'Không có người nghe máy';

  @override
  String get voiceEndedMissed => 'Cuộc gọi nhỡ';

  @override
  String get voiceEndedTripClosed => 'Chuyến đã kết thúc nên cuộc gọi dừng lại';

  @override
  String get voiceEndedConnectionLost => 'Mất kết nối cuộc gọi';

  @override
  String get voiceMicDenied => 'Cần quyền micro để gọi. Hãy bật trong Cài đặt.';

  @override
  String get apiErrVoiceDisabled =>
      'Tính năng gọi trong ứng dụng đang tạm tắt.';

  @override
  String get apiErrVoiceUnavailable =>
      'Gọi thoại tạm thời chưa sẵn sàng. Vui lòng nhắn tin.';

  @override
  String get apiErrVoiceBusy => 'Chuyến này đang có một cuộc gọi khác.';

  @override
  String get apiErrVoiceNoCounterpart => 'Chưa có tài xế nhận chuyến này.';

  @override
  String get apiErrVoiceWindowClosed => 'Chỉ gọi được khi chuyến đang diễn ra.';

  @override
  String get apiErrChatWindowClosed =>
      'Đã hết thời hạn liên hệ cho chuyến đi hoặc đơn hàng này.';

  @override
  String get apiErrChatNoCounterpart =>
      'Chưa có tài xế nhận chuyến hoặc đơn hàng này.';

  @override
  String get apiErrChatForbidden =>
      'Bạn không tham gia vào cuộc trò chuyện này.';

  @override
  String get apiErrChatUnavailable =>
      'Tính năng nhắn tin tạm thời không khả dụng. Vui lòng thử lại sau.';

  @override
  String get apiErrChatBodyInvalid => 'Nội dung tin nhắn không hợp lệ.';

  @override
  String get bannerOfflineTitle => 'Bạn đang ngoại tuyến';

  @override
  String get commonSelected => 'Đã chọn';

  @override
  String get actionSeeDetail => 'Xem chi tiết →';

  @override
  String get rideOfferDetailTitle => 'Chi tiết báo giá';

  @override
  String get rideOfferAmountLabel => 'Giá tài xế chào';

  @override
  String get rideYourBidLabel => 'Giá bạn đề xuất';

  @override
  String get rideTripInfoTitle => 'Hành trình';

  @override
  String get rideSelectOfferCta => 'Chọn giá này';

  @override
  String get ridePickupCodeTitle => 'Mã đón khách';

  @override
  String get ridePickupCodeChip => 'Đưa mã cho tài xế';

  @override
  String get ridePickupCodeHeadline => 'Mã xác thực đón';

  @override
  String get ridePickupCodeBody => 'Chỉ đưa mã khi đúng xe, biển số.';

  @override
  String get ridePickupCodeSafetyTitle => 'Giữ mã riêng tư';

  @override
  String get ridePickupCodeSafetyBody => 'Không gửi mã qua chat.';

  @override
  String get rideSafetyTitle => 'Trung tâm an toàn';

  @override
  String get rideSafetyBannerTitle => 'An toàn trong chuyến';

  @override
  String get rideSafetyBannerBody => 'Chia sẻ hành trình, gọi 113/115 khi cần.';

  @override
  String get rideSafetyShareTitle => 'Chia sẻ chuyến';

  @override
  String get rideSafetyShareBody => 'Gửi link theo dõi chuyến cho người thân.';

  @override
  String get rideSafetyShareCta => 'Chia sẻ liên kết';

  @override
  String get rideSafetyShareCopied => 'Đã sao chép liên kết chuyến';

  @override
  String get rideSafetyContactsTitle => 'Liên hệ khẩn cấp';

  @override
  String get rideSafetyContactsBody => 'Lưu trên máy này.';

  @override
  String get rideSafetyAddContact => 'Thêm liên hệ';

  @override
  String get rideSafetyEmergencyTitle => 'Trợ giúp khẩn cấp';

  @override
  String get rideSafetyEmergencyBody => 'Gọi số khẩn cấp bằng điện thoại.';

  @override
  String get rideCancelTitle => 'Hủy chuyến';

  @override
  String get rideCancelPickReason => 'Bạn hủy vì lý do nào?';

  @override
  String get rideCancelReasonWait => 'Chờ quá lâu';

  @override
  String get rideCancelReasonPlans => 'Đổi kế hoạch';

  @override
  String get rideCancelReasonAddress => 'Sai điểm đón/đến';

  @override
  String get rideCancelBookAgain => 'Đặt chuyến khác';

  @override
  String get rideCancelReasonOptional => 'Lý do hủy (không bắt buộc)';

  @override
  String get rideCancelReasonDriver => 'Vấn đề với tài xế';

  @override
  String get rideCancelReasonOther => 'Lý do khác';

  @override
  String get rideCancelConfirm => 'Xác nhận hủy';

  @override
  String get rideCancelKeep => 'Giữ chuyến này';

  @override
  String get rideCancelSuccess => 'Đã hủy chuyến';

  @override
  String get rideCancelSubmitted => 'Đã gửi yêu cầu hủy';

  @override
  String get rideCancelSoftFail =>
      'Chưa kết nối được. Vui lòng thử lại khi có mạng.';

  @override
  String get foodCancelTitle => 'Hủy đơn';

  @override
  String get foodCancelPickReason => 'Bạn hủy vì lý do nào?';

  @override
  String get foodCancelPolicyHint => 'Chỉ hủy được khi quán chưa nhận đơn.';

  @override
  String get foodCancelReasonWrong => 'Đặt nhầm món';

  @override
  String get foodCancelReasonWait => 'Chờ quá lâu';

  @override
  String get foodCancelReasonAddress => 'Đổi địa chỉ giao';

  @override
  String get foodCancelReasonOther => 'Lý do khác';

  @override
  String get foodCancelConfirm => 'Xác nhận hủy';

  @override
  String get foodCancelKeep => 'Giữ đơn này';

  @override
  String get driverJobFailedTitle => 'Giao thất bại';

  @override
  String get driverJobFailedChip => 'Thất bại';

  @override
  String get driverJobFailedBody => 'Chọn lý do.';

  @override
  String get driverJobFailedPick => 'Kết quả';

  @override
  String get driverFailAbsent => 'Khách vắng';

  @override
  String get driverFailAddress => 'Sai địa chỉ';

  @override
  String get driverFailRefused => 'Từ chối nhận';

  @override
  String get driverFailOther => 'Khác';

  @override
  String get driverJobFailedSubmit => 'Gửi kết quả';

  @override
  String get driverJobFailedSoftFail => 'Đã ghi nhận lý do trên thiết bị này.';

  @override
  String get driverOpenCompletedSample => 'Xem chi tiết chuyến';

  @override
  String get driverJobIdLabel => 'Việc';

  @override
  String get driverJobCompletedTitle => 'Chi tiết việc đã xong';

  @override
  String get driverBackToJobs => 'Về danh sách việc';

  @override
  String get driverCompletedEarningsTitle => 'Thu nhập chuyến này';

  @override
  String get driverCompletedFareLabel => 'Giá đã chấp nhận';

  @override
  String get driverJobsHistorySection => 'Kết quả việc';

  @override
  String get driverServicesTitle => 'Chọn dịch vụ';

  @override
  String get driverServicesHeadline => 'Dịch vụ';

  @override
  String get driverServicesOnlineTitle => 'Đang trực tuyến';

  @override
  String get driverServicesApprovedSection => 'Dịch vụ đã được duyệt';

  @override
  String get driverServicesRideTitle => 'Chở khách';

  @override
  String get driverServicesFoodTitle => 'Giao đồ ăn';

  @override
  String get driverServicesApprovedChip => 'Đã duyệt';

  @override
  String get driverServicesVehicleSection => 'Phương tiện hoạt động';

  @override
  String get driverServicesAreaSection => 'Khu vực nhận yêu cầu';

  @override
  String get driverServicesAreaFromGps => 'Từ vị trí hiện tại của tài xế';

  @override
  String get driverServicesSave => 'Lưu cấu hình';

  @override
  String driverServicesCount(int count) {
    return '$count dịch vụ';
  }

  @override
  String get driverOtpTitle => 'Mã OTP đón khách';

  @override
  String get driverOtpHeadline => 'Xác thực khách lên xe';

  @override
  String get driverOtpBody => 'Nhập mã 4 số của khách.';

  @override
  String get driverOtpVerifyTitle => 'Xác minh hành khách';

  @override
  String driverOtpValidFor(String rideId) {
    return 'Mã OTP chỉ có hiệu lực cho chuyến $rideId';
  }

  @override
  String get driverOtpWaitingHint => 'Chờ khách đọc mã đón';

  @override
  String get driverOtpWrong =>
      'Mã OTP không khớp. Kiểm tra lại với hành khách.';

  @override
  String get driverOtpConfirm => 'Xác nhận và bắt đầu chuyến';

  @override
  String get driverOtpWaitingChip => 'CHỜ KHÁCH';

  @override
  String get driverActiveNavTitle => 'Đang đến đón khách';

  @override
  String get driverActiveArrivedTitle => 'Đã đến điểm đón';

  @override
  String get driverActiveOnTripTitle => 'Chuyến đang chạy';

  @override
  String get driverActiveCompleteTitle => 'Kết thúc chuyến';

  @override
  String get driverActiveArrivedCta => 'Đã đến điểm đón';

  @override
  String get driverActiveOpenOtp => 'Nhập OTP hành khách';

  @override
  String get driverActiveWaitingBody => 'Chờ khách, nhập OTP để bắt đầu.';

  @override
  String get driverActiveOnTripBody => 'Lái xe an toàn.';

  @override
  String get driverActiveCompleteCta => 'Hoàn tất / thu tiền';

  @override
  String get driverActiveCompleteBody => 'Thu đúng giá đã chốt.';

  @override
  String get driverActiveReportIssue => 'Báo sự cố';

  @override
  String get driverFoodPhaseNavTitle => 'Đang tới quán';

  @override
  String get driverFoodPhaseWaitTitle => 'Chờ món tại quán';

  @override
  String get driverFoodPhasePickupTitle => 'Xác nhận lấy món';

  @override
  String get driverFoodPhaseDeliverTitle => 'Giao tới khách';

  @override
  String get driverFoodPhaseCompleteTitle => 'Đã giao';

  @override
  String get driverFoodConfirmPickup => 'Đã lấy món';

  @override
  String get driverFoodArrivedCustomer => 'Đã đến điểm giao';

  @override
  String get driverFoodCompleteDelivery => 'Hoàn tất giao';

  @override
  String get driverFoodWaitBody => 'Chờ quán làm xong món.';

  @override
  String get driverFoodPickupBody => 'Kiểm tra số túi và mã bàn giao.';

  @override
  String get driverFoodDeliverBody => 'Giao món, thu COD.';

  @override
  String get driverFoodCompleteBody => 'COD sẽ được đối soát.';

  @override
  String get driverFoodIncomePending => 'Cập nhật sau đối soát';

  @override
  String get driverFoodNoClientFee =>
      'Thu nhập thực nhận hiển thị sau khi đối soát.';

  @override
  String get driverFoodCodCollect => 'Thu hộ (COD)';

  @override
  String get merchantRejectOrder => 'Từ chối';

  @override
  String get merchantAcceptOrder => 'Xác nhận đơn';

  @override
  String get merchantRejectConfirmTitle => 'Từ chối đơn này?';

  @override
  String get merchantRejectConfirmBody => 'Từ chối đơn này?';

  @override
  String get merchantRejectConfirmCta => 'Xác nhận từ chối';

  @override
  String get merchantRejectKeep => 'Giữ đơn';

  @override
  String get merchantRejectDone =>
      'Đã từ chối đơn. Khách được thông báo đơn bị hủy.';

  @override
  String get merchantHomeFinanceTitle => 'Tài chính hôm nay';

  @override
  String get merchantHomeCompletedToday => 'Hoàn thành hôm nay';

  @override
  String get merchantHomeFoodToday => 'Doanh thu món hôm nay';

  @override
  String get merchantOrderItemsTitle => 'Danh sách món';

  @override
  String get merchantOrderValueTitle => 'Giá trị đơn';

  @override
  String get merchantOrderCodTotal => 'Tổng COD';

  @override
  String get merchantOrderFoodRevenue => 'Doanh thu tiền món';

  @override
  String get merchantOrderDiscount => 'Giảm giá';

  @override
  String get merchantSettingsShellTitle => 'Cài đặt Shop';

  @override
  String get merchantAcceptTitle => 'Cấu hình nhận đơn';

  @override
  String get merchantAcceptModeLabel => 'Chế độ xác nhận đơn';

  @override
  String get merchantAcceptManual => 'Thủ công';

  @override
  String get merchantAcceptAuto => 'Tự động theo điều kiện';

  @override
  String get merchantAcceptManualHint => 'Duyệt từng đơn.';

  @override
  String get merchantAcceptAutoHint => 'Tự nhận khi quán mở.';

  @override
  String get merchantHoursTitle => 'Giờ mở cửa';

  @override
  String get merchantHoursOpen => 'Mở';

  @override
  String get merchantHoursClosed => 'Nghỉ';

  @override
  String get merchantBusyTitle => 'Bận / Tạm ngưng';

  @override
  String get merchantBusyModeLabel => 'Chế độ phục vụ';

  @override
  String get merchantBusyOpen => 'Hoạt động bình thường';

  @override
  String get merchantBusyBusy => 'Bếp đang bận';

  @override
  String get merchantBusyPaused => 'Tạm ngưng nhận đơn';

  @override
  String get merchantBusyOpenHint => 'Nhận đơn theo lịch mở cửa.';

  @override
  String get merchantBusyBusyHint => 'Vẫn nhận đơn, chuẩn bị lâu hơn.';

  @override
  String get merchantBusyPausedHint => 'Ngưng nhận đơn mới.';

  @override
  String get merchantVariantsTitle => 'Tùy chọn món';

  @override
  String get merchantVariantsCta => 'Sửa biến thể';

  @override
  String get merchantVariantsSave => 'Lưu cấu hình';

  @override
  String get dayMon => 'Thứ Hai';

  @override
  String get dayTue => 'Thứ Ba';

  @override
  String get dayWed => 'Thứ Tư';

  @override
  String get dayThu => 'Thứ Năm';

  @override
  String get dayFri => 'Thứ Sáu';

  @override
  String get daySat => 'Thứ Bảy';

  @override
  String get daySun => 'Chủ Nhật';

  @override
  String get rideRouteOverviewTitle => 'Kiểm tra hành trình';

  @override
  String get rideRouteSwapTooltip => 'Đổi điểm đón/đến';

  @override
  String get rideRouteDistance => 'Quãng đường';

  @override
  String get rideRouteRefPrice => 'Giá tham khảo';

  @override
  String get rideRouteContinueBooking => 'Chọn xe & đề xuất giá';

  @override
  String get rideFareBreakdownTitle => 'Chi tiết giá cước';

  @override
  String get rideFareEstimatedFee => 'Phí dự kiến';

  @override
  String get rideFareComponentsTitle => 'Cấu phần giá';

  @override
  String get rideFareTripInfoTitle => 'Thông tin hành trình';

  @override
  String get rideFareProposeCta => 'Đề xuất giá chuyến';

  @override
  String get rideShareTrip => 'Chia sẻ chuyến đi';

  @override
  String get foodSearchTitle => 'Tìm món & cửa hàng';

  @override
  String get foodSearchHint => 'bún bò';

  @override
  String get foodSearchFilterNear => 'Gần tôi';

  @override
  String get foodSearchSortNewest => 'Mới nhất';

  @override
  String get foodSearchSuggestions => 'Gợi ý tìm kiếm';

  @override
  String foodSearchResults(int count) {
    return '$count kết quả';
  }

  @override
  String get foodSearchEmpty => 'Chưa có quán khớp từ khóa';

  @override
  String get foodSearchDishes => 'Món ăn';

  @override
  String get foodSearchStores => 'Quán';

  @override
  String get foodDeliverTo => 'Giao đến';

  @override
  String get foodFilterButton => 'Bộ lọc';

  @override
  String get foodFilterTitle => 'Lọc & sắp xếp';

  @override
  String get foodFilterSort => 'Sắp xếp';

  @override
  String get foodFilterNear => 'Gần nhất';

  @override
  String get foodFilterRating => 'Đánh giá cao';

  @override
  String get foodFilterDistance => 'Khoảng cách';

  @override
  String get foodFilterAnyDistance => 'Mọi khoảng cách';

  @override
  String foodFilterKm(int km) {
    return 'Trong $km km';
  }

  @override
  String get foodFilterOpenNow => 'Đang mở cửa';

  @override
  String get foodFilterOffers => 'Có ưu đãi';

  @override
  String get foodFilterApply => 'Áp dụng';

  @override
  String get foodFilterReset => 'Đặt lại';

  @override
  String get foodFilterClear => 'Xóa lọc';

  @override
  String get foodSearchHistory => 'Lịch sử tìm kiếm';

  @override
  String get foodSearchClearHistory => 'Xóa tất cả';

  @override
  String get foodCategoryTitle => 'Quán ăn & danh mục';

  @override
  String get foodCategorySortNear => 'Gần nhất';

  @override
  String get foodCategorySortRating => 'Đánh giá cao';

  @override
  String get foodCategoryAroundYou => 'Quán ăn quanh bạn';

  @override
  String foodCategoryAroundHint(int count) {
    return '$count cửa hàng';
  }

  @override
  String get foodItemOptionsTitle => 'Tùy chọn món ăn';

  @override
  String get foodItemOptionsNoGroups => 'Món này chưa có tùy chọn.';

  @override
  String get foodItemOptionsTotal => 'Tổng cộng';

  @override
  String get foodItemOptionsAdd => 'Thêm vào giỏ hàng';

  @override
  String get foodItemOptionsRequired => 'Bắt buộc';

  @override
  String get foodItemOptionsOptional => 'Tùy chọn';

  @override
  String get foodItemDetailTitle => 'Chi tiết món';

  @override
  String foodDishPhotoCount(int index, int total) {
    return 'Ảnh $index/$total';
  }

  @override
  String get foodItemOptionsChoose => 'Tùy chọn';

  @override
  String get foodItemOptionsChooseRequired => 'Chọn tùy chọn';

  @override
  String foodItemOptionsMissingRequired(String groups) {
    return 'Chọn $groups';
  }

  @override
  String get foodItemOptionsFree => 'Miễn phí';

  @override
  String get foodItemQuantity => 'Số lượng';

  @override
  String foodItemSelectedOptions(String options) {
    return 'Đã chọn: $options';
  }

  @override
  String get foodItemInfoTitle => 'Thông tin món';

  @override
  String foodItemInStore(String store) {
    return 'Tại $store';
  }

  @override
  String get foodStoreDirections => 'Chỉ đường';

  @override
  String get foodStoreOpenInMaps => 'Mở Google Maps';

  @override
  String get foodStoreMapOpenFailed => 'Không mở được bản đồ.';

  @override
  String get foodStoreMenuSections => 'Danh mục món';

  @override
  String foodItemOptionsMaxReached(int count) {
    return 'Đã chọn tối đa $count';
  }

  @override
  String get foodInvoiceTitle => 'Biên nhận đơn hàng';

  @override
  String get foodInvoiceDelivered => 'Đã giao thành công';

  @override
  String get foodInvoiceOrderId => 'Đơn';

  @override
  String get foodInvoiceSyncChip => 'v1 · Dữ liệu đồng bộ';

  @override
  String get foodInvoiceDeliveredChip => 'Đã giao';

  @override
  String get foodInvoiceStore => 'Quán';

  @override
  String get foodInvoiceRecipient => 'Người nhận';

  @override
  String get foodInvoiceItemsTitle => 'Món đã nhận';

  @override
  String get foodInvoiceItemsEmpty => 'Chưa có dòng món trên đơn này.';

  @override
  String get foodInvoiceReceiptTitle => 'Biên nhận';

  @override
  String get foodInvoiceSubtotal => 'Tiền món';

  @override
  String get foodInvoiceDelivery => 'Phí giao';

  @override
  String get foodInvoiceDiscount => 'Giảm giá';

  @override
  String get foodInvoiceCodTotal => 'Tổng thanh toán';

  @override
  String get foodInvoiceMethod => 'Phương thức';

  @override
  String get foodInvoiceMethodCollected => 'Tiền mặt · Đã thanh toán';

  @override
  String foodInvoiceCodNote(String amount) {
    return 'Đã trả $amount tiền mặt.';
  }

  @override
  String get foodInvoiceRateCta => 'Đánh giá đơn hàng';

  @override
  String get foodInvoiceTrackCta => 'Theo dõi đơn';

  @override
  String get foodInvoiceItemsTitleOpen => 'Món đã chọn';

  @override
  String get foodInvoiceCodDue => 'Tổng cần thanh toán';

  @override
  String get checkoutEmptyBody => 'Chưa có món.';

  @override
  String get checkoutBackToMenu => 'Quay lại thực đơn';

  @override
  String get foodTrackingMapChip => 'Đơn đang được giao';

  @override
  String get foodTrackingMapWaitingDriver => 'Đang chờ vị trí tài xế';

  @override
  String get foodTrackingMapEmptyHint => 'Quán chưa có vị trí trên bản đồ.';

  @override
  String get foodTrackingCodDue => 'Cần thanh toán khi nhận hàng';

  @override
  String get foodTrackingCodHint => 'Trả tiền khi nhận hàng.';

  @override
  String get paymentHistoryTitle => 'Lịch sử thanh toán';

  @override
  String get paymentHistoryFilterAll => 'Tất cả';

  @override
  String get paymentHistoryRecent => 'Giao dịch gần đây';

  @override
  String get stateErrorTitle => 'Có lỗi xảy ra';

  @override
  String get stateErrorBody => 'Tải thất bại. Thử lại.';

  @override
  String get fieldShowPassword => 'Hiện mật khẩu';

  @override
  String get fieldHidePassword => 'Ẩn mật khẩu';

  @override
  String get authHelp => 'Trợ giúp';

  @override
  String get authHelpHotline => 'Trung tâm trợ giúp DealGo: 1900 6868';

  @override
  String get authLegalPrefix => 'Bằng việc tiếp tục, bạn đồng ý với ';

  @override
  String get authLegalTerms => 'Điều khoản sử dụng';

  @override
  String get authLegalConsentPrefix => 'Tôi đã đọc và đồng ý với ';

  @override
  String get authLegalConsentRequired =>
      'Vui lòng đọc và đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư để tiếp tục.';

  @override
  String get authWelcomeTo => 'Chào mừng đến với';

  @override
  String get authMethodPasskey => 'Passkey';

  @override
  String get authMethodsEmptyTitle => 'Chưa có cách đăng nhập';

  @override
  String get authMethodsEmptyBody => 'Thử lại sau.';

  @override
  String get authPhoneTitle => 'Đăng nhập';

  @override
  String get authPhoneRequired => 'Vui lòng nhập số điện thoại';

  @override
  String get authPhoneInvalid => 'Số điện thoại không hợp lệ (từ 9 đến 11 số)';

  @override
  String get authOtherMethods => 'Đăng nhập bằng phương thức khác';

  @override
  String get emailErrRequired => 'Vui lòng nhập địa chỉ email';

  @override
  String get emailErrInvalid => 'Địa chỉ email không hợp lệ';

  @override
  String get passwordErrRequired => 'Vui lòng nhập mật khẩu';

  @override
  String get passwordErrTooShort => 'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get passwordErrConfirm => 'Vui lòng xác nhận mật khẩu';

  @override
  String get passwordErrMismatch => 'Mật khẩu xác nhận không khớp';

  @override
  String get emailErrWrongCredentials => 'Email hoặc mật khẩu không đúng';

  @override
  String get emailErrInUse => 'Email này đã được đăng ký';

  @override
  String get emailLoginTitle => 'Đăng nhập bằng Email';

  @override
  String get emailRegisterTitle => 'Đăng ký bằng Email';

  @override
  String get emailLoginSubtitle =>
      'Đăng nhập bằng email và mật khẩu đã đăng ký.';

  @override
  String get emailRegisterSubtitle =>
      'Tạo tài khoản DealGo bằng email và mật khẩu.';

  @override
  String get emailFieldPassword => 'Mật khẩu';

  @override
  String get emailFieldConfirmPassword => 'Xác nhận mật khẩu';

  @override
  String get emailFieldDisplayName => 'Tên hiển thị (tuỳ chọn)';

  @override
  String get emailTabLogin => 'Đăng nhập';

  @override
  String get emailTabRegister => 'Đăng ký';

  @override
  String otpSeconds(int count) {
    return '$count giây';
  }

  @override
  String get otpChangePhone => 'Đổi số';

  @override
  String get otpPhoneHeadingPrefix => 'Xác minh ';

  @override
  String get otpPhoneHeadingAccent => 'số điện thoại';

  @override
  String get otpResendIn => 'Gửi lại mã sau';

  @override
  String get otpShieldNote => 'Mã OTP bảo vệ tài khoản.';

  @override
  String get otpConfirm => 'Xác nhận';

  @override
  String get passkeyTitle => 'Đăng nhập bằng Passkey';

  @override
  String get passkeyOr => 'hoặc';

  @override
  String get passkeyContinue => 'Tiếp tục với passkey';

  @override
  String get passkeySignIn => 'Đăng nhập';

  @override
  String get passkeySignUp => 'Tạo tài khoản';

  @override
  String get splashTagline => 'Đi muôn nơi · Ăn vạn món';

  @override
  String get splashPreparing => 'Đang chuẩn bị trải nghiệm của bạn...';

  @override
  String get serviceRideTitle => 'Đặt xe';

  @override
  String get serviceRideBlurb => 'Xe máy, ô tô';

  @override
  String get serviceFoodTitle => 'Đồ ăn';

  @override
  String get serviceFoodBlurb => 'Hàng ngàn món\nngon mỗi ngày';

  @override
  String get onbSlide1Title => 'Một ứng dụng,\n';

  @override
  String get onbSlide1Accent => 'vạn trải nghiệm';

  @override
  String get onbSlide1Body =>
      'Đặt xe, khám phá món ngon và mua sắm hằng ngày — tất cả trong DealGo.';

  @override
  String get onbSlide2Title => 'Di chuyển nhanh,\n';

  @override
  String get onbSlide2Accent => 'an toàn & tiết kiệm';

  @override
  String get onbSlide2Body => 'Tài xế đón tận nơi, giá minh bạch, tự trả giá.';

  @override
  String get onbSlide2Pill1Title => 'Xe máy & Ô tô';

  @override
  String get onbSlide2Pill1Body => 'Đón nhanh chỉ\ntừ 3 phút';

  @override
  String get onbSlide2Pill2Title => 'Giá thương lượng';

  @override
  String get onbSlide2Pill2Body => 'Chủ động chốt\ngiá ưng ý';

  @override
  String get onbSlide3Title => 'Món ngon nóng hổi,\n';

  @override
  String get onbSlide3Accent => 'giao siêu tốc';

  @override
  String get onbSlide3Body => 'Món ngon Đà Nẵng, giao tận tay.';

  @override
  String get onbSlide3Pill1Title => 'Đặc sản chuẩn vị';

  @override
  String get onbSlide3Pill1Body => 'Mì Quảng, Bún chả cá,\nBánh mì giòn';

  @override
  String get onbSlide3Pill2Title => 'Giao siêu tốc 20\'';

  @override
  String get onbSlide3Pill2Body => 'Món ngon luôn\nnóng hổi tận tay';

  @override
  String get onbSkip => 'Bỏ qua';

  @override
  String get onbStart => 'Bắt đầu ngay';

  @override
  String get profileSetupTitle => 'Hoàn thiện hồ sơ';

  @override
  String get profileAvatarOptional => 'Ảnh đại diện (tuỳ chọn)';

  @override
  String get profileFullName => 'Họ và tên';

  @override
  String get profileBirthdayOptional => 'Ngày sinh (tuỳ chọn)';

  @override
  String get profileGender => 'Giới tính';

  @override
  String get profileGenderMale => 'Nam';

  @override
  String get profileGenderFemale => 'Nữ';

  @override
  String get profileGenderOther => 'Khác';

  @override
  String get profileDone => 'Hoàn tất';

  @override
  String get rolePickerPrefix => 'Bạn muốn dùng ';

  @override
  String get rolePickerSuffix => ' theo vai trò nào?';

  @override
  String get rolePickerPartnerSection => 'Hoàn tất hồ sơ đối tác';

  @override
  String get rolePickerLearnMore => 'Tìm hiểu thêm';

  @override
  String get actionGotIt => 'Đã hiểu';

  @override
  String get rolePickerInfoTitle => 'Ba vai trò, một ứng dụng';

  @override
  String get roleCustomer => 'Khách hàng';

  @override
  String get roleCustomerBody => 'Đặt xe, gọi đồ ăn, mua sắm hằng ngày';

  @override
  String get roleMerchant => 'Cửa hàng';

  @override
  String get roleMerchantBody => 'Thực đơn, đơn hàng, doanh thu';

  @override
  String get roleDriver => 'Tài xế';

  @override
  String get roleDriverBody => 'Chở khách, giao đồ ăn';

  @override
  String get rolePartnerDriver => 'Đăng ký đối tác tài xế';

  @override
  String get rolePartnerShop => 'Đăng ký đối tác Shop';

  @override
  String get rolePartnerPending => 'Hồ sơ đang thẩm định — tiếp tục theo dõi';

  @override
  String get rolePartnerRejected => 'Hồ sơ cần bổ sung trước khi hoạt động';

  @override
  String get rolePartnerStart => 'Hoàn tất hồ sơ để kích hoạt vai trò';

  @override
  String onbStep(int step, int total) {
    return 'Bước $step trong $total';
  }

  @override
  String get driverActionFailed =>
      'Chưa cập nhật được trạng thái. Vui lòng thử lại.';

  @override
  String get driverActionConflict =>
      'Trạng thái đã thay đổi trên hệ thống. Quay lại danh sách việc để cập nhật.';

  @override
  String get driverAgreedFare => 'Giá đã chốt';

  @override
  String get driverCollect => 'Thu tiền';

  @override
  String get driverPhasePickup => 'Đang đón';

  @override
  String get driverPhaseWaiting => 'Chờ khách';

  @override
  String get driverPhaseOnTrip => 'Đang chạy';

  @override
  String get driverPhaseDone => 'Hoàn tất';

  @override
  String driverItemsCount(int count) {
    return '$count món';
  }

  @override
  String driverCodNote(String amount) {
    return 'COD $amount là tiền thu hộ.';
  }

  @override
  String get actionSkip => 'Bỏ qua';

  @override
  String get driverClaimJob => 'Nhận việc';

  @override
  String get driverClaimFailed => 'Không nhận được việc. Vui lòng thử lại.';

  @override
  String get driverFoodRequestTitle => 'Đơn giao';

  @override
  String get driverJobInfo => 'Thông tin việc';

  @override
  String get driverPickupStore => 'Cửa hàng đối tác DealGo';

  @override
  String get driverDeliveryStops => 'Điểm nhận và giao';

  @override
  String get driverPickupPoint => 'Điểm lấy món';

  @override
  String get driverDropoffPoint => 'Giao cho khách';

  @override
  String get driverFinance => 'Thông tin tài chính';

  @override
  String get driverFoodSubtotal => 'Tiền món';

  @override
  String get driverFoodDeliveryFee => 'Phí giao';

  @override
  String get driverFoodFeeCustomerPays => 'Phí giao khách thanh toán';

  @override
  String get driverFoodExpectedIncome => 'Thu nhập tài xế dự kiến';

  @override
  String get driverDeliveredTitle => 'Đã giao thành công';

  @override
  String get driverHeadToStore => 'Đến cửa hàng lấy món';

  @override
  String get driverHeadToCustomer => 'Đến điểm giao';

  @override
  String get driverFoodNavigateBody => 'Đến quán rồi bấm xác nhận.';

  @override
  String get driverFoodPhaseWait => 'Chờ món';

  @override
  String get driverFoodPhasePicked => 'Đã lấy';

  @override
  String get driverFoodPhaseDelivering => 'Đang giao';

  @override
  String get driverNearbyRequests => 'Yêu cầu gần tài xế';

  @override
  String get actionRefresh => 'Làm mới';

  @override
  String get driverFindOtherJobs => 'Tìm việc khác';

  @override
  String get driverJobTakenTitle => 'Yêu cầu đã được nhận';

  @override
  String get driverJobTakenBody => 'Yêu cầu đã có tài xế khác nhận.';

  @override
  String get driverOfferNotChosenTitle => 'Đề xuất của bạn không được chọn';

  @override
  String get driverOfferNotChosenBody =>
      'Khách đã chọn tài xế khác cho đơn này.';

  @override
  String get driverJobUnavailable => 'Yêu cầu không còn khả dụng';

  @override
  String get driverRequestId => 'Mã yêu cầu';

  @override
  String get driverService => 'Dịch vụ';

  @override
  String get driverServiceFood => 'Giao đồ ăn';

  @override
  String get driverOtpMatched => 'Mã khớp — bắt đầu chuyến đi.';

  @override
  String get driverHeadToPickup => 'Điểm đón';

  @override
  String get driverFollowRoute => 'Điểm trả khách';

  @override
  String get driverPassenger => 'Khách hàng';

  @override
  String get driverPickupLabel => 'Điểm đón';

  @override
  String get driverDropoffLabel => 'Điểm đến';

  @override
  String get driverRideNavigateNote => 'Đến điểm đón.';

  @override
  String get driverCallCustomer => 'Gọi khách hàng';

  @override
  String get driverChatCustomer => 'Nhắn tin cho khách hàng';

  @override
  String get rideTrackTitle => 'Theo dõi tài xế';

  @override
  String get rideTrackAssigned => 'Tài xế đang đến đón';

  @override
  String get rideTrackArrived => 'Tài xế đã đến điểm đón';

  @override
  String get rideTrackInTrip => 'Đang trong chuyến đi';

  @override
  String get rideTrackCompleted => 'Chuyến đi đã hoàn tất';

  @override
  String get rideTrackNegotiating => 'Đang chờ tài xế nhận chuyến';

  @override
  String get rideTrackExpired => 'Chuyến đã hết hạn';

  @override
  String get rideTrackCancelled => 'Chuyến đã hủy';

  @override
  String get rideTrackDriverFallback => 'Tài xế DealGo';

  @override
  String get foodCancelNotAllowed =>
      'Đơn đã được cửa hàng nhận nên không thể hủy. Vui lòng liên hệ cửa hàng.';

  @override
  String get foodCancelFailed => 'Chưa hủy được đơn. Vui lòng thử lại.';

  @override
  String get foodCancelDone => 'Đã hủy đơn hàng.';

  @override
  String voucherValid(String code, String amount) {
    return '$code hợp lệ · giảm $amount';
  }

  @override
  String get voucherLabel => 'Mã ưu đãi';

  @override
  String get voucherHint => 'Nhập mã ưu đãi';

  @override
  String get voucherApply => 'Áp dụng';

  @override
  String get voucherRemove => 'Bỏ mã';

  @override
  String get voucherErrEmpty => 'Vui lòng nhập mã ưu đãi';

  @override
  String get voucherErrInvalid => 'Mã ưu đãi không hợp lệ';

  @override
  String get voucherErrFailed => 'Chưa kiểm tra được mã. Vui lòng thử lại.';

  @override
  String get driverOfflineNote => 'Bạn đang ngoại tuyến.';

  @override
  String get vouchersEmptyTitle => 'Chưa có ưu đãi';

  @override
  String get vouchersEmptyBody => 'Chưa có ưu đãi.';

  @override
  String get accountTitle => 'Tài khoản';

  @override
  String get accountNotifications => 'Thông báo';

  @override
  String get accountVouchers => 'Ưu đãi của tôi';

  @override
  String get accountVouchersBody => 'Các mã giảm giá đang có';

  @override
  String get accountSectionServices => 'Tài khoản và dịch vụ';

  @override
  String get accountActivity => 'Hoạt động của tôi';

  @override
  String get accountActivityBody => 'Chuyến đi và đơn hàng';

  @override
  String get accountAddresses => 'Địa chỉ đã lưu';

  @override
  String get accountAddressesBody => 'Nhà riêng, công ty và địa chỉ khác';

  @override
  String get accountPayments => 'Lịch sử thanh toán';

  @override
  String get accountPaymentsBody => 'Biên nhận và hoàn tiền';

  @override
  String get accountRoles => 'Trung tâm vai trò';

  @override
  String get accountSwitchRole => 'Đổi vai trò';

  @override
  String get accountAcceptMode => 'Nhận đơn auto/manual';

  @override
  String get accountAcceptModeBody => 'Chọn cách nhận đơn mới';

  @override
  String get accountHours => 'Giờ hoạt động';

  @override
  String get accountHoursBody => 'Lịch mở cửa / nghỉ';

  @override
  String get accountBusy => 'Chế độ bận';

  @override
  String get accountBusyBody => 'Tạm ngưng nhận đơn';

  @override
  String get accountSectionHelp => 'Trợ giúp và cài đặt';

  @override
  String get accountSectionDisplay => 'Hiển thị';

  @override
  String get accountLanguage => 'Ngôn ngữ';

  @override
  String get accountTheme => 'Giao diện';

  @override
  String get accountThemeSystem => 'Theo hệ thống';

  @override
  String get accountThemeLight => 'Sáng';

  @override
  String get accountThemeDark => 'Tối';

  @override
  String get accountSupport => 'Trung tâm hỗ trợ';

  @override
  String get accountSupportBody =>
      'Câu hỏi thường gặp, chat Messenger trên web';

  @override
  String get accountSupportTicketsBody => 'Theo dõi các yêu cầu hỗ trợ đã gửi';

  @override
  String get accountSignOut => 'Đăng xuất';

  @override
  String get accountPartnerHubTitle => 'Cơ hội gia tăng thu nhập';

  @override
  String get accountPartnerHubSubtitle =>
      'Trở thành đối tác Tài xế hoặc mở Quán ăn cùng DealGo';

  @override
  String get accountDriverPartner => 'Hồ sơ đối tác tài xế';

  @override
  String get accountShopPartner => 'Hồ sơ đối tác Shop';

  @override
  String get partnerStatusDraft => 'Chưa gửi xét duyệt';

  @override
  String get partnerStatusPending => 'Đang thẩm định';

  @override
  String get partnerStatusRejected => 'Cần bổ sung hồ sơ';

  @override
  String get partnerStatusActive => 'Đã kích hoạt';

  @override
  String get partnerActionRegister => 'Đăng ký';

  @override
  String get partnerActionTrack => 'Theo dõi';

  @override
  String get partnerActionUpdate => 'Bổ sung';

  @override
  String get partnerActionView => 'Xem';

  @override
  String get accountRoleShop => 'Shop';

  @override
  String get activityEmptyTitle => 'Chưa có hoạt động';

  @override
  String get activityEmptyBody => 'Chưa có hoạt động.';

  @override
  String get activityRecent => 'Gần đây';

  @override
  String get activityOfflineBody => 'Có thể chưa cập nhật.';

  @override
  String get statusExpired => 'Hết hạn';

  @override
  String get statusFailed => 'Không thành công';

  @override
  String get statusRejected => 'Bị từ chối';

  @override
  String get statusInProgress => 'Đang thực hiện';

  @override
  String get emptyStoresNearbyBody => 'Quay lại sau nhé.';

  @override
  String get notificationsEmptyTitle => 'Chưa có thông báo';

  @override
  String get notificationsEmptyBody => 'Chưa có thông báo.';

  @override
  String get helpNoResults => 'Không có hướng dẫn phù hợp với từ khóa này.';

  @override
  String get driverOpenRequests => 'Yêu cầu đang mở';

  @override
  String get driverOfflineTitle => 'Bạn đang ngoại tuyến';

  @override
  String get driverJobsOfflineBody => 'Bật nhận việc để xem yêu cầu.';

  @override
  String get checkoutVoucherRejected =>
      'Voucher không còn dùng được cho đơn này. Hãy gỡ mã hoặc thử mã khác.';

  @override
  String get checkoutErrOrderOpen => 'Bạn đang có một đơn đồ ăn chưa kết thúc.';

  @override
  String get checkoutErrItemUnavailable =>
      'Một món vừa hết. Hãy chọn lại thực đơn.';

  @override
  String get checkoutErrFareRange => 'Phí giao nằm ngoài khoảng cho phép.';

  @override
  String get checkoutErrStoreNotFound => 'Không tìm thấy cửa hàng.';

  @override
  String get checkoutErrGeneric =>
      'Không gửi được đơn. Giỏ hàng vẫn còn trên máy.';

  @override
  String get checkoutMenuChangedEmpty =>
      'Thực đơn vừa đổi và không còn món đã chọn.';

  @override
  String get checkoutTitleSubmitting => 'Đang xác nhận đơn';

  @override
  String get checkoutTitleOffline => 'Thanh toán đơn hàng';

  @override
  String get checkoutTitleRepriced => 'Xác nhận lại giỏ hàng';

  @override
  String get checkoutTitle => 'Thanh toán đơn đồ ăn';

  @override
  String get checkoutBackToCart => 'Quay về giỏ hàng';

  @override
  String get checkoutRetry => 'Thử đặt lại';

  @override
  String get checkoutBackToCartShort => 'Quay lại giỏ';

  @override
  String get checkoutRecipient => 'Người nhận';

  @override
  String get checkoutRecipientAddress => 'Người nhận và địa chỉ';

  @override
  String get checkoutItems => 'Danh sách món';

  @override
  String get checkoutTotalSection => 'Tổng thanh toán';

  @override
  String get checkoutSubtotal => 'Tiền món';

  @override
  String get checkoutDeliveryFee => 'Phí giao';

  @override
  String get checkoutDiscount => 'Giảm giá';

  @override
  String get checkoutCodTotal => 'Tổng thanh toán';

  @override
  String get checkoutPayment => 'Thanh toán';

  @override
  String get checkoutCodUncollected => 'Tiền mặt · Chưa thanh toán';

  @override
  String get checkoutPlacedNote => 'Trả tiền mặt khi nhận hàng.';

  @override
  String get checkoutPayLaterNote => 'Trả tiền mặt khi nhận hàng.';

  @override
  String get checkoutProcessingTitle => 'Đơn đang được xử lý';

  @override
  String get checkoutProcessingBody => 'Đang xác nhận, đừng đặt lại.';

  @override
  String get checkoutPendingRequest => 'Yêu cầu đang chờ';

  @override
  String get checkoutCartRef => 'Giỏ hàng';

  @override
  String get checkoutExpectedAmount => 'Số tiền dự kiến';

  @override
  String get checkoutOfflineTitle => 'Bạn đang ngoại tuyến';

  @override
  String get checkoutOfflineBody => 'Chưa gửi được đơn. Giỏ hàng vẫn giữ.';

  @override
  String get checkoutUnsentCart => 'Giỏ hàng chưa gửi';

  @override
  String get checkoutExpectedTotal => 'Tổng dự kiến';

  @override
  String get checkoutCodShort => 'Tiền mặt · Chưa trả';

  @override
  String get checkoutRepricedTitle => 'Giá đã thay đổi';

  @override
  String get checkoutRepricedBody => 'Xác nhận lại tổng tiền.';

  @override
  String get checkoutCompare => 'Đối chiếu thay đổi';

  @override
  String get checkoutPreviousTotal => 'Tổng giá trước';

  @override
  String get checkoutDeliveryIncrease => 'Phí giao tăng';

  @override
  String get checkoutNewTotal => 'Tổng giá mới';

  @override
  String get checkoutRepricedDraftNote => 'Đơn chỉ tạo khi bạn đồng ý giá mới.';

  @override
  String get checkoutRepricedPlacedNote =>
      'Đã đặt theo giá mới. Trả tiền mặt khi nhận.';

  @override
  String checkoutAcceptTotal(String amount) {
    return 'Đồng ý $amount';
  }

  @override
  String checkoutPlaceTotal(String amount) {
    return 'Đặt hàng · $amount';
  }

  @override
  String get inboxRideAssignedTitle => 'Đã có tài xế';

  @override
  String get inboxRideAssignedBody => 'Tài xế đang chuẩn bị đến điểm đón.';

  @override
  String get inboxRideDriverEnRouteTitle => 'Tài xế đang đến';

  @override
  String get inboxRideDriverEnRouteBody =>
      'Tài xế đang trên đường đến điểm đón.';

  @override
  String get inboxRideDriverArrivedTitle => 'Tài xế đã đến';

  @override
  String get inboxRideDriverArrivedBody =>
      'Hãy ra điểm đón và đọc mã cho tài xế.';

  @override
  String get inboxRideInTripTitle => 'Chuyến đi đã bắt đầu';

  @override
  String get inboxRideInTripBody => 'Chúc bạn có chuyến đi an toàn.';

  @override
  String get inboxRideCompletedTitle => 'Chuyến đi hoàn thành';

  @override
  String get inboxRideCompletedBody => 'Cảm ơn bạn đã đi cùng DealGo.';

  @override
  String get inboxRideCancelledTitle => 'Chuyến đi đã hủy';

  @override
  String get inboxRideCancelledBody => 'Chuyến đi đã được hủy.';

  @override
  String get inboxRideExpiredTitle => 'Yêu cầu hết hạn';

  @override
  String get inboxRideExpiredBody => 'Chưa có tài xế nhận.';

  @override
  String get inboxFoodPreparingTitle => 'Quán đang làm món';

  @override
  String get inboxFoodPreparingBody => 'Đơn của bạn đã được quán xác nhận.';

  @override
  String get inboxFoodReadyTitle => 'Món đã sẵn sàng';

  @override
  String get inboxFoodReadyBody => 'Đang tìm tài xế giao đơn của bạn.';

  @override
  String get inboxFoodAssignedTitle => 'Đã có tài xế nhận đơn';

  @override
  String get inboxFoodAssignedBody => 'Tài xế đang đến quán lấy món.';

  @override
  String get inboxFoodPickedUpTitle => 'Tài xế đã lấy món';

  @override
  String get inboxFoodPickedUpBody => 'Đơn đang trên đường giao đến bạn.';

  @override
  String get inboxFoodDeliveredTitle => 'Đã giao';

  @override
  String get inboxFoodDeliveredBody => 'Chúc bạn ngon miệng.';

  @override
  String get inboxFoodFailedTitle => 'Giao không thành công';

  @override
  String get inboxFoodFailedBody =>
      'Đơn chưa giao được. Liên hệ hỗ trợ nếu cần.';

  @override
  String get inboxFoodCancelledTitle => 'Đơn đã hủy';

  @override
  String get inboxFoodCancelledBody => 'Đơn đồ ăn đã được hủy.';

  @override
  String get inboxMarkAllRead => 'Đọc hết';

  @override
  String get inboxSectionToday => 'Hôm nay';

  @override
  String get inboxSectionYesterday => 'Hôm qua';

  @override
  String get inboxSectionEarlier => 'Trước đó';

  @override
  String get inboxFilterPromos => 'Ưu đãi';

  @override
  String get inboxUnread => 'Chưa đọc';

  @override
  String inboxUnreadCount(int count) {
    return '$count thông báo chưa đọc';
  }

  @override
  String get inboxLoading => 'Đang tải thông báo';

  @override
  String get inboxJustNow => 'Vừa xong';

  @override
  String inboxMinutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String inboxHoursAgo(int count) {
    return '$count giờ trước';
  }

  @override
  String get addrBookTitle => 'Địa chỉ đã lưu';

  @override
  String get addrBookAdd => 'Thêm địa chỉ';

  @override
  String get addrBookAddTitle => 'Thêm địa chỉ';

  @override
  String get addrBookEditTitle => 'Sửa địa chỉ';

  @override
  String get addrBookFull =>
      'Bạn đã lưu tối đa 20 địa chỉ. Xóa bớt để thêm mới.';

  @override
  String get addrBookLoading => 'Đang tải địa chỉ';

  @override
  String get addrBookEmptyTitle => 'Chưa có địa chỉ nào';

  @override
  String get addrBookEmptyBody => 'Lưu địa chỉ để đặt nhanh.';

  @override
  String get addrBookDefault => 'Mặc định';

  @override
  String get addrBookNoPin => 'Chưa ghim vị trí trên bản đồ';

  @override
  String get addrBookPinned => 'Đã ghim vị trí hiện tại';

  @override
  String get addrBookPinHere => 'Ghim vị trí hiện tại';

  @override
  String get addrBookLocating => 'Đang lấy vị trí…';

  @override
  String get addrBookPinFailed =>
      'Không lấy được vị trí. Hãy bật quyền vị trí rồi thử lại.';

  @override
  String get addrBookMore => 'Tùy chọn';

  @override
  String get addrBookEdit => 'Sửa';

  @override
  String get addrBookMakeDefault => 'Đặt làm mặc định';

  @override
  String get addrBookDelete => 'Xóa';

  @override
  String get addrBookCancel => 'Hủy';

  @override
  String get addrBookDeleteTitle => 'Xóa địa chỉ?';

  @override
  String get addrBookDeleted => 'Đã xóa địa chỉ';

  @override
  String get addrBookSaved => 'Đã lưu địa chỉ';

  @override
  String get addrBookKindHome => 'Nhà';

  @override
  String get addrBookKindWork => 'Công ty';

  @override
  String get addrBookKindOther => 'Khác';

  @override
  String get addrBookLabel => 'Tên gợi nhớ';

  @override
  String get addrBookLabelRequired => 'Nhập tên gợi nhớ';

  @override
  String get addrBookLine => 'Địa chỉ';

  @override
  String get addrBookLineHint => 'Số nhà, đường, phường/quận';

  @override
  String get addrBookLineRequired => 'Nhập địa chỉ (ít nhất 3 ký tự)';

  @override
  String get addrBookNote => 'Ghi chú cho tài xế';

  @override
  String get addrBookSave => 'Lưu địa chỉ';

  @override
  String get addrBookErrKindTaken =>
      'Bạn đã lưu địa chỉ loại này. Chọn \"Khác\" hoặc sửa địa chỉ cũ.';

  @override
  String get addrBookErrNotFound =>
      'Địa chỉ không còn tồn tại. Đã tải lại danh sách.';

  @override
  String get addrBookErrOffline => 'Không có kết nối mạng. Thử lại sau.';

  @override
  String get addrBookErrGeneric => 'Chưa lưu được. Thử lại sau.';

  @override
  String addrBookDeleteBody(String label) {
    return 'Xóa \"$label\"?';
  }

  @override
  String get rateRidePrompt => 'Chuyến đi thế nào?';

  @override
  String get rateOrderPrompt => 'Đơn hàng thế nào?';

  @override
  String get rateWhy => 'Đánh giá giúp DealGo giữ chất lượng tài xế và quán.';

  @override
  String get rateRideAction => 'Đánh giá chuyến đi';

  @override
  String get rateOrderAction => 'Đánh giá đơn hàng';

  @override
  String get rateRideTitle => 'Đánh giá chuyến đi';

  @override
  String get rateOrderTitle => 'Đánh giá đơn hàng';

  @override
  String get rateDriverLabel => 'Tài xế';

  @override
  String get rateStoreLabel => 'Quán';

  @override
  String get rateTagsLabel => 'Điều bạn thấy nổi bật';

  @override
  String get rateCommentLabel => 'Góp ý';

  @override
  String get rateCommentHint => 'Chia sẻ trải nghiệm của bạn';

  @override
  String get rateSubmit => 'Gửi đánh giá';

  @override
  String get rateThanks => 'Cảm ơn bạn đã đánh giá!';

  @override
  String get rateErrAlready => 'Bạn đã đánh giá trước đó.';

  @override
  String get rateErrNotAllowed =>
      'Chỉ đánh giá được khi chuyến/đơn đã hoàn tất.';

  @override
  String get rateErrOffline => 'Không có kết nối mạng. Thử lại sau.';

  @override
  String get rateErrGeneric => 'Chưa gửi được đánh giá. Thử lại sau.';

  @override
  String get rateTagOnTime => 'Đúng giờ';

  @override
  String get rateTagFriendly => 'Thân thiện';

  @override
  String get rateTagSafeDriving => 'Lái xe an toàn';

  @override
  String get rateTagCleanVehicle => 'Xe sạch sẽ';

  @override
  String get rateTagTastyFood => 'Món ngon';

  @override
  String get rateTagWellPacked => 'Đóng gói cẩn thận';

  @override
  String get rateTagLate => 'Đến trễ';

  @override
  String get rateTagRude => 'Thái độ chưa tốt';

  @override
  String get rateTagUnsafeDriving => 'Lái xe ẩu';

  @override
  String get rateTagWrongItems => 'Sai món';

  @override
  String get rateTagColdFood => 'Món bị nguội';

  @override
  String rateDone(int stars) {
    return 'Bạn đã đánh giá $stars sao. Cảm ơn bạn!';
  }

  @override
  String rateStarTooltip(int star) {
    return '$star sao';
  }

  @override
  String get drvHistTitle => 'Thu nhập & lịch sử';

  @override
  String get drvHistToday => 'Hôm nay';

  @override
  String get drvHistWeek => '7 ngày';

  @override
  String get drvHistEarnedToday => 'Thu nhập hôm nay';

  @override
  String get drvHistEarnedWeek => 'Thu nhập 7 ngày';

  @override
  String get drvHistRides => 'Chở khách';

  @override
  String get drvHistFood => 'Giao đồ ăn';

  @override
  String get drvHistRating => 'Đánh giá';

  @override
  String get drvHistNoRating => 'Chưa có đánh giá';

  @override
  String get drvHistRecent => 'Lịch sử công việc';

  @override
  String get drvHistFilterAll => 'Tất cả';

  @override
  String get drvHistEmptyTitle => 'Chưa có công việc nào';

  @override
  String get drvHistEmptyBody => 'Chưa có công việc.';

  @override
  String get drvHistLoadMore => 'Xem thêm';

  @override
  String get drvHistLoadMoreFailed => 'Không tải thêm được. Thử lại';

  @override
  String get drvHistOutcomeCancelled => 'Đã huỷ';

  @override
  String get drvHistOutcomeFailed => 'Giao thất bại';

  @override
  String get drvHistLoading => 'Đang tải lịch sử';

  @override
  String drvHistJobs(int count) {
    return '$count công việc';
  }

  @override
  String drvHistCancelled(int count) {
    return '$count việc bị huỷ';
  }

  @override
  String drvHistStars(int stars) {
    return '$stars/5 sao';
  }

  @override
  String drvHistRatingCount(int count) {
    return '$count lượt đánh giá';
  }

  @override
  String drvHistGrossLine(String gross, String fee) {
    return 'Tổng cước $gross · Hoa hồng DealGo −$fee';
  }

  @override
  String drvHistItemFee(String percent, String fee) {
    return 'Hoa hồng $percent% −$fee';
  }

  @override
  String drvHistItemFeeFood(String percent, String fee) {
    return 'Hoa hồng $percent% phí giao −$fee';
  }

  @override
  String rateDeadline(String date) {
    return 'Bạn có thể đánh giá đến hết $date.';
  }

  @override
  String get rateErrExpired => 'Đã quá hạn đánh giá cho chuyến/đơn này.';

  @override
  String get placePickerPickupTitle => 'Chọn điểm đón';

  @override
  String get placePickerDropoffTitle => 'Bạn muốn đi đâu?';

  @override
  String get placePickerDeliveryTitle => 'Địa chỉ giao hàng';

  @override
  String get placePickerHint => 'Tìm địa điểm, địa chỉ';

  @override
  String get placeCurrentLocation => 'Vị trí hiện tại của bạn';

  @override
  String get placeCurrentLocationHint => 'Dùng GPS của điện thoại';

  @override
  String get placeLocating => 'Đang lấy vị trí…';

  @override
  String get placeLocationDenied =>
      'Chưa có quyền vị trí. Bật trong Cài đặt hoặc chọn địa chỉ khác.';

  @override
  String get placeLocationFailed => 'Không lấy được vị trí. Hãy thử lại.';

  @override
  String get placeCurrentNamed => 'Vị trí hiện tại';

  @override
  String get placeSavedTitle => 'Địa chỉ đã lưu';

  @override
  String get placeSavedManage => 'Quản lý';

  @override
  String get placeResultsTitle => 'Kết quả tìm kiếm';

  @override
  String get placeSearchEmptyTitle => 'Không tìm thấy';

  @override
  String get placeSearchEmptyBody => 'Thử từ khóa khác.';

  @override
  String get placeSearchUnavailable =>
      'Tìm kiếm địa điểm đang tạm ngưng. Hãy dùng vị trí hiện tại hoặc địa chỉ đã lưu.';

  @override
  String get placeSearchError => 'Không tải được kết quả tìm kiếm.';

  @override
  String get placeNothingYet =>
      'Tìm địa điểm hoặc dùng vị trí hiện tại để bắt đầu.';

  @override
  String get placeHistoryTitle => 'Gần đây';

  @override
  String get placeHistoryClear => 'Xóa hết';

  @override
  String get placeHistoryDelete => 'Xóa khỏi lịch sử';

  @override
  String get placeHistoryClearTitle => 'Xóa lịch sử tìm kiếm?';

  @override
  String get placeHistoryClearBody => 'Xóa lịch sử địa điểm?';

  @override
  String get placeHistoryClearConfirm => 'Xóa lịch sử';

  @override
  String get placeApproximate => 'Số nhà ước tính · kiểm tra ghim';

  @override
  String placeDistanceKm(String km) {
    return '$km km';
  }

  @override
  String get rideBookTitle => 'Đặt xe';

  @override
  String get mapRecenter => 'Về vị trí của tôi';

  @override
  String get rideWhereTo => 'Bạn muốn đi đâu?';

  @override
  String get ridePickupPlaceholder => 'Chọn điểm đón';

  @override
  String get rideDropoffPlaceholder => 'Chọn điểm đến';

  @override
  String get rideSuggestionsTitle => 'Gợi ý cho bạn';

  @override
  String get rideOpenPendingOffers => 'Xem đề xuất đang chờ';

  @override
  String get rideSamePlaces => 'Điểm đón và điểm đến đang trùng nhau.';

  @override
  String rideEtaMinutes(int minutes) {
    return '$minutes phút';
  }

  @override
  String rideDistanceKm(String km) {
    return '$km km';
  }

  @override
  String get rideQuoteLoading => 'Đang tính giá tham khảo…';

  @override
  String get rideQuoteError =>
      'Chưa tính được giá. Kiểm tra kết nối và thử lại.';

  @override
  String rideFareRange(String min, String max) {
    return 'Mức cho phép từ $min đến $max';
  }

  @override
  String get rideFareInvalid => 'Nhập số tiền hợp lệ.';

  @override
  String get rideFareAllowedRange => 'Khoảng giá cho phép';

  @override
  String get rideVehicleBikeTitle => 'Xe máy';

  @override
  String get rideVehicleCar4Title => 'Xe 4 chỗ';

  @override
  String get rideVehicleCar7Title => 'Xe 7 chỗ';

  @override
  String rideVehicleSeats(int count) {
    return '$count chỗ';
  }

  @override
  String get rideFareOpening => 'Giá mở cửa';

  @override
  String get rideFarePerKm => 'Theo km';

  @override
  String rideFareTime(int minutes) {
    return 'Theo thời gian ($minutes phút)';
  }

  @override
  String get rideVehicleBikeSubtitle => 'Tiện lợi · 1 khách';

  @override
  String rideVehicleFrom(String amount) {
    return 'Từ $amount';
  }

  @override
  String get rideVehicleTitle => 'Chọn loại xe';

  @override
  String get rideVehicleRouteTitle => 'Lộ trình của bạn';

  @override
  String get rideVehicleContinueToOffer => 'Đề xuất giá chuyến';

  @override
  String get rideVehicleClassesUnavailable =>
      'Hiện chưa có loại xe khả dụng. Thử lại sau hoặc kéo để làm mới.';

  @override
  String get homeQuickBookTitle => 'Đặt xe nhanh';

  @override
  String get homeQuickBookPickup => '123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng';

  @override
  String get homeQuickBookVehicle => 'Xe máy & ô tô';

  @override
  String get homeQuickBookEstimate => 'Ước tính';

  @override
  String get homeQuickBookEtaPrice => 'Khi chọn điểm';

  @override
  String get homeQuickBookEtaTime => 'Thời gian ~ 12 phút';

  @override
  String get foodCartTitle => 'Giỏ hàng';

  @override
  String get foodCartEmpty => 'Giỏ hàng trống';

  @override
  String get foodCartEstimate => 'Dự tính thanh toán';

  @override
  String get foodCartContinue => 'Tiếp tục thanh toán';

  @override
  String get foodDropoffTitle => 'Địa chỉ nhận';

  @override
  String get foodDropoffChoose => 'Chọn địa chỉ giao hàng';

  @override
  String get foodDropoffChange => 'Đổi';

  @override
  String get foodFareNeedAddress => 'Chọn địa chỉ để tính';

  @override
  String get foodFareQuoting => 'Đang tính…';

  @override
  String get foodFareQuoteError =>
      'Chưa tính được phí giao. Kiểm tra kết nối và thử lại.';

  @override
  String get foodOrderNoteLabel => 'Ghi chú cho quán / tài xế';

  @override
  String get foodOrderNoteHint => 'Ví dụ: ít cay, không hành, giao trước cửa…';

  @override
  String get foodLineNoteLabel => 'Ghi chú cho món này';

  @override
  String get foodLineNoteHint => 'Ví dụ: ít đá, không đường…';

  @override
  String get foodUtensilsLabel => 'Dụng cụ ăn uống';

  @override
  String get foodUtensilsYes => 'Có';

  @override
  String get foodUtensilsNo => 'Không';

  @override
  String get foodCartUpsellTitle => 'Mua thêm cho đủ bữa';

  @override
  String get foodNoteSaved => 'Đã lưu ghi chú';

  @override
  String get foodNoteCleared => 'Đã xóa ghi chú';

  @override
  String get foodCheckoutExtrasTitle => 'Ghi chú & dụng cụ';

  @override
  String get foodCheckoutNoteEmpty => 'Chưa có ghi chú cho quán hoặc tài xế';

  @override
  String get foodCheckoutNoteAdd => 'Thêm';

  @override
  String get foodCheckoutNoteEdit => 'Sửa';

  @override
  String get foodFareFixedLabel => 'Phí giao cố định';

  @override
  String get foodFareFixedHint =>
      'Mức phí này do DealGo quy định cho quãng đường, không thương lượng.';

  @override
  String get foodFareNegotiationHint =>
      'Tài xế có thể nhận đúng mức này hoặc trả giá cao hơn.';

  @override
  String get foodLineNoteClear => 'Xoá ghi chú';

  @override
  String get foodCartLineRemove => 'Xoá món';

  @override
  String get driverOtpLocked =>
      'Nhập sai quá nhiều lần. Liên hệ hỗ trợ để tiếp tục chuyến.';

  @override
  String get ridePickupCodeUnavailable =>
      'Mã đón sẽ hiện khi tài xế đã nhận chuyến.';

  @override
  String driverCardRating(String rating, int count) {
    return '$rating · $count đánh giá';
  }

  @override
  String get driverCardNew => 'Mới';

  @override
  String get driverDetailTitle => 'Tài xế';

  @override
  String get driverDetailOpen => 'Xem chi tiết tài xế';

  @override
  String get driverDetailVehicle => 'Xe';

  @override
  String get driverDetailPlate => 'Biển số';

  @override
  String get driverDetailClass => 'Loại xe';

  @override
  String get driverAvatarOpen => 'Xem ảnh đại diện';

  @override
  String get driverAvatarClose => 'Đóng';

  @override
  String driverCardTrips(String count) {
    return '$count chuyến';
  }

  @override
  String get actionReload => 'Tải lại';

  @override
  String get rideAgreedFare => 'Giá đã chốt';

  @override
  String get rideVehicleLabel => 'Phương tiện';

  @override
  String get rideViewReceipt => 'Xem biên nhận';

  @override
  String get rideOfflineTitle => 'Tạm mất kết nối';

  @override
  String get rideOfflineBody => 'Đang hiện dữ liệu cũ.';

  @override
  String get rideTripSummary => 'Thông tin chuyến';

  @override
  String rideSelectOfferAmount(String amount) {
    return 'Chọn giá $amount';
  }

  @override
  String get rideSelectOfferPrompt => 'Chọn báo giá';

  @override
  String get rideReceiptTitle => 'Biên nhận chuyến đi';

  @override
  String get rideReceiptHelp => 'Cần hỗ trợ';

  @override
  String get rideReceiptDone => 'Chuyến đi hoàn tất!';

  @override
  String get rideReceiptThanks => 'Cảm ơn bạn đã đồng hành cùng DealGo';

  @override
  String get rideReceiptNoFare => 'Máy chủ chưa trả giá đã chốt.';

  @override
  String get rideReceiptCash => 'Thanh toán tiền mặt cho tài xế';

  @override
  String get rideReceiptFinishedAt => 'Thời điểm';

  @override
  String get rideReceiptPayment => 'Chi tiết thanh toán';

  @override
  String get rideReceiptOffline =>
      'Chưa tải được biên nhận. Giá đã chốt chưa được hiển thị.';

  @override
  String rideReceiptRef(String ref) {
    return 'Biên nhận $ref';
  }

  @override
  String get foodTrackingTitle => 'Theo dõi đơn đồ ăn';

  @override
  String get paymentHistoryTotal => 'Tổng đã thanh toán';

  @override
  String get paymentHistoryFilterRides => 'Chuyến xe';

  @override
  String get paymentHistoryFilterFood => 'Đồ ăn';

  @override
  String get paymentHistoryCash => 'Tiền mặt';

  @override
  String get paymentHistoryEmpty =>
      'Chưa có giao dịch nào. Chuyến xe hoàn tất và đơn đã giao sẽ hiện ở đây.';

  @override
  String paymentHistoryCount(int count) {
    return '$count giao dịch';
  }

  @override
  String get driverStatTodayJobs => 'Chuyến hôm nay';

  @override
  String get driverStatTodayEarnings => 'Thu nhập hôm nay';

  @override
  String get driverStatRating => 'Đánh giá trung bình';

  @override
  String get driverStatWeekJobs => 'Chuyến 7 ngày qua';

  @override
  String get helpTitle => 'Trung tâm hỗ trợ';

  @override
  String get helpSearchHint => 'Tìm câu trả lời';

  @override
  String get helpTopicsTitle => 'Chủ đề phổ biến';

  @override
  String get helpTopicRide => 'Chuyến xe';

  @override
  String get helpTopicFood => 'Đồ ăn';

  @override
  String get helpTopicPayment => 'Thanh toán';

  @override
  String get helpTopicAccount => 'Tài khoản';

  @override
  String get helpTopicSelected => 'Chủ đề cho yêu cầu hỗ trợ';

  @override
  String get helpFaqTitle => 'Câu hỏi thường gặp';

  @override
  String get helpSeeAll => 'Xem tất cả';

  @override
  String get helpStillNeedTitle => 'Bạn vẫn cần hỗ trợ?';

  @override
  String get helpStillNeedBody => 'Xem yêu cầu đã gửi.';

  @override
  String get helpMyTickets => 'Yêu cầu của bạn';

  @override
  String get helpCreateTicket => 'Gửi yêu cầu hỗ trợ';

  @override
  String get supportListTitle => 'Yêu cầu hỗ trợ';

  @override
  String get supportListHeading => 'Yêu cầu của bạn';

  @override
  String get supportListEmptyTitle => 'Chưa có yêu cầu nào';

  @override
  String get supportListEmptyBody => 'Chưa có yêu cầu.';

  @override
  String get supportListLoadFailed =>
      'Không tải được danh sách yêu cầu. Kiểm tra kết nối và thử lại.';

  @override
  String get supportNewTicket => 'Tạo yêu cầu mới';

  @override
  String get supportStatusOpen => 'Đã tiếp nhận';

  @override
  String get supportStatusInProgress => 'Đang xử lý';

  @override
  String get supportStatusReplied => 'Đã phản hồi';

  @override
  String get supportStatusResolved => 'Đã giải quyết';

  @override
  String get supportStatusClosed => 'Đã đóng';

  @override
  String get supportCategoryRide => 'Chuyến đi';

  @override
  String get supportCategoryFood => 'Đồ ăn';

  @override
  String get supportCategoryPayment => 'Thanh toán';

  @override
  String get supportCategoryAccount => 'Tài khoản';

  @override
  String get supportCategorySafety => 'An toàn';

  @override
  String get supportCategoryOther => 'Khác';

  @override
  String get supportPriorityLow => 'Thấp';

  @override
  String get supportPriorityNormal => 'Bình thường';

  @override
  String get supportPriorityHigh => 'Cao';

  @override
  String get supportPriorityUrgent => 'Khẩn cấp';

  @override
  String get supportCreateTitle => 'Tạo yêu cầu hỗ trợ';

  @override
  String get supportCreateHeading => 'Bạn cần trợ giúp?';

  @override
  String get supportFieldCategory => 'Loại vấn đề';

  @override
  String get supportFieldRelated => 'Chuyến đi / đơn hàng liên quan';

  @override
  String get supportRelatedNone => 'Không liên quan đến chuyến/đơn cụ thể';

  @override
  String get supportRelatedPickTitle => 'Chọn chuyến / đơn';

  @override
  String get supportRelatedEmpty => 'Chưa có chuyến đi hay đơn hàng hoàn tất.';

  @override
  String get supportFieldSubject => 'Tiêu đề yêu cầu';

  @override
  String get supportFieldDescription => 'Mô tả chi tiết';

  @override
  String get supportPrivacyNote => 'Không gửi mật khẩu, OTP hoặc thẻ.';

  @override
  String get supportSubmit => 'Gửi yêu cầu hỗ trợ';

  @override
  String get supportSubjectTooShort => 'Tiêu đề cần ít nhất 3 ký tự.';

  @override
  String get supportDescriptionTooShort => 'Mô tả cần ít nhất 10 ký tự.';

  @override
  String get supportLimitReached =>
      'Bạn đang có nhiều yêu cầu chưa xử lý xong. Hãy bổ sung vào yêu cầu cũ hoặc chờ phản hồi.';

  @override
  String get supportTextTooLong => 'Nội dung quá dài. Vui lòng rút gọn.';

  @override
  String get supportSendFailed =>
      'Không gửi được. Kiểm tra kết nối và thử lại.';

  @override
  String get supportCreated => 'Đã gửi yêu cầu hỗ trợ.';

  @override
  String get supportDetailTitle => 'Chi tiết yêu cầu';

  @override
  String get supportInfoCategory => 'Loại vấn đề';

  @override
  String get supportInfoRelated => 'Liên quan';

  @override
  String get supportInfoPriority => 'Ưu tiên';

  @override
  String get supportProgressTitle => 'Tiến độ xử lý';

  @override
  String get supportProgressReceived => 'Đã tiếp nhận';

  @override
  String get supportProgressInProgress => 'Đang xử lý';

  @override
  String get supportProgressInProgressBody => 'Đang xử lý.';

  @override
  String get supportProgressResolved => 'Đã giải quyết';

  @override
  String get supportProgressClosed => 'Đã đóng';

  @override
  String get supportThreadTitle => 'Trao đổi hỗ trợ';

  @override
  String get supportStaffName => 'Hỗ trợ DealGo';

  @override
  String get supportReplyHint => 'Nhập phản hồi của bạn...';

  @override
  String get supportReplySend => 'Gửi phản hồi';

  @override
  String get supportClosedNote => 'Yêu cầu đã đóng.';

  @override
  String get supportResolvedNote => 'Đã giải quyết. Phản hồi để mở lại.';

  @override
  String get supportDetailLoadFailed => 'Không tải được yêu cầu này.';

  @override
  String get supportRelatedRide => 'Chuyến';

  @override
  String get supportRelatedFood => 'Đơn';

  @override
  String get inboxSupportReplyTitle => 'Hỗ trợ đã phản hồi';

  @override
  String get inboxSupportResolvedTitle => 'Yêu cầu đã giải quyết';

  @override
  String supportFilterAll(int count) {
    return 'Tất cả · $count';
  }

  @override
  String supportFilterActive(int count) {
    return 'Đang xử lý · $count';
  }

  @override
  String supportFilterDone(int count) {
    return 'Đã xong · $count';
  }

  @override
  String supportCodeCreated(String code, String time) {
    return 'Mã yêu cầu $code · Tạo lúc $time';
  }

  @override
  String supportProgressReceivedAt(String time) {
    return 'Yêu cầu được ghi nhận lúc $time';
  }

  @override
  String supportProgressAt(String time) {
    return 'Lúc $time';
  }

  @override
  String get helpBannerBadge => 'Hỗ trợ DealGo';

  @override
  String get foodGroupNear => 'Gần tôi';

  @override
  String get storeRatingNew => 'Quán mới';

  @override
  String storeRatingFew(int count) {
    return '$count đánh giá';
  }

  @override
  String storeRatingValue(String rating, int count) {
    return '$rating ($count)';
  }

  @override
  String storeDistance(String km) {
    return '$km km';
  }

  @override
  String get foodDiscoverySearchHint => 'Tìm quán, món ăn, đồ uống';

  @override
  String get foodFeedEndOfList => 'Bạn đã xem hết quán quanh đây';

  @override
  String get foodStoreBestsellers => 'Món bán chạy';

  @override
  String foodStorePrepChip(int minutes) {
    return 'Khoảng $minutes phút';
  }

  @override
  String get foodSearchGroups => 'Danh mục';

  @override
  String get foodSeeAll => 'Xem tất cả →';

  @override
  String get foodEmptyNoStoresInCategory => 'Chưa có quán trong danh mục này';

  @override
  String get foodEmptyOutOfArea => 'DealGo chưa giao tới khu vực này';

  @override
  String get foodStoreTitle => 'Chi tiết quán';

  @override
  String get foodStoreOpen => 'Đang mở';

  @override
  String get foodStorePaused => 'Tạm ngưng';

  @override
  String get foodStoreTabMenu => 'Thực đơn';

  @override
  String get foodStoreTabReviews => 'Đánh giá';

  @override
  String get foodStoreTabInfo => 'Thông tin';

  @override
  String get foodStoreNoItems => 'Cửa hàng chưa có món.';

  @override
  String get foodItemSoldOut => 'Hết món';

  @override
  String get foodAddToCart => 'Thêm vào giỏ';

  @override
  String get foodDecreaseQuantity => 'Giảm số lượng';

  @override
  String get foodViewCart => 'Xem giỏ hàng';

  @override
  String get foodStoreReviewsUnavailable => 'Chưa tải được đánh giá.';

  @override
  String get foodStoreReviewsNone => 'Quán chưa có đánh giá nào.';

  @override
  String get foodStoreInfoName => 'Tên quán';

  @override
  String get foodStoreInfoCategory => 'Loại hình';

  @override
  String get foodStoreInfoAddress => 'Địa chỉ';

  @override
  String get foodStoreInfoAddressMissing => 'Quán chưa cập nhật địa chỉ';

  @override
  String get foodStoreInfoPayment => 'Thanh toán';

  @override
  String get foodStoreInfoPaymentCod => 'Tiền mặt khi nhận hàng';

  @override
  String foodStoreMenuCount(int count) {
    return 'Thực đơn · $count món';
  }

  @override
  String foodStoreSectionCount(int count) {
    return '$count món';
  }

  @override
  String foodStoreReviewsHidden(int count) {
    return '$count đánh giá — điểm sẽ hiện khi quán có thêm đánh giá';
  }

  @override
  String foodStoreReviewsSummary(String average, int count) {
    return '$average ★ · $count đánh giá';
  }

  @override
  String get homeVoucherBadge => 'DealGo Voucher';

  @override
  String get homeVoucherTitle => 'Ưu đãi hôm nay';

  @override
  String get homeRecentEmpty => 'Chưa có chuyến đi hay đơn hàng nào.';

  @override
  String get homeShopTitle => 'Mua hàng nổi bật';

  @override
  String get homeRecentTitle => 'Gần đây';

  @override
  String get homeCatFood => 'Đồ ăn';

  @override
  String get actionSave => 'Lưu';

  @override
  String get rideSafetyContactName => 'Tên';

  @override
  String get rideSafetyContactPhone => 'Số điện thoại';

  @override
  String get rideSafetyRemoveContact => 'Xóa liên hệ';

  @override
  String get rideSafetyContactsEmpty =>
      'Chưa có liên hệ khẩn cấp. Thêm tối đa 3 người thân.';

  @override
  String get driverNotificationsTitle => 'Thông báo tài xế';

  @override
  String get driverOpenHistory => 'Xem lịch sử chuyến';

  @override
  String get driverCompletedNotFound => 'Chưa thấy việc này trong lịch sử';

  @override
  String get driverCompletedNotFoundHint => 'Thử lại sau ít phút.';

  @override
  String get driverCompletedFeeLabel => 'Hoa hồng DealGo';

  @override
  String get driverCompletedNetLabel => 'Thực nhận';

  @override
  String get merchantOrderTitle => 'Chi tiết đơn';

  @override
  String get merchantOrderNotFound => 'Không tìm thấy đơn';

  @override
  String get merchantOrderTitleNew => 'Chi tiết đơn mới';

  @override
  String get merchantOrderTitlePreparing => 'Đơn đang chuẩn bị';

  @override
  String get merchantOrderTitleReady => 'Bàn giao cho tài xế';

  @override
  String get merchantMarkReady => 'Đã chuẩn bị xong';

  @override
  String get merchantHandoffAwaitDriver =>
      'Tài xế chưa xác nhận lấy hàng. Đưa mã bàn giao cho tài xế để hoàn tất.';

  @override
  String get merchantMarkHandedOver => 'Đã bàn giao hàng';

  @override
  String get merchantOrderHeadNew => 'Đơn chờ xác nhận';

  @override
  String get merchantOrderHeadPreparing => 'Đơn đã nhận';

  @override
  String get merchantOrderHeadReady => 'Đơn đã sẵn sàng';

  @override
  String get merchantOrderCustomer => 'Khách hàng DealGo';

  @override
  String get merchantOrderNewChip => 'Mới · Chờ quán xác nhận';

  @override
  String get merchantItemsToPrepare => 'Món cần chuẩn bị';

  @override
  String get merchantReadyHint => 'Bấm khi đã đủ món.';

  @override
  String get merchantDriverTitle => 'Tài xế nhận món';

  @override
  String get merchantDriverWaiting => 'Đang chờ tài xế DealGo nhận đơn.';

  @override
  String get merchantHandoffTitle => 'Đối chiếu khi giao';

  @override
  String get merchantOrderRefLabel => 'Mã đơn';

  @override
  String get merchantLineCountLabel => 'Số món';

  @override
  String get merchantHandoffCodLabel => 'Tiền món (COD)';

  @override
  String get merchantHandoffNote => 'Đối chiếu mã đơn với tài xế.';

  @override
  String get merchantHandoffDoneNote => 'Chờ tài xế xác nhận.';

  @override
  String get merchantFoodValueLabel => 'Tiền món';

  @override
  String get merchantDeliveryFeeLabel => 'Phí giao';

  @override
  String get merchantTotalLabel => 'Tổng';

  @override
  String get merchantConflictTitle => 'Xác nhận đơn';

  @override
  String get merchantBackToOrders => 'Về danh sách đơn';

  @override
  String get merchantConflictRefresh => 'Xem trạng thái mới';

  @override
  String get merchantConflictHeadline => 'Đơn đã được xử lý';

  @override
  String get merchantConflictBody => 'Đơn đã đổi trạng thái.';

  @override
  String get merchantConflictOrder => 'Đơn hàng';

  @override
  String orderRef(String ref) {
    return 'Đơn $ref';
  }

  @override
  String rideRef(String ref) {
    return 'Chuyến $ref';
  }

  @override
  String driverCompletedFeePercentLabel(String percent) {
    return 'Hoa hồng DealGo ($percent%)';
  }

  @override
  String driverCompletedFoodFeePercentLabel(String percent) {
    return 'Hoa hồng phí giao ($percent%)';
  }

  @override
  String merchantOrderPlacedAt(String time) {
    return 'Đặt lúc $time';
  }

  @override
  String merchantLineQty(int qty, String price) {
    return 'x$qty · $price / món';
  }

  @override
  String get partnerModeChip => 'Chế độ đối tác';

  @override
  String get partnerContinue => 'Tiếp tục';

  @override
  String partnerStepOf(int current, int total) {
    return 'Bước $current/$total';
  }

  @override
  String get partnerDocTake => 'Chụp ảnh';

  @override
  String get partnerDocPick => 'Thư viện ảnh';

  @override
  String get partnerDocRetake => 'Chụp lại';

  @override
  String get partnerDocRemove => 'Bỏ ảnh';

  @override
  String get partnerDocStored => 'Đã lưu trên hồ sơ';

  @override
  String get partnerDocPicked => 'Ảnh mới — sẽ gửi khi nộp hồ sơ';

  @override
  String get partnerDocMissing => 'Chưa có ảnh';

  @override
  String get partnerDocFlagged => 'Cần chụp lại theo yêu cầu';

  @override
  String get partnerDocOptional => 'Không bắt buộc';

  @override
  String get partnerDocHint => 'Rõ nét, đủ 4 góc. JPG/PNG ≤ 4 MB.';

  @override
  String get partnerDocPickFailed => 'Không mở được máy ảnh hoặc thư viện ảnh.';

  @override
  String get partnerKindIdFront => 'CCCD — mặt trước';

  @override
  String get partnerKindIdBack => 'CCCD — mặt sau';

  @override
  String get partnerKindSelfie => 'Ảnh chân dung';

  @override
  String get partnerKindLicense => 'Giấy phép lái xe';

  @override
  String get partnerKindVehicleReg => 'Giấy đăng ký xe';

  @override
  String get partnerKindVehicleInsurance => 'Bảo hiểm xe (ảnh)';

  @override
  String get partnerKindBusinessLicense => 'Giấy phép kinh doanh';

  @override
  String get partnerKindFoodSafetyCert => 'Giấy chứng nhận an toàn thực phẩm';

  @override
  String kycLicenseClassMismatch(String licenseClass) {
    return 'Hạng $licenseClass không được lái loại xe này. Quay lại chọn đúng hạng in trên giấy phép.';
  }

  @override
  String get partnerKindRepIdFront => 'CCCD người đại diện — mặt trước';

  @override
  String get partnerKindRepIdBack => 'CCCD người đại diện — mặt sau';

  @override
  String get partnerKindStorefront => 'Ảnh mặt tiền cửa hàng';

  @override
  String get partnerSectionPersonal => 'Thông tin cá nhân';

  @override
  String get partnerSectionIdCard => 'Ảnh CCCD';

  @override
  String get partnerSectionSelfie => 'Ảnh chân dung';

  @override
  String get partnerSectionLicense => 'Giấy phép lái xe';

  @override
  String get partnerSectionVehicle => 'Phương tiện / đăng ký xe';

  @override
  String get partnerSectionBank => 'Tài khoản nhận tiền';

  @override
  String get partnerSectionShopInfo => 'Thông tin cửa hàng';

  @override
  String get partnerSectionRepresentative => 'Người đại diện';

  @override
  String get partnerSectionBusinessDocs => 'Giấy tờ kinh doanh';

  @override
  String get partnerSectionStorefront => 'Ảnh mặt tiền';

  @override
  String get partnerSectionOther => 'Khác';

  @override
  String get partnerFix => 'Sửa mục này';

  @override
  String get partnerStartFix => 'Bắt đầu chỉnh sửa';

  @override
  String get partnerReasonLabel => 'Lý do từ DealGo';

  @override
  String get partnerIssuesTitle => 'Mục cần bổ sung';

  @override
  String get partnerNoIssues =>
      'DealGo chưa ghi mục cụ thể. Vui lòng kiểm tra lại toàn bộ hồ sơ.';

  @override
  String get partnerTimelineSubmitted => 'Đã gửi hồ sơ';

  @override
  String get partnerTimelineReview => 'Xét duyệt giấy tờ';

  @override
  String get partnerTimelineReviewQuick => 'Admin duyệt hồ sơ';

  @override
  String get kycStatusTitleQuick => 'Trạng thái đăng ký tài xế';

  @override
  String get partnerTimelineReviewing => 'Đang đối chiếu';

  @override
  String get partnerTimelineReviewed => 'Đã đối chiếu';

  @override
  String get partnerTimelineDone => 'Hoàn thành';

  @override
  String get partnerTimelineInProgress => 'Đang xử lý';

  @override
  String get partnerTimelineWaiting => 'Chờ';

  @override
  String get partnerErrorSession =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get partnerErrorNetwork => 'Không kết nối được DealGo. Thử lại sau.';

  @override
  String get partnerErrorMissingDocs => 'Hồ sơ còn thiếu giấy tờ bắt buộc.';

  @override
  String get partnerErrorTooLarge =>
      'Ảnh quá lớn. Chụp lại với độ phân giải thấp hơn.';

  @override
  String get partnerErrorType => 'Định dạng ảnh không được hỗ trợ.';

  @override
  String get partnerErrorStorage =>
      'Máy chủ tạm thời chưa nhận tệp. Thử lại sau.';

  @override
  String get partnerErrorGeneric => 'Không gửi được hồ sơ. Thử lại sau.';

  @override
  String get partnerBankName => 'Ngân hàng';

  @override
  String get partnerBankAccount => 'Số tài khoản';

  @override
  String get partnerBankHolder => 'Chủ tài khoản';

  @override
  String get partnerBankHolderHint => 'VIẾT HOA KHÔNG DẤU';

  @override
  String get partnerBankNote => 'Tên chủ TK phải trùng giấy tờ.';

  @override
  String get partnerReviewTitleDocs => 'Giấy tờ';

  @override
  String get partnerReviewEntered => 'Đã nhập';

  @override
  String get partnerReviewMissing => 'Còn thiếu';

  @override
  String get kycRoleBadge => 'Tài xế';

  @override
  String get kycFlowLabel => 'ĐĂNG KÝ TÀI XẾ';

  @override
  String get kycIntroTitle => 'Đăng ký tài xế';

  @override
  String get kycIntroSubtitle => 'Đối tác tài xế';

  @override
  String get kycIntroHero => 'Đi muôn nơi\nKiếm thêm thu nhập';

  @override
  String get kycIntroHeadline => 'Lái xe cùng DealGo';

  @override
  String get kycIntroRideTitle => 'Chở khách';

  @override
  String get kycIntroRideBody => 'Nhận chuyến, chào giá';

  @override
  String get kycIntroFoodTitle => 'Giao đồ ăn';

  @override
  String get kycIntroFoodBody => 'Lấy món, giao khách';

  @override
  String get kycIntroEarnTitle => 'Theo dõi thu nhập';

  @override
  String get kycIntroEarnBody => 'Thu nhập minh bạch';

  @override
  String get kycIntroRequirements =>
      'Cần xác minh trước khi hoạt động: CCCD, ảnh chân dung, giấy phép lái xe, đăng ký xe và tài khoản nhận tiền.';

  @override
  String get kycStartCta => 'Bắt đầu đăng ký';

  @override
  String get kycExistingCta => 'Tôi đã có hồ sơ';

  @override
  String get kycStepServices => 'Chọn dịch vụ';

  @override
  String get kycStepPersonal => 'Thông tin cá nhân';

  @override
  String get kycStepIdentity => 'Chụp CCCD';

  @override
  String get kycStepConfirm => 'Kiểm tra thông tin';

  @override
  String get kycStepSelfie => 'Ảnh chân dung';

  @override
  String get kycStepLicense => 'Giấy phép lái xe';

  @override
  String get kycStepVehicle => 'Phương tiện';

  @override
  String get kycStepBank => 'Ngân hàng nhận thu nhập';

  @override
  String get kycStepReview => 'Rà soát hồ sơ tài xế';

  @override
  String get kycSubServices =>
      'Bạn có thể đăng ký nhiều dịch vụ, tùy theo hồ sơ và phương tiện được xét duyệt.';

  @override
  String get kycSubPersonal =>
      'Nhập đúng như trên giấy tờ định danh để tránh sai lệch khi xác minh.';

  @override
  String get kycSubIdentity =>
      'Chụp hai mặt CCCD gắn chip. Ảnh được mã hóa và chỉ đội xét duyệt xem được.';

  @override
  String get kycSubConfirm =>
      'Đối chiếu thông tin bạn nhập với CCCD trước khi gửi.';

  @override
  String get kycSubSelfie =>
      'Chụp ảnh chân dung rõ mặt, không đeo kính râm hay khẩu trang.';

  @override
  String get kycSubLicense => 'Khai báo GPLX hợp lệ theo dịch vụ đã chọn.';

  @override
  String get kycSubVehicle =>
      'Thông tin phương tiện dùng khi xét duyệt điều kiện nhận việc.';

  @override
  String get kycSubBank => 'Tài khoản nhận thu nhập và đối soát.';

  @override
  String get kycSubReview => 'Kiểm tra trước khi gửi xét duyệt';

  @override
  String get kycServiceRideBody => 'Đón khách, thỏa thuận giá';

  @override
  String get kycServiceFoodBody => 'Lấy món, giao khách';

  @override
  String get kycFullName => 'Họ và tên';

  @override
  String get kycBirthDate => 'Ngày sinh';

  @override
  String get kycNationality => 'Quốc tịch';

  @override
  String get kycNationalityVn => 'Việt Nam';

  @override
  String get kycAddress => 'Địa chỉ liên hệ';

  @override
  String get kycPrivacyNote => 'Chỉ dùng để xét duyệt, được bảo mật.';

  @override
  String get kycIdNumber => 'Số CCCD';

  @override
  String get kycIdNumberHint => '12 chữ số';

  @override
  String get kycLicenseClass => 'Hạng giấy phép';

  @override
  String get kycLicenseNumber => 'Số giấy phép lái xe';

  @override
  String get kycVehicleType => 'Loại phương tiện';

  @override
  String get kycVehiclePlate => 'Biển số';

  @override
  String get kycVehicleBrand => 'Hãng xe';

  @override
  String get kycVehicleModel => 'Dòng xe';

  @override
  String get kycVehicleInsuranceNote => 'Ô tô cần ảnh bảo hiểm xe.';

  @override
  String get kycReviewProfile => 'Hồ sơ cá nhân';

  @override
  String get kycReviewDriver => 'Thông tin tài xế';

  @override
  String get kycReviewServices => 'Dịch vụ đăng ký';

  @override
  String get kycReviewBank => 'Ngân hàng nhận tiền';

  @override
  String get kycReviewNote => 'Nhận việc sau khi được duyệt.';

  @override
  String get kycSubmitCta => 'Gửi hồ sơ';

  @override
  String get kycResubmitCta => 'Gửi bổ sung';

  @override
  String get kycStatusTitle => 'Kết quả xét duyệt KYC';

  @override
  String get kycTrackCta => 'Về trang Tài xế';

  @override
  String get kycPendingTitle => 'Đang thẩm định';

  @override
  String kycPendingBody(String name) {
    return 'Hồ sơ tài xế $name';
  }

  @override
  String get kycActiveTitle => 'Đã kích hoạt';

  @override
  String get kycActiveBody => 'Bạn có thể bật nhận việc.';

  @override
  String get kycStatusPendingNote => 'Đang chờ duyệt.';

  @override
  String get kycStatusActiveNote => 'Đã duyệt.';

  @override
  String get kycTimelineActivate => 'Kích hoạt nhận việc';

  @override
  String get kycRejectedTitle => 'Bổ sung hồ sơ tài xế';

  @override
  String get kycRejectedBanner => 'Cần chỉnh sửa các mục bên dưới.';

  @override
  String get kybRoleBadge => 'Shop';

  @override
  String get kybFlowLabel => 'ĐĂNG KÝ CỬA HÀNG';

  @override
  String get kybStepFlowLabel => 'THÔNG TIN CỬA HÀNG';

  @override
  String get kybIntroTitle => 'Đăng ký cửa hàng';

  @override
  String get kybIntroSubtitle => 'Đối tác cửa hàng';

  @override
  String get kybIntroHeadline => 'Bán hàng cùng DealGo';

  @override
  String get kybIntroHero => 'Từ gian hàng nhỏ đến cửa hàng phát triển';

  @override
  String get kybIntroBenefits => 'DealGo đồng hành cùng bạn';

  @override
  String get kybBenefitReachTitle => 'Tiếp cận khách hàng';

  @override
  String get kybBenefitReachBody => 'Hiển thị theo khu vực';

  @override
  String get kybBenefitOrdersTitle => 'Nhận và xử lý đơn';

  @override
  String get kybBenefitOrdersBody => 'Theo dõi đơn hàng';

  @override
  String get kybBenefitRevenueTitle => 'Quản lý doanh thu';

  @override
  String get kybBenefitRevenueBody => 'Thống kê, đối soát';

  @override
  String get kybBenefitTrustTitle => 'Đăng ký minh bạch';

  @override
  String get kybBenefitTrustBody => 'Được xét duyệt';

  @override
  String get kybIntroRequirements =>
      'Bạn cần cung cấp thông tin cửa hàng, người đại diện, tài khoản nhận tiền và giấy tờ kinh doanh để được xét duyệt.';

  @override
  String get kybStartCta => 'Bắt đầu đăng ký Shop';

  @override
  String get kybStepBusinessType => 'Loại hình kinh doanh';

  @override
  String get kybStepBusinessTypeHeadline => 'Bạn kinh doanh gì?';

  @override
  String get kybStepShopInfo => 'Thông tin cửa hàng';

  @override
  String get kybStepRepresentative => 'Người đại diện & nhận tiền';

  @override
  String get kybStepDocuments => 'Tài liệu kinh doanh';

  @override
  String get kybStepReview => 'Rà soát hồ sơ Shop';

  @override
  String get kybSubBusinessType =>
      'Chọn loại hình phù hợp để DealGo gợi ý danh mục và quy trình xác minh.';

  @override
  String get kybSubShopInfo =>
      'Tên và địa chỉ dùng khi xét duyệt và hiển thị cho khách.';

  @override
  String get kybSubRepresentative =>
      'Người đại diện pháp lý và tài khoản nhận đối soát.';

  @override
  String get kybSubDocuments =>
      'Chụp giấy phép kinh doanh và CCCD người đại diện. Ảnh chỉ đội xét duyệt xem được.';

  @override
  String get kybSubReview => 'Kiểm tra trước khi gửi';

  @override
  String get kybTypeRestaurant => 'Quán ăn / Nhà hàng';

  @override
  String get kybTypeRestaurantBody => 'Món chế biến';

  @override
  String get kybTypeCafe => 'Quán cà phê / Trà sữa';

  @override
  String get kybTypeCafeBody => 'Đồ uống, bánh';

  @override
  String get kybTypeGrocery => 'Siêu thị / Cửa hàng thực phẩm';

  @override
  String get kybTypeGroceryBody => 'Thực phẩm, gia dụng';

  @override
  String get kybTypeConvenience => 'Cửa hàng tiện lợi';

  @override
  String get kybTypeConvenienceBody => 'Nhu yếu phẩm';

  @override
  String get kybTypeOther => 'Loại hình khác';

  @override
  String get kybTypeOtherBody => 'Loại khác';

  @override
  String get kybSubjectLabel => 'Chủ thể đăng ký';

  @override
  String get kybSubjectHousehold => 'Hộ kinh doanh';

  @override
  String get kybSubjectCompany => 'Doanh nghiệp';

  @override
  String get kybSubjectOther => 'Khác';

  @override
  String get kybShopName => 'Tên cửa hàng';

  @override
  String get kybShopAddress => 'Địa chỉ';

  @override
  String get kybShopPin => 'Ghim vị trí quán trên bản đồ';

  @override
  String get kybShopPinRequired =>
      'Bắt buộc: tài xế dùng điểm này để đến lấy món.';

  @override
  String get kybShopPinChange => 'Đã ghim. Chạm để đổi vị trí.';

  @override
  String get kybShopType => 'Loại hình';

  @override
  String get kybShopCategory => 'Danh mục quán (có thể chọn sau)';

  @override
  String get kybRepName => 'Họ và tên người đại diện';

  @override
  String get kybReviewStatus => 'Tình trạng hồ sơ';

  @override
  String get kybReviewShop => 'Thông tin cửa hàng';

  @override
  String get kybReviewRep => 'Người đại diện';

  @override
  String get kybReviewBank => 'Ngân hàng nhận tiền';

  @override
  String get kybReviewNote => 'Bán hàng sau khi được duyệt.';

  @override
  String get kybSubmitCta => 'Gửi xét duyệt';

  @override
  String get kybResubmitCta => 'Gửi lại hồ sơ';

  @override
  String get kybStatusTitle => 'Trạng thái duyệt';

  @override
  String get kybTrackCta => 'Về trang Shop';

  @override
  String get kybPendingTitle => 'Đang thẩm định hồ sơ';

  @override
  String get kybActiveTitle => 'Đã kích hoạt';

  @override
  String get kybActiveBody => 'Bạn có thể mở bán.';

  @override
  String get kybStatusPendingNote => 'Đang chờ duyệt.';

  @override
  String get kybStatusActiveNote => 'Đã duyệt.';

  @override
  String get kybTimelineActivate => 'Kích hoạt bán hàng';

  @override
  String get kybRejectedTitle => 'Bổ sung hồ sơ Shop';

  @override
  String get kybRejectedBanner => 'Cần bổ sung hồ sơ.';

  @override
  String get merchantStatsTitle => 'Thống kê';

  @override
  String get merchantStatsToday => 'Hôm nay';

  @override
  String get merchantStatsSales => 'Doanh thu món';

  @override
  String get merchantStatsDelivered => 'Đơn hoàn thành';

  @override
  String get merchantStatsOpen => 'Đơn đang xử lý';

  @override
  String get merchantStatsRating => 'Đánh giá';

  @override
  String get merchantStatsRatingNew => 'Quán mới';

  @override
  String merchantStatsRatingCount(int count) {
    return '$count lượt';
  }

  @override
  String merchantStatsLastDays(int days) {
    return '$days ngày gần đây';
  }

  @override
  String get merchantStatsRange7 => '7 ngày';

  @override
  String get merchantStatsRange30 => '30 ngày';

  @override
  String get merchantStatsOrdersByDay => 'Đơn hoàn thành theo ngày';

  @override
  String merchantStatsTotals(int count, String sales, int cancelled) {
    return 'Tổng $count đơn · $sales · $cancelled đơn huỷ';
  }

  @override
  String get merchantStatsTopItems => 'Món bán chạy';

  @override
  String get merchantStatsTopEmpty =>
      'Chưa có món nào được giao trong khoảng này.';

  @override
  String merchantStatsPortions(int count) {
    return '$count phần';
  }

  @override
  String get merchantStatementTitle => 'Hoa hồng DealGo';

  @override
  String merchantStatementCash(int count) {
    return 'Tiền mặt nhận từ tài xế ($count đơn)';
  }

  @override
  String merchantStatementCommission(String percent) {
    return 'Hoa hồng ($percent%)';
  }

  @override
  String get merchantStatementNet => 'Quán giữ lại';

  @override
  String merchantStatementCycle(int days) {
    return 'Đối soát mỗi $days ngày';
  }

  @override
  String get merchantStatementUnsettled => 'Hoa hồng chưa nộp';

  @override
  String get merchantStatementAllPaid => 'Đã nộp đủ hoa hồng trong khoảng này.';

  @override
  String merchantStatementLastPaid(String period, String amount) {
    return 'Lần nộp gần nhất: $period · $amount';
  }

  @override
  String get merchantStatementNote => 'Quán nộp hoa hồng cho DealGo.';

  @override
  String get merchantStatsFailed =>
      'Không tải được thống kê. Kéo xuống để thử lại.';

  @override
  String merchantOrderCustomerName(String name) {
    return 'Khách: $name';
  }

  @override
  String merchantOrderDriverName(String name) {
    return 'Tài xế: $name';
  }

  @override
  String get merchantQueueTitle => 'Hàng đợi đơn của Shop';

  @override
  String merchantQueueViewOrder(String ref) {
    return 'Xem đơn $ref';
  }

  @override
  String get merchantQueueYourShop => 'Cửa hàng của bạn';

  @override
  String get merchantQueueToHandle => 'Đơn cần xử lý';

  @override
  String get merchantQueueOthers => 'Hàng đợi khác';

  @override
  String get merchantQueueNewChip => 'Đơn mới';

  @override
  String get merchantQueueDeliverTo => 'Giao đến';

  @override
  String get merchantQueueItemsFood => 'Số món · Tiền món';

  @override
  String get merchantQueueDeliveryFee => 'Phí giao';

  @override
  String get merchantQueueTotal => 'Tổng';

  @override
  String get merchantHomeTitle => 'Tổng quan cửa hàng';

  @override
  String get merchantHomeOpenChip => 'Đang mở';

  @override
  String get merchantHomeToConfirm => 'Đơn cần xác nhận';

  @override
  String get merchantHomePreparing => 'Đang chuẩn bị';

  @override
  String get merchantHomeNoOrders => 'Không có đơn đang mở trên hàng đợi.';

  @override
  String merchantHomeOrderLine(int count, String food) {
    return '$count món · $food tiền món';
  }

  @override
  String get merchantHomeView => 'Xem →';

  @override
  String get merchantHomeShopFallback => 'Cửa hàng của bạn';

  @override
  String get merchantStatusPlaced => 'Chờ Shop xác nhận';

  @override
  String get merchantStatusPreparing => 'Đang chuẩn bị';

  @override
  String get merchantStatusReady => 'Sẵn sàng giao';

  @override
  String get merchantStatusAssigned => 'Đã có tài xế';

  @override
  String get merchantStatusPickedUp => 'Đang giao';

  @override
  String get merchantStatusDelivered => 'Đã giao';

  @override
  String get merchantStatusUnknown => 'Đang cập nhật';

  @override
  String get merchantNotSynced => 'Chưa đồng bộ';

  @override
  String get merchantHomeCancelledToday => 'Đơn huỷ hôm nay';

  @override
  String get merchantHomeSalesToday => 'Doanh thu món hôm nay';

  @override
  String get merchantHomeOpenOrders => 'Đơn đang mở';

  @override
  String get merchantStatsIneligible =>
      'Cửa hàng chưa được phép bán. Thống kê có sau khi hồ sơ Shop được duyệt.';

  @override
  String get supportAttachTitle => 'Ảnh đính kèm';

  @override
  String get supportAttachCamera => 'Chụp ảnh';

  @override
  String get supportAttachGallery => 'Thư viện';

  @override
  String get supportAttachRemove => 'Bỏ ảnh';

  @override
  String supportAttachCount(int count, int max) {
    return '$count/$max ảnh';
  }

  @override
  String supportAttachPhoto(int n) {
    return 'Ảnh $n';
  }

  @override
  String supportAttachFile(int n) {
    return 'Tệp $n';
  }

  @override
  String get supportAttachPdfNote => 'Đã đính kèm PDF.';

  @override
  String get supportAttachOpenFailed => 'Không mở được tệp. Vui lòng thử lại.';

  @override
  String get supportAttachTooLarge => 'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn.';

  @override
  String get supportAttachBadType => 'Định dạng tệp không được hỗ trợ.';

  @override
  String get supportAttachUnavailable =>
      'Chưa gửi được tệp đính kèm lúc này. Hãy gửi không kèm ảnh hoặc thử lại sau.';

  @override
  String get helpFaqLoadFailed => 'Chưa tải được câu hỏi thường gặp.';

  @override
  String get helpSubtitle => 'Cần hỗ trợ?';

  @override
  String get helpFaqEmpty => 'Chưa có câu hỏi.';

  @override
  String rideShareMessage(String url) {
    return 'Theo dõi chuyến đi DealGo của mình: $url';
  }

  @override
  String get rideShareSubject => 'Chuyến đi DealGo của mình';

  @override
  String get rideShareSentChip => 'Đã chia sẻ';

  @override
  String get rideSafetyCopyLink => 'Sao chép liên kết';

  @override
  String get rideShareCopiedChip => 'Đã sao chép';

  @override
  String get rideShareNotActive =>
      'Chỉ chia sẻ được khi đã có tài xế nhận chuyến.';

  @override
  String get rideShareLimit =>
      'Bạn đã tạo đủ 5 liên kết cho chuyến này. Hãy dùng lại liên kết đã gửi.';

  @override
  String get rideShareFailed => 'Chưa tạo được liên kết. Vui lòng thử lại.';

  @override
  String get foodRejectOutOfStock => 'Hết món';

  @override
  String get foodRejectStoreBusy => 'Quán đang quá tải';

  @override
  String get foodRejectStoreClosing => 'Quán sắp đóng cửa';

  @override
  String get foodRejectPriceChanged => 'Giá món đã thay đổi';

  @override
  String get foodRejectOther => 'Lý do khác';

  @override
  String foodRejectReasonLine(String reason) {
    return 'Lý do: $reason';
  }

  @override
  String foodRejectReasonLineWithNote(String reason, String note) {
    return 'Lý do: $reason — $note';
  }

  @override
  String get foodRejectedTitle => 'Quán đã từ chối đơn';

  @override
  String get merchantRejectReasonTitle => 'Lý do từ chối';

  @override
  String get merchantRejectNoteRequired => 'Ghi chú cho khách (bắt buộc)';

  @override
  String get merchantRejectNoteOptional => 'Ghi chú cho khách (không bắt buộc)';

  @override
  String get vouchersUse => 'Dùng khi đặt món';

  @override
  String vouchersUseDone(String code) {
    return 'Đã gắn mã $code vào giỏ hàng (và sao chép). Mã được kiểm tra lại ở bước thanh toán.';
  }

  @override
  String get vouchersFootnote => 'Số tiền giảm tính khi thanh toán.';

  @override
  String voucherPercent(int percent) {
    return 'Giảm $percent%';
  }

  @override
  String voucherPercentMax(int percent, String max) {
    return 'Giảm $percent%, tối đa $max';
  }

  @override
  String voucherFixed(String amount) {
    return 'Giảm $amount';
  }

  @override
  String voucherDelivery(String amount) {
    return 'Giảm $amount phí giao';
  }

  @override
  String voucherMinOrder(String amount) {
    return 'Đơn từ $amount';
  }

  @override
  String voucherEnds(String date) {
    return 'HSD $date';
  }

  @override
  String voucherUsesLeft(int count) {
    return 'Còn $count lượt';
  }

  @override
  String get homeVoucherSeeAll => 'Săn ưu đãi';

  @override
  String get rideQuoteExpiredBadge => 'Hết hạn';

  @override
  String get foodCancelledBrowse => 'Chọn quán khác';

  @override
  String get rideMatchingReceiving => 'Đang nhận báo giá';

  @override
  String get rideMatchingSearching => 'Đang chờ báo giá';

  @override
  String get rideMatchingLoadFailed =>
      'Chưa tải được yêu cầu. Chuyến chưa đổi trạng thái.';

  @override
  String get rideMatchingSent => 'Đã gửi đề xuất';

  @override
  String get rideMatchingWaiting => 'Đang chờ tài xế chào giá...';

  @override
  String rideViewersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tài xế đang xem yêu cầu',
      one: '1 tài xế đang xem yêu cầu',
    );
    return '$_temp0';
  }

  @override
  String get rideViewersNone => 'Chưa có tài xế mở yêu cầu';

  @override
  String get rideViewersNotifying => 'Đang báo cho tài xế gần bạn';

  @override
  String rideAutoAcceptLabel(String price) {
    return 'Tự động nhận khi tài xế đồng ý $price';
  }

  @override
  String get rideAutoAcceptHint =>
      'Chỉ nhận đúng giá bạn đưa. Giá khác vẫn cần bạn chọn.';

  @override
  String get rideStatusLabel => 'Trạng thái';

  @override
  String get rideStatusNegotiating => 'Đang thương lượng';

  @override
  String get rideStatusAssigned => 'Đã có tài xế';

  @override
  String get rideStatusDriverEnRoute => 'Tài xế đang đến';

  @override
  String get rideStatusDriverArrived => 'Tài xế đã tới';

  @override
  String get rideStatusInTrip => 'Đang trong chuyến';

  @override
  String get rideStatusCompleted => 'Đã hoàn tất';

  @override
  String get rideStatusCancelled => 'Đã hủy';

  @override
  String get rideStatusExpired => 'Hết hạn';

  @override
  String get rideNoOffersTitle => 'Chưa có báo giá';

  @override
  String get rideNoOffersMessage => 'Chưa có tài xế báo giá.';

  @override
  String get rideProgress => 'Tiến trình';

  @override
  String get rideMatchingRefreshFailed =>
      'Chưa làm mới được yêu cầu. Trạng thái chuyến chưa đổi.';

  @override
  String get rideViewOffers => 'Xem báo giá';

  @override
  String get rideCancelSearch => 'Hủy tìm kiếm';

  @override
  String get rideTimeoutTitle => 'Chưa tìm được tài xế';

  @override
  String get rideTimeoutMessage => 'Hết thời gian, chưa có tài xế.';

  @override
  String get rideCurrentRoute => 'Hành trình đang chọn';

  @override
  String get rideCurrentOfferedFare => 'Giá đề xuất đang dùng';

  @override
  String get rideOfferedFare => 'Giá đề xuất';

  @override
  String get rideEditRoute => 'Sửa hành trình';

  @override
  String get rideFindAgain => 'Tìm lại tài xế';

  @override
  String get rideAssignedNote => 'Tài xế đã nhận chuyến.';

  @override
  String get rideTrack => 'Theo dõi chuyến';

  @override
  String get rideConfirmTitle => 'Xác nhận chuyến xe';

  @override
  String get rideConfirmNoAgreed =>
      'Chưa nhận được giá đã chốt cho chuyến này. Vui lòng thử lại.';

  @override
  String get rideConfirmNewPrice => 'Xác nhận giá mới';

  @override
  String get rideFareChangedTitle => 'Giá đã thay đổi';

  @override
  String get rideFareChangedMessage => 'Báo giá cũ hết hiệu lực. Xem lại giá.';

  @override
  String get rideCompareFares => 'So sánh giá';

  @override
  String get rideFareYouPicked => 'Giá bạn đã chọn';

  @override
  String get rideFareDifference => 'Chênh lệch';

  @override
  String get rideChosenRoute => 'Hành trình đã chọn';

  @override
  String get rideOfferAgreed => 'Báo giá được chốt';

  @override
  String get rideStillValid => 'Còn hiệu lực';

  @override
  String get rideFare => 'Cước chuyến';

  @override
  String get rideCustomerPays => 'Khách thanh toán';

  @override
  String get ridePaymentMethod => 'Phương thức thanh toán';

  @override
  String get rideCashNote => 'Trả khi hoàn tất';

  @override
  String get rideFarePendingExists =>
      'Bạn đang có một đề xuất chờ. Hãy mở báo giá đó hoặc hủy trước khi gửi giá mới.';

  @override
  String get rideFareSendFailed => 'Không gửi được đề xuất.';

  @override
  String get rideYourOffer => 'Đề xuất của bạn';

  @override
  String get rideSuggestedFareShort => 'Giá gợi ý';

  @override
  String get ridePickVehicleClassFirst =>
      'Chọn loại xe (xe máy hoặc ô tô) trước khi gửi đề xuất.';

  @override
  String get rideEnterAmount => 'Nhập số tiền';

  @override
  String get rideFareOffline =>
      'Chưa gửi được đề xuất. Chuyến xe chưa được tạo.';

  @override
  String get rideSeeDriverOffers => 'Xem tài xế chào giá';

  @override
  String get rideNoAgreedYet => 'Giá chuyến chưa được chốt.';

  @override
  String get rideSelectFailed => 'Không chọn được báo giá.';

  @override
  String get rideCancelFailed => 'Không hủy được yêu cầu.';

  @override
  String get rideDriverOffers => 'Tài xế chào giá';

  @override
  String get rideRequestCancelled => 'Yêu cầu đã hủy';

  @override
  String get rideOfferInvalid => 'Đề xuất không còn hiệu lực.';

  @override
  String get rideAgreedTitle => 'Chuyến đã được chốt';

  @override
  String get rideAgreedMissing => 'Chưa nhận được giá đã chốt.';

  @override
  String get rideOffersLoadFailed =>
      'Chưa tải được báo giá. Chuyến chưa được xác nhận.';

  @override
  String get rideCurrentQuoteFare => 'Giá đề xuất hiện tại';

  @override
  String get rideTripCode => 'Mã chuyến';

  @override
  String get rideListRefreshFailed => 'Chưa làm mới được danh sách.';

  @override
  String get rideChangeOffer => 'Thay đổi đề xuất';

  @override
  String get rideQuoteExpiredTitle => 'Báo giá đã hết hạn';

  @override
  String get rideQuoteExpiredMessage => 'Báo giá đã hết hạn.';

  @override
  String get rideOldFare => 'Giá cũ (tham khảo)';

  @override
  String get rideFindNewOffers => 'Tìm báo giá mới';

  @override
  String get rideOfferTakenTitle => 'Tài xế đã bận';

  @override
  String get rideOfferTakenMessage => 'Báo giá không còn.';

  @override
  String get ridePreviousOffer => 'Giá chào trước đó';

  @override
  String get rideRefreshList => 'Làm mới danh sách';

  @override
  String get rideSeeOtherDrivers => 'Xem tài xế khác';

  @override
  String get rideOfferList => 'Danh sách báo giá';

  @override
  String get rideRouteAndFare => 'Hành trình & giá đề xuất';

  @override
  String get rideLowestFirst => 'Giá thấp nhất';

  @override
  String get rideSelectOffline =>
      'Chưa gửi được lựa chọn. Giá chuyến chưa được chốt.';

  @override
  String rideAcceptAmount(String amount) {
    return 'Đồng ý $amount';
  }

  @override
  String rideRecordedAmount(String amount) {
    return 'Đã ghi nhận $amount';
  }

  @override
  String rideCustomerPaysAmount(String amount) {
    return 'Khách thanh toán $amount.';
  }

  @override
  String rideOffersCount(int count) {
    return '$count báo giá phù hợp';
  }

  @override
  String rideFindDriverCta(String amount) {
    return 'Tìm tài xế · $amount';
  }

  @override
  String get rideFindDriverPlain => 'Tìm tài xế';

  @override
  String rideRecommendedFareLabel(String amount) {
    return 'Giá gợi ý $amount';
  }

  @override
  String get rideOfferKindAccept => 'Bằng giá bạn đề xuất';

  @override
  String get rideOfferKindCounter => 'Đề nghị khác';

  @override
  String get rideOfferUnavailable => 'Không còn khả dụng';

  @override
  String get rideOfferJustInvalid => 'Báo giá vừa hết hiệu lực';

  @override
  String get rideOfferExpiredShort => 'Báo giá hết hạn';

  @override
  String get rideYouAreOffline => 'Bạn đang ngoại tuyến';

  @override
  String get driverServicesOfflineTitle => 'Đang ngoại tuyến';

  @override
  String get driverServicesNotRegistered => 'Chưa đăng ký';

  @override
  String get driverServicesNoneOn =>
      'Bạn đang tắt hết dịch vụ nên sẽ không nhận được việc mới.';

  @override
  String driverVehiclePlate(String plate) {
    return 'Biển số $plate';
  }

  @override
  String get driverVehicleUnknown => 'Chưa có biển số trong hồ sơ tài xế';

  @override
  String get driverVehicleNotOnFile => 'Chưa có phương tiện trong hồ sơ';

  @override
  String get driverServicesSaved =>
      'Đã lưu. Danh sách việc chỉ hiện các dịch vụ bạn đang bật.';

  @override
  String get driverServicesSaveFailed =>
      'Chưa lưu được lựa chọn. Kiểm tra kết nối rồi thử lại.';

  @override
  String get driverHomeTitle => 'Tổng quan tài xế';

  @override
  String get driverSeeHistory => 'Xem lịch sử';

  @override
  String get driverGoOnline => 'Bật nhận việc';

  @override
  String get driverOfflineHeroMessage => 'Bật để nhận chuyến và đơn giao.';

  @override
  String get driverDutyStatus => 'Tình trạng hoạt động';

  @override
  String get driverOfflineChip => 'Ngoại tuyến · Chưa nhận việc';

  @override
  String get driverServiceTypes => 'Loại dịch vụ';

  @override
  String get driverNoServiceOn => 'Chưa bật dịch vụ nào';

  @override
  String get driverContactSupport => 'Liên hệ hỗ trợ';

  @override
  String get driverOpenApplication => 'Xem hồ sơ tài xế';

  @override
  String get driverIneligibleTitle => 'Chưa thể nhận việc';

  @override
  String get driverIneligibleMessage =>
      'Tài khoản chưa được duyệt hoặc bị khoá.';

  @override
  String get driverRightsByService => 'Quyền theo dịch vụ';

  @override
  String get driverServicePassenger => 'Chở khách';

  @override
  String get driverServiceBlocked => 'Chưa thể nhận';

  @override
  String get driverAllowedServices => 'Dịch vụ bạn đang nhận';

  @override
  String get driverConfigure => 'Cấu hình';

  @override
  String get driverOnlineBadge => 'Trực tuyến';

  @override
  String get driverOnDutyMapLabel => 'Đang nhận việc';

  @override
  String get driverRideLoadFailed =>
      'Chưa tải được chuyến xe. Kiểm tra kết nối rồi thử lại.';

  @override
  String get driverRideDetailTitle => 'Yêu cầu chở khách';

  @override
  String get driverCounterOffer => 'Chào giá khác';

  @override
  String driverAcceptAtPrice(String price) {
    return 'Nhận giá $price';
  }

  @override
  String get driverRideChip => 'Chở khách · Xe máy & ô tô';

  @override
  String get driverCustomerFare => 'Giá khách đề xuất';

  @override
  String get driverReferenceFare => 'Giá tham chiếu';

  @override
  String get driverOfferCount => 'Số chào giá';

  @override
  String get driverOfferSendFailed =>
      'Không gửi được báo giá. Vui lòng thử lại.';

  @override
  String get driverOfferTitle => 'Trả giá';

  @override
  String get driverSendOffer => 'Gửi báo giá';

  @override
  String get driverCustomerRequest => 'Yêu cầu của khách';

  @override
  String get driverVehicle => 'Phương tiện';

  @override
  String get driverOfferSent => 'Đã gửi báo giá';

  @override
  String get driverOfferWaitingAccept => 'Đúng giá khách · Chờ khách chọn';

  @override
  String get driverOfferWaitingCounter => 'Giá của bạn · Chờ khách chọn';

  @override
  String get driverOfferChosen => 'Khách đã chọn bạn';

  @override
  String get driverOfferLost => 'Không được chọn';

  @override
  String get driverWaitingForCustomer => 'Đang chờ khách chọn';

  @override
  String get driverWaitingForCustomerBody => 'Chờ khách chọn.';

  @override
  String get driverReadyToNavigate => 'Sẵn sàng đón khách';

  @override
  String get driverReadyToNavigateBody => 'Mở lộ trình đón.';

  @override
  String get driverOfferLostBody => 'Khách đã chọn tài xế khác.';

  @override
  String get driverOpenPickupNavigation => 'Mở điều hướng đón';

  @override
  String get driverYourOffer => 'Chào giá của bạn';

  @override
  String get currencySuffixVnd => 'đ';

  @override
  String get driverOfferAmount => 'Giá gửi lên';

  @override
  String get driverOfferKind => 'Hình thức';

  @override
  String get driverOfferKindAccept => 'Nhận đúng giá khách';

  @override
  String get driverOfferKindCounter => 'Đề xuất giá khác';

  @override
  String get driverOfferHintSame => 'Bạn đang nhận đúng giá khách đề xuất.';

  @override
  String get driverOfferHintCounter =>
      'Khác giá khách đề xuất. Khách sẽ thấy đây là giá bạn đề xuất.';

  @override
  String get driverOpenJobDetails => 'Xem chi tiết công việc';

  @override
  String get driverNoOpenRequests => 'Chưa có yêu cầu đang mở';

  @override
  String get driverRidesAvailable => 'Chở khách có thể nhận';

  @override
  String get driverFoodAvailable => 'Giao đồ ăn có thể nhận';

  @override
  String driverFoodJobSummary(int count, String dropoff) {
    return '$count món · $dropoff';
  }

  @override
  String get driverDeliveryFare => 'Phí giao';

  @override
  String get driverLoadRequestsFailed =>
      'Không tải được yêu cầu. Vui lòng thử lại.';

  @override
  String get driverRequestTitle => 'Yêu cầu';

  @override
  String get driverRequestNotFound =>
      'Không tìm thấy yêu cầu. Có thể yêu cầu đã được nhận hoặc đã hết hạn.';

  @override
  String get apiErrGeneric => 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get apiErrPasskeyUnavailable =>
      'Thiết bị hoặc phiên bản app này chưa hỗ trợ passkey.';

  @override
  String get apiErrPasskeyInvalid =>
      'Xác minh passkey không thành công. Vui lòng thử lại hoặc chọn cách đăng nhập khác.';

  @override
  String get apiErrNetwork =>
      'Không kết nối được DealGo. Kiểm tra mạng rồi thử lại.';

  @override
  String get apiErrInvalidResponse =>
      'Dữ liệu nhận về không đọc được. Vui lòng thử lại.';

  @override
  String get apiErrCarDocsTitle => 'Cần bổ sung giấy tờ xe ô tô';

  @override
  String get apiErrCarDocsBody =>
      'Tài khoản tài xế ô tô cần ảnh bảo hiểm xe (bảo hiểm TNDS) trước khi nhận chuyến. Bổ sung giấy tờ để DealGo duyệt lại.';

  @override
  String get actionCompleteDocuments => 'Bổ sung giấy tờ';

  @override
  String get apiErrForbidden => 'Bạn không có quyền thực hiện thao tác này.';

  @override
  String get apiErrNotFound =>
      'Không tìm thấy dữ liệu. Có thể nội dung đã bị xoá hoặc thay đổi.';

  @override
  String get apiErrConflict =>
      'Dữ liệu vừa thay đổi. Vui lòng tải lại rồi thử lại.';

  @override
  String get apiErrGone => 'Nội dung này đã hết hạn.';

  @override
  String get apiErrTooLarge => 'Tệp quá lớn.';

  @override
  String get apiErrBadType => 'Định dạng tệp không được hỗ trợ.';

  @override
  String get apiErrTooMany =>
      'Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại.';

  @override
  String get apiErrServer => 'DealGo đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get apiErrRoleNotActive =>
      'Vai trò này chưa được duyệt hoặc đang tạm khoá.';

  @override
  String get apiErrRoleSuspended =>
      'Vai trò này đang bị tạm khoá. Liên hệ hỗ trợ để biết thêm.';

  @override
  String get apiErrValidation =>
      'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.';

  @override
  String get apiErrRideNotFound => 'Không tìm thấy chuyến xe.';

  @override
  String get apiErrRideChanged =>
      'Chuyến xe vừa đổi trạng thái. Vui lòng tải lại.';

  @override
  String get apiErrRideNotCancellable => 'Chuyến xe không thể huỷ ở bước này.';

  @override
  String get apiErrFareOutOfRange => 'Giá nằm ngoài khoảng cho phép.';

  @override
  String get apiErrRideAlreadyOpen =>
      'Bạn đang có một chuyến xe chưa kết thúc.';

  @override
  String get apiErrNegotiationLimit =>
      'Đã hết lượt thương lượng giá cho chuyến này.';

  @override
  String get apiErrSelfAction => 'Bạn không thể nhận yêu cầu của chính mình.';

  @override
  String get apiErrNotYourJob => 'Công việc này không còn được giao cho bạn.';

  @override
  String get apiErrOrderNotFound => 'Không tìm thấy đơn hàng.';

  @override
  String get apiErrOrderChanged =>
      'Đơn hàng vừa đổi trạng thái. Vui lòng tải lại.';

  @override
  String get apiErrJobTaken => 'Công việc đã được tài xế khác nhận.';

  @override
  String get apiErrOrderNotCancellable => 'Đơn hàng không thể huỷ ở bước này.';

  @override
  String get apiErrNotStoreOwner => 'Tài khoản không quản lý cửa hàng này.';

  @override
  String get apiErrItemNotFound => 'Không tìm thấy món.';

  @override
  String get apiErrVoucherNotFound => 'Mã ưu đãi không tồn tại.';

  @override
  String get apiErrVoucherEnded => 'Mã ưu đãi đã hết hạn hoặc tạm ngưng.';

  @override
  String get apiErrVoucherNotStarted => 'Mã ưu đãi chưa đến thời gian áp dụng.';

  @override
  String get apiErrVoucherMinOrder => 'Chưa đạt giá trị tối thiểu để dùng mã.';

  @override
  String get apiErrVoucherUsedUp => 'Mã ưu đãi đã hết lượt.';

  @override
  String get apiErrVoucherUserLimit => 'Bạn đã dùng hết lượt cho mã này.';

  @override
  String get apiErrVoucherWrongService =>
      'Mã ưu đãi không áp dụng cho dịch vụ này.';

  @override
  String get merchantIneligibleTitle => 'Chưa thể nhận đơn';

  @override
  String get merchantIneligibleMessage =>
      'Cửa hàng chưa được duyệt hoặc bị khoá.';

  @override
  String get merchantReloadOrders => 'Tải lại đơn hàng';

  @override
  String get merchantNoNewOrders => 'Chưa có đơn mới';

  @override
  String get merchantNoNewOrdersBody => 'Đơn mới sẽ hiện ở đây.';

  @override
  String get merchantViewSavedOrders => 'Xem đơn đã lưu';

  @override
  String get merchantOrdersLoadFailed => 'Không tải được đơn hàng';

  @override
  String get merchantOrdersLoadFailedBody => 'Danh sách có thể chưa mới.';

  @override
  String get merchantConnection => 'Kết nối';

  @override
  String get merchantLoadFailedChip => 'Tải dữ liệu thất bại';

  @override
  String get merchantLastSynced => 'Đồng bộ gần nhất';

  @override
  String get merchantNoSavedOrders => 'Chưa có đơn đã lưu trên máy.';

  @override
  String get merchantSavedOrders => 'Đơn đã lưu';

  @override
  String get merchantItemInvalid => 'Tên món và giá không hợp lệ.';

  @override
  String get merchantItemUpdateFailed => 'Không cập nhật được trạng thái món.';

  @override
  String get merchantItemCreateFailed => 'Không thêm được món.';

  @override
  String get foodStageAwaitingStore => 'Chờ quán xác nhận';

  @override
  String get foodStagePreparing => 'Đang chuẩn bị món';

  @override
  String get foodStageOnTheWay => 'Đơn đang được giao';

  @override
  String get foodStageCancelled => 'Đơn đã hủy';

  @override
  String get foodStageUnknown => 'Chưa rõ trạng thái đơn';

  @override
  String merchantMenuSummary(int available, int total) {
    return '$available món đang bán · $total món tổng';
  }

  @override
  String get merchantAddItem => 'Thêm món';

  @override
  String get merchantItemName => 'Tên món';

  @override
  String get merchantItemPrice => 'Giá (VND)';

  @override
  String get merchantPriceInvalid => 'Giá không hợp lệ';

  @override
  String get merchantItemOnSale => 'Đang bán';

  @override
  String get merchantItemSoldOut => 'Tạm hết';

  @override
  String get merchantItemPendingReview => 'Chờ duyệt';

  @override
  String get merchantItemRejected => 'Bị từ chối';

  @override
  String get foodOrderSentTitle => 'Đã gửi đơn hàng';

  @override
  String get foodOrderPlaced => 'Đặt hàng thành công';

  @override
  String get foodOrderPlacedSub => 'Chờ quán xác nhận';

  @override
  String get foodPayOnDelivery => 'Thanh toán khi nhận hàng';

  @override
  String get foodCashNotPaid => 'Tiền mặt · Chưa thanh toán';

  @override
  String get foodStepSent => 'Đơn đã gửi';

  @override
  String get foodStepAwaitStore => 'Chờ quán xác nhận';

  @override
  String get foodStepNotPreparing => 'Chưa chuẩn bị';

  @override
  String get foodTrackOrder => 'Theo dõi đơn hàng';

  @override
  String get foodReconnecting => 'Đang kết nối lại...';

  @override
  String get foodReconnectingBody => 'Đang kết nối lại…';

  @override
  String get foodOrderInProgress => 'Đơn hàng đang xử lý';

  @override
  String get foodCustomerPays => 'Bạn thanh toán';

  @override
  String get foodLastKnownStatus => 'Trạng thái gần nhất';

  @override
  String foodLineQtyPrice(int quantity, String price) {
    return 'x$quantity · $price / món';
  }

  @override
  String get homeSearchHint => 'Tìm điểm đến, món ăn';

  @override
  String get homeServiceRideSub => 'Đi ngay';

  @override
  String get homeServiceFoodSub => 'Giao tận nơi';

  @override
  String get voiceOpenFailed => 'Không mở được cuộc gọi. Vui lòng thử lại.';

  @override
  String get mapIllustrative => 'Bản đồ minh họa';

  @override
  String get mapRouteRoadFollowed => 'Theo đường thật';

  @override
  String get mapRouteStraightFallback => 'Đường thẳng minh họa';

  @override
  String get rideVoucherTitle => 'Mã ưu đãi';

  @override
  String rideVoucherLine(String code) {
    return 'Ưu đãi $code';
  }

  @override
  String get rideCashDueLabel => 'Tiền mặt trả tài xế';

  @override
  String rideVoucherDropped(String reason) {
    return '$reason Bạn có thể chọn lại không kèm mã.';
  }

  @override
  String driverCashToCollect(String amount) {
    return 'Thu tiền mặt $amount';
  }

  @override
  String driverVoucherFunded(String amount) {
    return 'Khách dùng ưu đãi $amount; DealGo trả phần này cho bạn.';
  }

  @override
  String get merchantBusyEyebrow => 'KHẢ NĂNG PHỤC VỤ';

  @override
  String get merchantBusyHeading => 'Tình trạng cửa hàng';

  @override
  String get merchantBusyAccepting => 'Đang nhận đơn';

  @override
  String get merchantBusyNotAccepting => 'Tạm ngưng nhận đơn';

  @override
  String merchantBusyAcceptingBody(String store) {
    return 'Khách có thể đặt hàng từ $store.';
  }

  @override
  String get merchantBusyNotAcceptingBody => 'Khách không đặt được đơn mới.';

  @override
  String merchantBusyResumesAt(String time) {
    return 'Tự mở lại lúc $time';
  }

  @override
  String get merchantBusyResumeLabel => 'Hẹn giờ tự mở lại';

  @override
  String merchantBusyResumeMinutes(int minutes) {
    return '$minutes phút';
  }

  @override
  String merchantBusyResumeHours(int hours) {
    return '$hours giờ';
  }

  @override
  String get merchantBusyResumeManual => 'Thủ công';

  @override
  String get merchantBusySave => 'Lưu trạng thái cửa hàng';

  @override
  String get merchantBusySaved => 'Đã lưu trạng thái cửa hàng.';

  @override
  String get checkoutErrStorePaused =>
      'Quán đang tạm ngưng nhận đơn. Vui lòng thử lại sau.';

  @override
  String get foodStorePausedBanner => 'Quán đang tạm ngưng nhận đơn mới.';

  @override
  String get foodStoreBusyBanner => 'Quán đông, chuẩn bị lâu hơn.';

  @override
  String get merchantHomeBusyChip => 'Bếp bận';

  @override
  String get merchantHomePausedChip => 'Tạm ngưng';

  @override
  String get merchantHoursEyebrow => 'THỜI GIAN KINH DOANH';

  @override
  String get merchantHoursHeading => 'Lịch hoạt động';

  @override
  String get merchantHoursUnset =>
      'Bạn chưa lưu giờ hoạt động nên quán đang nhận đơn cả ngày. Lưu lịch dưới đây để áp dụng.';

  @override
  String get merchantHoursWeekly => 'Lịch cố định trong tuần';

  @override
  String get merchantHoursClosedShort => 'Đóng';

  @override
  String get merchantHoursClosures => 'Ngày nghỉ đặc biệt';

  @override
  String get merchantHoursAddClosure => '+ Thêm ngày nghỉ';

  @override
  String get merchantHoursNoClosures => 'Chưa có ngày nghỉ đặc biệt.';

  @override
  String get merchantHoursRemoveClosure => 'Xóa';

  @override
  String get merchantHoursCutoffTitle => 'Ngừng nhận trước';

  @override
  String get merchantHoursCutoffNone => 'Không';

  @override
  String get merchantHoursSave => 'Lưu lịch hoạt động';

  @override
  String get merchantHoursSaved => 'Đã lưu lịch hoạt động.';

  @override
  String merchantHoursInvalidRange(String day) {
    return '$day: giờ đóng không được trùng giờ mở.';
  }

  @override
  String get dayShortMon => 'T2';

  @override
  String get dayShortTue => 'T3';

  @override
  String get dayShortWed => 'T4';

  @override
  String get dayShortThu => 'T5';

  @override
  String get dayShortFri => 'T6';

  @override
  String get dayShortSat => 'T7';

  @override
  String get dayShortSun => 'CN';

  @override
  String get checkoutErrStoreClosed =>
      'Quán đang ngoài giờ nhận đơn. Vui lòng quay lại sau.';

  @override
  String get merchantHoursErrInvalid =>
      'Lịch hoạt động chưa hợp lệ. Kiểm tra giờ mở/đóng và ngày nghỉ.';

  @override
  String get foodStoreClosedLabel => 'Đóng cửa';

  @override
  String get foodStorePausedLabel => 'Tạm ngưng';

  @override
  String get foodStoreClosedBanner => 'Quán đang đóng cửa.';

  @override
  String foodStoreHoursToday(String range) {
    return 'Hôm nay: $range';
  }

  @override
  String get foodStoreHoursTodayOff => 'Hôm nay quán nghỉ.';

  @override
  String get merchantAcceptEyebrow => 'CẤU HÌNH VẬN HÀNH';

  @override
  String get merchantAcceptHeading => 'Thiết lập nhận đơn';

  @override
  String merchantAcceptStoreState(String state) {
    return 'Trạng thái hoạt động: $state';
  }

  @override
  String get merchantAcceptStateOpen => 'đang nhận đơn';

  @override
  String get merchantAcceptStateBusy => 'bếp đang bận';

  @override
  String get merchantAcceptStatePaused => 'tạm ngưng nhận đơn';

  @override
  String get merchantAcceptStateClosed => 'ngoài giờ mở cửa';

  @override
  String get merchantAcceptLimits => 'Giới hạn vận hành';

  @override
  String get merchantAcceptMaxActive => 'Số đơn đang xử lý tối đa';

  @override
  String merchantAcceptOrdersCount(int count) {
    return '$count đơn';
  }

  @override
  String get merchantAcceptNoLimit => 'Không giới hạn';

  @override
  String get merchantAcceptPrep => 'Thời gian chuẩn bị mặc định';

  @override
  String get merchantAcceptCutoff => 'Nhận đơn khi sắp đóng cửa';

  @override
  String get merchantAcceptSave => 'Lưu thiết lập';

  @override
  String get merchantAcceptSaved => 'Đã lưu thiết lập nhận đơn.';

  @override
  String get merchantAcceptPickTitle => 'Chọn giá trị';

  @override
  String get merchantBusyExtraLabel => 'Thêm giờ khi bận';

  @override
  String merchantBusyExtraHint(int minutes) {
    return 'Chuẩn bị ≈$minutes phút.';
  }

  @override
  String foodTrackingReadyBy(String time) {
    return 'Dự kiến món sẵn sàng lúc $time';
  }

  @override
  String get checkoutErrStoreAtCapacity =>
      'Quán đang quá tải đơn. Vui lòng thử lại sau ít phút.';

  @override
  String get merchantHoursNextDay => 'hôm sau';

  @override
  String foodStoreHoursOvernight(String range) {
    return '$range (đến sáng hôm sau)';
  }

  @override
  String get homeSearchChooseTitle => 'Bạn muốn tìm gì?';

  @override
  String homeSearchAsFood(String query) {
    return 'Cửa hàng, món ăn: “$query”';
  }

  @override
  String homeSearchAsPlace(String query) {
    return 'Điểm đến để đặt xe: “$query”';
  }

  @override
  String trackingDriverLiveAt(String time) {
    return 'Vị trí tài xế lúc $time';
  }

  @override
  String get foodStageFailed => 'Giao không thành công';

  @override
  String foodItemOptionsUpTo(int count) {
    return 'Tối đa $count';
  }

  @override
  String get foodItemOptionsSoldOut => 'Hết';

  @override
  String get apiErrFoodOptionInvalid =>
      'Lựa chọn của món đã thay đổi hoặc chưa đủ. Vui lòng chọn lại.';

  @override
  String merchantOptionsBasePrice(String price) {
    return 'Giá bán $price';
  }

  @override
  String get merchantOptionsAddChoice => '+ Thêm lựa chọn';

  @override
  String get merchantOptionsAddGroup => '+ Thêm nhóm tuỳ chọn';

  @override
  String get merchantOptionsEmpty =>
      'Món này chưa có tuỳ chọn. Thêm nhóm như Size hoặc Topping để khách chọn.';

  @override
  String get merchantOptionsRuleRequiredOne => 'Bắt buộc · chọn 1';

  @override
  String get merchantOptionsRuleOptionalOne => 'Không bắt buộc · chọn 1';

  @override
  String merchantOptionsRuleUpTo(int max) {
    return 'Không bắt buộc · tối đa $max';
  }

  @override
  String merchantOptionsRuleRange(int min, int max) {
    return 'Bắt buộc · chọn $min–$max';
  }

  @override
  String get merchantOptionsSoldOut => 'Tạm hết';

  @override
  String get merchantOptionsGroupDialogTitle => 'Nhóm tuỳ chọn';

  @override
  String get merchantOptionsGroupName => 'Tên nhóm (vd. Size, Topping)';

  @override
  String get merchantOptionsMin => 'Khách phải chọn tối thiểu';

  @override
  String get merchantOptionsMax => 'Khách được chọn tối đa';

  @override
  String get merchantOptionsChoiceDialogTitle => 'Lựa chọn';

  @override
  String get merchantOptionsChoiceName => 'Tên lựa chọn';

  @override
  String get merchantOptionsChoicePrice => 'Giá cộng thêm (đ)';

  @override
  String get merchantOptionsChoiceAvailable => 'Đang bán';

  @override
  String get merchantOptionsDelete => 'Xoá';

  @override
  String get merchantOptionsApply => 'Xong';

  @override
  String get merchantOptionsSaved => 'Đã lưu tuỳ chọn món';

  @override
  String get merchantOptionsInvalidGroup =>
      'Mỗi nhóm cần tên riêng, ít nhất 1 lựa chọn không trùng tên, và tối thiểu ≤ tối đa ≤ số lựa chọn.';

  @override
  String get merchantOptionsItemMissing => 'Không tìm thấy món trong thực đơn.';

  @override
  String get merchantOptionsUnsaved => 'Có thay đổi chưa lưu';

  @override
  String get driverFoodNoStorePoint =>
      'Quán chưa có toạ độ trên bản đồ — đi theo địa chỉ quán.';

  @override
  String get driverNavGoogleMaps => 'Google Maps';

  @override
  String get driverNavWaze => 'Waze';

  @override
  String get driverNavAppleMaps => 'Apple Maps';

  @override
  String get chatRoleDriver => 'Tài xế';

  @override
  String get chatRoleCustomer => 'Khách hàng';

  @override
  String get chatRoleShop => 'Quán';

  @override
  String get chatCallAction => 'Gọi';

  @override
  String get chatCloseAction => 'Đóng';

  @override
  String get chatSendAction => 'Gửi';

  @override
  String get chatStatusSending => 'Đang gửi';

  @override
  String get chatStatusSent => 'Đã gửi';

  @override
  String get chatStatusFailed => 'Chưa gửi được · Chạm để thử lại';

  @override
  String get chatToday => 'Hôm nay';

  @override
  String get chatYesterday => 'Hôm qua';

  @override
  String get chatEmptyBody => 'Gửi tin nhắn để trao đổi nhanh';

  @override
  String chatUnreadCount(int count) {
    return '$count tin nhắn mới';
  }

  @override
  String get chatQuickDriverComing => 'Tôi đang tới';

  @override
  String get chatQuickDriverDelivering => 'Tôi đang giao tới';

  @override
  String get chatQuickDriverArrived => 'Tôi đã đến';

  @override
  String get chatQuickDriverWait => 'Chờ tôi 2 phút';

  @override
  String get chatQuickCustomerGate => 'Tôi đứng ở cổng';

  @override
  String get chatQuickCustomerComing => 'Tôi ra ngay';

  @override
  String get chatQuickCustomerWhere => 'Bạn đang ở đâu?';

  @override
  String get chatQuickCustomerLeaveAtGate => 'Để ở cổng giúp tôi';

  @override
  String get driverNavOpenFailed =>
      'Không mở được ứng dụng chỉ đường. Kiểm tra Google Maps hoặc Waze trên máy.';

  @override
  String get driverNavOpen => 'Điều hướng';

  @override
  String get driverNavSheetTitle => 'Chỉ đường bằng';

  @override
  String get driverNavWeb => 'Google Maps (trình duyệt)';

  @override
  String get driverNavLastUsed => 'Lần trước';

  @override
  String get driverNavToPickup => 'Đến điểm đón khách';

  @override
  String get driverNavToDropoff => 'Đến điểm trả khách';

  @override
  String get driverNavToStore => 'Đến quán lấy món';

  @override
  String get driverNavToCustomer => 'Đến chỗ khách nhận món';

  @override
  String get driverRideUnassignedTitle => 'Chuyến đã chuyển';

  @override
  String get driverRideUnassignedStartTimeout =>
      'Bạn chưa bắt đầu đi đón khách đúng hạn.';

  @override
  String get driverRideUnassignedArriveTimeout =>
      'Bạn chưa đến điểm đón đúng hạn.';

  @override
  String get driverRideUnassignedOps =>
      'Bộ phận hỗ trợ DealGo đã điều phối lại chuyến.';

  @override
  String get driverRideUnassignedGeneric =>
      'Chuyến đã được mở lại để nhận báo giá mới.';

  @override
  String get driverFoodDeliveryCodeTitle => 'Mã giao hàng';

  @override
  String get driverFoodDeliveryCodeBody => 'Nhập mã 4 số của khách.';

  @override
  String get driverFoodHandoverCodeTitle => 'Mã bàn giao';

  @override
  String get driverFoodHandoverCodeBody => 'Nhập mã 4 số của quán.';

  @override
  String get driverFoodCodeWrong => 'Mã chưa đúng, kiểm tra lại.';

  @override
  String get driverFoodCodeLocked =>
      'Nhập sai quá số lần cho phép. Liên hệ hỗ trợ để xử lý đơn.';

  @override
  String get driverFoodCodeSubmit => 'Xác nhận';

  @override
  String get foodDeliveryCodeTitle => 'Mã giao hàng';

  @override
  String get foodDeliveryCodeHint => 'Đọc mã cho tài xế khi nhận món.';

  @override
  String get merchantHandoverCodeLabel => 'Mã bàn giao';

  @override
  String get merchantHandoverCodeHint => 'Đọc mã cho tài xế khi lấy món.';

  @override
  String get accountDeleteRow => 'Xoá tài khoản';

  @override
  String get accountDeleteRowBody => 'Yêu cầu xoá vĩnh viễn tài khoản DealGo';

  @override
  String get deleteAccountHeader => 'Xóa tài khoản';

  @override
  String get deleteAccountTitle => 'Yêu cầu xóa tài khoản';

  @override
  String get deleteAccountWarnTitle => 'Lưu ý';

  @override
  String get deleteAccountWarnBody => 'Không thể khôi phục sau khi xoá.';

  @override
  String get deleteAccountWhatHappens => 'Điều gì sẽ xảy ra?';

  @override
  String get deleteAccountNoLoginTitle => 'Không thể đăng nhập';

  @override
  String get deleteAccountNoLoginBody =>
      'Bạn sẽ không còn sử dụng tài khoản này';

  @override
  String get deleteAccountDataTitle => 'Dữ liệu tài khoản';

  @override
  String get deleteAccountHistoryTitle => 'Lịch sử giao dịch';

  @override
  String get deleteAccountHistoryBody =>
      'Một số hồ sơ có thể phải lưu theo pháp luật';

  @override
  String get deleteAccountBefore => 'Trước khi gửi yêu cầu';

  @override
  String get deleteAccountCheckNoJobs =>
      'Không có chuyến hoặc đơn đang thực hiện';

  @override
  String get deleteAccountCheckBackup => 'Tôi đã sao lưu thông tin cần thiết';

  @override
  String get deleteAccountTypeLabel => 'Nhập XÓA để xác nhận';

  @override
  String get deleteAccountTypeHint => 'XÓA';

  @override
  String get deleteAccountContinue => 'Tiếp tục xóa';

  @override
  String get deleteAccountKeep => 'Giữ tài khoản';

  @override
  String get deleteAccountVerifyTitle => 'Xác minh danh tính';

  @override
  String get deleteAccountPasswordBody => 'Nhập mật khẩu để xác nhận.';

  @override
  String get deleteAccountPasswordLabel => 'Mật khẩu';

  @override
  String get deleteAccountCodeLabel => 'Mã xác minh';

  @override
  String get deleteAccountConfirm => 'Xác nhận xoá';

  @override
  String get deleteAccountRestart => 'Gửi lại yêu cầu';

  @override
  String get deleteAccountDoneTitle => 'Đã gửi yêu cầu xoá';

  @override
  String get deleteAccountDoneAction => 'Về màn hình đăng nhập';

  @override
  String get deleteAccountLoadError =>
      'Không tải được thông tin xoá tài khoản.';

  @override
  String get deleteAccountReauthUnavailable =>
      'Chưa xác minh lại được tài khoản này trong ứng dụng. Hãy liên hệ hỗ trợ.';

  @override
  String get deleteAccountWrongPassword => 'Mật khẩu không đúng.';

  @override
  String get deleteAccountWrongCode => 'Mã xác minh không đúng.';

  @override
  String get deleteAccountLocked =>
      'Xác minh sai quá nhiều lần. Hãy gửi lại yêu cầu.';

  @override
  String get deleteAccountPasskeyVerify => 'Xác minh passkey';

  @override
  String get deleteAccountWrongPasskey => 'Không xác minh được passkey.';

  @override
  String get deleteAccountExpired => 'Yêu cầu đã hết hạn. Gửi lại yêu cầu.';

  @override
  String get deleteBlockerOps =>
      'Tài khoản nhân sự vận hành không xoá được trên app. Liên hệ quản trị viên.';

  @override
  String get apiErrAccountDeleted =>
      'Tài khoản này đã bị xoá. Nếu muốn khôi phục, hãy liên hệ hỗ trợ DealGo trong thời gian chờ.';

  @override
  String deleteAccountDataBody(int days) {
    return 'Dữ liệu cá nhân được xoá vĩnh viễn sau $days ngày';
  }

  @override
  String deleteAccountCodeBody(String phone) {
    return 'Nhập mã 6 số vừa gửi tới $phone.';
  }

  @override
  String deleteAccountDoneBody(String date) {
    return 'Tài khoản đã bị khoá và bạn đã được đăng xuất khỏi mọi thiết bị. Dữ liệu cá nhân sẽ được xoá vĩnh viễn vào $date. Nếu đổi ý, hãy liên hệ hỗ trợ trước thời điểm đó.';
  }

  @override
  String deleteBlockerRide(int count) {
    return 'Bạn đang có $count chuyến xe chưa kết thúc.';
  }

  @override
  String deleteBlockerFood(int count) {
    return 'Bạn đang có $count đơn đồ ăn chưa hoàn tất.';
  }

  @override
  String deleteBlockerDriver(int count) {
    return 'Bạn đang nhận $count cuốc/đơn với vai trò tài xế.';
  }

  @override
  String deleteBlockerStore(int count) {
    return 'Quán của bạn còn $count đơn đang xử lý.';
  }

  @override
  String deleteBlockerCod(String amount) {
    return 'Còn $amount phí nền tảng của cuốc tiền mặt chưa đối soát với DealGo.';
  }

  @override
  String get accountNotifPrefs => 'Cài đặt thông báo';

  @override
  String get accountNotifPrefsBody => 'Chọn loại cập nhật bạn muốn nhận';

  @override
  String get accountSecurity => 'Bảo mật & quyền riêng tư';

  @override
  String get accountSecurityBody => 'Đăng nhập, thiết bị và xoá tài khoản';

  @override
  String get editProfileHeader => 'Chỉnh sửa hồ sơ';

  @override
  String get editProfileChangePhoto => 'Thay đổi ảnh đại diện';

  @override
  String get editProfileName => 'Họ và tên';

  @override
  String get editProfilePhone => 'Số điện thoại';

  @override
  String get editProfilePhoneLocked =>
      'Số điện thoại đã xác minh, không đổi tại đây.';

  @override
  String get editProfileEmail => 'Email';

  @override
  String get editProfileDob => 'Ngày sinh (tùy chọn)';

  @override
  String get editProfileGender => 'Giới tính (tùy chọn)';

  @override
  String get editProfileGenderMale => 'Nam';

  @override
  String get editProfileGenderFemale => 'Nữ';

  @override
  String get editProfileGenderOther => 'Khác';

  @override
  String get editProfileSave => 'Lưu thay đổi';

  @override
  String get editProfileSaved => 'Đã lưu hồ sơ';

  @override
  String get notifPrefsHeader => 'Cài đặt thông báo';

  @override
  String get notifPrefsTitle => 'Thông báo của bạn';

  @override
  String get notifPrefsPushOn => 'Thông báo đẩy đang bật';

  @override
  String get notifPrefsImportant => 'Thông báo quan trọng';

  @override
  String get notifPrefsRide => 'Chuyến đi';

  @override
  String get notifPrefsRideBody => 'Tài xế nhận, đến nơi và hoàn tất chuyến';

  @override
  String get notifPrefsFood => 'Đồ ăn và đơn hàng';

  @override
  String get notifPrefsFoodBody => 'Xác nhận, chuẩn bị và giao hàng';

  @override
  String get notifPrefsChat => 'Tin nhắn và cuộc gọi';

  @override
  String get notifPrefsChatBody => 'Tin nhắn từ người liên quan đến giao dịch';

  @override
  String get notifPrefsNewJobSound => 'Âm báo có đơn mới';

  @override
  String get notifPrefsNewJobSoundBody =>
      'Đọc \"DealGo, có cuốc mới\" khi có việc.';

  @override
  String get notifPrefsOther => 'Thông báo khác';

  @override
  String get notifPrefsPromo => 'Ưu đãi và khuyến mãi';

  @override
  String get notifPrefsPromoBody => 'Mã giảm giá, chương trình mới';

  @override
  String get notifPrefsNews => 'Tin tức DealGo';

  @override
  String get notifPrefsNewsBody => 'Cập nhật dịch vụ và tính năng';

  @override
  String get notifPrefsMandatory =>
      'Một số cập nhật bắt buộc về giao dịch hoặc bảo mật vẫn được gửi để bảo vệ tài khoản của bạn.';

  @override
  String get notifPrefsSave => 'Lưu cài đặt';

  @override
  String get notifPrefsSaved => 'Đã lưu cài đặt thông báo';

  @override
  String get securityHeader => 'Bảo mật & quyền riêng tư';

  @override
  String get securityTitle => 'An toàn tài khoản';

  @override
  String get securityProtected => 'Tài khoản đang được bảo vệ';

  @override
  String get securityLoginSection => 'Đăng nhập và xác minh';

  @override
  String get securityPhone => 'Số điện thoại';

  @override
  String get securityVerified => 'Đã xác minh';

  @override
  String get securityEmail => 'Email';

  @override
  String get securityPasskey => 'Passkey';

  @override
  String get securitySessions => 'Thiết bị và phiên đăng nhập';

  @override
  String get securityChangePassword => 'Đổi mật khẩu';

  @override
  String get securityPrivacySection => 'Quyền riêng tư';

  @override
  String get securityPermissions => 'Quyền của ứng dụng';

  @override
  String get securityTerms => 'Điều khoản & dữ liệu cá nhân';

  @override
  String get securityAccountSection => 'Quản lý tài khoản';

  @override
  String get securityDelete => 'Yêu cầu xóa tài khoản';

  @override
  String get changePasswordHeader => 'Đổi mật khẩu';

  @override
  String get changePasswordCurrent => 'Mật khẩu hiện tại';

  @override
  String get changePasswordNew => 'Mật khẩu mới';

  @override
  String get changePasswordConfirm => 'Nhập lại mật khẩu mới';

  @override
  String get changePasswordSave => 'Cập nhật mật khẩu';

  @override
  String get changePasswordMismatch => 'Mật khẩu mới không khớp.';

  @override
  String get changePasswordDone => 'Đã đổi mật khẩu';

  @override
  String get sessionsHeader => 'Thiết bị đăng nhập';

  @override
  String get sessionsTitle => 'Phiên hoạt động';

  @override
  String get sessionsWarn =>
      'Nếu phát hiện thiết bị lạ, hãy đăng xuất phiên đó và kiểm tra lại phương thức xác minh tài khoản.';

  @override
  String get sessionsCurrent => 'Thiết bị hiện tại';

  @override
  String get sessionsThisDevice => 'Thiết bị này';

  @override
  String get sessionsOthers => 'Các phiên khác';

  @override
  String get sessionsLogout => 'Đăng xuất';

  @override
  String get sessionsLogoutOthers => 'Đăng xuất tất cả thiết bị khác';

  @override
  String get sessionsEmptyOthers =>
      'Không có thiết bị nào khác đang đăng nhập.';

  @override
  String get sessionsRevoked => 'Đã đăng xuất thiết bị';

  @override
  String get merchantHistoryTitle => 'Lịch sử đơn hàng';

  @override
  String get merchantHistoryHeadline => 'Lịch sử đơn';

  @override
  String get merchantHistorySearch => 'Tìm theo mã đơn hoặc tên khách';

  @override
  String get merchantHistoryAll => 'Tất cả';

  @override
  String get merchantHistoryDone => 'Hoàn thành';

  @override
  String get merchantHistoryCancelled => 'Đã hủy';

  @override
  String merchantHistoryRevenue(String amount) {
    return 'Doanh thu đơn hoàn tất: $amount';
  }

  @override
  String get merchantHistoryList => 'Danh sách đơn';

  @override
  String get merchantHistoryEmpty => 'Chưa có đơn đã kết thúc';

  @override
  String get merchantCategoriesTitle => 'Danh mục';

  @override
  String get merchantCategoriesHeadline => 'Quản lý danh mục';

  @override
  String get merchantCategoriesSearch => 'Tìm danh mục';

  @override
  String merchantCategoriesCount(String count) {
    return '$count danh mục';
  }

  @override
  String merchantCategoriesItemsOnSale(String count) {
    return '$count món đang bán';
  }

  @override
  String get merchantCategoriesAdd => 'Thêm danh mục mới +';

  @override
  String get merchantCategoriesEmpty => 'Chưa có danh mục nào';

  @override
  String get merchantCategoryName => 'Tên danh mục';

  @override
  String get merchantCategoryDesc => 'Mô tả (tuỳ chọn)';

  @override
  String get merchantItemEditTitle => 'Thêm / chỉnh sửa món';

  @override
  String get merchantItemInfo => 'THÔNG TIN SẢN PHẨM';

  @override
  String get merchantItemCategory => 'Danh mục';

  @override
  String get merchantItemDescription => 'Mô tả món ăn';

  @override
  String get merchantItemPrep => 'Thời gian chuẩn bị (phút)';

  @override
  String get merchantItemVisible => 'Hiển thị với khách hàng';

  @override
  String get merchantItemVisibleBody => 'Cho phép khách đặt món ngay';

  @override
  String get merchantItemContinue => 'Tiếp tục: Size & topping';

  @override
  String get merchantItemSaved => 'Đã lưu món';

  @override
  String get merchantProductsEdit => 'Sửa';

  @override
  String get merchantProductsCategories => 'Danh mục';

  @override
  String get merchantProductsHistory => 'Lịch sử đơn';

  @override
  String get merchantItemPhoto => 'Ảnh món';

  @override
  String get merchantItemPhotoPick => 'Chọn ảnh';

  @override
  String get merchantItemPhotoUploading => 'Đang tải ảnh…';

  @override
  String get merchantItemPhotoClear => 'Xoá ảnh';

  @override
  String get merchantItemPhotoError => 'Không tải được ảnh. Thử lại.';

  @override
  String get merchantCategoriesReordered => 'Đã lưu thứ tự danh mục';

  @override
  String merchantProductsSoldCount(String count) {
    return 'Đã bán $count';
  }

  @override
  String get merchantProductsSearch => 'Tìm món';

  @override
  String get merchantProductsFilterAll => 'Tất cả';

  @override
  String get merchantProductsFilterOnSale => 'Đang bán';

  @override
  String get merchantProductsFilterHidden => 'Ẩn / nháp';

  @override
  String get merchantProductsEmptyFilter => 'Không có món khớp bộ lọc';

  @override
  String get merchantProductsEmptyMenu =>
      'Chưa có món nào. Bấm “Thêm món” để bắt đầu bán.';

  @override
  String get merchantOptionsChoiceMaxQty => 'Số lượng tối đa mỗi dòng';

  @override
  String merchantOptionsMaxQty(String count) {
    return 'Tối đa ×$count';
  }

  @override
  String get merchantCategoriesSearchHint => 'Tìm danh mục';

  @override
  String get merchantEditStatusHidden => 'Ẩn / nháp — khách không thấy';

  @override
  String get merchantEditStatusOnSale => 'Đang bán';

  @override
  String get merchantLocationTitle => 'Vị trí quán';

  @override
  String get merchantLocationUnset => 'Chưa ghim vị trí — quán đang ẩn.';

  @override
  String get merchantLocationPinNow => 'Ghim ngay';

  @override
  String get merchantLocationUnsetValue => 'Chưa đặt vị trí';

  @override
  String get merchantLocationPickHint => 'Chọn trên bản đồ';

  @override
  String get merchantLocationPendingHint => 'Chưa lưu — bấm Lưu vị trí';

  @override
  String get merchantLocationSave => 'Lưu vị trí';

  @override
  String get merchantLocationSaved => 'Đã lưu vị trí quán.';

  @override
  String get placePickerStoreTitle => 'Vị trí quán';

  @override
  String get accountStoreLocationBody => 'Điểm lấy hàng cho tài xế';

  @override
  String get forgotPasswordLink => 'Quên mật khẩu?';

  @override
  String get forgotPasswordTitle => 'Đặt lại mật khẩu';

  @override
  String get forgotPasswordIntro => 'Nhập email để nhận mã 6 số.';

  @override
  String get forgotPasswordSendCode => 'Gửi mã';

  @override
  String forgotPasswordCodeSent(String email) {
    return 'Nếu $email có tài khoản dùng mật khẩu, mã 6 số đã được gửi tới email này. Mã chỉ có hiệu lực trong ít phút.';
  }

  @override
  String get forgotPasswordCodeLabel => 'Mã 6 số trong email';

  @override
  String get forgotPasswordNewLabel => 'Mật khẩu mới (≥ 6 ký tự)';

  @override
  String get forgotPasswordConfirmLabel => 'Nhập lại mật khẩu mới';

  @override
  String get forgotPasswordSubmit => 'Đặt lại mật khẩu';

  @override
  String get forgotPasswordResend => 'Gửi lại mã';

  @override
  String get forgotPasswordResent =>
      'Đã gửi lại mã mới. Mã cũ không dùng được nữa.';

  @override
  String get forgotPasswordDone =>
      'Đã đặt lại mật khẩu. Các phiên đăng nhập cũ đã bị đăng xuất; hãy đăng nhập bằng mật khẩu mới.';

  @override
  String get forgotPasswordErrCode => 'Nhập đủ 6 chữ số của mã.';

  @override
  String get forgotPasswordErrCooldown =>
      'Vui lòng đợi một chút rồi mới gửi lại mã.';

  @override
  String get forgotPasswordErrResendLimit =>
      'Đã gửi mã quá số lần cho phép. Hãy bắt đầu lại.';

  @override
  String get forgotPasswordStartOver => 'Bắt đầu lại';

  @override
  String get securityPasskeyAdded => 'Đã thêm passkey cho tài khoản.';

  @override
  String get securityPasskeyUnsupported =>
      'Thiết bị hoặc phiên bản app này chưa hỗ trợ passkey.';

  @override
  String get securityPasskeyExists =>
      'Thiết bị này đã có passkey cho tài khoản.';

  @override
  String get securityPasskeyFailed =>
      'Chưa thêm được passkey. Vui lòng thử lại.';

  @override
  String get securityPasskeyNeedsVerifiedLogin =>
      'Cần xác minh tài khoản trước khi thêm passkey.';

  @override
  String get merchantProfileTitle => 'Hồ sơ quán';

  @override
  String get merchantProfileName => 'Tên quán';

  @override
  String get merchantProfileNameInvalid => 'Tên quán cần từ 2 đến 120 ký tự.';

  @override
  String get merchantProfileCategory => 'Danh mục quán';

  @override
  String get merchantProfileSave => 'Lưu thay đổi';

  @override
  String get merchantProfileSaved => 'Đã lưu hồ sơ quán.';

  @override
  String get merchantProfileLogo => 'Logo quán';

  @override
  String get merchantProfileLogoAdd => 'Thêm logo';

  @override
  String get merchantProfileLogoChange => 'Đổi logo';

  @override
  String get merchantProfileLogoRemove => 'Gỡ logo';

  @override
  String get merchantProfileLogoSaved => 'Đã cập nhật logo.';

  @override
  String get merchantProfileLogoRemoved => 'Đã gỡ logo.';

  @override
  String get accountStoreProfileBody => 'Tên quán, danh mục và logo';

  @override
  String get foodReorderConfirmTitle => 'Đặt lại đơn này?';

  @override
  String get foodReorderConfirmBody => 'Thêm món vào giỏ theo giá hiện tại?';

  @override
  String get actionReorder => 'Đặt lại';

  @override
  String get foodReorderNone => 'Các món trong đơn cũ hiện không còn bán';

  @override
  String foodReorderPartial(int count) {
    return '$count món không còn bán đã được bỏ khỏi giỏ';
  }

  @override
  String get kycQuickModeBanner => 'Đăng ký nhanh, không cần giấy tờ.';

  @override
  String get kybQuickModeBanner => 'Đăng ký nhanh, không cần giấy tờ.';

  @override
  String get handoverRefLabel => 'Mã đối chiếu';

  @override
  String handoverRefSemantics(String ref) {
    return 'Mã đối chiếu đơn $ref';
  }

  @override
  String get rideRebookAction => 'Đặt lại chuyến';

  @override
  String trackEtaMinutes(int minutes) {
    return '≈$minutes phút';
  }

  @override
  String get trackStepFinding => 'Tìm xe';

  @override
  String get trackStepComing => 'Đang tới';

  @override
  String get trackStepArrived => 'Đã đến';

  @override
  String get trackStepOnTrip => 'Trên xe';

  @override
  String get trackStepDone => 'Hoàn tất';

  @override
  String get trackStepPlaced => 'Đã đặt';

  @override
  String get trackStepPreparing => 'Đang làm';

  @override
  String get trackStepReady => 'Chờ lấy';

  @override
  String get trackStepDriverToStore => 'Tài xế đến quán';

  @override
  String get trackStepDelivering => 'Đang giao';

  @override
  String get trackStepDelivered => 'Đã giao';

  @override
  String trackItemsMore(int count) {
    return '+$count món khác';
  }

  @override
  String get foodStageFindingDriver => 'Đang tìm tài xế';

  @override
  String get foodStageDriverToStore => 'Tài xế đang đến quán';

  @override
  String get foodStageDeliveringToYou => 'Tài xế đang giao tới bạn';

  @override
  String get accountSignOutConfirmTitle => 'Đăng xuất?';

  @override
  String get accountSignOutConfirmBody => 'Bạn sẽ cần đăng nhập lại.';

  @override
  String get accountSignOutCancel => 'Huỷ';

  @override
  String get rideOfferConfirmTitle => 'Chọn tài xế này?';

  @override
  String rideOfferConfirmBody(String amount) {
    return 'Giá chuyến $amount.';
  }

  @override
  String get rideOfferConfirmAction => 'Chọn tài xế';

  @override
  String get rideOfferConfirmCancel => 'Xem lại';

  @override
  String get rideRaiseFare => 'Tăng giá';

  @override
  String get rideRaiseFareTitle => 'Tăng giá đề nghị';

  @override
  String rideRaiseFareBody(String amount) {
    return 'Giá hiện tại: $amount';
  }

  @override
  String rideRaiseFareStep(String amount) {
    return '+$amount';
  }

  @override
  String rideRaiseFareDone(String amount) {
    return 'Đã tăng giá lên $amount';
  }

  @override
  String get rideDeclineOffer => 'Từ chối giá này';

  @override
  String get rideDeclineOfferDone => 'Đã từ chối. Tài xế có thể gửi giá mới.';

  @override
  String get driverWithdrawOffer => 'Rút đề nghị';

  @override
  String get driverWithdrawOfferDone => 'Đã rút đề nghị';

  @override
  String get driverCustomerRating => 'Đánh giá khách';

  @override
  String driverCustomerRatingValue(String average, int count) {
    return '$average★ ($count lượt)';
  }

  @override
  String get driverCustomerRatingNone => 'Chưa có đánh giá';

  @override
  String get driverCancelRide => 'Huỷ chuyến';

  @override
  String get driverCancelReasonTitle => 'Lý do huỷ chuyến?';

  @override
  String get driverCancelHint => 'Tính vào tỉ lệ huỷ.';

  @override
  String get driverCancelReasonCustomerUnreachable =>
      'Không liên lạc được khách';

  @override
  String get driverCancelReasonPickupTooFar => 'Điểm đón quá xa';

  @override
  String get driverCancelReasonVehicleProblem => 'Xe gặp sự cố';

  @override
  String get driverCancelReasonSafetyConcern => 'Lo ngại an toàn';

  @override
  String get driverCancelReasonCustomerAsked => 'Khách yêu cầu huỷ';

  @override
  String get driverCancelReasonOther => 'Lý do khác';

  @override
  String get driverCancelDone => 'Đã huỷ chuyến';

  @override
  String get driverNoShow => 'Khách không xuất hiện';

  @override
  String get driverNoShowBody => 'Chỉ dùng khi đã chờ ở điểm đón.';

  @override
  String get driverNoShowDone =>
      'Đã ghi nhận khách không xuất hiện. Chuyến đã đóng.';

  @override
  String get driverRateCustomerTitle => 'Đánh giá khách hàng';

  @override
  String get driverRateCustomerSubmit => 'Gửi đánh giá';

  @override
  String get driverRateCustomerDone => 'Đã gửi đánh giá – cảm ơn bạn!';

  @override
  String driverRateCustomerYours(int stars) {
    return 'Bạn đã đánh giá: $stars★';
  }

  @override
  String get driverRateTagOnTime => 'Đúng giờ';

  @override
  String get driverRateTagPolite => 'Lịch sự';

  @override
  String get driverRateTagClearPickup => 'Điểm đón rõ ràng';

  @override
  String get driverRateTagLate => 'Để chờ lâu';

  @override
  String get driverRateTagRude => 'Thiếu lịch sự';

  @override
  String get driverRateTagWrongPickup => 'Sai điểm đón';

  @override
  String get driverFoodRelease => 'Trả đơn';

  @override
  String get driverFoodReleaseTitle => 'Lý do trả đơn?';

  @override
  String get driverFoodReleaseHint => 'Trả đơn tính là một lần huỷ.';

  @override
  String get driverFoodReleaseStoreTooSlow => 'Quán chuẩn bị quá lâu';

  @override
  String get driverFoodReleaseStoreClosed => 'Quán đóng cửa';

  @override
  String get driverFoodReleaseVehicleProblem => 'Xe gặp sự cố';

  @override
  String get driverFoodReleaseSafetyConcern => 'Lo ngại an toàn';

  @override
  String get driverFoodReleaseOther => 'Lý do khác';

  @override
  String get driverFoodReleaseDone => 'Đã trả đơn';

  @override
  String get driverFailNoteLabel => 'Mô tả (bắt buộc)';

  @override
  String get driverFailNoteRequired => 'Vui lòng mô tả chuyện gì đã xảy ra.';

  @override
  String get driverFailAbsentHint =>
      'Gọi và nhắn khách, chờ vài phút trước khi báo.';

  @override
  String get driverFoodFailedDone => 'Đã báo giao không thành công';

  @override
  String get apiErrLiveOffersFull =>
      'Chuyến này đã đủ số giá đề nghị. Thử lại sau ít phút.';

  @override
  String get apiErrFareRaiseLimit =>
      'Bạn không thể tăng giá thêm cho chuyến này.';

  @override
  String get apiErrCancelCooldown =>
      'Bạn vừa huỷ nhiều chuyến. Vui lòng chờ một lúc trước khi đặt lại.';

  @override
  String get apiErrRepostInvalid => 'Không thể đăng lại chuyến này.';

  @override
  String get apiErrFailTooEarly =>
      'Hãy chờ ở điểm giao thêm vài phút rồi mới báo không liên lạc được khách.';

  @override
  String get apiErrFailNoteRequired => 'Vui lòng ghi chú mô tả vấn đề.';

  @override
  String get apiErrStoreLocationRequired => 'Quán chưa ghim vị trí.';

  @override
  String get apiErrDriverLocationStale =>
      'Chưa lấy được vị trí hiện tại của bạn. Bật định vị rồi kéo xuống để tải lại.';

  @override
  String get apiErrOutsideServiceZone =>
      'Địa chỉ này nằm ngoài khu vực phục vụ.';

  @override
  String get apiErrTooFar => 'Địa chỉ giao quá xa quán.';

  @override
  String get apiErrSettlementOverlap =>
      'Kỳ này trùng với một bảng đối soát đã có.';

  @override
  String get apiErrSettlementPeriodOpen => 'Kỳ này chưa kết thúc.';

  @override
  String get apiErrShopLocationRequired =>
      'Hãy ghim vị trí cửa hàng trên bản đồ để tiếp tục.';

  @override
  String get apiErrChangePending =>
      'Đơn đang có một thay đổi chờ khách xác nhận.';

  @override
  String get apiErrChangeInvalid =>
      'Thay đổi không hợp lệ. Chỉ được giảm số lượng hoặc bỏ món.';

  @override
  String get apiErrChangeNotFound => 'Thay đổi này không còn chờ xác nhận.';

  @override
  String get foodCancelChangeRejected => 'Bạn đã từ chối thay đổi của quán';

  @override
  String get foodCancelChangeExpired =>
      'Thay đổi của quán không được xác nhận kịp';

  @override
  String get foodChangeTitle => 'Quán đổi đơn';

  @override
  String get foodChangeReasonOutOfStock => 'Một số món đã hết';

  @override
  String get foodChangeReasonNotEnough => 'Không đủ phần';

  @override
  String get foodChangeReasonOther => 'Lý do khác';

  @override
  String get foodChangeLineRemoved => 'Bỏ món';

  @override
  String get foodChangeNewTotal => 'Tổng mới';

  @override
  String foodChangeAnswerBy(String time) {
    return 'Trả lời trước $time, nếu không đơn sẽ tự huỷ miễn phí.';
  }

  @override
  String get foodChangeAccept => 'Đồng ý';

  @override
  String get foodChangeReject => 'Huỷ đơn';

  @override
  String get foodChangeRejectConfirmTitle => 'Huỷ đơn này?';

  @override
  String get foodChangeRejectConfirmBody => 'Đơn sẽ bị huỷ, không mất phí.';

  @override
  String get merchantEditOrder => 'Báo hết món / sửa đơn';

  @override
  String get merchantEditOrderHint => 'Khách cần đồng ý thay đổi.';

  @override
  String get merchantEditOrderNote => 'Ghi chú cho khách';

  @override
  String get merchantEditOrderAllRemoved => 'Nếu bỏ hết món, hãy từ chối đơn.';

  @override
  String merchantEditOrderNewSubtotal(String amount) {
    return 'Giá trị món mới: $amount';
  }

  @override
  String get merchantEditOrderSend => 'Gửi khách xác nhận';

  @override
  String merchantChangePending(String total, String time) {
    return 'Đang chờ khách đồng ý thay đổi (tổng mới $total) đến $time.';
  }

  @override
  String get pushForegroundOpen => 'Xem';

  @override
  String get mapPinPickup => 'Đón';

  @override
  String get mapPinDropoff => 'Đến';

  @override
  String get mapPinStore => 'Quán';

  @override
  String get mapPinHome => 'Giao';

  @override
  String get mapPickerTitle => 'Chọn trên bản đồ';

  @override
  String get mapPickerConfirm => 'Chọn vị trí này';

  @override
  String get mapPickerPinned => 'Vị trí đã ghim';

  @override
  String get mapPickerSearch => 'Tìm địa điểm';

  @override
  String get mapStyleTitle => 'Kiểu bản đồ';

  @override
  String get mapStyleStandard => 'Chuẩn';

  @override
  String get mapStyleSatellite => 'Vệ tinh';

  @override
  String get mapStyleDark => 'Tối';

  @override
  String get mapOpenSettings => 'Cài đặt';

  @override
  String homeBannerSlideLabel(int index, int count) {
    return 'Banner $index/$count';
  }

  @override
  String foodStoreFeeFrom(String fee) {
    return 'Phí giao từ $fee';
  }

  @override
  String foodStoreOpenUntil(String time) {
    return 'Mở đến $time';
  }

  @override
  String get foodOffersNearTitle => 'Ưu đãi quanh bạn';

  @override
  String get foodStoreOffersTitle => 'Ưu đãi của quán';

  @override
  String get foodStoreOfferUse => 'Dùng';

  @override
  String foodStoreOfferApplied(String code) {
    return 'Đã chọn mã $code cho đơn này';
  }

  @override
  String get foodStoreSearchMenu => 'Tìm món trong quán';

  @override
  String get foodStoreSearchNone => 'Không có món phù hợp';

  @override
  String get foodStoreSectionOther => 'Món khác';

  @override
  String get foodStoreReviewsAll => 'Tất cả';

  @override
  String get foodStoreReviewsMore => 'Xem thêm';

  @override
  String get foodStoreMerchantReply => 'Phản hồi của quán';

  @override
  String get foodStoreReviewsFilterNone => 'Chưa có đánh giá phù hợp';

  @override
  String foodItemSold(int count) {
    return 'Đã bán $count';
  }

  @override
  String get merchantOffersTitle => 'Ưu đãi của quán';

  @override
  String get merchantOffersEmpty => 'Chưa có ưu đãi';

  @override
  String get merchantOffersCreate => 'Tạo ưu đãi';

  @override
  String get merchantOfferNewTitle => 'Ưu đãi mới';

  @override
  String get merchantOfferStatusActive => 'Đang chạy';

  @override
  String get merchantOfferStatusPaused => 'Tạm dừng';

  @override
  String get merchantOfferStatusEnded => 'Đã kết thúc';

  @override
  String get merchantOfferStatusUpcoming => 'Sắp diễn ra';

  @override
  String get merchantOfferPause => 'Tạm dừng';

  @override
  String get merchantOfferResume => 'Chạy tiếp';

  @override
  String get merchantOfferEnd => 'Kết thúc';

  @override
  String merchantOfferEndConfirm(String name) {
    return 'Kết thúc ưu đãi $name?';
  }

  @override
  String merchantOfferUsage(int used, int limit) {
    return 'Đã dùng $used/$limit';
  }

  @override
  String merchantOfferLimitReached(int count) {
    return 'Đã đủ $count ưu đãi đang chạy';
  }

  @override
  String get merchantOfferFormName => 'Tên ưu đãi';

  @override
  String get merchantOfferFormCode => 'Mã ưu đãi';

  @override
  String get merchantOfferKindPercent => 'Giảm %';

  @override
  String get merchantOfferKindFixed => 'Giảm tiền';

  @override
  String get merchantOfferFormPercent => 'Phần trăm giảm';

  @override
  String get merchantOfferFormAmount => 'Số tiền giảm';

  @override
  String get merchantOfferFormMax => 'Giảm tối đa';

  @override
  String get merchantOfferFormMinOrder => 'Đơn tối thiểu';

  @override
  String get merchantOfferFormUsage => 'Tổng lượt dùng';

  @override
  String get merchantOfferFormPerUser => 'Lượt mỗi khách';

  @override
  String get merchantOfferFormStart => 'Bắt đầu';

  @override
  String get merchantOfferFormEnd => 'Kết thúc';

  @override
  String get merchantOfferFieldRequired => 'Bắt buộc';

  @override
  String get merchantOfferFieldInvalid => 'Không hợp lệ';

  @override
  String get merchantOfferMinBelowValue => 'Phải từ số tiền giảm trở lên';

  @override
  String get merchantOfferSave => 'Tạo ưu đãi';

  @override
  String get merchantReviewsTitle => 'Đánh giá của khách';

  @override
  String get merchantReviewsEmpty => 'Chưa có đánh giá';

  @override
  String get merchantReviewHidden => 'Đã ẩn';

  @override
  String get merchantReviewReply => 'Phản hồi';

  @override
  String get merchantReviewEditReply => 'Sửa phản hồi';

  @override
  String get merchantReviewReplySend => 'Gửi';

  @override
  String get merchantReviewReplyRemove => 'Xoá phản hồi';

  @override
  String get foodBadgeBestSeller => 'Bán chạy';

  @override
  String get foodBadgeNew => 'Mới';

  @override
  String foodStoreMinOrder(String amount) {
    return 'Đơn tối thiểu $amount';
  }

  @override
  String get foodCollectionNear => 'Gần bạn';

  @override
  String get foodCollectionTopRated => 'Đánh giá cao';

  @override
  String get foodCollectionDeals => 'Đang giảm giá';

  @override
  String get foodCollectionNewDishes => 'Món mới';

  @override
  String foodEtaArriveAt(String time) {
    return 'Dự kiến giao lúc $time';
  }

  @override
  String foodCartBarShortfall(String amount) {
    return 'Còn thiếu $amount';
  }

  @override
  String foodCartMinOrderMissing(String amount) {
    return 'Mua thêm $amount để đạt đơn tối thiểu';
  }

  @override
  String get foodStoreInfoHours => 'Giờ mở cửa';

  @override
  String get foodStoreInfoMinOrder => 'Đơn tối thiểu';

  @override
  String get foodStoreInfoNoMinOrder => 'Không yêu cầu';

  @override
  String get foodStoreInfoPrep => 'Thời gian chuẩn bị';

  @override
  String get foodStoreTagsTitle => 'Khách khen';

  @override
  String foodStoreSoldTotal(int count) {
    return '$count+ đã bán';
  }

  @override
  String voucherSaveAmount(String amount) {
    return 'Tiết kiệm $amount';
  }

  @override
  String get voucherBestPick => 'Tốt nhất';

  @override
  String voucherNeedMore(String amount) {
    return 'Mua thêm $amount';
  }

  @override
  String get voucherPickerApply => 'Dùng';

  @override
  String get checkoutErrMinOrder => 'Đơn chưa đạt mức tối thiểu của quán';

  @override
  String get merchantItemOriginalPrice => 'Giá gốc';

  @override
  String get merchantItemOriginalPriceInvalid => 'Giá gốc phải cao hơn giá bán';

  @override
  String get merchantStoreMinOrder => 'Đơn tối thiểu';

  @override
  String get merchantStoreMinOrderInvalid => 'Nhập từ 0 đến 10.000.000';

  @override
  String get foodStoreFeeFree => 'Miễn phí giao';

  @override
  String get merchantProfileCover => 'Ảnh bìa';

  @override
  String get merchantProfileCoverAdd => 'Thêm ảnh bìa';

  @override
  String get merchantProfileCoverChange => 'Đổi ảnh bìa';

  @override
  String get merchantProfileCoverRemove => 'Gỡ ảnh bìa';

  @override
  String get merchantProfileCoverSaved => 'Đã cập nhật ảnh bìa.';

  @override
  String get merchantProfileCoverRemoved => 'Đã gỡ ảnh bìa.';

  @override
  String get merchantProfileDescription => 'Giới thiệu quán';

  @override
  String get foodStoreAbout => 'Giới thiệu';

  @override
  String voucherCap(String amount) {
    return 'Tối đa $amount';
  }

  @override
  String get voucherUsed => 'Đã dùng';

  @override
  String otpPasteChip(String code) {
    return 'Dán mã $code';
  }

  @override
  String get otpNoCodeYet => 'Chưa nhận được mã?';

  @override
  String get otpEmailSpamHint =>
      'Không thấy email? Hãy kiểm tra mục Spam hoặc Quảng cáo.';

  @override
  String get emailVerifyLocked =>
      'Bạn đã nhập sai quá số lần cho phép. Hãy gửi lại để nhận mã mới.';

  @override
  String get emailVerifySuccess => 'Đã xác minh email';

  @override
  String get emailVerifyPendingNotice =>
      'Email mới chỉ được cập nhật sau khi bạn nhập mã xác minh.';

  @override
  String get profileEmailUnverified => 'Email chưa được xác minh';

  @override
  String get profileEmailVerifyAction => 'Xác minh';

  @override
  String get draftResumeTitle => 'Tiếp tục hồ sơ đang làm?';

  @override
  String get draftResumeBody =>
      'Thông tin bạn nhập trước đó đã được lưu trên máy này. Tiếp tục hay làm lại từ đầu?';

  @override
  String get draftResumeContinue => 'Tiếp tục';

  @override
  String get draftResumeDiscard => 'Làm lại từ đầu';

  @override
  String get draftRestoredNote => 'Đã khôi phục bản nháp chưa gửi.';

  @override
  String rideStopNumbered(int n) {
    return 'Điểm dừng $n';
  }

  @override
  String get rideAddStop => 'Thêm điểm dừng';

  @override
  String get rideRemoveStop => 'Xoá điểm dừng';

  @override
  String get rideMoveStopUp => 'Đưa điểm dừng lên trước';

  @override
  String rideStopsMax(int n) {
    return 'Tối đa $n điểm dừng';
  }

  @override
  String rideStopFeeNote(String fee) {
    return 'Mỗi điểm dừng cộng thêm $fee';
  }

  @override
  String get rideStopFeeLine => 'Phụ phí điểm dừng';

  @override
  String get rideWaitFeeLine => 'Phí chờ tại điểm dừng';

  @override
  String get rideStopPending => 'Chưa đến';

  @override
  String get rideStopArrived => 'Tài xế đang chờ';

  @override
  String get rideStopDeparted => 'Đã xong';

  @override
  String rideStopsCount(int n) {
    return '+$n điểm dừng';
  }

  @override
  String get rideRouteChanged =>
      'Khách vừa đổi lộ trình. Xem lại và trả giá lại nhé.';

  @override
  String get rideStopsLocked => 'Chỉ đổi điểm dừng được trước khi chọn tài xế.';

  @override
  String get rideStopsUnavailable => 'Dịch vụ này hiện chưa hỗ trợ điểm dừng.';

  @override
  String driverStopArrive(int n) {
    return 'Đã đến điểm dừng $n';
  }

  @override
  String driverStopDepart(int n) {
    return 'Rời điểm dừng $n';
  }

  @override
  String get driverStopsTitle => 'Các điểm dừng';

  @override
  String driverStopFreeWait(int m, String fee) {
    return 'Chờ miễn phí $m phút, sau đó $fee/phút';
  }

  @override
  String driverNavigateToStop(int n) {
    return 'Chỉ đường tới điểm dừng $n';
  }

  @override
  String get driverStopsPendingError =>
      'Hoàn tất các điểm dừng trước khi kết thúc chuyến.';

  @override
  String get rideEditStops => 'Sửa điểm dừng';

  @override
  String get rideEditStopsSave => 'Cập nhật lộ trình';

  @override
  String get rideEditStopsConfirmTitle => 'Đổi điểm dừng?';

  @override
  String get rideEditStopsConfirmBody =>
      'Đổi lộ trình sẽ xoá các đề nghị giá hiện tại của tài xế và tìm lại từ đầu.';

  @override
  String get rideEditStopsConfirmAction => 'Đổi lộ trình';

  @override
  String get rideEditStopsDone => 'Đã cập nhật lộ trình. Đang chờ đề nghị mới.';

  @override
  String get rideStopsNone => 'Chưa có điểm dừng';

  @override
  String mapPinStop(int n) {
    return 'Dừng $n';
  }

  @override
  String get paymentGroupWallet => 'Ví điện tử';

  @override
  String get paymentGroupCard => 'Thẻ tín dụng/ghi nợ';

  @override
  String get paymentGroupRecommended => 'Phương thức đề xuất';

  @override
  String get paymentGroupAddMore => 'Thêm phương thức';

  @override
  String get paymentCashLabel => 'Tiền mặt';

  @override
  String get paymentCashSubtitle => 'Trả trực tiếp cho tài xế';

  @override
  String get paymentStatusCash => 'Thanh toán tiền mặt';

  @override
  String get paymentStatusNotStarted => 'Chưa thanh toán';

  @override
  String get paymentStatusPending => 'Đang chờ xác nhận thanh toán';

  @override
  String get paymentStatusPaid => 'Thanh toán thành công';

  @override
  String get paymentStatusFailed => 'Thanh toán thất bại';

  @override
  String get paymentStatusExpired => 'Phiên thanh toán đã hết hạn';

  @override
  String get paymentStatusRefundPending => 'Đang hoàn tiền';

  @override
  String get paymentStatusRefunded => 'Đã hoàn tiền';

  @override
  String get paymentSheetTitle => 'Phương thức thanh toán';

  @override
  String get paymentClose => 'Đóng';

  @override
  String get paymentUnavailable => 'Không khả dụng';

  @override
  String get paymentChange => 'Đổi';

  @override
  String get paymentSessionExpired => 'Phiên đăng nhập đã hết hạn.';

  @override
  String get paymentStartFailed =>
      'Không khởi tạo được thanh toán. Bạn có thể thử lại hoặc trả tiền mặt.';

  @override
  String get paymentStatusLoadFailed => 'Không tải được trạng thái thanh toán.';

  @override
  String get paymentHeader => 'Thanh toán';

  @override
  String get paymentPreparing => 'Đang chuẩn bị thanh toán…';

  @override
  String get paymentPendingHint =>
      'Hoàn tất thanh toán trong ứng dụng ví/ngân hàng rồi quay lại DealGo. Trạng thái tự cập nhật.';

  @override
  String get paymentReopen => 'Mở lại trang thanh toán';

  @override
  String get paymentRetry => 'Thử lại';

  @override
  String get paymentSwitchToCash => 'Chuyển sang tiền mặt';

  @override
  String get paymentContinue => 'Tiếp tục';

  @override
  String get driverPaymentMethod => 'Phương thức thanh toán';

  @override
  String get driverPaidOnline => 'Đã thanh toán online';

  @override
  String driverPaidOnlineAmount(String amount) {
    return 'Đã thanh toán online $amount';
  }

  @override
  String get driverOnlinePaymentPending =>
      'Khách đang thanh toán online, chưa xác nhận';

  @override
  String get profilePhone => 'Số điện thoại';

  @override
  String get profilePhoneHint =>
      'Để tài xế và quán liên hệ khi giao hàng. Không cần mã xác minh.';

  @override
  String get profilePhoneInvalid =>
      'Số di động Việt Nam không hợp lệ (ví dụ 0901 234 567).';

  @override
  String get driverJobPushGone =>
      'Cuốc này đã bị huỷ hoặc đã có tài xế khác nhận.';

  @override
  String get incomingJobTitle => 'Cuốc xe mới';

  @override
  String get incomingJobSkip => 'Bỏ qua';

  @override
  String get incomingJobOpen => 'Xem & báo giá';

  @override
  String get driverStartTrip => 'Bắt đầu chuyến';

  @override
  String get rideOfferAcceptShort => 'Chấp nhận';

  @override
  String get rideOfferDeclineShort => 'Từ chối';

  @override
  String driverSendQuoteAmount(String amount) {
    return 'Gửi giá $amount';
  }

  @override
  String get driverWithdrawOfferShort => 'Rút giá';

  @override
  String get incomingJobDetails => 'Chi tiết';

  @override
  String get kycCaptureFrontTitle => 'Chụp mặt trước CCCD';

  @override
  String get kycCaptureBackTitle => 'Chụp mặt sau CCCD';

  @override
  String get kycCaptureAlignHint => 'Đặt thẻ vừa khung, đủ sáng, không lóa';

  @override
  String get kycCaptureChecking => 'Đang kiểm tra ảnh…';

  @override
  String get kycCaptureBlurry => 'Ảnh bị mờ';

  @override
  String get kycCaptureGlare => 'Ảnh bị lóa sáng';

  @override
  String get kycCaptureDark => 'Ảnh quá tối';

  @override
  String get kycCaptureRetake => 'Chụp lại';

  @override
  String get kycCaptureCameraError => 'Không mở được máy ảnh.';

  @override
  String get kycLivenessTitle => 'Xác thực khuôn mặt';

  @override
  String get kycLivenessCenter => 'Nhìn thẳng vào khung';

  @override
  String get kycLivenessTurnLeft => 'Quay mặt sang trái';

  @override
  String get kycLivenessTurnRight => 'Quay mặt sang phải';

  @override
  String get kycLivenessBlink => 'Chớp mắt';

  @override
  String get kycLivenessNoFace => 'Không thấy khuôn mặt';

  @override
  String get kycLivenessManyFaces => 'Chỉ một người trong khung';

  @override
  String get kycLivenessDone => 'Hoàn tất';

  @override
  String get kycLivenessTimeout => 'Hết thời gian, thử lại';

  @override
  String get kycHintFindCard => 'Đặt thẻ vào khung';

  @override
  String get kycHintCloser => 'Lại gần hơn';

  @override
  String get kycHintMoreLight => 'Thêm ánh sáng';

  @override
  String get kycHintNoGlare => 'Tránh lóa';

  @override
  String get kycHintHoldStill => 'Giữ yên';

  @override
  String get kycHintCaptured => 'Đã chụp';

  @override
  String get kycHintFaceInOval => 'Đưa mặt vào khung';

  @override
  String get kycLivenessRecording => 'Đang quay';

  @override
  String get partnerDocSelfieVideo => 'Video khuôn mặt';

  @override
  String get livenessClipRetry =>
      'Video khuôn mặt chưa lưu được (thiếu hoặc quá lớn). Thử lại nhé.';

  @override
  String get parcelWhereTo => 'Gửi hàng đến đâu?';

  @override
  String get driverServiceParcel => 'Giao hàng';

  @override
  String get driverServiceParcelHint => 'Nhận đơn chở hàng, giao bưu kiện';

  @override
  String get homeServiceParcel => 'Giao hàng';

  @override
  String get homeServiceParcelSub => 'Gửi hàng nội thành, nhanh chóng';

  @override
  String get parcelDetailsTitle => 'Thông tin gói hàng';

  @override
  String get parcelSizeTitle => 'Kích thước gói hàng';

  @override
  String parcelSizeHint(String dims) {
    return 'Tối đa $dims';
  }

  @override
  String get parcelSizeS => 'Nhỏ';

  @override
  String get parcelSizeM => 'Vừa';

  @override
  String get parcelSizeL => 'Lớn';

  @override
  String get parcelSizeXL => 'Rất lớn';

  @override
  String get parcelWeightLabel => 'Khối lượng (không bắt buộc)';

  @override
  String get parcelWeightInvalid => 'Nhập khối lượng hợp lệ';

  @override
  String parcelWeightOver(String limit) {
    return 'Vượt $limit kg cho kích thước này';
  }

  @override
  String get parcelNoteLabel => 'Ghi chú cho tài xế (không bắt buộc)';

  @override
  String get parcelSenderTitle => 'Người gửi';

  @override
  String get parcelRecipientTitle => 'Người nhận';

  @override
  String get parcelNameLabel => 'Họ tên';

  @override
  String get parcelPhoneLabel => 'Số điện thoại';

  @override
  String get parcelFieldRequired => 'Bắt buộc';

  @override
  String get parcelPhoneInvalid => 'Số điện thoại không hợp lệ';

  @override
  String get parcelPayerSender => 'Người gửi trả';

  @override
  String get parcelPayerRecipient => 'Người nhận trả';

  @override
  String get parcelItemPhotoAdd => 'Thêm ảnh gói hàng';

  @override
  String get parcelItemPhotoAdded => 'Đã thêm ảnh gói hàng';

  @override
  String get parcelVehicleTitle => 'Phương tiện';

  @override
  String parcelOptionHint(String min, String max) {
    return 'Trả giá $min – $max';
  }

  @override
  String get parcelQuoteCta => 'Xem giá';

  @override
  String get parcelSubmitCta => 'Đặt giao hàng';

  @override
  String get parcelDriverBadge => 'Gói hàng';

  @override
  String get parcelOutcomeDelivered => 'Đã giao';

  @override
  String get parcelOutcomeReturning => 'Đang hoàn về người gửi';

  @override
  String get parcelOutcomeReturned => 'Đã hoàn về người gửi';

  @override
  String get parcelOutcomeInTransit => 'Đang giao';

  @override
  String get parcelOutcomeWaitingPickup => 'Chờ lấy hàng';

  @override
  String get parcelFailUnreachable => 'Không liên lạc được người nhận';

  @override
  String get parcelFailRefused => 'Người nhận từ chối';

  @override
  String get parcelFailAddress => 'Sai địa chỉ';

  @override
  String get parcelFailDamaged => 'Hàng bị hư hỏng';

  @override
  String get parcelFailOther => 'Lý do khác';

  @override
  String get parcelFailTitle => 'Vì sao không giao được?';

  @override
  String get parcelErrorNoVehicle => 'Không có xe phù hợp cho kích thước này';

  @override
  String get parcelErrorTooHeavy => 'Gói hàng quá nặng so với kích thước';

  @override
  String get parcelErrorRecipientCode => 'Mã người nhận không đúng';

  @override
  String get parcelErrorCodeLocked => 'Nhập sai quá nhiều lần. Thử lại sau';

  @override
  String get parcelErrorSizeUnavailable => 'Kích thước này tạm không khả dụng';

  @override
  String get parcelErrorPayerMethod => 'Người nhận trả chỉ áp dụng tiền mặt';

  @override
  String get parcelErrorPhoto => 'Cần chụp ảnh';

  @override
  String get parcelErrorState => 'Đơn đã thay đổi trạng thái. Vui lòng tải lại';

  @override
  String get parcelErrorNetwork => 'Lỗi kết nối. Thử lại';

  @override
  String get parcelErrorGeneric => 'Đã có lỗi xảy ra';

  @override
  String get parcelRetry => 'Thử lại';

  @override
  String parcelSenderLine(String name, String phone) {
    return 'Người gửi: $name · $phone';
  }

  @override
  String parcelRecipientLine(String name, String phone) {
    return 'Người nhận: $name · $phone';
  }

  @override
  String parcelRecipientCode(String code) {
    return 'Mã nhận hàng: $code';
  }

  @override
  String get parcelRecipientCodeHint =>
      'Gửi mã này cho người nhận. Tài xế cần mã để hoàn tất giao hàng.';

  @override
  String get parcelPickupCta => 'Đã lấy hàng (chụp ảnh)';

  @override
  String get parcelReturningHint => 'Mang hàng hoàn về người gửi';

  @override
  String get parcelReturnedCta => 'Đã hoàn hàng (chụp ảnh)';

  @override
  String get parcelRecipientCodeInput => 'Mã người nhận';

  @override
  String get parcelDeliverCta => 'Đã giao (chụp ảnh)';

  @override
  String get parcelFailCta => 'Không giao được';

  @override
  String parcelServiceFeeLine(String amount) {
    return 'Phí dịch vụ $amount (đã gồm trong cước)';
  }

  @override
  String parcelReturnFeeLine(String amount) {
    return 'Phí hoàn hàng nếu giao không thành công: $amount';
  }

  @override
  String parcelReturnFeeCharged(String amount) {
    return 'Phí hoàn hàng $amount';
  }

  @override
  String get parcelReceiptServiceFee => 'Phí dịch vụ giao hàng (đã gồm)';

  @override
  String get parcelReceiptReturnFee => 'Phí hoàn hàng';

  @override
  String get driverServicesFoodMotorbikeOnly =>
      'Đơn đồ ăn chỉ dành cho tài xế xe máy.';

  @override
  String get partnerKindFoodSafetyCommitment =>
      'Bản cam kết bảo đảm an toàn thực phẩm';

  @override
  String get partnerFoodSafetyUseCommitment => 'Dùng bản cam kết ATTP';

  @override
  String get partnerFoodSafetyUseCommitmentHint =>
      'Hộ kinh doanh nhỏ được nộp bản cam kết bảo đảm ATTP thay cho giấy chứng nhận.';

  @override
  String get kycOcrPrefilledNote =>
      'Một số thông tin đã được điền tự động từ ảnh giấy tờ. Vui lòng kiểm tra và sửa nếu sai.';

  @override
  String get kycOcrReading => 'Đang đọc thông tin giấy tờ…';

  @override
  String get parcelPickContact => 'Chọn từ danh bạ';

  @override
  String get parcelEditRoute => 'Sửa lộ trình';

  @override
  String get parcelEdit => 'Sửa';

  @override
  String get parcelMoreDetails => 'Cân nặng, ghi chú, ảnh (không bắt buộc)';

  @override
  String get parcelPricing => 'Đang lấy giá…';

  @override
  String get parcelSectionPackage => 'Gói hàng';

  @override
  String get parcelSectionPayment => 'Thanh toán';

  @override
  String get parcelFareLabel => 'Giá cước';

  @override
  String get parcelPhoneHint => '0901 234 567';

  @override
  String get parcelSenderYou => 'Bạn';

  @override
  String get parcelPayerRecipientNote =>
      'Người nhận trả tiền mặt cho tài xế khi nhận hàng.';

  @override
  String parcelSubmitWithPrice(String price) {
    return 'Đặt giao · $price';
  }

  @override
  String get apiErrCrossRegion =>
      'Hiện DealGo chưa hỗ trợ chuyến đi liên tỉnh giữa hai khu vực. Vui lòng chọn điểm đến trong cùng thành phố với điểm đón.';

  @override
  String get apiErrDriverAtCapacity =>
      'Tài xế đang có chuyến, hoàn thành chuyến hiện tại trước khi nhận cuốc mới.';

  @override
  String get apiErrDriverTooFar =>
      'Bạn đang ở quá xa điểm đón. Hãy di chuyển gần hơn rồi thử lại.';

  @override
  String get apiErrOfferDriverUnavailable =>
      'Tài xế này vừa nhận cuốc khác. Vui lòng chọn tài xế khác.';

  @override
  String get apiErrItemNotApproved =>
      'Món này đang chờ duyệt nên chưa thể mở bán.';

  @override
  String get rideIntercity => 'Liên tỉnh';

  @override
  String rideIntercityQuote(String km, String minutes) {
    return 'Chuyến liên tỉnh · $km km · ≈$minutes phút';
  }

  @override
  String get rideIntercityNote =>
      'Điểm đến ở tỉnh/khu vực khác. Tài xế trả giá như chuyến thường.';

  @override
  String driverPickupAwayKm(String km) {
    return 'Cách $km km';
  }

  @override
  String get driverServiceSettings => 'Cài đặt dịch vụ';

  @override
  String get rideGoHome => 'Về trang chủ';

  @override
  String get apiErrIntercityStops =>
      'Chuyến liên tỉnh chỉ đi thẳng tới một điểm đến, không thêm điểm dừng.';

  @override
  String get apiErrIntercityTooFar =>
      'Quãng đường liên tỉnh dài hơn mức DealGo đang hỗ trợ.';

  @override
  String get apiErrIntercityVehicle =>
      'Loại xe này không chạy liên tỉnh. Vui lòng chọn loại xe khác.';

  @override
  String get apiErrIntercityNoVehicle =>
      'Hiện chưa có loại xe nào chạy liên tỉnh.';

  @override
  String driverJobTripKm(String km) {
    return 'Chuyến $km km';
  }

  @override
  String driverJobPickupKm(String km) {
    return 'Cách điểm đón $km km';
  }

  @override
  String get appUpdateRequiredTitle => 'Cập nhật bắt buộc';

  @override
  String get appUpdateRequiredBody =>
      'Phiên bản bạn đang dùng đã cũ. Vui lòng cập nhật lên bản mới nhất để tiếp tục sử dụng DealGo.';

  @override
  String get appUpdateNow => 'Cập nhật ngay';

  @override
  String appUpdateLatest(String version) {
    return 'Phiên bản mới: $version';
  }

  @override
  String get appUpdateOptionalTitle => 'Đã có phiên bản mới';

  @override
  String get appUpdateOptionalBody =>
      'Cập nhật để dùng tính năng và bản sửa lỗi mới nhất.';

  @override
  String get appUpdateLater => 'Để sau';

  @override
  String get appUpdateRetry => 'Kiểm tra lại';

  @override
  String get legalConsentTitle => 'Điều khoản đã được cập nhật';

  @override
  String get legalConsentBody =>
      'Vui lòng đọc và đồng ý với nội dung mới để tiếp tục sử dụng DealGo.';

  @override
  String get legalConsentRead => 'Xem nội dung đầy đủ';

  @override
  String legalConsentEffective(String date) {
    return 'Hiệu lực từ $date';
  }

  @override
  String legalConsentVersion(String version) {
    return 'phiên bản $version';
  }

  @override
  String get legalConsentAgree => 'Tôi đồng ý';

  @override
  String get legalConsentFailed => 'Không gửi được. Vui lòng thử lại.';

  @override
  String contactPhoneDial(String phone) {
    return 'Gọi điện $phone';
  }

  @override
  String get contactPhoneDialFailed => 'Không mở được ứng dụng gọi điện.';

  @override
  String get kycReviewAvatar => 'Ảnh đại diện';

  @override
  String get kycAvatarMissing =>
      'Bắt buộc trước khi nộp. Khách hàng sẽ thấy ảnh này khi bạn nhận cuốc.';

  @override
  String get kycAvatarReady => 'Khách hàng sẽ thấy ảnh này khi bạn nhận cuốc.';

  @override
  String get kycAvatarAdd => 'Thêm ảnh';

  @override
  String get partnerErrorAvatar =>
      'Bạn cần thêm ảnh đại diện trong hồ sơ trước khi nộp hồ sơ tài xế.';

  @override
  String offlineJobUpdatedAt(String time) {
    return 'Cập nhật lúc $time · đang mất kết nối';
  }

  @override
  String get offlineJobCallHint =>
      'Không có mạng vẫn gọi điện thoại thường được.';

  @override
  String get legalRegulationsTitle => 'Quy chế sử dụng';

  @override
  String get legalRegulationsBody => 'Dành cho tài xế và cửa hàng đối tác';

  @override
  String get legalTermsTitle => 'Điều khoản sử dụng';

  @override
  String get legalTermsBody => 'Quyền và nghĩa vụ khi sử dụng DealGo';

  @override
  String get legalPrivacyTitle => 'Chính sách bảo mật';

  @override
  String get legalPrivacyBody =>
      'Cách DealGo thu thập và bảo vệ dữ liệu của bạn';

  @override
  String get legalLoadError => 'Không tải được nội dung. Vui lòng thử lại.';

  @override
  String get partnerConsentTitle => 'Điều khoản đăng ký đối tác';

  @override
  String get partnerConsentRegulations =>
      'Tôi đã đọc và đồng ý với Quy chế sử dụng';

  @override
  String get partnerConsentPrivacy =>
      'Tôi đã đọc và đồng ý với Chính sách bảo mật';

  @override
  String get partnerConsentView => 'Xem';

  @override
  String get partnerConsentHint => 'Bạn cần đồng ý cả hai mục để gửi hồ sơ.';

  @override
  String get partnerConsentLoadError =>
      'Không tải được điều khoản — chạm để thử lại';

  @override
  String get partnerErrorLegalConsent =>
      'Quy chế sử dụng hoặc Chính sách bảo mật vừa được cập nhật. Vui lòng đọc và đồng ý lại.';

  @override
  String get foodFareSuggested => 'Phí giao gợi ý';

  @override
  String get foodFareYourOffer => 'Bạn đề nghị';

  @override
  String get foodFareFixedWaiting =>
      'Tài xế chỉ có thể nhận đúng mức phí bạn đưa ra. Nếu chờ lâu, hãy tăng phí để đơn hấp dẫn hơn.';

  @override
  String get driverFareFixed =>
      'Đơn này áp dụng giá cố định: bạn chỉ có thể nhận đúng phí khách đưa ra.';

  @override
  String get foodFareDecrease => 'Giảm phí giao';

  @override
  String get foodFareIncrease => 'Tăng phí giao';

  @override
  String get foodFareReset => 'Dùng phí gợi ý';

  @override
  String get foodFareNegotiationTitle => 'Phí giao';

  @override
  String foodFareWaiting(String amount) {
    return 'Đang chờ tài xế nhận giá $amount';
  }

  @override
  String foodFareAgreed(String amount) {
    return 'Phí giao đã chốt: $amount';
  }

  @override
  String get foodFareOffersEmpty => 'Chưa có tài xế đề xuất giá khác.';

  @override
  String get foodFareDriverOffer => 'Tài xế đề xuất';

  @override
  String get foodFareSelect => 'Chọn';

  @override
  String foodFareRaise(String amount) {
    return 'Tăng lên $amount';
  }

  @override
  String foodFareRaisesLeft(int count) {
    return 'Còn $count lần tăng giá';
  }

  @override
  String get foodFareOfferExpired => 'Hết hạn';

  @override
  String get foodFareSelectFailed =>
      'Không chọn được đề xuất này. Có thể đề xuất đã hết hạn hoặc tài xế đã nhận đơn khác.';

  @override
  String get foodFareRaiseFailed => 'Chưa tăng được phí giao. Thử lại sau.';

  @override
  String get foodFareCodExtra =>
      'Nếu phí giao chốt cao hơn số đã thanh toán trực tuyến, phần chênh lệch thu tiền mặt khi nhận hàng.';

  @override
  String get driverFareCounter => 'Đề xuất giá';

  @override
  String get driverFareCounterTitle => 'Đề xuất phí giao';

  @override
  String driverFareCustomerOffer(String amount) {
    return 'Khách trả $amount';
  }

  @override
  String driverFareCounterSend(String amount) {
    return 'Gửi đề xuất $amount';
  }

  @override
  String get driverFareCounterSent => 'Đã gửi đề xuất. Chờ khách chọn.';

  @override
  String get driverFareCounterFailed => 'Chưa gửi được đề xuất.';

  @override
  String get merchantFareAgreed => 'Phí giao (đã thoả thuận)';

  @override
  String get driverCreditTitle => 'Số dư tạm ứng';

  @override
  String get driverCreditSubtitle =>
      'Chỉ dùng để trừ phí nền tảng. Không rút và không chuyển cho người khác.';

  @override
  String get driverCreditBalance => 'Số dư tạm ứng';

  @override
  String get driverCreditOwes => 'Công nợ phí';

  @override
  String get driverCreditBlocked =>
      'Công nợ phí đã vượt hạn mức. Bạn sẽ không nhận được chuyến mới cho đến khi nạp thêm.';

  @override
  String get driverCreditNearLimit =>
      'Công nợ phí sắp chạm hạn mức. Nạp thêm để tiếp tục nhận chuyến.';

  @override
  String get driverCreditDisabled =>
      'Tính năng nạp tiền chưa mở. Vui lòng thử lại sau.';

  @override
  String get driverCreditAmount => 'Số tiền nạp';

  @override
  String driverCreditAmountRange(String min, String max) {
    return 'Từ $min đến $max';
  }

  @override
  String get driverCreditTopUp => 'Nạp tiền';

  @override
  String get driverCreditPending => 'Đang chờ thanh toán';

  @override
  String driverCreditRemaining(String amount) {
    return 'Còn $amount';
  }

  @override
  String get driverCreditOpenCheckout => 'Mở trang thanh toán';

  @override
  String get driverCreditCancelTopUp => 'Huỷ lệnh nạp này';

  @override
  String get driverCreditChecking => 'Đang kiểm tra thanh toán…';

  @override
  String get driverCreditPaidHint =>
      'Đã thanh toán. Số tiền đã vào số dư tạm ứng.';

  @override
  String get driverCreditRecent => 'Lịch sử nạp tiền';

  @override
  String get driverCreditEmpty => 'Chưa có lần nạp nào.';

  @override
  String get driverCreditLoading => 'Đang tải số dư…';

  @override
  String get driverCreditCardTitle => 'Nạp phí';

  @override
  String get driverCreditCardBody =>
      'Giữ công nợ phí ở mức 0 để tiếp tục nhận chuyến.';

  @override
  String get driverCreditStatusPending => 'Chờ thanh toán';

  @override
  String get driverCreditStatusPaid => 'Đã cộng';

  @override
  String get driverCreditStatusExpired => 'Hết hạn';

  @override
  String get driverCreditStatusCancelled => 'Đã huỷ';

  @override
  String get driverCreditStatusRefundPending => 'Đang hoàn tiền';

  @override
  String get driverCreditStatusRefunded => 'Đã hoàn tiền';

  @override
  String get driverCreditStatusFailed => 'Thất bại';

  @override
  String get driverCreditErrorGeneric =>
      'Chưa nạp được tiền. Vui lòng thử lại.';

  @override
  String get driverCreditErrorPending =>
      'Bạn đang có một lệnh nạp chờ thanh toán.';

  @override
  String get driverCreditErrorDailyLimit => 'Đã đạt hạn mức nạp trong ngày.';

  @override
  String get driverCreditErrorCreditLimit => 'Đã đạt hạn mức số dư tạm ứng.';

  @override
  String get driverCreditErrorAmount => 'Số tiền nằm ngoài khoảng cho phép.';

  @override
  String get driverCreditErrorKyc =>
      'Cần hồ sơ KYC đã duyệt trước khi nạp tiền.';

  @override
  String get driverCreditErrorDisabled => 'Tính năng nạp tiền chưa mở.';

  @override
  String get driverCreditErrorProvider =>
      'Cổng thanh toán hiện không khả dụng.';

  @override
  String get driverCreditScanHint =>
      'Mở app ngân hàng và quét mã QR này. Số tiền đã được điền sẵn.';

  @override
  String get driverCreditOrderCode => 'Mã đơn';

  @override
  String driverCreditExpiresIn(String time) {
    return 'Còn $time';
  }

  @override
  String get driverCreditDetailTitle => 'Chi tiết lệnh nạp';

  @override
  String get driverCreditCopyCode => 'Sao chép mã đơn';

  @override
  String get driverCreditCopied => 'Đã sao chép mã đơn.';

  @override
  String get driverCreditPaymentReceived => 'Đã nhận thanh toán';

  @override
  String driverCreditPaymentReceivedBody(String amount) {
    return 'Đã cộng $amount vào số dư tạm ứng.';
  }

  @override
  String get driverCreditLinkExpired =>
      'Lệnh thanh toán này không còn hiệu lực.';

  @override
  String get driverCreditCreateNew => 'Tạo lệnh nạp mới';

  @override
  String get driverCreditAppliedFees => 'Đã cấn trừ phí';

  @override
  String get driverCreditRefundedAmount => 'Đã hoàn';

  @override
  String get driverCreditMethod => 'Phương thức thanh toán';

  @override
  String get driverCreditCreatedAt => 'Tạo lúc';

  @override
  String get driverCreditPaidAt => 'Thanh toán lúc';

  @override
  String get driverCreditClose => 'Đóng';

  @override
  String get driverCreditWaitingBank =>
      'Số dư tự cập nhật khi ngân hàng xác nhận.';
}
