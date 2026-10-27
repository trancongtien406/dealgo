---
title: "DealGo — Use Case Catalog / Danh mục kịch bản sử dụng"
document_id: "DOC-PRD-UC-001"
version: "0.2.0"
status: "DRAFT"
updated_at: "2026-10-12"
owner_role: "Product / Business Analysis"
review_roles: ["Product Owner", "Tech Lead", "Mobile Lead", "Operations", "Finance", "Security/Legal", "QA"]
product: "DealGo"
scope: ["Ride (xe máy, ô tô)", "Food", "Customer", "Merchant", "Driver", "Admin Web"]
predecessors:
  - "../00-governance/README.md"
  - "../00-governance/project-charter.md"
  - "../00-governance/scope-release-plan.md"
  - "../00-governance/glossary.md"
  - "../00-governance/decisions-and-assumptions.md"
  - "./product-requirements.md"
  - "./competitor-benchmark.md"
  - "./personas-and-stakeholders.md"
---

# DealGo — Use Case Catalog / Danh mục kịch bản sử dụng

> **Trạng thái: DRAFT — tài liệu thiết kế và kiểm thử, không phải thông báo đã phê duyệt chính sách kinh doanh.** Cấu hình thời gian, bán kính, số job, giá, trách nhiệm bồi hoàn, chứng cứ giao nhận, chính sách tracking và thanh toán hiện phụ thuộc các `OPEN-001..021` theo Governance. Ví dụ trong file dùng fixture môi trường kiểm thử, tuyệt đối không được suy diễn thành policy production.

## 1. Mục tiêu, phạm vi và định nghĩa hoàn thành

### 1.1. Mục tiêu

- Chuyển **71 yêu cầu chức năng `FR-*` trong PRD** thành danh mục hành vi quan sát được, và bổ sung **12 use case xuyên vai trò** để không bỏ lỡ điểm bàn giao Ride/Food.
- Làm rõ actor, trigger, tiền/hậu điều kiện, các cam kết tối thiểu nếu thất bại, luồng chính, ngoại lệ, bằng chứng nghiệm thu và policy blocker.
- Là **cầu nối** giữa PRD → quy tắc nghiệp vụ `BR-*` → workflow `WF-*` → UI `SCR-*` → API/event → kiểm thử `TC-*`, nhưng **không thay thế** những đặc tả chuyên trách.
- Cung cấp bộ khung cho Product Owner, UX, QA, Backend, Flutter và AI Agent chia công việc thành vertical slice có thể kiểm chứng.

### 1.2. Phạm vi đã được xác nhận

- `DEC-PROD-001`: MVP có hai dịch vụ **Ride (xe máy, ô tô theo `DG-DEC-VEH-001`)** và **Food**; không tự thêm giao kiện hàng riêng thành P0.
- `DEC-PROD-002`: **một ứng dụng Flutter** hỗ trợ Customer, Merchant, Driver thông qua role/eligibility phù hợp; **Admin Web** là bề mặt quản trị riêng.
- `DEC-PROD-003`: học quy trình công khai từ Grab/GrabFood/ShopeeFood; không coi giả định về logic nội bộ đối thủ là yêu cầu DealGo.
- `DEC-PROD-004`: yêu cầu bao gồm khả năng chạy thực, xử lý lỗi, kiểm thử, bảo mật và vận hành chứ không chỉ những màn hình đẹp.

### 1.3. Không thuộc phạm vi mặc định

- Ride bốn bánh, giao bưu kiện độc lập, hàng hóa có quy định chuyên ngành đặc biệt, booking theo hợp đồng doanh nghiệp, ví điện tử tự phát hành, loyalty nâng cao và tối ưu dispatch bằng ML không được tự thêm vào P0.
- Những thứ có thể học từ đối thủ như surge pricing, nhóm đơn, đa cửa hàng cùng một giỏ, ví tiền, chat trực tiếp **không tự động là feature đã được duyệt**.
- Quy trình này mô tả hệ thống mục tiêu, **không** khẳng định các tính năng đã được triển khai hoặc được phép khai thác thương mại.

### 1.4. Sản phẩm bàn giao

- 71 UC mức goal/subfunction bám PRD, 12 UC E2E xuyên role; có bảng truy vết kiểm tra tự động.
- Các use case rủi ro cao có đặc tả **fully dressed** chi tiết và ví dụ tình huống kiểm thử.
- Chỉ mục policy blockers, ma trận release gate, tình huống lỗi, điều kiện để chi tiết hóa use case còn lại khi bắt đầu code.

## 2. Nguồn sự thật và thứ tự ưu tiên

1. Quyết định đã xác nhận: `../00-governance/decisions-and-assumptions.md`.
2. Phạm vi, nhãn P0/P1/P2 và release gate: `../00-governance/scope-release-plan.md`.
3. Yêu cầu sản phẩm và business invariants: `./product-requirements.md`.
4. Thuật ngữ như `RideRequest`, `Trip`, `FoodOrder`, `DeliveryTask`, `FareCounterOffer`, `DispatchOffer`, `AcceptedFareAgreement`, `Quote`, `Ledger`: `../00-governance/glossary.md`.
5. Persona và customer/partner journey: `./personas-and-stakeholders.md`.
6. File này là *catalog + scenario specification*, không được override nguồn 1–4. Khi mâu thuẫn: ghi issue + mở quyết định; **không chọn quy tắc theo ý agent**.

**Không tự sáng tạo** mã `BR-*`, `WF-*`, `SCR-*`, `API-*`, `EVT-*`, `TC-*` cho artifact chưa tồn tại. Liên kết mang nhãn `[PLANNED]` là đường dẫn docs dự kiến, **không** khẳng định file đã có trên disk.

## 3. Phương pháp viết Use Case

### 3.1. Cấp độ, ranh giới và định dạng

- **Summary:** kết quả nghiệp vụ xuyên nhiều actor, ví dụ `UC-X-002` hoàn tất một FoodOrder.
- **User goal:** người dùng hoàn thành một mục đích trọn vẹn, ví dụ xác nhận đặt xe (`UC-RIDE-003`).
- **Subfunction:** năng lực hỗ trợ luồng chính như kiểm quyền dữ liệu (`UC-CORE-010`). Một số `FR-CORE-*` được catalog như *service/quality enabling scenarios*, không nhầm đây là một màn hình UX độc lập.
- Viết **actor ↔ hệ thống** (black-box) ở mức business; endpoint, queue, DB/locking thuộc docs kiến trúc/API chuyên trách.
- Mọi use case chủ động có `success guarantee` và `minimal guarantee`; failure path không được tự biến thành completed/captured/settled.
- Mỗi bước `MSS` chỉ tường thuật một tình huống đúng; điều kiện tách thành `EX-`/extension; không nhét tất cả nhánh vào một bước.

**Cơ sở phương pháp:** Alistair Cockburn, *Writing Effective Use Cases* (fully dressed, user-goal và extensions) và OMG UML 2.5.1 use-case model. Các link chuẩn ở mục 19.

### 3.2. Quy ước định danh

| Ký hiệu | Định nghĩa | Ví dụ |
|---|---|---|
| `UC-CORE-NNN` | Dùng chung: account, authorization, notification, finance | `UC-CORE-006` |
| `UC-RIDE-NNN` | Nhu cầu Customer với Ride | `UC-RIDE-003` |
| `UC-FOOD-NNN` | Nhu cầu Customer với Food | `UC-FOOD-005` |
| `UC-MER-NNN` | Nhu cầu Merchant | `UC-MER-005` |
| `UC-DRV-NNN` | Nhu cầu Driver | `UC-DRV-004` |
| `UC-OPS-NNN` | Nhu cầu Admin/Operations | `UC-OPS-004` |
| `UC-X-NNN` | Hành trình xuyên actor, system integration hoặc reliability | `UC-X-002` |
| `MSS-N` | Bước trong luồng chính (main success scenario) | `MSS-3` |
| `EX-N[a-z]` | Nhánh thay thế/lỗi từ bước MSS tương ứng | `EX-4a` |
| `AC-UC-...` | Nhãn local acceptance; không phải `TC-*` chính thức | `AC-UC-RIDE-003-01` |

Quy tắc: không dùng lại ID, không xóa âm thầm; tài liệu thay đổi phải cập nhật PRD/traceability/test tương ứng. Mã trong catalog `UC-XXX-NNN` là **ID mới của file này**, còn `FR-*` giữ đúng số trong PRD. `P0-candidate` là đề xuất mức ưu tiên đang chờ xác nhận chi tiết, **không** có nghĩa ticket đã sẵn sàng để sản xuất.

### 3.3. Trạng thái kịch bản

| Trạng thái | Có nghĩa | Cho phép agent làm gì |
|---|---|---|
| `CATALOGED` | Có tên, actor, kết quả, nguồn FR, dependency | Discovery, outline UI, test ideas |
| `SPECIFIED_DRAFT` | Có full flows nhưng policy có thể vẫn TBD | Code sandbox theo test fixture, không phát hành live |
| `BLOCKED_BY_POLICY` | Hành vi cần quyết định `OPEN-*` để đúng thực tế | Mock, adapter, invariant guard; không tự chốt |
| `APPROVED` | Owner đã phê duyệt FR/BR/policy và trạng thái | Thực thi với contract và tests được duyệt |
| `IMPLEMENTED` | Code đã tồn tại; không đồng nghĩa verified | Tích hợp và kiểm thử |
| `VERIFIED` | Có bằng chứng QA/contract/security cho scope tương ứng | Xét release gate; vẫn cần legal/ops go-live |

## 4. Actor và boundaries

| Actor | Mục tiêu điển hình | Quyền cần kiểm | Nhánh ứng dụng |
|---|---|---|---|
| Customer | Đặt xe, đặt món, theo dõi, hỗ trợ | Chủ RideRequest/Trip/FoodOrder | Flutter Customer |
| Merchant owner | Đăng ký, quản lý cửa hàng, nhận đơn | Owner/role của đúng merchant/store; eligibility | Flutter Merchant |
| Merchant staff | Xử lý thực đơn, inbox, đơn | Role nhân viên và store assignment; phụ thuộc `OPEN-013` | Flutter Merchant |
| Driver | Khai báo sẵn sàng, nhận offer, đón khách/lấy món, giao/hoàn thành | KYC/đủ điều kiện dịch vụ, driver identity, active assignment | Flutter Driver |
| Admin Support | Tra cứu, điều phối hỗ trợ, ticket | Scope quyền, reason code, audit | Admin Web |
| Admin Ops/Dispatcher | Quản lý vùng, theo dõi công việc kẹt, tạm dừng | Approval, phân quyền vùng, audit | Admin Web |
| Admin Finance | Đối soát/điều chỉnh đúng thẩm quyền | Separation of duties cho hành động tiền | Admin Web |
| Admin Security/Reviewer | Phê duyệt partner, điều tra an toàn | Least privilege, kiểm soát PII | Admin Web |
| System scheduler | Hết hạn offer, retry, reconcile, alert | System credential + idempotency + trace | Backend internal |
| External payment/map/OTP/push provider | Chuyển thông tin ngoài hệ thống | Chữ ký, nguồn sự kiện, độ tin cậy, privacy | Integration boundary |

> **Một Account có nhiều role không có nghĩa nhiều quyền luôn được hợp nhất.** Active role là ngữ cảnh giao diện; mọi thao tác server phải dùng permission + eligibility + object ownership (và, khi cần, policy capacity).

## 5. Bất biến nghiệp vụ áp dụng mọi Use Case

1. `RideRequest` khác `Trip`: gửi yêu cầu chưa có nghĩa tài xế đã nhận hoặc chuyến đã bắt đầu.
2. `FoodOrder` khác `DeliveryTask`: nhà hàng xác nhận đơn chưa có nghĩa có tài xế được phân công.
3. `FareCounterOffer` khác `DispatchOffer`; lựa chọn của khách mới tạo `AcceptedFareAgreement`, và chỉ assignment được server commit mới là tài xế được gán.
4. Backend là nguồn sự thật cuối cùng. Client state, push, local time hoặc GPS không được tự quyết định `completed`/`cancelled`/`paid`.
5. Cùng một business intent khi retry/double tap không được tạo thêm đơn/chuyến/payment; event/webhook replay không tạo tác động tiền lặp.
6. Không cho phép hai active assignment **cùng một job**; driver capacity/concurrent jobs khác nhau cần chính sách `OPEN-005`.
7. State transition phải có guard, quyền đúng actor, thời điểm và nguyên nhân; mọi chuyển trái stage phải bị từ chối minh bạch.
8. Giá/quote/cửa hàng/món được xác minh phía server tại commit; client không tự gửi `price` đáng tin để bắt hệ thống sử dụng.
9. Payment, refund, ledger, settlement, payout là những trạng thái/nghiệp vụ khác nhau; lỗi của một bước không được biến thành thành công bước kia.
10. Merchant/Driver chưa eligible không được thực hiện công việc bị giới hạn; dữ liệu giấy tờ cần phạm vi truy cập, retention và audit phù hợp.
11. Không xuyên quyền người khác bằng cách thay ID trong API, deep link, push, cache hoặc màn hình đa vai trò.
12. Reconnect phải reload state authoritative; push cũ không được lùi state; task lỗi luôn có đường xử lý, escalation và support case khi cần.
13. Không đánh đồng **giao hàng thực tế thất bại** với **thanh toán thất bại**; phải theo dõi hai lifecycle.
14. Một chiến lược recovery không được âm thầm ghi `completed` để giải phóng job hoặc `settled` để che mismatch.

Các bất biến trên là cách diễn giải và kiểm thử yêu cầu PRD; thay đổi chính sách phải qua Governance. Không lấy chúng làm định nghĩa chi tiết state machine thay cho tài liệu `03-workflows/*`.

## 6. Ma trận danh mục 71 Use Cases bám `FR-*`

**Cách đọc:** mỗi dòng có một mục đích/thao tác rõ, kết quả chi tiết tra ở `FR-*` gốc. Cột `OPEN-*` nghĩa đặc tả/chính sách còn cần quyết định; không có `OPEN-*` **không chứng minh use case đã được APPROVED**. Các ID được lập song song FR để đảm bảo baseline coverage; khi triển khai, có thể nhóm nhiều UC trong một vertical slice, nhưng không xóa tính truy vết riêng.


### 6.1. Shared Platform (18)

| Use Case | Mục tiêu người dùng / hệ thống | Actor chính | FR liên quan | Policy TBD |
|---|---|---|---|---|
| `UC-CORE-001` | Đăng nhập và khôi phục quyền truy cập | Account holder | `FR-CORE-001` | `OPEN-008` |
| `UC-CORE-002` | Chọn vai trò hoạt động đã được cấp | Multi-role user | `FR-CORE-002` | `OPEN-005` |
| `UC-CORE-003` | Nộp hồ sơ đối tác và nhận kết quả xét duyệt | Merchant/Driver | `FR-CORE-003` | `OPEN-006`, `OPEN-008` |
| `UC-CORE-004` | Chọn và xác minh vị trí/địa chỉ | Customer/Driver | `FR-CORE-004` | `OPEN-001`, `OPEN-012` |
| `UC-CORE-005` | Phát hành và xác nhận quyền nhận offer | Dispatch service/Driver | `FR-CORE-005` | `OPEN-004`, `OPEN-005` |
| `UC-CORE-006` | Gửi lại một hành động giao dịch an toàn | Customer/Driver/Merchant | `FR-CORE-006` | `OPEN-004` |
| `UC-CORE-007` | Xem và xác nhận điều kiện quote còn hiệu lực | Customer | `FR-CORE-007` | `OPEN-003` |
| `UC-CORE-008` | Tra cứu kết quả thu/hoàn/đối soát | Finance/Operations | `FR-CORE-008` | `OPEN-002`, `OPEN-003`, `OPEN-010`, `OPEN-018` |
| `UC-CORE-009` | Khôi phục trạng thái sau offline/reconnect | All mobile roles | `FR-CORE-009` | `OPEN-012` |
| `UC-CORE-010` | Truy cập dữ liệu chỉ trong phạm vi được quyền | All roles | `FR-CORE-010` | `OPEN-005`, `OPEN-013` |
| `UC-CORE-011` | Gửi và theo dõi yêu cầu hỗ trợ | All roles | `FR-CORE-011` | `OPEN-014`, `OPEN-015` |
| `UC-CORE-012` | Phát hiện công việc hoặc giao dịch bị kẹt | Ops/System | `FR-CORE-012` | `OPEN-007`, `OPEN-015` |
| `UC-CORE-013` | Xem lịch sử và chi tiết giao dịch đúng trạng thái | Customer/Merchant/Driver | `FR-CORE-013` | `OPEN-002`, `OPEN-003` |
| `UC-CORE-014` | Nhận thông báo liên quan đúng vai trò | All roles | `FR-CORE-014` | `OPEN-014` |
| `UC-CORE-015` | Kiểm tra lịch sử thay đổi quan trọng | Authorized auditor | `FR-CORE-015` | `OPEN-006`, `OPEN-015` |
| `UC-CORE-016` | Đăng ký/liên kết passkey, phone SMS, verified email và khôi phục truy cập | Account holder | `FR-CORE-016` | `OPEN-008/020` |
| `UC-CORE-017` | Chat trong Ride/Food với participant đủ quyền | Customer/Driver/Merchant | `FR-CORE-017` | `OPEN-014/021` |
| `UC-CORE-018` | Gọi thoại trong app theo Ride/Food transaction | Customer/Driver/Merchant | `FR-CORE-018` | `OPEN-021` |


### 6.2. Ride / Customer (12)

| Use Case | Mục tiêu người dùng / hệ thống | Actor chính | FR liên quan | Policy TBD |
|---|---|---|---|---|
| `UC-RIDE-001` | Thiết lập điểm đón và điểm đến của Ride (xe máy, ô tô) | Customer | `FR-RIDE-001` | `OPEN-001` |
| `UC-RIDE-002` | Xem route/ETA và giá tham khảo; nhập giá đề xuất | Customer | `FR-RIDE-002` | `OPEN-003/019` |
| `UC-RIDE-003` | Gửi yêu cầu và hoàn tất thương lượng giá Ride trước assignment | Customer | `FR-RIDE-003` | `DEC-PROD-005`, `OPEN-003/019` |
| `UC-RIDE-004` | Theo dõi tìm tài xế hoặc không có tài xế | Customer | `FR-RIDE-004` | `OPEN-004` |
| `UC-RIDE-005` | Xác minh thông tin tài xế đến đón | Customer | `FR-RIDE-005` | `OPEN-004` |
| `UC-RIDE-006` | Liên hệ và yêu cầu hỗ trợ khi chờ đón | Customer | `FR-RIDE-006` | `OPEN-014`, `OPEN-015` |
| `UC-RIDE-007` | Theo dõi hành trình từ đón tới kết thúc | Customer | `FR-RIDE-007` | `OPEN-012`, `OPEN-017` |
| `UC-RIDE-008` | Yêu cầu hủy chuyến theo giai đoạn | Customer | `FR-RIDE-008` | `OPEN-003`, `OPEN-017` |
| `UC-RIDE-009` | Khôi phục hành trình khi tài xế rời chuyến/mất mạng | Customer | `FR-RIDE-009` | `OPEN-004`, `OPEN-012`, `OPEN-015` |
| `UC-RIDE-010` | Xem biên nhận chuyến xe đã hoàn thành | Customer | `FR-RIDE-010` | `OPEN-002`, `OPEN-003` |
| `UC-RIDE-011` | Tra cứu lịch sử chuyến xe của mình | Customer | `FR-RIDE-011` | `OPEN-005` |
| `UC-RIDE-012` | Báo sự cố và tranh chấp chuyến xe | Customer | `FR-RIDE-012` | `OPEN-015`, `OPEN-017` |


### 6.3. Food / Customer (12)

| Use Case | Mục tiêu người dùng / hệ thống | Actor chính | FR liên quan | Policy TBD |
|---|---|---|---|---|
| `UC-FOOD-001` | Đặt địa chỉ giao và xem khu vực cửa hàng phục vụ | Customer | `FR-FOOD-001` | `OPEN-001` |
| `UC-FOOD-002` | Tìm cửa hàng và xem menu đang bán | Customer | `FR-FOOD-002` | `OPEN-001` |
| `UC-FOOD-003` | Chọn món cùng biến thể/tùy chọn bắt buộc | Customer | `FR-FOOD-003` | `OPEN-009` |
| `UC-FOOD-004` | Thay đổi giỏ và xem tạm tính | Customer | `FR-FOOD-004` | `OPEN-009` |
| `UC-FOOD-005` | Kiểm tra lại giỏ hàng trước thanh toán | Customer | `FR-FOOD-005` | `OPEN-002`, `OPEN-003`, `OPEN-009`, `OPEN-010` |
| `UC-FOOD-006` | Xác nhận tạo một đơn đồ ăn | Customer | `FR-FOOD-006` | `OPEN-002`, `OPEN-009`, `OPEN-010` |
| `UC-FOOD-007` | Theo dõi cửa hàng xác nhận và chuẩn bị | Customer | `FR-FOOD-007` | `OPEN-016` |
| `UC-FOOD-008` | Theo dõi tài xế nhận và giao món | Customer | `FR-FOOD-008` | `OPEN-004`, `OPEN-012` |
| `UC-FOOD-009` | Nhận kết quả giao món hoặc giao thất bại | Customer | `FR-FOOD-009` | `OPEN-011`, `OPEN-016` |
| `UC-FOOD-010` | Yêu cầu hủy, hỗ trợ hoặc hoàn tiền đơn đồ ăn | Customer | `FR-FOOD-010` | `OPEN-003`, `OPEN-010`, `OPEN-016` |
| `UC-FOOD-011` | Xem lịch sử và hóa đơn đơn đồ ăn | Customer | `FR-FOOD-011` | `OPEN-002`, `OPEN-003` |
| `UC-FOOD-012` | Hiểu nguyên nhân không thể đặt/giao món | Customer | `FR-FOOD-012` | `OPEN-001`, `OPEN-004`, `OPEN-016` |


### 6.4. Merchant (9)

| Use Case | Mục tiêu người dùng / hệ thống | Actor chính | FR liên quan | Policy TBD |
|---|---|---|---|---|
| `UC-MER-001` | Đăng ký và cập nhật hồ sơ cửa hàng | Merchant owner | `FR-MER-001` | `OPEN-006`, `OPEN-008`, `OPEN-013` |
| `UC-MER-002` | Thiết lập giờ mở cửa và khả năng nhận đơn | Merchant authorized staff | `FR-MER-002` | `OPEN-013` |
| `UC-MER-003` | Cập nhật thực đơn, giá và tình trạng món | Merchant authorized staff | `FR-MER-003` | `OPEN-009`, `OPEN-013` |
| `UC-MER-004` | Xem hàng chờ đơn của cửa hàng mình | Merchant authorized staff | `FR-MER-004` | `OPEN-013` |
| `UC-MER-005` | Xác nhận hoặc từ chối đơn được gửi đến quán | Merchant authorized staff | `FR-MER-005` | `OPEN-010`, `OPEN-016` |
| `UC-MER-006` | Chuyển đơn sang chế biến và sẵn sàng bàn giao | Merchant authorized staff | `FR-MER-006` | `OPEN-011`, `OPEN-016` |
| `UC-MER-007` | Theo dõi tài xế lấy và giao món của quán | Merchant authorized staff | `FR-MER-007` | `OPEN-011`, `OPEN-012` |
| `UC-MER-008` | Xem báo cáo khoản phải thu và đối soát cửa hàng | Merchant finance staff | `FR-MER-008` | `OPEN-002`, `OPEN-003`, `OPEN-013` |
| `UC-MER-009` | Báo hết món hoặc vấn đề bàn giao/đơn | Merchant authorized staff | `FR-MER-009` | `OPEN-014`, `OPEN-016` |


### 6.5. Driver (10)

| Use Case | Mục tiêu người dùng / hệ thống | Actor chính | FR liên quan | Policy TBD |
|---|---|---|---|---|
| `UC-DRV-001` | Đăng ký hoạt động và xác minh hồ sơ tài xế | Driver | `FR-DRV-001` | `OPEN-006`, `OPEN-008` |
| `UC-DRV-002` | Bật/tắt nhận việc theo dịch vụ đủ điều kiện | Driver | `FR-DRV-002` | `OPEN-005` |
| `UC-DRV-003` | Xem yêu cầu Ride và giá khách đề xuất | Driver | `FR-DRV-003` | `OPEN-004`, `OPEN-005`, `OPEN-019` |
| `UC-DRV-004` | Chấp nhận giá khách hoặc gửi counter-offer; nhận kết quả chọn của khách | Driver | `FR-DRV-004` | `OPEN-004`, `OPEN-005`, `OPEN-019` |
| `UC-DRV-005` | Đi tới điểm đón, bắt đầu và kết thúc Ride | Driver | `FR-DRV-005` | `OPEN-017` |
| `UC-DRV-006` | Đến quán, lấy món và xác nhận giao thành công | Driver | `FR-DRV-006` | `OPEN-011`, `OPEN-016` |
| `UC-DRV-007` | Sử dụng GPS/đường đi và xử lý thiếu quyền vị trí | Driver | `FR-DRV-007` | `OPEN-012` |
| `UC-DRV-008` | Không nhận việc chồng chéo trái chính sách | Driver/System | `FR-DRV-008` | `OPEN-005` |
| `UC-DRV-009` | Tra cứu lịch sử job và thu nhập | Driver | `FR-DRV-009` | `OPEN-002`, `OPEN-003`, `OPEN-018` |
| `UC-DRV-010` | Báo khách vắng, quán chưa sẵn hoặc không giao được | Driver | `FR-DRV-010` | `OPEN-011`, `OPEN-015`, `OPEN-016` |


### 6.6. Admin / Operations (10)

| Use Case | Mục tiêu người dùng / hệ thống | Actor chính | FR liên quan | Policy TBD |
|---|---|---|---|---|
| `UC-OPS-001` | Đăng nhập quản trị với vai trò được cấp | Admin | `FR-OPS-001` | `OPEN-006` |
| `UC-OPS-002` | Xét duyệt/từ chối/tạm khóa Merchant và Driver | Authorized reviewer | `FR-OPS-002` | `OPEN-006`, `OPEN-008` |
| `UC-OPS-003` | Tra cứu lịch sử và timeline nghiệp vụ đa vai trò | Support/Ops | `FR-OPS-003` | `OPEN-015` |
| `UC-OPS-004` | Giải quyết tranh chấp và hoàn/hủy có kiểm soát | Support/Finance | `FR-OPS-004` | `OPEN-003`, `OPEN-010`, `OPEN-015`, `OPEN-016` |
| `UC-OPS-005` | Phát hiện offer/assignment kẹt và can thiệp | Ops dispatcher | `FR-OPS-005` | `OPEN-004`, `OPEN-007` |
| `UC-OPS-006` | Đối soát giao dịch và xử lý sai lệch | Finance/Ops | `FR-OPS-006` | `OPEN-002`, `OPEN-003`, `OPEN-018` |
| `UC-OPS-007` | Thiết lập vùng dịch vụ và cấu hình đối tác | Authorized operations | `FR-OPS-007` | `OPEN-001`, `OPEN-006` |
| `UC-OPS-008` | Tra soát audit và phân loại bất thường | Security/Ops | `FR-OPS-008` | `OPEN-015` |
| `UC-OPS-009` | Tạm dừng nhận giao dịch mới theo vùng/dịch vụ | Authorized ops | `FR-OPS-009` | `OPEN-001`, `OPEN-007` |
| `UC-OPS-010` | Bật/tắt phương thức xác thực theo quyền và scope | Security Admin / authorized Config Manager | `FR-OPS-010` | `OPEN-020` |


## 7. Danh mục 12 Use Cases xuyên actor / E2E

Các UC này là **hành trình tích hợp**, không tạo thêm 12 yêu cầu chức năng độc lập. Dùng để chặn lỗi bàn giao và phục hồi mà single-actor screens thường bỏ sót.

| Use Case | Nghiệp vụ xuyên vai trò | Actor | Liên kết FR | Gate | Policy TBD |
|---|---|---|---|---|---|
| `UC-X-001` | Hoàn tất Ride end-to-end qua ba actor | Customer + Driver + System | `FR-RIDE-003`, `FR-RIDE-004`, `FR-RIDE-007`, `FR-DRV-004`, `FR-DRV-005`, `FR-CORE-008` | `G2` | `OPEN-003`, `OPEN-004`, `OPEN-005`, `OPEN-017` |
| `UC-X-002` | Hoàn tất Food end-to-end qua ba actor | Customer + Merchant + Driver + System | `FR-FOOD-006`, `FR-FOOD-007`, `FR-FOOD-008`, `FR-MER-005`, `FR-MER-006`, `FR-DRV-006` | `G3` | `OPEN-002`, `OPEN-009`, `OPEN-010`, `OPEN-011`, `OPEN-016` |
| `UC-X-003` | Giải quyết không có tài xế sau khi quán đã chế biến | Merchant + Ops + Customer | `FR-FOOD-007`, `FR-MER-006`, `FR-OPS-004`, `FR-DRV-010` | `G3` | `OPEN-004`, `OPEN-016` |
| `UC-X-004` | Phát hiện thay đổi giá/món khi đang checkout | Customer + Merchant + System | `FR-FOOD-003`, `FR-FOOD-004`, `FR-FOOD-005`, `FR-MER-003` | `G3` | `OPEN-003`, `OPEN-009` |
| `UC-X-005` | Chống lặp callback và điều chỉnh tiền trùng | System/Finance | `FR-CORE-006`, `FR-CORE-008`, `FR-OPS-006` | `G4` | `OPEN-002`, `OPEN-010`, `OPEN-018` |
| `UC-X-006` | Đổi vai trò trong khi đang có công việc | Multi-role user | `FR-CORE-002`, `FR-DRV-008`, `FR-MER-004` | `G4` | `OPEN-005`, `OPEN-013` |
| `UC-X-007` | Khôi phục realtime sau app kill, push trễ và offline | All mobile roles + System | `FR-CORE-009`, `FR-CORE-014`, `FR-RIDE-009`, `FR-FOOD-008` | `G4` | `OPEN-012`, `OPEN-014` |
| `UC-X-008` | Ngăn dữ liệu xuyên tài khoản/cửa hàng | Attacker simulated + Security | `FR-CORE-010`, `FR-MER-004`, `FR-OPS-001` | `G4` | `OPEN-005`, `OPEN-013` |
| `UC-X-009` | Hủy hoặc hoàn tiền qua nhiều trạng thái | Customer + Merchant + Driver + Ops | `FR-RIDE-008`, `FR-FOOD-010`, `FR-OPS-004` | `G4` | `OPEN-003`, `OPEN-010`, `OPEN-016`, `OPEN-017` |
| `UC-X-010` | Xử lý không có tài xế trước khi gán chuyến | Customer + Dispatch + Ops | `FR-RIDE-004`, `FR-RIDE-009`, `FR-OPS-005` | `G2` | `OPEN-004` |
| `UC-X-011` | Phê duyệt đối tác trước khi bật khả năng nhận việc | Merchant/Driver + Reviewer | `FR-CORE-003`, `FR-MER-001`, `FR-DRV-001`, `FR-OPS-002` | `G4` | `OPEN-006`, `OPEN-008`, `OPEN-013` |
| `UC-X-012` | Khóa giao dịch mới khi xảy ra sự cố vùng/dịch vụ | Ops + Customer + Driver | `FR-CORE-012`, `FR-OPS-009`, `FR-CORE-014` | `G4` | `OPEN-001`, `OPEN-007`, `OPEN-015` |


## 8. Khuôn mẫu `fully dressed` áp dụng khi chi tiết hóa

Một UC đến bước triển khai P0 phải được nâng từ `CATALOGED` thành `SPECIFIED_DRAFT` / `APPROVED` bằng biểu mẫu:

```markdown
### UC-XXX-NNN — Động từ + mục tiêu
- Level, Priority, Status, Owner/Reviewer
- Primary Actor; Supporting Actors; Stakeholders
- FR / BR / WF / Gate / OPEN / data sensitivity
- Trigger, Preconditions, Minimal Guarantee, Success Guarantee
- MSS-1..N: Actor action → system observable response
- EX-N[a-z]: condition → expected behavior → resume/terminate
- State guard + actor permissions + persisted effects
- Notification/UX states + timeout policy reference
- Idempotency/concurrency/security/reconnect notes
- AC-UC-...: acceptance observable và testable
- Evidence required; Unresolved questions; Handoff links
```

**Ranh giới:** chi tiết bên dưới là **scenario specification**. Những lựa chọn policy chưa chốt đánh dấu rõ, không tự tạo `BR-*` hoặc API endpoints. Khi `OPEN-*` liên quan chưa CONFIRMED, toàn bộ UC vẫn `BLOCKED_BY_POLICY` cho production, mặc dù có thể triển khai mock và test kỹ thuật.

## 9. Fully dressed — Shared Platform và kiểm soát vai trò

### 9.1. `UC-CORE-002` — Chọn vai trò hoạt động an toàn

- **Level / status:** user-goal; `SPECIFIED_DRAFT` + `BLOCKED_BY_POLICY` (`OPEN-005`). **Actor:** người dùng có nhiều role.
- **Liên kết:** `FR-CORE-002`, `FR-CORE-010`, `FR-DRV-008`, `UC-X-006`; gate `G1/G4`.
- **Trigger:** người dùng chọn chuyển từ Customer sang Merchant hoặc Driver (hoặc ngược lại).
- **Tiền điều kiện:** session hợp lệ; account đã có ít nhất hai role; role đích được cấp đúng trạng thái.
- **Bảo đảm tối thiểu:** không cấp mới permission; dữ liệu vai trò cũ không rò sang vai trò mới; active job đang chạy không bị xóa.
- **Bảo đảm thành công:** app chuyển đúng shell/route; server xử lý authorization theo role/eligibility hiện tại, trạng thái còn dang dở có thể khôi phục.

**Luồng chính**
1. `MSS-1`: Người dùng mở danh sách vai trò đã có.
2. `MSS-2`: Hệ thống lấy quyền và trạng thái đủ điều kiện từ nguồn có thẩm quyền; thể hiện role có thể chọn.
3. `MSS-3`: Người dùng chọn role đích.
4. `MSS-4`: App kiểm tra policy job-in-progress (`OPEN-005`), đồng thời backend vẫn bảo vệ thao tác theo quyền.
5. `MSS-5`: App đổi route stack/namespace state, làm mới badge/inbox/bản đồ phù hợp role; trạng thái công việc active không mất.
6. `MSS-6`: Nếu vào màn bằng deep link cũ, backend kiểm quyền lại; hiển thị lỗi có thể xử lý thay vì hiện nội dung trái quyền.

**Extensions**
- `EX-2a`: Role chưa duyệt → chỉ cho xem tiến độ hồ sơ, không hiện action nhận việc.
- `EX-4a`: Đang có active job → dùng policy đã duyệt để cho xem/đổi/chặn role; **không mặc định tự hủy job**.
- `EX-5a`: Token hết hạn → đăng nhập lại và khôi phục intent một cách an toàn.
- `EX-6a`: Truy cập URL cũ bằng role mới → `403`/denial tương đương, không lộ PII.

**AC:** `AC-UC-CORE-002-01` đổi role không làm tăng quyền; `-02` deep link cũ không bypass object authorization; `-03` dữ liệu state/cache của vai trò khác không xuất hiện; `-04` behavior active job có test theo `OPEN-005` đã duyệt.

### 9.2. `UC-CORE-003` — Nộp hồ sơ và nhận trạng thái xét duyệt đối tác

- **Level/status:** user-goal; `SPECIFIED_DRAFT`; live activation blocked `OPEN-006/008`.
- **Actor:** Merchant owner hoặc Driver. **Supporting:** Admin reviewer, dịch vụ xác minh nếu chọn.
- **FR:** `FR-CORE-003`, `FR-MER-001`, `FR-DRV-001`, `FR-OPS-002`.
- **Trigger:** chọn đăng ký role kinh doanh/lái xe.
- **Tiền điều kiện:** session hợp lệ; tài khoản có quyền đăng ký; biểu mẫu chính thức cần xác định theo pháp lý/đối tác.
- **Bảo đảm tối thiểu:** upload không hợp lệ không được coi đã xác minh; tài liệu PII lưu theo chính sách truy cập và retention.
- **Bảo đảm thành công:** hồ sơ được ghi nhận, hiển thị trạng thái; khi reviewer có thẩm quyền duyệt, eligibility được cập nhật theo điều kiện pháp lý.

**Luồng chính**
1. `MSS-1`: Actor chọn loại đối tác và truy cập checklist giấy tờ.
2. `MSS-2`: App cho nhập thông tin, đính tài liệu và xác nhận cần thiết theo biểu mẫu được phê duyệt.
3. `MSS-3`: Server xác thực cấu trúc, chống upload độc hại, lưu reference và audit, trả submission ID.
4. `MSS-4`: Reviewer chỉ xem được hồ sơ thuộc phạm vi được cấp, đánh giá và yêu cầu bổ sung hoặc quyết định.
5. `MSS-5`: Partner nhận tiến độ/đầu mục cần bổ sung/được duyệt/từ chối; không dựa hoàn toàn vào push.
6. `MSS-6`: Khi được phê duyệt theo policy, tính năng bật nhận đơn/offer mới có thể được cấp eligibility.

**Extensions**
- `EX-3a`: Upload gián đoạn/định dạng không hợp lệ → giữ tiến độ an toàn nếu được phép, không tạo hồ sơ đã xác minh giả.
- `EX-4a`: Thiếu giấy tờ → trả yêu cầu bổ sung có reason code; không tự xét duyệt.
- `EX-4b`: Reviewer thiếu quyền hoặc tự duyệt trái segregation policy → bị chặn và ghi audit.
- `EX-5a`: Push không đến → kiểm tra lại trạng thái qua API; không làm sai quyền.

**AC:** `AC-UC-CORE-003-01` hồ sơ pending không bật nhận việc; `-02` từ chối/bổ sung có reason; `-03` user A không xem tài liệu user B; `-04` mọi approval/rejection có actor, timestamp, lý do và audit.

## 10. Fully dressed — Ride

### 10.1. `UC-RIDE-003` — Khách xác nhận gọi xe

- **Level/status:** user-goal; `SPECIFIED_DRAFT`, business pattern confirmed by `DEC-PROD-005`; production parameters/policy blocked by `OPEN-001/003/004/019`.
- **Actor:** Customer. **Supporting:** Maps/Quote Service, Ride Service, Dispatch.
- **FR:** `FR-RIDE-001`, `FR-RIDE-002`, `FR-RIDE-003`, `FR-CORE-006`, `FR-CORE-007`. **Gate:** `G2`.
- **Trigger:** khách gửi Ride request với pickup/dropoff và passenger proposed fare sau khi xem reference fare.
- **Tiền điều kiện:** authenticated; pickup/dropoff/route và reference fare còn hợp lệ; vùng mở; giá đề xuất tuân theo guardrail nếu đã duyệt; customer được quyền tạo request.
- **Bảo đảm tối thiểu:** không tạo RideRequest trùng từ cùng intent; booking lỗi không tự gán Trip/thu tiền; client có thể tra lại kết quả nếu response thất lạc.
- **Bảo đảm thành công:** một RideRequest canonical có route, giá đề xuất và negotiation state; trước khi khách chọn thì chưa có driver assignment. Sau khi chọn, có một `AcceptedFareAgreement` và tối đa một assignment gắn đúng tài xế/giá cuối.

**Luồng chính**
1. `MSS-1`: Khách chọn Ride (xe máy, ô tô), pickup/dropoff; backend xác thực vùng và route rồi trả ETA/quãng đường cùng **giá tham khảo** có version.
2. `MSS-2`: Khách nhập/chỉnh **giá đề xuất**; UI phân biệt rõ giá tham khảo, giá đề xuất, phụ phí/điều kiện đã biết.
3. `MSS-3`: Khách gửi yêu cầu với idempotency key; server kiểm tra eligibility, policy version, giới hạn giá đã được phê duyệt và tạo `RideFareNegotiation`.
4. `MSS-4`: Tài xế đủ điều kiện nhận lời mời thương lượng, xem projection dữ liệu tối thiểu, rồi chấp nhận giá khách hoặc gửi `FareCounterOffer` mới; mọi đề nghị có actor, amount, currency, expiry và state.
5. `MSS-5`: Khách xem các đề nghị còn hiệu lực và chọn một; server atomic xác thực request/offer, khóa giá thỏa thuận, đánh dấu đối thủ hết hiệu lực và tạo assignment cho đúng tài xế.
6. `MSS-6`: Chỉ sau commit mới thông báo “đã xác nhận”; mọi bên nhận snapshot giá cuối và trạng thái authoritative. `DispatchOffer` nội bộ/khác biệt không thay cho counter-offer.

**Không có winner tự động:** server không chọn giá thấp nhất, offer đầu tiên hoặc đề nghị gần giá tham khảo thay cho khách.

**Extensions**
- `EX-2a`: Không xác định được pickup hoặc ngoài vùng → hiển thị sửa vị trí, không tạo yêu cầu.
- `EX-3a`: Quote hết hạn/giá đổi → yêu cầu review lại, không dùng giá cũ.
- `EX-4a`: Double tap/retry/reconnect → cùng intent trả về cùng RideRequest hoặc kết quả tương đương, không sinh bản ghi thứ hai.
- `EX-5a`: Service tạm dừng theo vùng → từ chối tạo mới có lý do, không tác động các job đang active.
- `EX-6a`: Đã commit nhưng HTTP response thất lạc → kiểm tra lại bằng operation/intention reference, không tự gửi intent mới.

**AC:** `AC-UC-RIDE-003-01` retry một intent → một negotiation; `-02` giá tham khảo stale yêu cầu refresh; `-03` khách đề xuất ngoài rule bị từ chối rõ; `-04` chỉ khách chọn một offer còn hiệu lực mới sinh assignment; `-05` hai lần chọn cạnh tranh có một winner; `-06` lost response khôi phục đúng trạng thái; không auto-select lowest/first offer. Chi tiết số vòng/TTL/giới hạn giá thuộc `OPEN-019`, biểu giá/phí thuộc `OPEN-003`.

### 10.2. `UC-RIDE-004` — Tìm tài xế và xử lý không có xe

- **Level/status:** user-goal; `SPECIFIED_DRAFT`, policy blocked `OPEN-004`.
- **Actor:** Customer; supporting Dispatch, Drivers, Operations.
- **FR:** `FR-RIDE-004`, `FR-CORE-005`, `FR-DRV-003`, `FR-DRV-004`, `FR-OPS-005`.
- **Trigger:** RideRequest được chấp nhận vào tìm tài xế.
- **Tiền điều kiện:** request active, không cancel/assigned/expired; các driver candidate theo cấu hình hệ thống.
- **Minimal guarantee:** offer cũ bị hết hạn không thể nhận; đúng một assignment tối đa cho request; không báo assigned chỉ vì một push đã gửi.
- **Success guarantee:** customer thấy driver được commit hoặc thấy kết quả no-driver/timeout/cancel đúng và cách xử lý.

**Luồng chính**
1. `MSS-1`: Dispatch bắt đầu tìm candidate đủ điều kiện tại thời điểm xét.
2. `MSS-2`: Server tạo một hoặc nhiều offer theo **policy chưa chốt**; mỗi offer có identity, lifecycle, expiry.
3. `MSS-3`: Tài xế có offer hợp lệ chọn accept/decline trong app.
4. `MSS-4`: Server kiểm tra eligibility, offer validity, capacity và atomic commit assignment.
5. `MSS-5`: Các offer thua cuộc được đánh dấu hết hiệu lực; customer được thông báo kết quả committed.
6. `MSS-6`: App Customer tải thông tin đúng tài xế/xe và chuyển sang trạng thái theo dõi đón.

**Extensions**
- `EX-1a`: Không có candidate → xử lý no-driver hoặc mở vòng tìm mới theo policy đã duyệt; không quay mãi vô hạn.
- `EX-3a`: Driver từ chối hoặc bỏ quá hạn → offer expired; dispatch xử lý next wave dựa config.
- `EX-4a`: Hai driver nhận cùng lúc → một commit thắng; người còn lại nhận conflict hợp lệ, không có 2 active assignment.
- `EX-4b`: Driver đang bận/eligibility đổi trước commit → reject; không dựa vào dữ liệu lúc phát offer.
- `EX-5a`: Khách hủy cạnh tranh lúc driver accept → outcome duy nhất theo transaction/state guard; không `cancelled + assigned` mâu thuẫn.
- `EX-6a`: Push trễ hoặc offline → refresh trạng thái server; stale push không đảo ngược giao diện.

**AC:** `AC-UC-RIDE-004-01` không 2 assignments; `-02` hết offer không nhận được; `-03` no-driver có trạng thái chấm dứt/hỗ trợ; `-04` cancel vs accept race có kết quả tất định. Bán kính/thời gian là `OPEN-004`.

### 10.3. `UC-RIDE-007` — Đi từ trạng thái được gán đến kết thúc chuyến

- **Actor:** Customer (quan sát), Driver (thao tác), System (kiểm tra). **Level:** multi-actor user-goal. **Status:** `SPECIFIED_DRAFT`, policy blocked `OPEN-017/012`.
- **FR:** `FR-RIDE-005`, `FR-RIDE-007`, `FR-DRV-005`, `FR-DRV-007`.
- **Precondition:** RideRequest có assignment committed, Driver đủ điều kiện, Trip chưa completed/cancelled.
- **Minimal guarantee:** evidence/timeline không mất; sai actor hoặc sai stage không thể advance; dữ liệu location không được dùng làm bằng chứng duy nhất ngoài policy.
- **Success guarantee:** Trip kết thúc qua state transition hợp lệ, thu/chi ghi trạng thái riêng, thông báo/receipt chính xác.

**Luồng chính**
1. `MSS-1`: Driver mở assignment hiện hành và điều hướng đến pickup.
2. `MSS-2`: App Customer hiển thị thông tin tài xế/biển số và ETA ước tính.
3. `MSS-3`: Driver tới vị trí đón; hệ thống cập nhật sự kiện mốc phù hợp policy.
4. `MSS-4`: Driver/Customer hoàn thành cơ chế xác nhận bắt đầu **sau khi OPEN-017 được duyệt**.
5. `MSS-5`: Server cho chuyển sang in-progress; Customer theo dõi trạng thái, Driver thực hiện chuyến.
6. `MSS-6`: Kết thúc theo cơ chế chứng cứ đã duyệt; hệ thống kiểm quyền/trạng thái và ghi Trip end.
7. `MSS-7`: Trip completed được tách khỏi Payment success/settlement; phát hành receipt/timeline tương ứng.

**Extensions**
- `EX-3a`: Không thấy khách → gọi hỗ trợ hoặc hủy theo policy, không đánh dấu started giả.
- `EX-4a`: Sai mã chứng thực/nút start trái stage → từ chối, không thay state.
- `EX-5a`: GPS/mạng mất → app biểu thị degraded/reconnecting, server không kết thúc trip chỉ vì mất ping.
- `EX-6a`: Driver gửi complete 2 lần → idempotent; timestamp, audit, charging không nhân đôi.
- `EX-7a`: Thanh toán chưa hoàn tất → trạng thái debt/pending/payment-failed đúng policy, Trip không bị đảo ngược vô căn cứ.

**AC:** `AC-UC-RIDE-007-01` mọi transition có guard; `-02` không kết thúc sai driver; `-03` hoàn tất không đồng nghĩa paid; `-04` app restart tải lại Trip active; `-05` evidence start/end theo `OPEN-017` được kiểm chứng.

### 10.4. `UC-RIDE-008` — Hủy chuyến có kiểm soát

- **Actor:** Customer; supporting Driver, Support, Finance. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-003/017`.
- **FR:** `FR-RIDE-008`, `FR-RIDE-009`, `FR-CORE-008`.
- **Trigger:** khách chọn hủy tại một giai đoạn được phép.
- **Precondition:** request/trip thuộc Customer; có trạng thái authoritative; cancel intent có reason nếu policy yêu cầu.
- **Minimal guarantee:** không thu phí tùy tiện; không đồng thời `completed` và `cancelled`; mọi điều chỉnh tiền có reference/audit.
- **Success guarantee:** trạng thái hủy hợp lệ được phản ánh cho các actor; offer/assignment và nghĩa vụ tài chính được xử lý theo policy.

**Luồng chính**
1. `MSS-1`: Customer yêu cầu hủy; hệ thống tải giai đoạn hiện tại từ server.
2. `MSS-2`: Hiển thị điều kiện có thể hủy và ảnh hưởng phí (nếu có) theo rule đã duyệt.
3. `MSS-3`: Customer xác nhận sau khi xem hậu quả.
4. `MSS-4`: Server atomic-validate trạng thái, quyền, charge policy, ghi cancellation + cancel reason.
5. `MSS-5`: Thu hồi offer/chặn accept mới hoặc kết thúc assignment theo stage; thông báo đúng actor.
6. `MSS-6`: Các khoản hoàn/thu/phí phát sinh đi qua financial lifecycle riêng và có thể reconciliation.

**Extensions**
- `EX-2a`: State đã thay đổi giữa lúc load và confirm → báo stale, hiển thị điều kiện mới, không âm thầm áp phí.
- `EX-4a`: Driver hoàn thành hoặc pickup vừa xác nhận → reject cancel không hợp lệ/đưa sang support case; không ép rollback trip.
- `EX-4b`: Đồng thời accept offer → một outcome hợp lệ theo state version; các event đến sau không hồi sinh offer.
- `EX-6a`: Provider refund timeout → hiển thị pending/error, không đánh dấu refunded khi chưa confirmed.

**AC:** `AC-UC-RIDE-008-01` cancel/accept race nhất quán; `-02` phí không hiển thị/áp dụng nếu chưa approved; `-03` refund state độc lập; `-04` stale action không ghi trùng.

## 11. Fully dressed — Food

### 11.1. `UC-FOOD-005` — Xác thực giỏ và giá tại checkout

- **Actor:** Customer; supporting Merchant Catalog, Quote Service. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-002/003/009/010`.
- **FR:** `FR-FOOD-003`, `FR-FOOD-004`, `FR-FOOD-005`, `FR-CORE-007`.
- **Precondition:** giỏ có các dòng hàng được chọn, địa chỉ giao, loại dịch vụ Food; catalog có trạng thái hợp lệ tại thời điểm kiểm tra.
- **Minimal guarantee:** giỏ chưa phải đơn hàng; không áp dụng giá stale; không âm thầm thay món/tùy chọn.
- **Success guarantee:** checkout review hiển thị snapshot current items, giá và điều kiện cho user confirm.

**Luồng chính**
1. `MSS-1`: Khách vào checkout từ cart; client gửi item IDs, options, số lượng, ghi chú, địa chỉ.
2. `MSS-2`: Backend kiểm tra merchant, store availability, menu version, inventory/availability, option validity, serviceability.
3. `MSS-3`: Backend tính lại price breakdown, delivery fee và các điều kiện theo policy đã duyệt.
4. `MSS-4`: Trả draft/quote có version/reference và expiry (nếu policy có) cùng các thay đổi quan trọng.
5. `MSS-5`: UI nêu rõ những khác biệt cần chấp thuận; Customer xác nhận lại nếu có thay đổi.
6. `MSS-6`: Checkout được đưa sang create-order với reference đã xác nhận; server kiểm tra lần nữa tại commit.

**Extensions**
- `EX-2a`: Quán đóng/ngoài vùng → không checkout, hiển thị cách chọn quán/địa chỉ khác.
- `EX-2b`: Hết món/option không hợp lệ → yêu cầu sửa giỏ, không tự đổi sang món khác.
- `EX-3a`: Giá mới khác snapshot → hiển thị so sánh cũ/mới trước confirm.
- `EX-5a`: Người dùng từ chối giá mới → giỏ được giữ nếu an toàn, không tạo đơn.
- `EX-6a`: Catalog/quote thay đổi lại khi commit → báo conflict/stale và revalidate, không ép thanh toán theo giá cũ.

**AC:** `AC-UC-FOOD-005-01` không nhận giá do client sửa; `-02` price change yêu cầu review; `-03` unavailable/required options bị chặn; `-04` retry không nhân order. **Quy tắc một hay nhiều merchant mỗi cart là `OPEN-009`**.

### 11.2. `UC-FOOD-006` — Tạo FoodOrder một lần duy nhất

- **Actor:** Customer; supporting Merchant Service, Payment Service, Order Service. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-002/009/010`.
- **FR:** `FR-FOOD-006`, `FR-CORE-006`, `FR-CORE-008`.
- **Trigger:** người dùng xác nhận checkout đã được xác minh.
- **Precondition:** current checkout snapshot hợp lệ, eligibility merchant theo policy; phương thức payment được hỗ trợ trong test environment.
- **Minimal guarantee:** tạo đơn thất bại không gây thu/ủy nhiệm thu lặp; trong trạng thái không rõ kết quả có recovery bằng intent reference.
- **Success guarantee:** một FoodOrder có ID, immutable item/price snapshot và trạng thái chính xác, đủ để merchant tiếp nhận; financial state lưu riêng.

**Luồng chính**
1. `MSS-1`: Client gửi xác nhận order với stable intent/idempotency reference.
2. `MSS-2`: Server kiểm tra ownership, checkout version, merchant/store availability, giá/địa chỉ/contract.
3. `MSS-3`: Server tạo FoodOrder + item snapshots và các nghĩa vụ cần ghi nhận trong transaction boundary thích hợp.
4. `MSS-4`: Payment flow (nếu áp dụng) được kích hoạt theo **policy `OPEN-010`**, không suy đoán capture trước/sau merchant accept.
5. `MSS-5`: Merchant inbox nhận order cần xử lý; customer theo dõi trạng thái authoritative.
6. `MSS-6`: Server trả ID và status; khách có thể mở order detail sau reconnect.

**Extensions**
- `EX-2a`: Cart/quote stale → trả review required, chưa commit.
- `EX-3a`: Request lặp / mất response → tra theo intent ID, không sinh order khác.
- `EX-4a`: PSP chậm, timeout hoặc callback trễ → `pending/unknown` theo contract; không tự tuyên bố paid.
- `EX-5a`: Merchant nhận order lặp do event retry → consumer dedupe theo event/order identity, không tạo 2 bản đơn trong inbox.

**AC:** `AC-UC-FOOD-006-01` one intent → one order; `-02` order/items snapshot đúng; `-03` pending payment không giả paid; `-04` idempotent event delivery; `-05` transaction có thể reconcile về trạng thái cuối.

### 11.3. `UC-MER-005` — Merchant chấp nhận hoặc từ chối đơn

- **Actor:** Merchant owner/staff được ủy quyền; supporting Food Service, Customer, Ops. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-010/013/016`.
- **FR:** `FR-MER-004`, `FR-MER-005`, `FR-FOOD-007`.
- **Precondition:** order của đúng store, đang chờ merchant decision, store actor đủ quyền.
- **Minimal guarantee:** không accept và reject đồng thời, không ghi thay đổi cho order khác store, không tạo duplicate prep/payment.
- **Success guarantee:** FoodOrder có merchant decision committed và customer biết kết quả.

**Luồng chính**
1. `MSS-1`: Merchant mở inbox của store mình đang quản lý.
2. `MSS-2`: Server trả order detail với item/option/note và thời gian nhận có nguồn.
3. `MSS-3`: Merchant chọn accept (hoặc reject có reason theo policy).
4. `MSS-4`: Server kiểm quyền store + current state, ghi decision atomic và audit.
5. `MSS-5`: Customer nhận kết quả; nếu accept, quán được tiến đến preparing và theo dõi kế hoạch giao.

**Extensions**
- `EX-2a`: Nhân viên đổi cửa hàng mà inbox cũ còn cache → server deny; UI refresh.
- `EX-3a`: Hết món vừa phát hiện → reject/request support theo flow được duyệt, không sửa order âm thầm.
- `EX-4a`: Hai thiết bị accept/reject song song → first valid commit thắng; thiết bị thua nhận conflict/current state.
- `EX-5a`: Customer cancel cạnh tranh → transition guard xử lý outcome duy nhất; payment/refund theo policy.
- `EX-5b`: Quán accept nhưng không có driver sau khi làm → chuyển `UC-X-003`, không mặc định merchant mất tiền.

**AC:** `AC-UC-MER-005-01` không quyết định 2 lần; `-02` staff store A không xử lý order B; `-03` customer thấy kết quả; `-04` timeout/lost response retry an toàn; `-05` cancel cạnh tranh nhất quán.

### 11.4. `UC-DRV-004` — Driver chấp nhận một offer hợp lệ

- **Actor:** Driver; supporting Dispatch. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-004/005`.
- **FR:** `FR-DRV-003`, `FR-DRV-004`, `FR-DRV-008`, `FR-CORE-005`.
- **Precondition:** eligible/available cho service tương ứng; có offer không expired/revoked; driver capacity theo policy.
- **Minimal guarantee:** driver không có assignment ảo khi bấm nhận, không mất quyền audit, không vượt công suất theo policy.
- **Success guarantee:** server ghi nhận một committed assignment và cập nhật actor liên quan.

**Luồng chính**
1. `MSS-1`: Driver thấy offer với dữ liệu tối thiểu được phép.
2. `MSS-2`: Driver nhấn nhận trước thời điểm hết hiệu lực.
3. `MSS-3`: Server đánh giá eligibility, availability, capacity, current job state và offer version.
4. `MSS-4`: Server atomic commit assignment hoặc trả kết quả thất bại xác định; không dùng tốc độ push làm quyền sở hữu job.
5. `MSS-5`: Nếu thắng, app chuyển sang active job đúng service và tải lại chi tiết; nếu thua, giải thích job đã có người nhận/hết hạn.

**Extensions**
- `EX-2a`: Nhấn từ notification stale → phải kiểm server, không giả nhận thành công.
- `EX-3a`: Driver bị suspended trong lúc xem offer → reject.
- `EX-3b`: Driver có job không tương thích → chặn theo policy `OPEN-005`.
- `EX-4a`: Nhiều drivers submit cùng lúc → một thắng, các request khác conflict.
- `EX-4b`: Customer hủy cùng lúc → một terminal/committed outcome hợp lệ, không assignment mồ côi.

**AC:** `AC-UC-DRV-004-01` không 2 active assignments cùng job; `-02` expired/revoked deny; `-03` wrong driver deny; `-04` retry/parallel handling deterministic; `-05` chưa có server ACK không hiển thị chắc chắn đã nhận.

### 11.5. `UC-DRV-006` — Driver nhận món, giao và xác nhận hoàn thành

- **Actor:** Driver; supporting Merchant, Customer, Food Service. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-011/012/016/018`.
- **FR:** `FR-DRV-006`, `FR-MER-006`, `FR-MER-007`, `FR-FOOD-008`, `FR-FOOD-009`.
- **Precondition:** có committed assignment liên kết DeliveryTask, merchant có quyền bàn giao, order/stage cho phép pickup.
- **Minimal guarantee:** không đánh dấu delivered nếu chưa có evidence theo policy; không lộ tracking quá actor; failure không làm mất order/finance state.
- **Success guarantee:** giao thành công với proof hợp lệ, event final có audit, customer/merchant được đồng bộ, financial obligations có thể tính tiếp độc lập.

**Luồng chính**
1. `MSS-1`: Driver đến merchant dựa trên assignment, xác minh đúng order.
2. `MSS-2`: Merchant chuẩn bị xong/ready theo workflow riêng.
3. `MSS-3`: Driver và Merchant thực hiện giao nhận theo chứng cứ `OPEN-011` sau phê duyệt.
4. `MSS-4`: Server kiểm tra actor, state, evidence, liên kết DeliveryTask; cập nhật picked-up.
5. `MSS-5`: Driver di chuyển tới điểm giao, trạng thái cập nhật có kiểm soát quyền privacy/tracking.
6. `MSS-6`: Driver thực hiện xác nhận giao đến người nhận bằng proof theo policy.
7. `MSS-7`: Server commit delivered cho DeliveryTask và kết quả phù hợp FoodOrder; payment/settlement được đối soát theo lifecycle riêng.

**Extensions**
- `EX-2a`: Merchant chưa ready → chờ/report delay, không ghi picked-up.
- `EX-3a`: Sai món/túi/merchant → chặn handoff, báo issue liên kết đơn.
- `EX-4a`: Driver cố pickup sai assignment/đã thu hồi → deny và audit.
- `EX-5a`: Mất GPS/quyền location → degraded tracking và khôi phục, không tự completed.
- `EX-6a`: Không gặp khách/không giao được → mở exception, hỗ trợ, trách nhiệm chi phí chờ policy `OPEN-016`.
- `EX-7a`: Driver gửi complete hai lần → một completion, không double earnings/ledger.

**AC:** `AC-UC-DRV-006-01` only assigned driver can pickup/dropoff; `-02` no premature delivered; `-03` failed delivery ≠ paid; `-04` proof logic theo `OPEN-011`; `-05` retry no double earnings.

## 12. Fully dressed — Admin/Finance và xử lý sự cố

### 12.1. `UC-OPS-004` — Giải quyết hủy/hoàn tiền hoặc tranh chấp

- **Actor:** Admin Support/Finance có quyền; supporting Customer, Merchant, Driver. **Status:** `SPECIFIED_DRAFT`, blocked `OPEN-002/003/010/015/016/018`.
- **FR:** `FR-OPS-004`, `FR-OPS-006`, `FR-CORE-008`, `FR-CORE-011`.
- **Trigger:** case từ actor hoặc hệ thống cảnh báo sai lệch.
- **Precondition:** ticket có ID, subject/order/trip reference, actor sở hữu hợp lệ, reviewer có quyền truy cập/an toàn tài chính.
- **Minimal guarantee:** không lộ hồ sơ trái quyền; không tạo hoàn tiền/chi trả không trace; không silently mutate ledger.
- **Success guarantee:** ticket có disposition/reason/approval, hành động tài chính có outcome riêng, các bên thấy trạng thái phù hợp.

**Luồng chính**
1. `MSS-1`: Support mở case qua work queue có quyền.
2. `MSS-2`: Hệ thống hiển thị timeline giao dịch, bằng chứng, payment/ledger references tối thiểu cần thiết.
3. `MSS-3`: Nhân sự xác định nguyên nhân và hướng xử lý theo bảng quy tắc đã phê duyệt.
4. `MSS-4`: Hành động thay đổi tiền/hủy đặc biệt phải qua authorization + approval theo chính sách.
5. `MSS-5`: Server ghi decision audit, phát lệnh refund/adjustment có idempotency + trace.
6. `MSS-6`: Nhận provider result/reconciliation, cập nhật trạng thái `pending/succeeded/failed` đúng bản chất.
7. `MSS-7`: Case được giải quyết hoặc chuyển cấp, actor nhận thông báo không lộ dữ liệu ngoài quyền.

**Extensions**
- `EX-2a`: Dữ liệu bằng chứng bị thiếu → case pending investigation, không kết luận.
- `EX-3a`: Chưa có chính sách bồi hoàn Food đã chế biến → chặn compensation live (`OPEN-016`), escalation PO/Finance.
- `EX-4a`: Người xử lý không có quyền hoặc vượt limit → denied/escalated, audit.
- `EX-5a`: Submit lặp hoặc webhook retry → một financial effect theo reference.
- `EX-6a`: PSP chưa xác nhận → trạng thái pending, không phát receipt refunded giả.

**AC:** `AC-UC-OPS-004-01` no unauthorized refund; `-02` retry no duplicate money; `-03` case status độc lập payment outcome; `-04` evidence có audit; `-05` thiếu policy thì action bị chặn/đề nghị duyệt.

## 13. Use Cases xuyên vai trò — các luồng cần đọc như một hệ thống

### 13.1. `UC-X-001` — Ride end-to-end

- **Summary / actors:** Customer → RideService → Dispatch → Driver → TripService → Finance/Support.
- **Tiền điều kiện:** Customer/Driver hợp lệ; vùng/sản phẩm đã cấu hình ở test environment, quote và assignment contract đã định nghĩa.
- **Kết quả cuối:** RideRequest hợp lệ được assigned; Trip được hoàn tất qua evidence/guard, receipt và money states không lẫn.
- **Happy path:** `UC-RIDE-001` → `UC-RIDE-002` → `UC-RIDE-003` → `UC-RIDE-004` → `UC-DRV-004` → `UC-RIDE-005` → `UC-DRV-005`/`UC-RIDE-007` → `UC-RIDE-010`.
- **Alternative:** no-driver (`UC-X-010`), customer cancel (`UC-RIDE-008`), driver missing, GPS/mạng mất (`UC-X-007`), payment pending, tranh chấp (`UC-RIDE-012`).
- **Invariant:** Không có RideRequest trùng, hai assignments, complete không evidence hoặc double payment.
- **Gate:** `G2` functional Ride + race/reconnect/security tests; `G4` tích hợp role/finance; `G5` chỉ khi legal/ops phê duyệt.

```mermaid
sequenceDiagram
    actor C as Customer
    participant S as DealGo API
    participant D as Dispatch
    actor R as Driver
    C->>S: Xác nhận RideRequest (intent ref)
    S-->>C: RideRequest + trạng thái searching
    S->>D: Yêu cầu tìm tài xế
    D-->>R: DispatchOffer hợp lệ
    R->>S: Accept offer
    S->>S: Check capacity + atomic assignment
    S-->>C: Assignment đã commit
    S-->>R: Job được phân công
    R->>S: Xác nhận bắt đầu theo policy
    S-->>C: Trip in progress
    R->>S: Xác nhận kết thúc theo policy
    S-->>C: Trip completed; tài chính riêng
```

### 13.2. `UC-X-002` — Food end-to-end

- **Summary / actors:** Customer → Merchant → Dispatch → Driver → Finance/Support.
- **Tiền điều kiện:** Merchant/store eligible, item/menu đang mở, vùng giao hợp lệ, phương thức thanh toán sandbox đã cấu hình.
- **Kết quả:** một FoodOrder, merchant decision hợp lệ, một DeliveryTask/assignment đúng khi cần, delivered đúng bằng chứng và finance có thể reconcile.
- **Happy path:** `UC-FOOD-001` → `UC-FOOD-002` → `UC-FOOD-003` → `UC-FOOD-004` → `UC-FOOD-005` → `UC-FOOD-006` → `UC-MER-005` → `UC-MER-006` → `UC-DRV-004` → `UC-DRV-006` → `UC-FOOD-011`.
- **Alternative:** stale menu/price (`UC-X-004`), merchant reject, không driver sau ready (`UC-X-003`), không giao được, duplicate PSP event (`UC-X-005`), cancel/refund (`UC-X-009`).
- **Invariant:** FoodOrder và DeliveryTask tách lifecycle; Merchant accept ≠ picked up ≠ delivered ≠ paid; failed delivery không được sửa thành completed để close task.
- **Gate:** `G3` và sau đó `G4`, với `OPEN-009/010/011/016` là nhóm blocker chính.

```mermaid
sequenceDiagram
    actor C as Customer
    participant S as DealGo API
    actor M as Merchant
    participant D as Dispatch
    actor R as Driver
    C->>S: Checkout confirm (intent ref)
    S-->>C: FoodOrder + payment state riêng
    S-->>M: Đơn cần quyết định
    M->>S: Accept order
    S-->>C: Merchant accepted
    M->>S: Preparing -> Ready
    S->>D: Chuẩn bị/khởi tạo điều phối theo policy
    D-->>R: Delivery offer
    R->>S: Accept offer
    S->>S: Atomic assignment
    R->>S: Pickup proof (theo policy)
    S-->>C: Đơn đã được lấy
    R->>S: Delivery proof (theo policy)
    S-->>C: Đã giao; tài chính xử lý riêng
```

### 13.3. `UC-X-003` — Food quán đã làm nhưng không tìm được tài xế

- **Actor:** Merchant/Ops, affected Customer. **Status:** `BLOCKED_BY_POLICY` `OPEN-004/016`, minh họa failure path quan trọng.
- **Trigger:** FoodOrder đã chuẩn bị/ready hoặc vượt mốc xử lý đã duyệt, chưa có committed DeliveryTask assignment.
- **Precondition:** order trạng thái hợp lệ, merchant đã thực hiện công việc; tài xế chưa được gán.
- **Minimal guarantee:** không tự hủy không thông báo, không tự coi delivered, không suy đoán ai chịu phí chế biến.
- **Failure/Recovery sequence:** (1) Dò tình trạng supply/dispatch; (2) Giữ order timeline đầy đủ; (3) Cảnh báo Merchant/Customer về trì hoãn theo quy định; (4) Thử dispatch lại/chuyển Ops theo policy; (5) Nếu buộc hủy, đi qua approval/compensation/refund case và ledger độc lập; (6) Reconcile hoàn tất và thông báo kết quả.
- **Exceptions:** khách hủy đồng thời; quán đóng cửa; đã capture tiền; offer cũ được nhận muộn; customer mất kết nối.
- **AC:** không phantom assignment/delivered; không auto refund/compensate với công thức TBD; có incident/case ID; trạng thái tiền và đơn được đối chiếu.

### 13.4. `UC-X-004` — Thay đổi giá khi khách đang checkout

- **Trigger:** item/menu/giá thay đổi sau khi Customer thêm vào giỏ.
- **Steps:** (1) Cart giữ dữ liệu đã chọn; (2) backend revalidate at checkout; (3) trả changed-items/current total; (4) khách review/accept hoặc sửa/thoát; (5) create-order kiểm lại tại commit.
- **Failure guarantee:** không dùng giá client cũ, không thu theo giá chưa chấp thuận, không tự đổi món.
- **AC:** test đồng thời merchant cập nhật giá, 2 checkout requests, lost response; giá snapshot phản ánh kết quả khách đã xác nhận.

### 13.5. `UC-X-005` — PSP callback đến lặp hoặc không theo thứ tự

- **Actor:** External PSP, System, Finance; use case thuộc integration test, không phải thao tác người dùng.
- **Trigger:** callback/webhook cho payment/refund hoặc settlement reference đã xử lý, hoặc đến không theo thứ tự.
- **Precondition:** provider đã cấu hình và verify origin/signature theo hợp đồng riêng; idempotency keys/event refs có thể reconcile.
- **Steps:** (1) Xác thực callback; (2) nhận và lưu event reference; (3) kiểm event đã xử lý chưa; (4) kiểm quan hệ state/amount/reference; (5) tạo financial effect một lần hoặc gắn exception; (6) trả acknowledgment/đưa vào retry/DLQ theo contract.
- **Failure guarantee:** duplicate không làm ledger nhân đôi; không ghi `paid` khi signature sai hoặc amount mismatch; vẫn điều tra được sự kiện ngoại lệ.
- **AC:** replay cùng event 10 lần hoặc delivery đảo thứ tự → số effect hợp lệ không tăng; mismatch có exception case; callback sai chữ ký bị chặn.

### 13.6. `UC-X-006` — Multi-role cùng lúc có active job

- **Trigger:** User có role Driver và Customer/Merchant cố chuyển role hoặc thực hiện thao tác khi đang có assignment.
- **Steps:** (1) Lấy active role + active job; (2) kiểm role eligibility và capacity policy; (3) quyết định allow-switch/foreground job visibility/block theo `OPEN-005`; (4) đảm bảo thao tác server luôn kiểm quyền; (5) app khôi phục công việc khi quay lại role liên quan.
- **Minimal guarantee:** không mất active job, không để một người khai thác chéo quyền; không mặc định cho phép nhiều job song song.
- **AC:** role switch liên tục, hai session, cold start, deep link trễ và logout được test; server rejects không phụ thuộc shell UI.

### 13.7. `UC-X-007` — Realtime recovery

- **Trigger:** app bị kill, mạng gián đoạn, push trễ hoặc socket reconnect trong lúc request/ride/food active.
- **Steps:** (1) Client lưu identifier tối thiểu an toàn; (2) sau reconnect xác thực session; (3) truy vấn snapshot state canonical; (4) đồng bộ timeline/version; (5) đăng ký lại updates; (6) bỏ qua thông báo cũ; (7) hiện trạng thái đã đồng bộ.
- **Minimal guarantee:** không nhảy lùi trạng thái hoặc tự complete/cancel; không tái tạo cùng intent thành giao dịch mới.
- **AC:** kill ở 5 stage chính, event out-of-order, nhiều thiết bị, push stale; snapshot authoritative luôn thắng.

### 13.8. `UC-X-008` — Ngăn IDOR và lộ dữ liệu đa role/store

- **Trigger:** actor cố truy cập order/trip/store khác bằng ID, deep link, cache hoặc API.
- **Steps:** (1) Backend authenticate; (2) authorize principal, active capabilities, ownership/store scope; (3) từ chối nếu không đủ quyền, tránh leaked existence nếu policy yêu cầu; (4) audit an toàn; (5) Flutter clear stale role-scoped UI data.
- **AC:** customer A không xem B; merchant X không sửa menu hoặc accept order Y; Driver không thấy thông tin assignment khác; Admin Support không tự xem PII ngoài scope.

### 13.9. `UC-X-009` — Hủy, hoàn và đối soát xuyên lifecycle

- **Trigger:** cancel ở stage pre/post merchant accept, before/after driver assigned, hoặc Ride trước/sau pickup; trạng thái cụ thể theo policy.
- **Steps:** (1) Xác minh stage + ownership; (2) đọc cancellation entitlement; (3) thông báo hậu quả; (4) commit business cancellation có audit nếu được phép; (5) xử lý payment/compensation/merchant/driver obligations riêng; (6) reconcile và gửi trạng thái cuối.
- **AC:** concurrent cancel vs accept/pickup, double refund request, PSP delayed, dispute; không có trạng thái tài chính mâu thuẫn và không suy đoán phí.

### 13.10. `UC-X-010` — No-driver trước Ride assignment

- **Trigger:** toàn bộ candidate không khả dụng hoặc dispatch đạt ngưỡng đã duyệt.
- **Steps:** (1) xác minh request chưa assigned/cancelled; (2) thực thi vòng/retry theo policy; (3) xử lý hết candidate/timeout thành trạng thái hợp lệ; (4) ngăn stale offer được nhận; (5) thông báo và hướng dẫn đặt lại hoặc hỗ trợ.
- **AC:** không vòng tìm vô hạn ngoài policy; không tiếp tục nhận offer sau terminal; không nhân RideRequest khi refresh.

### 13.11. `UC-X-011` — Phê duyệt đối tác trước live job

- **Trigger:** Merchant/Driver hoàn thành hồ sơ; reviewer có quyền bắt đầu thẩm định.
- **Steps:** (1) nhận hồ sơ và version; (2) giới hạn quyền xem PII; (3) xác minh theo quy trình hợp lệ; (4) approved/rejected/needs-more-info có reason+audit; (5) cập nhật eligibility chính xác; (6) chặn job mới nếu giấy tờ hết hạn hoặc status bị thu hồi.
- **AC:** pending/suspended không thấy eligible offers; no self-approval trái policy; audit + retention evidence.

### 13.12. `UC-X-012` — Khóa nhận giao dịch mới theo vùng / dịch vụ

- **Trigger:** incident nghiêm trọng do Ops được ủy quyền hoặc automation alert cần can thiệp.
- **Steps:** (1) cảnh báo có severity/correlation; (2) xác minh lý do và người có quyền; (3) duyệt/toggle trạng thái vùng-service có version + expiry khi áp dụng; (4) chặn RideRequest/FoodOrder mới; (5) **không âm thầm hủy** các giao dịch active; (6) khôi phục theo runbook và audit.
- **AC:** fail closed với request mới khi cần, không lặp/mất active job, cấu hình được propagate có bằng chứng; rollback có quyền và vết kiểm tra.

## 14. Phân tách happy path, alternative, exception và recovery

| Loại | Ý nghĩa | Trách nhiệm QA/agent |
|---|---|---|
| `HAPPY` | Đạt mục tiêu chính trên dữ liệu hợp lệ | Kiểm từ actor entry tới success guarantee |
| `ALTERNATIVE` | Vẫn đạt mục tiêu nhưng cách thực hiện khác | Kiểm cổng chuyển nhánh và quay lại main flow |
| `EXCEPTION` | Không thể hoàn tất mục tiêu | Kiểm minimal guarantee và error UX |
| `RECOVERY` | Khôi phục sau timeout/retry/offline/PSP outage | Kiểm authoritative state, idempotency, non-duplication |
| `CONCURRENCY` | 2+ tác nhân/thông điệp tranh nhau state | Kiểm atomicity, guards, deterministic loser result |
| `SECURITY` | IDOR, role bypass, event spoof, invalid evidence | Kiểm deny + audit + no sensitive leak |

Một hành động không được coi là `RECOVERY` nếu chỉ hiển thị toast rồi mất cơ hội tra cứu giao dịch. Một use case xử lý tiền không được đánh dấu `HAPPY` chỉ vì app hiển thị thành công trong khi PSP/ledger vẫn pending.

## 15. Risk-oriented edge-case test seeds

> Đây là **ý tưởng test**, không phải ID `TC-*` chính thức. QA sẽ tách thành test suite và gán `TC-*` trong `08-quality/*`.

| Nhóm | Scenario cần test | Expected observable result | UC |
|---|---|---|---|
| Auth | Token hết hạn khi submit | Không lặp booking; login/recovery có kiểm quyền | `UC-CORE-001`, `UC-X-007` |
| Roles | Deep link Merchant sau chuyển Customer | Authorization deny, role cache không rò | `UC-CORE-002`, `UC-X-008` |
| Onboarding | Driver pending bật available | Reject với eligibility reason | `UC-DRV-001`, `UC-X-011` |
| Location | GPS thiếu quyền, location null/out-of-zone | Không commit với dữ liệu không hợp lệ | `UC-CORE-004`, `UC-RIDE-001` |
| Quote | Giá thay sau khi confirm preview | Yêu cầu review lại | `UC-CORE-007`, `UC-X-004` |
| Ride | Double tap gọi xe | Một RideRequest | `UC-RIDE-003` |
| Ride | Tạo request commit nhưng response mất | Recovery đúng ID, không tạo mới | `UC-RIDE-003`, `UC-X-007` |
| Dispatch | 2 tài xế đồng thời accept | Một assignment thắng | `UC-DRV-004`, `UC-RIDE-004` |
| Dispatch | Customer cancel cùng driver accept | Một outcome không mâu thuẫn | `UC-RIDE-008`, `UC-X-010` |
| Dispatch | Offer hết hạn nhưng push đến muộn | Accept bị reject | `UC-RIDE-004`, `UC-DRV-004` |
| Ride | Begin/complete sai stage | Server từ chối, audit | `UC-DRV-005`, `UC-RIDE-007` |
| Ride | Không có khách tại điểm đón | Exception theo policy, không giả started | `UC-DRV-010`, `UC-RIDE-007` |
| Ride | Trip completed, payment pending | Hai status tách biệt | `UC-RIDE-010`, `UC-CORE-008` |
| Food | Merchant tạm đóng khi checkout | Block order, không thu âm thầm | `UC-FOOD-005` |
| Food | Item required option không hợp lệ | Revalidate and reject | `UC-FOOD-003`, `UC-FOOD-005` |
| Food | Menu tăng giá sau add-to-cart | Show difference, need consent | `UC-X-004` |
| Food | 2 confirm order cùng intent | Một order/payment intent | `UC-FOOD-006` |
| Merchant | Nhân viên Store A accept Order B | Deny, audit | `UC-MER-005`, `UC-X-008` |
| Merchant | Accept/reject cạnh tranh trên 2 devices | Một quyết định cuối | `UC-MER-005` |
| Merchant | Ready rồi không tìm được tài xế | Escalate đúng, không tự quyết bồi hoàn | `UC-X-003` |
| Driver | Driver mất GPS sau pickup Food | Recovery, không auto deliver | `UC-DRV-006`, `UC-X-007` |
| Driver | Pickup sai delivery assignment | Deny, không thay trạng thái | `UC-DRV-006` |
| Driver | Nhận Ride khi đã có Food active | Theo capacity policy đã duyệt | `UC-DRV-008`, `UC-X-006` |
| Finance | PSP gửi một webhook 10 lần | Chỉ một financial effect | `UC-X-005` |
| Finance | Refund API timeout rồi callback thành công | Reconcile đúng, không double refund | `UC-OPS-004`, `UC-X-005` |
| Finance | Refund amount khác số cho phép | Reject/escalate, không settled | `UC-OPS-004` |
| Security | Customer đổi URL order_id của người khác | `403/404` theo policy, không leak dữ liệu | `UC-X-008` |
| Realtime | Push `assigned` cũ sau `cancelled` | Snapshot/version canonical thắng | `UC-X-007` |
| Ops | Disable zone trong lúc active Ride | Chặn yêu cầu mới, giữ đúng active jobs | `UC-X-012` |
| Ops | Admin vượt quyền hoàn tiền | Deny và audit | `UC-OPS-004` |
| Ops | Audit report chứa nguyên PII/secrets | Masking/least privilege | `UC-OPS-008` |
| Reliability | Backend restart sau assignment commit | Không cấp thêm assignment | `UC-RIDE-004`, `UC-X-007` |
| Data | Duplicate event out of order | State không thoái lui hoặc nhân ledger | `UC-X-005`, `UC-X-007` |
| Privacy | Merchant nhìn GPS driver ngoài phạm vi | Chỉ trả projection theo quyền | `UC-MER-007`, `UC-X-008` |

## 16. Traceability và ma trận gán cho đội triển khai

### 16.1. Bảng nối tài liệu

| Từ | Đến | Cách xác minh |
|---|---|---|
| `UC-*` | `FR-*` hiện có | Mỗi UC catalog có FR hợp lệ; `71/71 FR` được cover |
| `UC-*` | `OPEN-*` | Các blocker thuộc `OPEN-001..019`; thay đổi phải cập nhật cả hai |
| `UC-*` | `BR-*` `[PLANNED]` | Thêm khi quy tắc đã được thiết kế/phê duyệt ở `02-domain/*` |
| `UC-*` | `WF-*` `[PLANNED]` | Map state transitions ở `03-workflows/*` |
| `UC-*` | `SCR-*` `[PLANNED]` | Map screen và empty/loading/error/permission states ở `04-experience/*` |
| `UC-*` | `API-*`, `EVT-*` `[PLANNED]` | OpenAPI/AsyncAPI contract khi tạo 06-data-api files |
| `UC-*` | `TC-*` `[PLANNED]` | Positive/negative/race/recovery/security test cases ở 08-quality |
| `UC-*` | release `G0–G5` | Test evidence + production gate như `scope-release-plan.md` |

### 16.2. Vertical slice đề xuất cho triển khai

| Slice | Đọc use cases trước | Chính sách phải chốt để chạy live | Mốc |
|---|---|---|---|
| VS-01 Identity & multi-role | `UC-CORE-001/002/003/010`, `UC-X-008/011` | `OPEN-005/006/008/013` | `G1/G4` |
| VS-02 Ride request | `UC-RIDE-001/002/003/004`, `UC-CORE-006/007` | `OPEN-001/003/004` | `G2` |
| VS-03 Ride trip | `UC-DRV-004/005`, `UC-RIDE-005/007/008`, `UC-X-001/010` | `OPEN-004/005/017` | `G2` |
| VS-04 Food catalog & cart | `UC-FOOD-001..005`, `UC-MER-002/003` | `OPEN-001/003/009/013` | `G3` |
| VS-05 Food order & fulfillment | `UC-FOOD-006..010`, `UC-MER-004..007`, `UC-DRV-006`, `UC-X-002/003` | `OPEN-004/009/010/011/016` | `G3` |
| VS-06 Payment & finance | `UC-CORE-008/013`, `UC-OPS-004/006`, `UC-X-005/009` | `OPEN-002/003/010/018` | `G4/G5` |
| VS-07 Reliability & Ops | `UC-X-007/008/012`, `UC-OPS-003/005/008/009` | `OPEN-007/012/015` | `G4/G5` |

### 16.3. Checklist cho một UC được đưa vào coding agent

- [ ] `FR-*` và actor đã được Product review; scope P0/P1/P2 có bằng chứng.
- [ ] `OPEN-*` liên quan được duyệt hoặc tài liệu ghi rõ chỉ mock/test, không chạy giao dịch thật.
- [ ] Có precondition, trigger, MSS, extensions, minimal/success guarantees.
- [ ] Workflow guard, state owner, failure recovery và source of truth rõ.
- [ ] Data/APIs/events/UI states có hợp đồng phù hợp; không lặp lại schema chỉ để tô đẹp docs.
- [ ] Có acceptance tests (success, negative, security, concurrency nếu liên quan, retry/reconnect nếu liên quan).
- [ ] Rà idempotency, permission, PII, audit, tài chính (nếu applicable).
- [ ] Có telemetry/diagnostics tối thiểu để chứng minh hoạt động.
- [ ] Có evidence ở release gate; agent không tự tuyên bố `APPROVED`/`VERIFIED`.

## 17. Ownership, review và quy trình sửa UC

| Nội dung thay đổi | Review bắt buộc | Output thay đổi tương ứng |
|---|---|---|
| Scope/role/user-facing goal | PO/BA/UX | PRD, personas, screen inventory |
| Giá, payment, refund, driver earnings | PO/Finance/Ops/Legal | Decision, finance rules, API/test |
| Dispatch, capacity, ETA | PO/Tech/Ops | State machine, concurrency tests, metrics |
| Identity, KYC/KYB, PII, security | PO/Tech/Security/Legal | Access model, threat model, privacy policy |
| Onboarding Merchant/Driver | PO/Ops/Legal | Documents, state, admin workflow, screens |
| Reliability, app background, GPS | Tech/Mobile/Ops/Privacy | Realtime strategy, permissions, recovery/test |

Khi scope thay đổi: mở issue và `DEC/OPEN` record → impact review → cập nhật `FR` → sửa `UC` → hợp đồng UI/API/BR/WF → test → nghiệm thu. Tránh chỉ sửa màn hình khiến quy trình phía backend trái ngữ nghĩa.

## 18. Các quyết định còn mở cần xử lý trước các mốc

| OPEN | Nhóm UC chịu ảnh hưởng chính | Hệ quả nếu chưa chốt |
|---|---|---|
| `OPEN-001` | Ride/Food địa bàn, Ops zone | Không public vùng hoạt động thực |
| `OPEN-002` | Food create, Ride receipt, Finance | Không thu tiền thật |
| `OPEN-003` | Quote, checkout, cancel, earnings/refund | Không hard-code mức giá/phí/thỏa thuận |
| `OPEN-004` | Ride/Food dispatch/offer/reassignment | Chỉ chạy dispatch fixture chưa chứng minh live |
| `OPEN-005` | Role switching, Driver accept/capacity | Không suy ra đa job/đa role cho live |
| `OPEN-006` | KYC/KYB, Partner approval | Không kích hoạt đối tác thương mại thiếu căn cứ |
| `OPEN-007` | Ops monitor, outage, G4/G5 | Chưa chốt SLO/performance targets |
| `OPEN-008` | OTP, Maps, payment, push, KYC providers | Chỉ dùng adapter/mock tới khi approved |
| `OPEN-009` | Cart và checkout Food | Không cố định một/đa merchant trong code production |
| `OPEN-010` | Food payment relative to merchant accept | Không quyết định capture/authorize ngầm |
| `OPEN-011` | Driver pickup/delivery proof | Không tự chọn OTP/ảnh/chữ ký là bắt buộc |
| `OPEN-012` | Driver GPS/background/reconnect | Không âm thầm tracking ngoài quyền/đồng ý |
| `OPEN-013` | Merchant staff/multi-store access | Không cho staff vượt tenancy |
| `OPEN-014` | In-app contact, notification, support | Không lộ PII bằng kênh chưa duyệt |
| `OPEN-015` | Ops support/safety/escalation | Chưa thể khẳng định đã sẵn sàng ứng cứu live |
| `OPEN-016` | Food ready/no-driver, cancel/compensation | Không tự kết luận bên chịu chi phí |
| `OPEN-017` | Ride trip start/end, evidence | Không giả định thao tác bắt đầu/kết thúc |
| `OPEN-018` | COD/collection/driver debt | Không tự bật thu hộ/công nợ |

## 19. Tài liệu tham khảo và giới hạn bằng chứng

### Phương pháp use case

- Object Management Group — [UML 2.5.1 Specification](https://www.omg.org/spec/UML/2.5.1/): quy ước actor, use case và relationship (UML); không coi UML thay cho quy tắc nghiệp vụ chi tiết.
- Alistair Cockburn — [Writing Effective Use Cases, chương Use Case Formats](https://www.cs.otago.ac.nz/coursework/cosc461/weucx.pdf): mô hình fully dressed với preconditions, minimal/success guarantee, main scenario và extensions. Quyền tác giả thuộc nguồn gốc; chỉ dùng phương pháp, không sao chép nội dung mẫu.
- Craig Larman — [Applying UML and Patterns, use-case templates](https://www.craiglarman.com/wiki/downloads/applying_uml/larman-ch6-applying-evolutionary-use-cases.pdf): hướng dẫn goal level và format có thể mở rộng.

### Tài liệu DealGo đã tồn tại

- `../00-governance/README.md` — map docs và quy tắc AI Agent.
- `../00-governance/project-charter.md` — product scope/actor/value.
- `../00-governance/scope-release-plan.md` — release gates, P0 candidates.
- `../00-governance/glossary.md` — thuật ngữ, không lẫn các entity.
- `../00-governance/decisions-and-assumptions.md` — decisions và open issues source of truth.
- `./product-requirements.md` — **nguồn 71 FR**, invariants và UAT cấp sản phẩm.
- `./competitor-benchmark.md` — bằng chứng luồng công khai; không đại diện logic nội bộ đối thủ.
- `./personas-and-stakeholders.md` — 14 proto-personas, journey maps và research hypotheses.

### Docs tiếp theo `[PLANNED]`

- `./functional-requirements.md`, `./non-functional-requirements.md` — tách atomic acceptance và NFR.
- `../02-domain/domain-model.md`, `../02-domain/roles-and-permissions.md`, `../02-domain/cancellation-refund-disputes.md` — domain policy và permissions.
- `../03-workflows/ride-booking-e2e.md`, `../03-workflows/food-ordering-e2e.md`, `../03-workflows/dispatch-and-assignment.md`, `../03-workflows/exceptions-and-recovery.md` — chi tiết state/timeout/race.
- `../04-experience/screen-inventory.md`, `../04-experience/screen-specifications.md` — ánh xạ UX/screen state.
- `../06-data-api/rest-api.openapi.yaml`, `../06-data-api/events.asyncapi.yaml` — hợp đồng giao tiếp.
- `../08-quality/critical-e2e-test-matrix.md`, `../10-ai-execution/requirement-traceability.md` — test/traceability.

## 20. Kiểm tra chất lượng tài liệu và ký duyệt

### 20.1. Checklist trước khi chuyển `IN_REVIEW`

- [x] Danh mục có **71 UC** 1:1 với tất cả `71 FR` PRD, không bịa mã FR.
- [x] Có **12 UC xuyên vai trò**, đánh dấu rõ không phải FR mới.
- [x] Cả Ride + Food, Merchant, Driver, Admin, Customer và Shared Platform đều được bao phủ.
- [x] Có use case có precondition, minimal/success guarantee, happy/alternative/failure và acceptance.
- [x] Chính sách chưa chốt link `OPEN-001..019`; không có giá/km, thời gian, bán kính, phí, COD tự đặt.
- [x] Không trộn Payment với Order/Trip; không xem received offer = committed assignment.
- [x] Có ma trận test negative/race/recovery/security và hướng dẫn agent.
- [ ] Owner/PO review scope và chấp nhận priority P0 candidates.
- [ ] Tech/Operations/Finance/Security/Legal phê duyệt các policy blocker tương ứng.
- [ ] QA tạo test case ID chuẩn và liên kết traceability.
- [ ] API/workflow/screens chính thức đã được viết và cross-link ở thời điểm triển khai.

### 20.2. Approval record

| Trường | Giá trị |
|---|---|
| Document version | `0.1.0` |
| Status | `DRAFT` |
| Proposed owner | Product / BA |
| Reviewers | PO, Tech Lead, Mobile Lead, QA, Ops, Finance, Security/Legal |
| Approved by | `TBD` |
| Effective date | `TBD` |

### 20.3. Changelog

| Ngày | Phiên bản | Thay đổi |
|---|---|---|
| 2026-10-12 | `0.2.0` | Bổ sung UC auth methods/admin controls/chat/voice; cập nhật baseline thành 71 FR-linked UCs, giữ 12 UC xuyên actor. |
| 2026-10-11 | `0.1.0` | Tạo catalog 67 FR-linked + 12 cross-actor UCs; fully dressed high-risk flows, exception matrix, policy blockers, agent handoff và traceability. |

**Tài liệu kế tiếp theo roadmap:** `docs/01-product/functional-requirements.md` (10/69) — tách 71 yêu cầu thành yêu cầu nguyên tử `shall`, các business constraints, acceptance và negative tests; giữ `FR-*` gốc, không tự thay đổi scope.
