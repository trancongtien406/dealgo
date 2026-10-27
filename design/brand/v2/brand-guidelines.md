# DealGo Brand v2 — Deal in motion

## Ý tưởng

Biểu tượng là chữ **D đang chuyển động**, kết hợp một tuyến đường ba điểm. Ba điểm gợi điểm đón, điểm đến và sự kết nối giữa Customer–Driver–Merchant; chúng không đại diện cho một workflow nghiệp vụ cố định. Hình khối đơn giản để nhận diện được ở kích thước app icon, favicon và header.

## Hệ màu

- Tím `#6D28D9`: màu nhận diện chính, liên tưởng đến lựa chọn và thương lượng.
- Xanh `#16A34A`: chuyển động tích cực, hoàn tất và Food.
- Cam `#F97316`: điểm nhấn Food/trạng thái; không dùng làm màu logo chủ đạo.
- Ink `#171B2C` và canvas `#FBFAFD`: nền trung tính dùng xuyên web/app.

## Quy tắc dùng logo

- Dùng `logo-primary.svg` trên nền sáng và `logo-reversed.svg` trên nền tối/ảnh đậm.
- Dùng `mark.svg` cho app icon, favicon, avatar sản phẩm và không gian dưới 112 px chiều ngang.
- Khoảng trống an toàn tối thiểu bằng 1/4 chiều rộng mark ở mọi phía.
- Mark không nhỏ hơn 24 px; lockup không nhỏ hơn 112 px trên màn hình.
- Không đổi màu riêng lẻ, thêm shadow/glow, kéo méo, xoay, đặt trực tiếp lên vùng ảnh nhiều chi tiết hoặc tự dựng lại wordmark bằng font UI khác.
- Bản `logo-mono.svg` dành cho in một màu, watermark hoặc tài liệu pháp lý.

## Banner

Artwork `banner-web-hero.png` không chứa chữ hoặc nút. Headline, CTA và badge phải được render bằng UI để bảo đảm accessibility, responsive và localization. Vùng trái khoảng 42% được dành cho nội dung; chủ thể nằm bên phải. Chỉ mô tả hai vertical đã xác nhận: Ride hai bánh và Food.

Với mobile, ưu tiên crop theo container thay vì ép co toàn bộ ảnh. Ở khung hẹp, anchor chủ thể về `70% center`; nếu chữ phủ trên ảnh phải có scrim bảo đảm contrast. Không dùng artwork này làm bằng chứng về khu vực hoạt động, đồng phục thật hoặc phương tiện được phê duyệt.

## Typography

Be Vietnam Pro là đề xuất chung cho UI vì mobile đã self-host và hỗ trợ tiếng Việt tốt. Wordmark trong SVG dùng font stack để preview; trước khi phát hành file in ấn hoặc gửi đối tác, chuyển chữ thành outline để kết quả không phụ thuộc máy người nhận.

## Checklist nghiệm thu

- Kiểm tra mark ở 16/24/32/48 px và launcher mask iOS/Android.
- Kiểm tra logo trên nền trắng, tím sâu, grayscale và ảnh banner.
- Kiểm tra crop banner tại 360, 390, 768 và 1440 px; giữ mặt người và xe ngoài vùng headline.
- Kiểm tra long Vietnamese copy, text scaling và dark mode.
- Không dùng nội dung ô tô, đi chợ hoặc dịch vụ chưa nằm trong scope đã xác nhận.
