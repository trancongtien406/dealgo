# DealGo Web Admin — Screen Inventory & Mockups

> Thư mục tài nguyên thiết kế UI cho **Kênh Web Quản trị (Admin Dashboard)** của DealGo.
> Triển khai thực tế trên Next.js 16 tại [`website/`](../../../../website/).

## 1. Thông số thiết kế chuẩn (Admin Design Tokens)

- **Độ phân giải chuẩn:** `1600 × 1180 px` (Desktop viewport).
- **Màu sắc chủ đạo:**
  - Primary Purple: `#6D28D9` / `#6525C9`
  - Secondary Green: `#16A34A` / `#11803E`
  - Khung nền chính (Canvas): `#F8F8FD` / `#F7F7FC`
  - Đường viền (Border): `#E7E3EF` / `#EFEAF6`
  - Text chính: `#171B2C` / `#101437`
  - Text phụ / Muted: `#787C99` / `#81869E`
- **Typography:** Font `Inter`, `Noto Sans`, `sans-serif`.
- **Cấu trúc layout:**
  - **Sidebar trái:** Cố định `238px`, chứa thương hiệu DealGo, menu 15 phân hệ điều hướng và trạng thái chọn.
  - **Header trên:** Cố định `64px`, chứa thanh tìm kiếm toàn cục (`570px`), chuông thông báo, avatar & tên tài khoản quản trị viên.
  - **Khu vực nội dung (Main):** Độ rộng `1362px`, bao gồm Breadcrumb, Tiêu đề trang + Mô tả, Toolbar tác vụ nhanh, KPI cards và bảng dữ liệu / biểu đồ.

---

## 2. Bảng kiểm kê 35 màn hình Admin (A001 – A035)

| Mã | Tên màn hình / Phân hệ | Mockup PNG (`design/`) | Kích thước | Trạng thái |
|:---:|---|:---:|:---:|:---:|
| **A001** | Đăng nhập quản trị | [`A001_dang_nhap_quan_tri.png`](A001_dang_nhap_quan_tri.png) | 1600×1180 | Đã có mockup PNG |
| **A002** | Quên và đặt lại mật khẩu | [`A002_quen_va_dat_lai_mat_khau.png`](A002_quen_va_dat_lai_mat_khau.png) | 1600×1180 | Đã có mockup PNG |
| **A003** | Dashboard tổng quan vận hành | [`A003_dashboard_tong_quan.png`](A003_dashboard_tong_quan.png) | 1600×1180 | Đã có mockup PNG |
| **A004** | Giám sát vận hành trực tiếp | [`A004_giam_sat_van_hanh_truc_tiep.png`](A004_giam_sat_van_hanh_truc_tiep.png) | 1600×1180 | Đã có mockup PNG |
| **A005** | Danh sách chuyến xe | [`A005_danh_sach_chuyen_xe.png`](A005_danh_sach_chuyen_xe.png) | 1600×1180 | Đã có mockup PNG |
| **A006** | Chi tiết chuyến xe | [`A006_chi_tiet_chuyen_xe.png`](A006_chi_tiet_chuyen_xe.png) | 1600×1180 | Đã có mockup PNG |
| **A007** | Danh sách phiên trả giá | [`A007_danh_sach_phien_tra_gia.png`](A007_danh_sach_phien_tra_gia.png) | 1600×1180 | Đã có mockup PNG |
| **A008** | Chi tiết phiên trả giá | [`A008_chi_tiet_phien_tra_gia.png`](A008_chi_tiet_phien_tra_gia.png) | 1600×1180 | Đã có mockup PNG |
| **A009** | Danh sách đơn đồ ăn | [`A009_danh_sach_don_do_an.png`](A009_danh_sach_don_do_an.png) | 1600×1180 | Đã có mockup PNG |
| **A010** | Chi tiết đơn đồ ăn | [`A010_chi_tiet_don_do_an.png`](A010_chi_tiet_don_do_an.png) | 1600×1180 | Đã có mockup PNG |
| **A011** | Danh sách đơn giao hàng | [`A011_danh_sach_don_giao_hang.png`](A011_danh_sach_don_giao_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A012** | Chi tiết đơn giao hàng | [`A012_chi_tiet_don_giao_hang.png`](A012_chi_tiet_don_giao_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A013** | Danh sách yêu cầu dịch vụ A/C | [`A013_danh_sach_yeu_cau_dich_vu_a_c.png`](A013_danh_sach_yeu_cau_dich_vu_a_c.png) | 1600×1180 | Đã có mockup PNG |
| **A014** | Chi tiết yêu cầu dịch vụ A/C | [`A014_chi_tiet_yeu_cau_dich_vu_a_c.png`](A014_chi_tiet_yeu_cau_dich_vu_a_c.png) | 1600×1180 | Đã có mockup PNG |
| **A015** | Danh sách khách hàng | [`A015_danh_sach_khach_hang.png`](A015_danh_sach_khach_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A016** | Chi tiết khách hàng | [`A016_chi_tiet_khach_hang.png`](A016_chi_tiet_khach_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A017** | Danh sách tài xế | [`A017_danh_sach_tai_xe.png`](A017_danh_sach_tai_xe.png) | 1600×1180 | Đã có mockup PNG |
| **A018** | Chi tiết tài xế | [`A018_chi_tiet_tai_xe.png`](A018_chi_tiet_tai_xe.png) | 1600×1180 | Đã có mockup PNG |
| **A019** | Duyệt hồ sơ KYC tài xế | [`A019_duyet_ho_so_kyc_tai_xe.png`](A019_duyet_ho_so_kyc_tai_xe.png) | 1600×1180 | Đã có mockup PNG |
| **A020** | Danh sách cửa hàng | [`A020_danh_sach_cua_hang.png`](A020_danh_sach_cua_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A021** | Chi tiết cửa hàng | [`A021_chi_tiet_cua_hang.png`](A021_chi_tiet_cua_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A022** | Duyệt hồ sơ cửa hàng (KYB) | [`A022_duyet_ho_so_cua_hang.png`](A022_duyet_ho_so_cua_hang.png) | 1600×1180 | Đã có mockup PNG |
| **A023** | Kiểm duyệt sản phẩm và thực đơn | [`A023_kiem_duyet_san_pham_va_thuc_don.png`](A023_kiem_duyet_san_pham_va_thuc_don.png) | 1600×1180 | Đã có mockup PNG |
| **A024** | Danh sách giao dịch tài chính | [`A024_danh_sach_giao_dich.png`](A024_danh_sach_giao_dich.png) | 1600×1180 | Đã có mockup PNG |
| **A025** | Đối soát và thanh toán đối tác | [`A025_doi_soat_va_thanh_toan_doi_tac.png`](A025_doi_soat_va_thanh_toan_doi_tac.png) | 1600×1180 | Đã có mockup PNG |
| **A026** | Xử lý hoàn tiền | [`A026_xu_ly_hoan_tien.png`](A026_xu_ly_hoan_tien.png) | 1600×1180 | Đã có mockup PNG |
| **A027** | Danh sách khiếu nại và tranh chấp | [`A027_danh_sach_khieu_nai_va_tranh_chap.png`](A027_danh_sach_khieu_nai_va_tranh_chap.png) | 1600×1180 | Đã có mockup PNG |
| **A028** | Chi tiết xử lý khiếu nại & tranh chấp | [`A028_chi_tiet_xu_ly_khieu_nai_tranh_chap.png`](A028_chi_tiet_xu_ly_khieu_nai_tranh_chap.png) | 1600×1180 | Đã có mockup PNG |
| **A029** | Quản lý khuyến mãi | [`A029_quan_ly_khuyen_mai.png`](A029_quan_ly_khuyen_mai.png) | 1600×1180 | Đã có mockup PNG |
| **A030** | Quản lý danh mục | [`A030_quan_ly_danh_muc.png`](A030_quan_ly_danh_muc.png) | 1600×1180 | Đã có mockup PNG |
| **A031** | Thông báo và CMS | [`A031_thong_bao_va_cms.png`](A031_thong_bao_va_cms.png) | 1600×1180 | Đã có mockup PNG |
| **A032** | Thống kê và phân tích | [`A032_thong_ke_va_phan_tich.png`](A032_thong_ke_va_phan_tich.png) | 1600×1180 | Đã có mockup PNG |
| **A033** | Khu vực hoạt động và quy tắc giá | [`A033_khu_vuc_hoat_dong_va_quy_tac_gia.png`](A033_khu_vuc_hoat_dong_va_quy_tac_gia.png) | 1600×1180 | Đã có mockup PNG |
| **A034** | Nhân sự và phân quyền | [`A034_nhan_su_va_phan_quyen.png`](A034_nhan_su_va_phan_quyen.png) | 1600×1180 | Đã có mockup PNG |
| **A035** | Cấu hình và nhật ký hệ thống | [`A035_cau_hinh_va_nhat_ky_he_thong.png`](A035_cau_hinh_va_nhat_ky_he_thong.png) | 1600×1180 | Đã có mockup PNG |

---

## 3. Quy cách tệp Mockup PNG

- Toàn bộ 35 màn hình quản trị (`A001_dang_nhap_quan_tri.png` đến `A035_cau_hinh_va_nhat_ky_he_thong.png`) đều được đặt trực tiếp tại thư mục này với quy ước đặt tên chuẩn `snake_case`.
- Định dạng ảnh: PNG kích thước `1600 × 1180 px`, tối ưu hóa độ nét cao cho màn hình Desktop.
- Ngoài ra, các ảnh đối soát gốc `image-gen-1(9).png`, `image-gen-2(3).png`, `image-gen-3(3).png` và ảnh bản đồ giám sát `map_danang_cropped.png` cũng được lưu trữ phục vụ đối chiếu.

## 4. Hướng dẫn sử dụng cho Developer Web (`website/`)

1. Mở trực tiếp các file ảnh mockup PNG để tham chiếu thiết kế UI pixel-perfect, màu sắc, khoảng cách và bố cục component của từng trang quản trị.
2. Tham chiếu mã màn hình (`A001` – `A035`) khi xây dựng các route tương ứng trong Next.js App Router (`website/app/admin/...`).
3. Dữ liệu hiển thị trong mockup là dữ liệu mẫu giả định (fixtures), không phải dữ liệu vận hành thật hay bí mật hệ thống.
