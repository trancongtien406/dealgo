---
doc_id: DG-SRS-FR-001
title: "DealGo — Functional Requirements Specification (FRS / SRS-Functional)"
version: "0.2.0"
status: "DRAFT"
owner: "Product Owner / Business Analyst"
reviewers:
  - "Tech Lead / Backend"
  - "Flutter Lead"
  - "UX Lead"
  - "QA Lead"
  - "Operations"
  - "Finance"
  - "Security / Privacy"
last_updated: "2026-10-12"
classification: "Internal"
upstream_docs:
  - "../00-governance/decisions-and-assumptions.md"
  - "../00-governance/scope-release-plan.md"
  - "../00-governance/glossary.md"
  - "./product-requirements.md"
  - "./use-case-catalog.md"
downstream_planned:
  - "./non-functional-requirements.md"
  - "../02-domain/domain-model.md"
  - "../03-workflows/ride-lifecycle.md"
  - "../03-workflows/food-fulfillment.md"
  - "../03-workflows/dispatch-and-assignment.md"
  - "../06-data-api/rest-api.openapi.yaml"
  - "../08-quality/acceptance-criteria.md"
---

# DealGo — Functional Requirements Specification (FRS)

> **Bản nháp kỹ thuật có kiểm soát.** File này chi tiết hóa **71 yêu cầu `FR-*` đã đăng ký trong PRD** và trỏ tới 71 `UC-*` tương ứng. Các điều kiện nghiệm thu trong đây là **đề xuất để kiểm thử**, không phải bằng chứng rằng tính năng đã được code hoặc policy đã được duyệt. Các định hướng sản phẩm `DEC-PROD-001..007` được xác nhận; mọi phụ thuộc `OPEN-*` phải tiếp tục xử lý theo Governance. `G2/G3/G4/G5` là release gates, **không phải ngày hẹn**.

## 1. Purpose, scope, nguyên tắc nguồn sự thật

- Chuyển PRD từ câu mô tả nhu cầu sang hành vi **có trigger, tiền điều kiện, output, negative path và acceptance có thể kiểm chứng**.
- Baseline hiện tại gồm 18 CORE, 12 RIDE, 12 FOOD, 9 MER, 10 DRV, 10 OPS = **71 functional requirements**. Không tự đổi mã; các FR 016–018 CORE và OPS-010 là change theo `DEC-PROD-006/007`.
- Đối tượng: **Customer, Merchant, Driver trong một app Flutter**, và **Ops/Support/Finance/Admin trong Admin Web tách biệt**. Ride hai bánh và Food đều thuộc mục tiêu MVP.
- Đây là **functional black-box requirements**, không áp đặt NestJS/Redis/Kafka/BLoC, endpoint, tên enum hay cấu trúc SQL. Contract cụ thể thuộc docs kiến trúc/data/API; không biến ví dụ thành yêu cầu production.
- PRD là nguồn của ý nghĩa FR và mức ưu tiên; `use-case-catalog.md` là nguồn của UC; `decisions-and-assumptions.md` là nguồn duy nhất về trạng thái `OPEN/RESOLVED`.

### 1.1. Chỉ dẫn tính chuẩn tắc

| Nhãn | Ý nghĩa | Hệ quả với coding agent |
|---|---|---|
| `CONFIRMED_SCOPE` | Định hướng đã được chủ dự án xác nhận | Không bỏ Ride/Food, không tách ba role thành ba app mà không qua change control |
| `PROPOSED_P0` | Hành vi cần để kiểm thử MVP nhưng chưa duyệt hết policy | Có thể xây khung, business guard và sandbox adapter; không mở production nếu còn blocker |
| `POLICY_BLOCKED` | Kết quả phụ thuộc `OPEN-*` | Stub/config/test fixture có dấu `TEST_ONLY`; không hard-code giá, timeout hay trách nhiệm bồi thường |
| `NOT_APPROVED` | Không có quyết định cho policy/provider | Dừng phần xử lý thật, chuyển câu hỏi sang Governance |
| `ACCEPTANCE_DRAFT` | Tiêu chí trong tài liệu này | QA/PO xác nhận trước khi dùng làm cổng release |

### 1.2. Ranh giới không được phá vỡ

1. `RideRequest` khác `RideTrip`, `FoodOrder` khác `DeliveryTask`; `FareCounterOffer` khác `DispatchOffer`/`DriverAssignment` (đề nghị giá không phải lời mời nhận job).
2. Quote/checkout có snapshot và phiên bản server; mobile không được chọn giá hoặc state cuối cùng.
3. Actor phải đủ role + eligibility + ownership/scope cho từng đối tượng; client hidden menu/deep link không cấp quyền.
4. Side effect có idempotency và concurrency guard; replay/late events không tạo order, assignment, refund, ledger posting lặp.
5. GPS, push, receipt, merchant-ready, delivered, payment, settlement có bằng chứng và lifecycle độc lập.
6. Policy thương mại, điều phối, OTP/KYC, proof delivery, tracking nền, contact channel, COD và support SLA cần `OPEN-*` tương ứng trước vận hành thật.

## 2. Cấu trúc của một yêu cầu có thể triển khai

Mỗi yêu cầu `FR-ID` có: **UC nguồn**, mô tả hành vi PRD, actor/trigger, tiền điều kiện và input, thành công/output, nhánh bị từ chối/fallback, một tình huống test chủ chốt và **ba acceptance IDs**. Cú pháp `AC-FR-...` dành riêng cho file này; về sau test catalog `TC-*` sẽ liên kết các mã này, **không giả vờ `TC-*` đã tồn tại**.

- `AC-...-01`: hành vi chính quan sát được trong môi trường test có fixture đã biết.
- `AC-...-02`: lỗi/validation/quyền phải từ chối an toàn, không tạo side effect sai.
- `AC-...-03`: regression test có tính chất cạnh tranh, khôi phục, privacy hoặc trạng thái đặc thù.
- Với acceptance phụ thuộc `OPEN-*`, chỉ được PASS sandbox với config được gắn nhãn; **không tự coi PASS sandbox là đủ cho G5**.
- Business rule ID `BR-*` chỉ được dẫn lại từ PRD; mọi rule chi tiết mới phải qua docs domain/governance.

## 3. Functional quality contract dùng chung

### 3.1. Authentication, authorization và tenancy

Mọi operation phải kiểm: authenticated principal → eligible role → operation permission → object ownership/merchant-store scope → state guard → business eligibility. Ẩn nút hoặc lựa chọn active role trên mobile không thay thế kiểm phía server. Với object không đủ quyền, response không được tiết lộ thông tin về chủ sở hữu, KYC hay trạng thái tài chính. Các policy lỗi cụ thể sẽ định nghĩa trong API contract.

### 3.2. Idempotency, optimistic concurrency và transaction boundaries

- Lệnh create/accept/complete/pay/refund có *stable business intent* và correlation ID; server định nghĩa semantic replay cùng key, payload fingerprint và retention theo contract tương lai. Không mặc định TTL khi chưa duyệt.
- Không để client tự quyết thắng offer. Assignment thắng phải commit atomic với guard eligibility/capacity/job version, xử lý concurrent requests và event đến trễ.
- Với payment/refund, event/provider reference duy nhất phải gắn journal/ledger outcome; không coi network timeout là thất bại chắc chắn hoặc thành công chắc chắn.
- Transition đến terminal state không được chạy lại side effect. Nếu retry một thao tác terminal đã thành công, trả replay result hoặc conflict thích hợp theo contract.

### 3.3. Validation và tính nhất quán của dữ liệu

- Input người dùng: trim/canonicalize hợp lý; giới hạn trường và kiểm type/range theo schema được duyệt; không nhúng giá/role/owner ID từ client làm nguồn tin cậy.
- Địa điểm: kiểm tọa độ, vùng khả dụng, độ chính xác và thời điểm lấy dữ liệu; route/ETA là **estimate**, không phải bằng chứng vị trí thực.
- Menu/quote: kiểm item/option thuộc cùng merchant và snapshot/version; sau khi commit không âm thầm thay đổi đơn đã bán.
- Tài chính: dùng currency, precision và rounding theo policy `OPEN-003`; không tính bằng float không kiểm soát. Số tiền trong ví dụ test không phải bảng giá live.

### 3.4. Trạng thái UI và lỗi tiêu chuẩn

Client/API phải phân biệt `initial`, `loading`, `success`, `empty`, `validation_error`, `forbidden`, `not_eligible`, `conflict`, `stale`, `retryable_error`, `terminal_failure`, `requires_support`. Các tên trên là **khái niệm**, không khóa enum. Bất cứ thao tác mutating nào timeout phải kiểm lại trạng thái bằng idempotency key / resource ID trước khi cho tạo lại. Đề xuất theo [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457.html) cho lỗi HTTP; cấu trúc `Problem Details` ở API docs chuyên trách.

### 3.5. Audit, privacy, offline và thông báo

- Audit: actor/role/resource/reason (nếu yêu cầu), timestamp server, correlation ID, before/after dạng được phép; không log OTP, bearer token, giấy tờ cá nhân dạng thô.
- Push/socket chỉ là tín hiệu thông báo; bản ghi cuối phải fetch từ server; reconnect không đảo trạng thái.
- Mobile offline không được báo tác vụ tài chính/giao hàng đã hoàn thành khi server chưa commit. Mọi queue offline mutating phải có policy đồng bộ/expiry và conflict detection.
- Sensitive location và partner documents phải bảo vệ theo actor scope, consent/permission/retention sẽ có docs riêng.

## 4. Ma trận FR → UC → domain/release/điểm review

**71 dòng sau có cùng ID và nội dung với PRD.** Chúng là `PROPOSED_P0` ở mức đặc tả; mức P0 của capability/phase được quản lý trong `scope-release-plan.md`.
### 4.1. Shared Platform / Identity & Consistency
| FR | UC nguồn | Gate(s) | Owner review |
|---|---|---|---|
| `FR-CORE-001` | `UC-CORE-001` | G1/G4 | Product + Tech + Security |
| `FR-CORE-002` | `UC-CORE-002` | G1/G4 | Product + Tech + Security |
| `FR-CORE-003` | `UC-CORE-003` | G1/G4 | Product + Tech + Security |
| `FR-CORE-004` | `UC-CORE-004` | G1/G4 | Product + Tech + Security |
| `FR-CORE-005` | `UC-CORE-005` | G1/G4 | Product + Tech + Security |
| `FR-CORE-006` | `UC-CORE-006` | G1/G4 | Product + Tech + Security |
| `FR-CORE-007` | `UC-CORE-007` | G1/G4 | Product + Tech + Security |
| `FR-CORE-008` | `UC-CORE-008` | G1/G4 | Product + Tech + Security |
| `FR-CORE-009` | `UC-CORE-009` | G1/G4 | Product + Tech + Security |
| `FR-CORE-010` | `UC-CORE-010` | G1/G4 | Product + Tech + Security |
| `FR-CORE-011` | `UC-CORE-011` | G1/G4 | Product + Tech + Security |
| `FR-CORE-012` | `UC-CORE-012` | G1/G4 | Product + Tech + Security |
| `FR-CORE-013` | `UC-CORE-013` | G1/G4 | Product + Tech + Security |
| `FR-CORE-014` | `UC-CORE-014` | G1/G4 | Product + Tech + Security |
| `FR-CORE-015` | `UC-CORE-015` | G1/G4 | Product + Tech + Security |
| `FR-CORE-016` | `UC-CORE-016` | G1/G4 | Product + Tech + Security |
| `FR-CORE-017` | `UC-CORE-017` | G2/G3/G4 | Product + Ops + Privacy + Tech |
| `FR-CORE-018` | `UC-CORE-018` | G2/G3/G4 | Product + Ops + Privacy + Tech |

### 4.2. Customer Ride
| FR | UC nguồn | Gate(s) | Owner review |
|---|---|---|---|
| `FR-RIDE-001` | `UC-RIDE-001` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-002` | `UC-RIDE-002` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-003` | `UC-RIDE-003` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-004` | `UC-RIDE-004` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-005` | `UC-RIDE-005` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-006` | `UC-RIDE-006` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-007` | `UC-RIDE-007` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-008` | `UC-RIDE-008` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-009` | `UC-RIDE-009` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-010` | `UC-RIDE-010` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-011` | `UC-RIDE-011` | G2/G4 | Product + Ride Ops |
| `FR-RIDE-012` | `UC-RIDE-012` | G2/G4 | Product + Ride Ops |

### 4.3. Customer Food
| FR | UC nguồn | Gate(s) | Owner review |
|---|---|---|---|
| `FR-FOOD-001` | `UC-FOOD-001` | G3/G4 | Product + Food Ops |
| `FR-FOOD-002` | `UC-FOOD-002` | G3/G4 | Product + Food Ops |
| `FR-FOOD-003` | `UC-FOOD-003` | G3/G4 | Product + Food Ops |
| `FR-FOOD-004` | `UC-FOOD-004` | G3/G4 | Product + Food Ops |
| `FR-FOOD-005` | `UC-FOOD-005` | G3/G4 | Product + Food Ops |
| `FR-FOOD-006` | `UC-FOOD-006` | G3/G4 | Product + Food Ops |
| `FR-FOOD-007` | `UC-FOOD-007` | G3/G4 | Product + Food Ops |
| `FR-FOOD-008` | `UC-FOOD-008` | G3/G4 | Product + Food Ops |
| `FR-FOOD-009` | `UC-FOOD-009` | G3/G4 | Product + Food Ops |
| `FR-FOOD-010` | `UC-FOOD-010` | G3/G4 | Product + Food Ops |
| `FR-FOOD-011` | `UC-FOOD-011` | G3/G4 | Product + Food Ops |
| `FR-FOOD-012` | `UC-FOOD-012` | G3/G4 | Product + Food Ops |

### 4.4. Merchant Operations
| FR | UC nguồn | Gate(s) | Owner review |
|---|---|---|---|
| `FR-MER-001` | `UC-MER-001` | G3/G4 | Product + Merchant Ops |
| `FR-MER-002` | `UC-MER-002` | G3/G4 | Product + Merchant Ops |
| `FR-MER-003` | `UC-MER-003` | G3/G4 | Product + Merchant Ops |
| `FR-MER-004` | `UC-MER-004` | G3/G4 | Product + Merchant Ops |
| `FR-MER-005` | `UC-MER-005` | G3/G4 | Product + Merchant Ops |
| `FR-MER-006` | `UC-MER-006` | G3/G4 | Product + Merchant Ops |
| `FR-MER-007` | `UC-MER-007` | G3/G4 | Product + Merchant Ops |
| `FR-MER-008` | `UC-MER-008` | G3/G4 | Product + Merchant Ops |
| `FR-MER-009` | `UC-MER-009` | G3/G4 | Product + Merchant Ops |

### 4.5. Driver Operations
| FR | UC nguồn | Gate(s) | Owner review |
|---|---|---|---|
| `FR-DRV-001` | `UC-DRV-001` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-002` | `UC-DRV-002` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-003` | `UC-DRV-003` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-004` | `UC-DRV-004` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-005` | `UC-DRV-005` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-006` | `UC-DRV-006` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-007` | `UC-DRV-007` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-008` | `UC-DRV-008` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-009` | `UC-DRV-009` | G2/G3/G4 | Product + Driver Ops |
| `FR-DRV-010` | `UC-DRV-010` | G2/G3/G4 | Product + Driver Ops |

### 4.6. Admin & Financial Operations
| FR | UC nguồn | Gate(s) | Owner review |
|---|---|---|---|
| `FR-OPS-001` | `UC-OPS-001` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-002` | `UC-OPS-002` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-003` | `UC-OPS-003` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-004` | `UC-OPS-004` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-005` | `UC-OPS-005` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-006` | `UC-OPS-006` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-007` | `UC-OPS-007` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-008` | `UC-OPS-008` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-009` | `UC-OPS-009` | G4/G5 | Ops + Finance + Security |
| `FR-OPS-010` | `UC-OPS-010` | G1/G4/G5 | Security + Tech + Product |

## 5. Bộ 71 Functional Requirements có kiểm thử

> `Minimum acceptance (PRD)` được giữ nguyên ý nghĩa nguồn, còn ba `AC-FR-*` phía dưới là tiêu chí chi tiết hóa để review. Không dùng thuật ngữ "đã nghiệm thu" khi chưa có evidence test được lưu ở QA.

### 5.1. Shared Platform / Identity & Consistency (18 yêu cầu)

#### `FR-CORE-001` — Account đăng nhập/đăng xuất, khôi phục quyền truy cập theo phương thức được duyệt.
- **Nguồn:** `UC-CORE-001` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-01`, `OPEN-008`.
- **Actor / trigger:** Account / bắt đầu hay kết thúc phiên đăng nhập.
- **Tiền điều kiện / input:** Phiên hợp lệ; provider login/OTP theo OPEN-008 trả kết quả đã kiểm chứng.
- **Kết quả chấp nhận:** Backend cấp session theo chính sách, báo trạng thái xác thực; logout hoặc thu hồi khiến credential không còn được chấp nhận theo policy.
- **Trường hợp từ chối / lỗi:** OTP sai/hết hạn, session bị thu hồi, thiếu token; không tạo session hợp lệ.
- **Minimum acceptance trong PRD:** Session invalid/expired không thể dùng để tạo giao dịch; logout thu hồi truy cập theo policy.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-001-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: backend cấp session theo chính sách, báo trạng thái xác thực; logout hoặc thu hồi khiến credential không còn được chấp nhận theo policy.
2. `AC-FR-CORE-001-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: oTP sai/hết hạn, session bị thu hồi, thiếu token; không tạo session hợp lệ.
3. `AC-FR-CORE-001-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: thực thi request tạo Ride/Food sau logout phải bị từ chối dù client còn lưu màn hình đã đăng nhập.

#### `FR-CORE-002` — Một account quản lý các role đã được cấp; có active role.
- **Nguồn:** `UC-CORE-002` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-02`, `CAP-ROLE-01`, `OPEN-005`.
- **Actor / trigger:** Account đã được cấp nhiều vai trò / chọn vai trò.
- **Tiền điều kiện / input:** Danh sách role/eligibility lấy từ server, selectedRole nằm trong role đã cấp.
- **Kết quả chấp nhận:** Ứng dụng thay vùng điều hướng theo role, backend vẫn kiểm quyền actor/đối tượng ở từng lệnh.
- **Trường hợp từ chối / lỗi:** Role đang chờ duyệt, role tự thêm bằng sửa payload, deep link role khác phải bị từ chối.
- **Minimum acceptance trong PRD:** Chuyển role không cấp quyền mới và deep link không bypass RBAC.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-002-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: ứng dụng thay vùng điều hướng theo role, backend vẫn kiểm quyền actor/đối tượng ở từng lệnh.
2. `AC-FR-CORE-002-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: role đang chờ duyệt, role tự thêm bằng sửa payload, deep link role khác phải bị từ chối.
3. `AC-FR-CORE-002-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: đổi Customer → Driver khi đang có active job phải tuân thủ policy OPEN-005; chưa duyệt thì fail closed phần xung đột.

#### `FR-CORE-003` — Partner gửi hồ sơ onboarding và biết trạng thái chờ/duyệt/bổ sung/từ chối.
- **Nguồn:** `UC-CORE-003` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-03`, `OPEN-006/008`.
- **Actor / trigger:** Merchant hoặc Driver / nộp hồ sơ đối tác.
- **Tiền điều kiện / input:** Bộ trường, tài liệu và consent theo chính sách KYC/KYB OPEN-006/008.
- **Kết quả chấp nhận:** Lưu hồ sơ và phiên bản, cho xem trạng thái review/bổ sung/phê duyệt qua backend.
- **Trường hợp từ chối / lỗi:** Hồ sơ thiếu/sai loại hoặc chưa duyệt không được kích hoạt nhận đơn/offer.
- **Minimum acceptance trong PRD:** Chưa eligible không được nhận công việc/đơn kinh doanh; dữ liệu nhạy cảm chỉ người có quyền xem.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-003-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: lưu hồ sơ và phiên bản, cho xem trạng thái review/bổ sung/phê duyệt qua backend.
2. `AC-FR-CORE-003-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: hồ sơ thiếu/sai loại hoặc chưa duyệt không được kích hoạt nhận đơn/offer.
3. `AC-FR-CORE-003-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: đối tác bị khóa sau khi duyệt không được tạo job mới; hồ sơ nhạy cảm không lọt sang account khác.

#### `FR-CORE-004` — Customer/Driver chọn, sửa, xác minh địa chỉ hoặc GPS khi được phép.
- **Nguồn:** `UC-CORE-004` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-04`, `OPEN-001/012`.
- **Actor / trigger:** Customer/Driver / nhập điểm hoặc cập nhật location.
- **Tiền điều kiện / input:** Tọa độ hoặc địa chỉ hợp lệ có nguồn, thời gian lấy, vùng và quyền vị trí.
- **Kết quả chấp nhận:** Trả location chuẩn hóa đủ cho Ride/Food theo provider adapter được duyệt.
- **Trường hợp từ chối / lỗi:** Tọa độ ngoài khoảng, địa chỉ mơ hồ hoặc vùng không phục vụ phải có lỗi xử lý được.
- **Minimum acceptance trong PRD:** Không có tọa độ hợp lệ thì không tạo booking/order; có fallback địa chỉ nhập tay theo policy.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-004-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trả location chuẩn hóa đủ cho Ride/Food theo provider adapter được duyệt.
2. `AC-FR-CORE-004-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: tọa độ ngoài khoảng, địa chỉ mơ hồ hoặc vùng không phục vụ phải có lỗi xử lý được.
3. `AC-FR-CORE-004-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: vị trí từ GPS cũ không âm thầm ghi là đang cập nhật trực tiếp; có đường nhập tay khi policy cho phép.

#### `FR-CORE-005` — Hệ thống phát hành và đánh giá tính hợp lệ của offer/assignment.
- **Nguồn:** `UC-CORE-005` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-05`, `OPEN-004/005`.
- **Actor / trigger:** Dispatch / xét tài xế nhận offer.
- **Tiền điều kiện / input:** Offer tham chiếu job, tài xế eligible, điều kiện workload và deadline từ server.
- **Kết quả chấp nhận:** Trạng thái offer/assignment do server ghi nhận, phản hồi kết quả chính thức.
- **Trường hợp từ chối / lỗi:** Offer bị thu hồi/hết hạn hoặc tài xế mất quyền phải từ chối accept.
- **Minimum acceptance trong PRD:** Offer expired/revoked không tạo assignment; chỉ người được quyền mới nhận.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-005-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trạng thái offer/assignment do server ghi nhận, phản hồi kết quả chính thức.
2. `AC-FR-CORE-005-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: offer bị thu hồi/hết hạn hoặc tài xế mất quyền phải từ chối accept.
3. `AC-FR-CORE-005-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: hai tài xế accept sát nhau chỉ có một assignment hữu hiệu; phần còn lại nhận trạng thái lost/expired.

#### `FR-CORE-006` — Mọi hành động create/confirm/complete có bảo vệ chống retry trùng và race.
- **Nguồn:** `UC-CORE-006` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-06`.
- **Actor / trigger:** Các actor / gửi lặp lệnh có side effect.
- **Tiền điều kiện / input:** Lệnh có business intent và cơ chế idempotency được contract xác định.
- **Kết quả chấp nhận:** Replay cùng intent trả kết quả tương thích của giao dịch đầu, không tạo side effect trùng.
- **Trường hợp từ chối / lỗi:** Cùng key với payload khác phải trả conflict, không ghi giao dịch mới.
- **Minimum acceptance trong PRD:** Cùng intent được replay không tạo thêm booking/order/payment/assignment ngoài ý muốn.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-006-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: replay cùng intent trả kết quả tương thích của giao dịch đầu, không tạo side effect trùng.
2. `AC-FR-CORE-006-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: cùng key với payload khác phải trả conflict, không ghi giao dịch mới.
3. `AC-FR-CORE-006-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: giả lập retry từ hai thiết bị song song: tối đa một đối tượng order/ride/assignment/payment tương ứng.

#### `FR-CORE-007` — Khách thấy quote/breakdown trước cam kết và phản hồi khi giá/điều kiện đổi.
- **Nguồn:** `UC-CORE-007` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-07`, `OPEN-003`.
- **Actor / trigger:** Customer / xem và xác nhận giá điều kiện.
- **Tiền điều kiện / input:** Pickup/destination hoặc cart, giá do server tính với quoteRef và phiên bản.
- **Kết quả chấp nhận:** Hiển thị breakdown/độ hiệu lực; commit dùng quote đã được server kiểm lại.
- **Trường hợp từ chối / lỗi:** Quote hết hạn, đổi địa chỉ/menu/phí vật chất buộc nhận quote mới theo chính sách.
- **Minimum acceptance trong PRD:** Không dùng quote không còn hợp lệ; phải xin xác nhận lại nếu thay đổi vật chất theo policy.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-007-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị breakdown/độ hiệu lực; commit dùng quote đã được server kiểm lại.
2. `AC-FR-CORE-007-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: quote hết hạn, đổi địa chỉ/menu/phí vật chất buộc nhận quote mới theo chính sách.
3. `AC-FR-CORE-007-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: client thay amount trong payload không làm thay amount ghi server; thay giá không âm thầm xác nhận.

#### `FR-CORE-008` — Ghi nhận các nghĩa vụ tài chính/correction/refund/settlement theo chính sách.
- **Nguồn:** `UC-CORE-008` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-08`, `OPEN-002/003`.
- **Actor / trigger:** Finance/System / ghi nhận và tra cứu nghiệp vụ tiền.
- **Tiền điều kiện / input:** Sự kiện được xác thực, tham chiếu giao dịch gốc, policy tiền đã duyệt.
- **Kết quả chấp nhận:** Ghi financial event + immutable/auditable reference; tra cứu state và số dư hợp lệ.
- **Trường hợp từ chối / lỗi:** Callback không xác thực, duplicate, mismatch hoặc unknown không chuyển thành PAID/SETTLED.
- **Minimum acceptance trong PRD:** Mọi tác động tiền có reference, state và audit; sai lệch không bị đánh dấu đã cân bằng.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-008-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: ghi financial event + immutable/auditable reference; tra cứu state và số dư hợp lệ.
2. `AC-FR-CORE-008-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: callback không xác thực, duplicate, mismatch hoặc unknown không chuyển thành PAID/SETTLED.
3. `AC-FR-CORE-008-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: webhook lặp/đảo thứ tự không double-credit, refund không double-debit; lệch phát sinh case đối soát.

#### `FR-CORE-009` — Trạng thái được đồng bộ qua foreground, background được phép và reconnect.
- **Nguồn:** `UC-CORE-009` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-09`, `OPEN-012`.
- **Actor / trigger:** Mọi vai trò mobile / mở lại app hoặc kết nối lại.
- **Tiền điều kiện / input:** Có giao dịch đang mở; client giữ cursor/version hợp lệ hoặc cho full refresh.
- **Kết quả chấp nhận:** Đọc lại active jobs và trạng thái authoritative từ backend, cập nhật UI theo phiên bản.
- **Trường hợp từ chối / lỗi:** Push cũ/realtime đảo thứ tự không ghi đè trạng thái mới hơn; khi offline hiển thị thiếu kết nối.
- **Minimum acceptance trong PRD:** Sau reconnect, trạng thái được đọc lại từ backend; không tin thông báo cũ là trạng thái cuối.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-009-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: đọc lại active jobs và trạng thái authoritative từ backend, cập nhật UI theo phiên bản.
2. `AC-FR-CORE-009-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: push cũ/realtime đảo thứ tự không ghi đè trạng thái mới hơn; khi offline hiển thị thiếu kết nối.
3. `AC-FR-CORE-009-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: kill app giữa ride/food rồi mở lại phải nhìn đúng assignment và bước hiện tại từ backend.

#### `FR-CORE-010` — Người dùng chỉ truy cập data/operation của mình hoặc được ủy quyền.
- **Nguồn:** `UC-CORE-010` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-10`.
- **Actor / trigger:** Mọi actor / đọc hoặc sửa đối tượng.
- **Tiền điều kiện / input:** Danh tính, permission, tenant/store/owner binding của đối tượng lấy từ server.
- **Kết quả chấp nhận:** Chỉ dữ liệu đủ quyền được trả, các trường nhạy cảm được giảm thiểu.
- **Trường hợp từ chối / lỗi:** ID của shop/đơn/chuyến người khác, đổi role/UI hoặc tự dựng deep link không vượt quyền.
- **Minimum acceptance trong PRD:** Thay ID của order/trip/store/driver không vượt object-level authorization.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-010-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: chỉ dữ liệu đủ quyền được trả, các trường nhạy cảm được giảm thiểu.
2. `AC-FR-CORE-010-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: iD của shop/đơn/chuyến người khác, đổi role/UI hoặc tự dựng deep link không vượt quyền.
3. `AC-FR-CORE-010-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: chạy negative tests đổi object ID trên mọi operation đọc/sửa, kể cả list filter và attachment.

#### `FR-CORE-011` — Có luồng báo lỗi/hỗ trợ/kháng nghị phù hợp từng role.
- **Nguồn:** `UC-CORE-011` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-11`, `OPEN-014/015`.
- **Actor / trigger:** Customer/Driver/Merchant / tạo case hỗ trợ.
- **Tiền điều kiện / input:** Actor gắn transaction hoặc nhóm sự cố hợp lệ, mô tả và evidence phù hợp quyền.
- **Kết quả chấp nhận:** Sinh case ID, trạng thái, timeline và quyền xem theo người liên quan.
- **Trường hợp từ chối / lỗi:** Không có quyền với đơn tham chiếu hoặc file lỗi phải bị từ chối rõ.
- **Minimum acceptance trong PRD:** Ticket/case có ID, người xử lý và dấu vết; không yêu cầu khách liên hệ tài xế ngoài kênh bắt buộc chưa duyệt.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-011-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: sinh case ID, trạng thái, timeline và quyền xem theo người liên quan.
2. `AC-FR-CORE-011-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không có quyền với đơn tham chiếu hoặc file lỗi phải bị từ chối rõ.
3. `AC-FR-CORE-011-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: hai lần gửi do mạng chập chờn không được tạo hồ sơ trùng ngoài ý muốn nếu dùng cùng intent.

#### `FR-CORE-012` — Vận hành có thể phát hiện giao dịch kẹt/sai lệch và tạm dừng năng lực an toàn.
- **Nguồn:** `UC-CORE-012` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-12`, `OPEN-007`.
- **Actor / trigger:** Monitoring/Ops / phát hiện trạng thái bất thường.
- **Tiền điều kiện / input:** Sự kiện và duration theo rule cấu hình, trace/correlation hợp lệ.
- **Kết quả chấp nhận:** Tạo anomaly/case có owner, evidence và hành động can thiệp được audit.
- **Trường hợp từ chối / lỗi:** Dữ liệu thiếu/trễ không tự chuyển transaction sang completed để xóa cảnh báo.
- **Minimum acceptance trong PRD:** Có sự kiện đo và thao tác can thiệp audit; không cần dashboard BI phức tạp để có cảnh báo.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-012-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: tạo anomaly/case có owner, evidence và hành động can thiệp được audit.
2. `AC-FR-CORE-012-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: dữ liệu thiếu/trễ không tự chuyển transaction sang completed để xóa cảnh báo.
3. `AC-FR-CORE-012-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: có thể tạm dừng admission mới mà không xóa/cancel tự động giao dịch đang thực hiện.

#### `FR-CORE-013` — Lịch sử và chi tiết giao dịch phản ánh nhất quán các trạng thái.
- **Nguồn:** `UC-CORE-013` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-08/09`.
- **Actor / trigger:** Actor có quyền / xem lịch sử và biên nhận.
- **Tiền điều kiện / input:** Record authoritative và từng money status; truy vấn được phân trang/lọc.
- **Kết quả chấp nhận:** Trả lịch sử đúng chủ sở hữu, state/timestamps/amount phân biệt estimate, paid, due, settled.
- **Trường hợp từ chối / lỗi:** Thiếu payment confirmation không được hiển thị đã thu; không lộ record người khác.
- **Minimum acceptance trong PRD:** Receipt, estimated amount, paid amount, due amount, settled amount không bị đánh đồng.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-013-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trả lịch sử đúng chủ sở hữu, state/timestamps/amount phân biệt estimate, paid, due, settled.
2. `AC-FR-CORE-013-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: thiếu payment confirmation không được hiển thị đã thu; không lộ record người khác.
3. `AC-FR-CORE-013-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: refresh/reconnect không thay đổi receipt trước đó trừ khi có adjustment hợp lệ với audit.

#### `FR-CORE-014` — Notification không tiết lộ dữ liệu nhạy cảm và chỉ đến actor liên quan.
- **Nguồn:** `UC-CORE-014` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-09/10`, `OPEN-014`.
- **Actor / trigger:** Backend / phát hành notification cho actor liên quan.
- **Tiền điều kiện / input:** Event nội bộ hợp lệ, recipient scope và template được duyệt.
- **Kết quả chấp nhận:** Push/in-app nhận sự kiện ít PII, liên kết mở đúng role/resource sau kiểm quyền.
- **Trường hợp từ chối / lỗi:** Token hết hạn, actor mất quyền hoặc notification đến trễ không lộ nội dung bảo mật.
- **Minimum acceptance trong PRD:** Push/deep link không lộ order/trip nhạy cảm trên role không được phép.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-014-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: push/in-app nhận sự kiện ít PII, liên kết mở đúng role/resource sau kiểm quyền.
2. `AC-FR-CORE-014-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: token hết hạn, actor mất quyền hoặc notification đến trễ không lộ nội dung bảo mật.
3. `AC-FR-CORE-014-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: tap notification của store khác/role không eligible phải dẫn đến từ chối, không hiển thị dữ liệu cache nhạy cảm.

#### `FR-CORE-015` — Hệ thống ghi nhận actor/time/reason cho thay đổi nhạy cảm.
- **Nguồn:** `UC-CORE-015` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-10/11/12`.
- **Actor / trigger:** System/Admin / thay đổi dữ liệu nhạy cảm.
- **Tiền điều kiện / input:** Có actor/service identity, action, reason khi cần, correlation ID.
- **Kết quả chấp nhận:** Ghi audit bất biến tương đối, truy xuất được lịch sử sửa/duyệt/hoàn/hủy.
- **Trường hợp từ chối / lỗi:** Thiếu quyền/reason bắt buộc không thay đổi domain object.
- **Minimum acceptance trong PRD:** Có audit chain đủ tra cứu sự cố mà không rò PII trong log ứng dụng công khai.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-CORE-015-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: ghi audit bất biến tương đối, truy xuất được lịch sử sửa/duyệt/hoàn/hủy.
2. `AC-FR-CORE-015-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: thiếu quyền/reason bắt buộc không thay đổi domain object.
3. `AC-FR-CORE-015-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: không ghi token, OTP, CCCD đầy đủ hoặc raw payment data vào logs/audit thường.

#### `FR-CORE-016` — Account đăng ký và quản lý nhiều phương thức xác thực an toàn.
- **Nguồn:** `UC-CORE-016` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc:** `DEC-PROD-006`, `OPEN-008/020`.
- **Actor / trigger:** Account holder / đăng ký, liên kết, xác thực hoặc khôi phục truy cập.
- **Yêu cầu:** Hỗ trợ passkey theo WebAuthn/platform credential; xác minh số phone bằng SMS; email được xác minh và gắn làm contact/account identifier. Phone SMS OTP có rate limit, expiry, one-time use và risk checks. Email verification không được biến thành email OTP đăng nhập độc lập. Người dùng có thể liên kết passkey và các contact methods vào cùng Account sau khi chứng minh quyền kiểm soát.
- **Kết quả chấp nhận:** Server xác minh challenge/passkey assertion, RP ID/origin, account binding, proof freshness và trạng thái method; method bị admin disable không thể enroll/authenticate.
- **Failure/Recovery:** OTP sai/hết hạn, replay, challenge reused, method disabled hoặc recovery risk cao không tạo session; hướng dẫn fallback/recovery mà không tiết lộ tài khoản.
**Acceptance criteria:**
1. `AC-FR-CORE-016-01` — Đăng ký với một hoặc nhiều method hợp lệ tạo một Account duy nhất; email/phone được lưu ở trạng thái verified riêng.
2. `AC-FR-CORE-016-02` — Sai chữ ký/challenge/origin/RP ID, SMS OTP hết hạn/replay/rate limit hoặc method disabled đều bị từ chối server-side; không log secret.
3. `AC-FR-CORE-016-03` — Đổi/mất phone hoặc passkey yêu cầu re-auth/risk-based recovery; admin không thể vô ý disable phương thức cuối cùng mà không mở recovery/lockout workflow có audit.

#### `FR-CORE-017` — Participant trao đổi chat văn bản trong ngữ cảnh Ride/Food được cấp.
- **Nguồn:** `UC-CORE-017` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc:** `DEC-PROD-007`, `OPEN-014/021`.
- **Actor / trigger:** Customer, Driver, Merchant / cần phối hợp về Ride hoặc Food order đang liên quan.
- **Yêu cầu:** Tạo conversation gắn RideRequest/Trip hoặc FoodOrder/DeliveryTask và chỉ cho participant/role liên quan đọc, gửi; cập nhật sent/delivered/read theo năng lực thật. Nội dung text-only ở baseline; không mở inbox tìm user, không gửi tệp/ảnh/voice note ở P0. Quyền chat bị thu hồi khi quan hệ giao dịch hết hiệu lực, trừ case support được cấp riêng.
- **Kết quả chấp nhận:** Message có server timestamp, author, context/version; realtime/push chỉ là tín hiệu, fetch sau reconnect phải lọc đúng quyền.
**Acceptance criteria:**
1. `AC-FR-CORE-017-01` — Participant của transaction hợp lệ gửi/nhận message đúng conversation và đồng bộ sau offline.
2. `AC-FR-CORE-017-02` — User ngoài transaction, participant bị revoke, sửa conversation ID hoặc push/deep link giả không đọc được body/metadata.
3. `AC-FR-CORE-017-03` — Nội dung chat không xuất hiện trong notification preview/log analytics mặc định; admin chỉ đọc nội dung khi permission + case/reason/audit cho phép.

#### `FR-CORE-018` — Participant đủ điều kiện thực hiện gọi thoại trong ứng dụng.
- **Nguồn:** `UC-CORE-018` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc:** `DEC-PROD-007`, `OPEN-021`.
- **Yêu cầu:** Voice-only VoIP giữa participant liên quan Ride/Food; người gọi chủ động bắt đầu, người nhận có thể từ chối; kiểm tra transaction relationship và call window ở backend; cấp credential/signaling token ngắn hạn. Không hiện số điện thoại cá nhân, không tự fallback sang PSTN, không ghi âm/video ở baseline. Xin microphone permission tại thời điểm người dùng gọi; permission denied/network failure phải có đường quay về chat/support.
- **Acceptance:**
1. `AC-FR-CORE-018-01` — Caller/receiver là participant đủ quyền; call session được tạo một lần, trạng thái ringing/accepted/rejected/ended/failed nhất quán.
2. `AC-FR-CORE-018-02` — Token hết hạn, participant ngoài giao dịch, user bị block/disabled hoặc call window hết hạn không thể join call.
3. `AC-FR-CORE-018-03` — Microphone permission denied, app backgrounded, mạng mất hoặc provider lỗi không làm app báo cuộc gọi đã kết nối; không có ghi âm ngầm hoặc lộ số.

### 5.2. Customer Ride (12 yêu cầu; FR-RIDE-002/003 bao gồm thương lượng giá)

#### `FR-RIDE-001` — Customer chọn loại Ride hai bánh, pickup và destination.
- **Nguồn:** `UC-RIDE-001` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-01`, `OPEN-001`.
- **Actor / trigger:** Customer / lựa chọn Ride hai bánh và điểm đi đến.
- **Tiền điều kiện / input:** Pickup và destination có định vị, coverage hợp lệ, service ride enabled.
- **Kết quả chấp nhận:** Hệ thống tạo route intent có điểm xác nhận, không tự tạo chuyến.
- **Trường hợp từ chối / lỗi:** Điểm không xác định, vùng ngoài phạm vi, 2 điểm bất khả dụng phải yêu cầu chỉnh.
- **Minimum acceptance trong PRD:** Điểm ngoài vùng/không hợp lệ có lỗi rõ; không gửi yêu cầu.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-001-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hệ thống tạo route intent có điểm xác nhận, không tự tạo chuyến.
2. `AC-FR-RIDE-001-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: điểm không xác định, vùng ngoài phạm vi, 2 điểm bất khả dụng phải yêu cầu chỉnh.
3. `AC-FR-RIDE-001-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: thay tọa độ trên client trước booking phải được backend tính lại eligibility/quote.

#### `FR-RIDE-002` — Xem route/ETA và giá tham khảo; khách có thể nhập giá đề xuất cho Ride.
- **Nguồn:** `UC-RIDE-002` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-01`, `DEC-PROD-005`, `OPEN-003/019`.
- **Actor / trigger:** Customer / xem route, reference fare và nhập mức đề xuất.
- **Tiền điều kiện / input:** Route request và reference fare backend cung cấp kèm currency/breakdown/version/expiry; user nhập amount đề xuất.
- **Kết quả chấp nhận:** Hiển thị quãng đường/ETA ước tính, giá tham khảo có nhãn rõ và điều kiện; cho khách nhập giá đề xuất riêng. Giá tham khảo không phải giá cuối nếu chưa được hai bên chấp nhận.
- **Trường hợp từ chối / lỗi:** Provider route lỗi hoặc quote stale không hiển thị giá giả có hiệu lực.
- **Minimum acceptance trong PRD:** Tách giá tham khảo, giá khách đề xuất, counter-offer và giá cuối; hiển thị phí/điều kiện tách biệt theo policy.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-002-01` — route/ETA được gắn nhãn ước tính; reference fare trả cùng currency, breakdown, route/policy version và expiry.
2. `AC-FR-RIDE-002-02` — stale/invalid reference fare không cho submit; server không nhận amount từ client làm giá authoritative.
3. `AC-FR-RIDE-002-03` — đổi route/version làm giá tham khảo mới; UI phân biệt reference fare với passenger proposed fare và giá cuối.

#### `FR-RIDE-003` — Gửi yêu cầu Ride và hoàn tất thương lượng giá trước assignment.
- **Nguồn:** `UC-RIDE-003` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-02`, `CAP-CORE-06`.
- **Actor / trigger:** Customer / gửi request với giá đề xuất; Customer cũng chọn offer sau đó.
- **Tiền điều kiện / input:** Reference fare còn hợp lệ, actor có quyền, passengerProposedFare, requestIdempotencyKey.
- **Kết quả chấp nhận:** Server tạo đúng một RideRequest/negotiation với giá đề xuất, trạng thái thương lượng và danh sách counter-offer hợp lệ; sau khi khách chọn, server khóa snapshot giá cuối và mới tạo assignment.
- **Trường hợp từ chối / lỗi:** Quote tham khảo hết hiệu lực, zone disabled, giá ngoài rule đã duyệt, offer hết hạn/đã chọn hoặc request lặp payload khác bị từ chối mà không tạo assignment/ghi tiền sai.
- **Minimum acceptance trong PRD:** Double tap không tạo trùng; chỉ một lựa chọn giá/driver thắng; không tự chọn giá rẻ nhất hoặc accept đầu tiên.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-003-01` — retry cùng idempotency key chỉ tạo một RideRequest/negotiation; chưa có assignment trước customer selection.
2. `AC-FR-RIDE-003-02` — counter-offer được lưu đúng driver/amount/expiry; expired, revoked hoặc offer của driver khác bị từ chối khi khách chọn.
3. `AC-FR-RIDE-003-03` — hai lựa chọn đồng thời chỉ có một accepted agreement/assignment; server không tự chọn rẻ nhất/đến trước; retry khôi phục kết quả commit.

#### `FR-RIDE-004` — Theo dõi quá trình tìm tài xế; có trạng thái hết tài xế/hủy.
- **Nguồn:** `UC-RIDE-004` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-03`, `OPEN-004`.
- **Actor / trigger:** Customer / theo dõi đang tìm tài xế.
- **Tiền điều kiện / input:** RideRequest chưa terminal, có trạng thái searching/offer events từ server.
- **Kết quả chấp nhận:** Hiển thị tiến trình, kết quả assigned, no-driver hoặc hủy với thao tác hợp lệ.
- **Trường hợp từ chối / lỗi:** Offer hết hạn hoặc không đủ cung không được hiển thị tài xế ảo.
- **Minimum acceptance trong PRD:** Searching không tồn tại vô hạn nếu policy yêu cầu timeout; UX giải thích kết quả.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-004-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị tiến trình, kết quả assigned, no-driver hoặc hủy với thao tác hợp lệ.
2. `AC-FR-RIDE-004-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: offer hết hạn hoặc không đủ cung không được hiển thị tài xế ảo.
3. `AC-FR-RIDE-004-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: theo timeout cấu hình được duyệt OPEN-004; không hard-code thời gian trong mobile.

#### `FR-RIDE-005` — Xem driver/vehicle được phân công và trạng thái đến điểm đón.
- **Nguồn:** `UC-RIDE-005` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-04`.
- **Actor / trigger:** Customer / xem tài xế đến đón.
- **Tiền điều kiện / input:** Có assignment thắng và driver/vehicle được phép hiển thị.
- **Kết quả chấp nhận:** Hiển thị đúng driver, phương tiện, vị trí có timestamp và pickup guidance.
- **Trường hợp từ chối / lỗi:** Assignment bị revoke/reassign phải xóa thông tin cũ và lấy phiên bản mới.
- **Minimum acceptance trong PRD:** Không lộ thông tin tài xế trước quyền phù hợp; không hiển thị assignment cũ.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-005-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị đúng driver, phương tiện, vị trí có timestamp và pickup guidance.
2. `AC-FR-RIDE-005-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: assignment bị revoke/reassign phải xóa thông tin cũ và lấy phiên bản mới.
3. `AC-FR-RIDE-005-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: một offer chưa được commit không được hiển thị như driver đã nhận chuyến.

#### `FR-RIDE-006` — Biết cách liên lạc/hỗ trợ tại điểm đón.
- **Nguồn:** `UC-RIDE-006` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-04/08`, `OPEN-014`.
- **Actor / trigger:** Customer / liên hệ hỗ trợ khi chờ xe.
- **Tiền điều kiện / input:** Có RideRequest/Trip thuộc mình; kênh liên hệ P0 được phê duyệt.
- **Kết quả chấp nhận:** Mở kênh liên hệ/hỗ trợ phù hợp, có fallback khi provider unavailable.
- **Trường hợp từ chối / lỗi:** Không được tiết lộ số điện thoại hoặc vị trí ngoài mức policy cho phép.
- **Minimum acceptance trong PRD:** Kênh liên hệ đúng policy, không lộ PII ngoài phạm vi được duyệt.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-006-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: mở kênh liên hệ/hỗ trợ phù hợp, có fallback khi provider unavailable.
2. `AC-FR-RIDE-006-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không được tiết lộ số điện thoại hoặc vị trí ngoài mức policy cho phép.
3. `AC-FR-RIDE-006-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: customer không được gọi/xem thông tin của tài xế khi assignment đã không còn quyền truy cập.

#### `FR-RIDE-007` — Theo dõi chuyến từ bắt đầu đến hoàn tất.
- **Nguồn:** `UC-RIDE-007` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-05`, `OPEN-017`.
- **Actor / trigger:** Customer / theo dõi RideTrip.
- **Tiền điều kiện / input:** RideTrip đã tồn tại, có state/version và event transitions hợp lệ.
- **Kết quả chấp nhận:** UI phản ánh pickup, in-progress, completed theo server, có cách xem details.
- **Trường hợp từ chối / lỗi:** Event đảo thứ tự/attempt skip trạng thái không lùi/làm giả hoàn thành.
- **Minimum acceptance trong PRD:** Transition không hợp lệ bị từ chối, không skip trip stages.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-007-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: uI phản ánh pickup, in-progress, completed theo server, có cách xem details.
2. `AC-FR-RIDE-007-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: event đảo thứ tự/attempt skip trạng thái không lùi/làm giả hoàn thành.
3. `AC-FR-RIDE-007-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: mở app sau mất mạng phải đồng bộ trip server thay vì dựa vào local progress animation.

#### `FR-RIDE-008` — Yêu cầu hủy chuyến theo giai đoạn và biết hệ quả.
- **Nguồn:** `UC-RIDE-008` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-06`, `OPEN-003/017`.
- **Actor / trigger:** Customer / gửi yêu cầu hủy.
- **Tiền điều kiện / input:** RideRequest/Trip thuộc mình, state cho phép hủy theo chính sách phí OPEN-003/017.
- **Kết quả chấp nhận:** Nếu được hủy: server xác nhận state/reason, cung cấp hậu quả tài chính được duyệt.
- **Trường hợp từ chối / lỗi:** Nếu không được hủy, phải trả lý do và kênh hỗ trợ; không tự đổi UI terminal.
- **Minimum acceptance trong PRD:** Nếu không được hủy/phát sinh phí phải phản hồi theo policy trước xác nhận cần thiết.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-008-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: nếu được hủy: server xác nhận state/reason, cung cấp hậu quả tài chính được duyệt.
2. `AC-FR-RIDE-008-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: nếu không được hủy, phải trả lý do và kênh hỗ trợ; không tự đổi UI terminal.
3. `AC-FR-RIDE-008-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: hủy cạnh tranh với assignment/ride start cần kết quả commit duy nhất, không cùng lúc cancelled và active.

#### `FR-RIDE-009` — Gặp tình huống không tìm thấy xe, tài xế rời chuyến, mất mạng.
- **Nguồn:** `UC-RIDE-009` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-06/08`.
- **Actor / trigger:** Customer / không có tài xế hoặc mất liên lạc.
- **Tiền điều kiện / input:** Active request/trip và các signal network/offline/reassignment.
- **Kết quả chấp nhận:** Báo trạng thái authoritative, gợi ý thử lại/hủy/hỗ trợ khi quyền cho phép.
- **Trường hợp từ chối / lỗi:** Mất WebSocket/push không làm auto-cancel hoặc auto-complete.
- **Minimum acceptance trong PRD:** Có trạng thái xử lý, recovery và đường hỗ trợ; không tự kết luận đã hủy nếu server chưa xác nhận.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-009-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: báo trạng thái authoritative, gợi ý thử lại/hủy/hỗ trợ khi quyền cho phép.
2. `AC-FR-RIDE-009-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: mất WebSocket/push không làm auto-cancel hoặc auto-complete.
3. `AC-FR-RIDE-009-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: driver offline sau assignment phải kích hoạt escalation/recovery theo policy, không tạo hai trip active.

#### `FR-RIDE-010` — Xem biên nhận/chuyến đã hoàn tất và chi phí tương ứng.
- **Nguồn:** `UC-RIDE-010` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-07`.
- **Actor / trigger:** Customer / xem biên nhận Ride.
- **Tiền điều kiện / input:** RideTrip terminal đủ điều kiện issue receipt; finance records đã ghi nhận.
- **Kết quả chấp nhận:** Receipt có tripRef, các khoản giá/phí và trạng thái thanh toán minh bạch.
- **Trường hợp từ chối / lỗi:** Transaction chưa xác định tiền không ghi Paid, không xuất sai số kết toán.
- **Minimum acceptance trong PRD:** Biên nhận tham chiếu đúng trip và payment/finance status.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-010-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: receipt có tripRef, các khoản giá/phí và trạng thái thanh toán minh bạch.
2. `AC-FR-RIDE-010-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: transaction chưa xác định tiền không ghi Paid, không xuất sai số kết toán.
3. `AC-FR-RIDE-010-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: nếu có điều chỉnh hợp lệ, dùng adjustment record thay vì ghi đè lịch sử âm thầm.

#### `FR-RIDE-011` — Xem lịch sử và chi tiết chuyến theo quyền.
- **Nguồn:** `UC-RIDE-011` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-07`.
- **Actor / trigger:** Customer / xem lịch sử Ride.
- **Tiền điều kiện / input:** Actor authenticated, query theo own customer ID và page cursor.
- **Kết quả chấp nhận:** Trả danh sách theo thứ tự xác định, chi tiết đúng owner, không lộ PII người khác.
- **Trường hợp từ chối / lỗi:** Đổi ID query/path sang chuyến của người khác không trả dữ liệu.
- **Minimum acceptance trong PRD:** Không xem chuyến của user khác; lọc test transactions theo môi trường.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-011-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trả danh sách theo thứ tự xác định, chi tiết đúng owner, không lộ PII người khác.
2. `AC-FR-RIDE-011-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: đổi ID query/path sang chuyến của người khác không trả dữ liệu.
3. `AC-FR-RIDE-011-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: đơn test/cancel/active phản ánh trạng thái thật; không gom cả vào completed.

#### `FR-RIDE-012` — Báo cáo sự cố/tranh chấp chuyến từ lịch sử hoặc chuyến active.
- **Nguồn:** `UC-RIDE-012` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-RIDE-08`, `OPEN-015`.
- **Actor / trigger:** Customer / báo sự cố Ride.
- **Tiền điều kiện / input:** Customer có quyền với request/trip, reason/evidence theo whitelist policy.
- **Kết quả chấp nhận:** Case liên kết trip, có trạng thái, owner và escalation nếu an toàn.
- **Trường hợp từ chối / lỗi:** Không tự thay trạng thái chuyến hoặc debit/credit khi chỉ mới mở case.
- **Minimum acceptance trong PRD:** Có case ID và quá trình xử lý; không có thao tác âm thầm thay đổi ledger.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-RIDE-012-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: case liên kết trip, có trạng thái, owner và escalation nếu an toàn.
2. `AC-FR-RIDE-012-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không tự thay trạng thái chuyến hoặc debit/credit khi chỉ mới mở case.
3. `AC-FR-RIDE-012-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: tranh chấp pickup/start/end giữ timeline/evidence phù hợp và hạn chế PII.

### 5.3. Customer Food (12 yêu cầu)

#### `FR-FOOD-001` — Customer chọn địa chỉ giao và xem merchant có thể phục vụ.
- **Nguồn:** `UC-FOOD-001` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-01`, `OPEN-001`.
- **Actor / trigger:** Customer / chọn địa chỉ giao đồ ăn.
- **Tiền điều kiện / input:** Delivery location đủ xác thực, cửa hàng và vùng phục vụ cấu hình.
- **Kết quả chấp nhận:** Chỉ hiển thị/cho đặt merchant khả dụng với địa chỉ đã chọn.
- **Trường hợp từ chối / lỗi:** Ngoài coverage, quán ngừng nhận đơn thì không checkout thành công.
- **Minimum acceptance trong PRD:** Merchant ngoài vùng/đóng không được nhận order sai trạng thái.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-001-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: chỉ hiển thị/cho đặt merchant khả dụng với địa chỉ đã chọn.
2. `AC-FR-FOOD-001-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: ngoài coverage, quán ngừng nhận đơn thì không checkout thành công.
3. `AC-FR-FOOD-001-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: thay địa chỉ sau thêm giỏ phải tái kiểm delivery fee và merchant eligibility.

#### `FR-FOOD-002` — Tìm, lọc, xem cửa hàng và menu.
- **Nguồn:** `UC-FOOD-002` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-01/02`.
- **Actor / trigger:** Customer / tìm cửa hàng và menu.
- **Tiền điều kiện / input:** Có zone/location và query/filter hợp lệ.
- **Kết quả chấp nhận:** Trả danh sách được phân trang và menu gắn availability/timestamp.
- **Trường hợp từ chối / lỗi:** Quán hoặc món không còn phục vụ cần trạng thái rõ, không tự cho đặt.
- **Minimum acceptance trong PRD:** Danh sách và menu phản ánh availability có nguồn thời điểm; empty/error states rõ.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-002-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trả danh sách được phân trang và menu gắn availability/timestamp.
2. `AC-FR-FOOD-002-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: quán hoặc món không còn phục vụ cần trạng thái rõ, không tự cho đặt.
3. `AC-FR-FOOD-002-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: tìm kiếm/empty/loading/error kết quả không làm rò merchant chưa được duyệt.

#### `FR-FOOD-003` — Xem chi tiết món, biến thể, tùy chọn, số lượng và ghi chú.
- **Nguồn:** `UC-FOOD-003` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-02`.
- **Actor / trigger:** Customer / chọn món và tùy chọn.
- **Tiền điều kiện / input:** Menu item thuộc merchant, variant/options schema, qty và note.
- **Kết quả chấp nhận:** Chỉ nhận cấu hình đáp ứng required choices, giới hạn qty và trạng thái còn bán.
- **Trường hợp từ chối / lỗi:** Không chọn required option, item ngừng bán, sai price/option ID phải báo validation.
- **Minimum acceptance trong PRD:** Required options được chọn hợp lệ, không bán item unavailable.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-003-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: chỉ nhận cấu hình đáp ứng required choices, giới hạn qty và trạng thái còn bán.
2. `AC-FR-FOOD-003-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không chọn required option, item ngừng bán, sai price/option ID phải báo validation.
3. `AC-FR-FOOD-003-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: payload giả mạo option của cửa hàng khác bị từ chối, giá do server xác minh.

#### `FR-FOOD-004` — Quản lý cart và tổng tạm tính.
- **Nguồn:** `UC-FOOD-004` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-03`, `OPEN-009`.
- **Actor / trigger:** Customer / quản lý giỏ.
- **Tiền điều kiện / input:** Cart own context, item configurations và address/merchant association.
- **Kết quả chấp nhận:** Thêm/sửa/xóa món cập nhật item/fee estimate và trạng thái cart.
- **Trường hợp từ chối / lỗi:** Đổi merchant trái model 1-merchant đang đề xuất phải có UX theo policy OPEN-009.
- **Minimum acceptance trong PRD:** Đổi số lượng/xóa món cập nhật chính xác; giỏ không tự biến thành đơn.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-004-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: thêm/sửa/xóa món cập nhật item/fee estimate và trạng thái cart.
2. `AC-FR-FOOD-004-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: đổi merchant trái model 1-merchant đang đề xuất phải có UX theo policy OPEN-009.
3. `AC-FR-FOOD-004-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: cart không tự trở thành FoodOrder khi mở lại app, không nhận giá local là final.

#### `FR-FOOD-005` — Checkout xác minh lại giá, trạng thái quán, món, địa chỉ, chính sách trả tiền.
- **Nguồn:** `UC-FOOD-005` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-03`, `OPEN-002/003`.
- **Actor / trigger:** Customer / checkout và xem lại đơn.
- **Tiền điều kiện / input:** Cart snapshot, merchant availability, address, menu, pricing/payment policy.
- **Kết quả chấp nhận:** Server revalidate từng item/options/qty/fee và trả checkout preview version.
- **Trường hợp từ chối / lỗi:** Món hết, giá đổi, quán offline, quote expired yêu cầu user xem/chốt lại.
- **Minimum acceptance trong PRD:** Thay đổi bắt buộc có review/confirm; server không dùng giá trong UI làm source-of-truth.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-005-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: server revalidate từng item/options/qty/fee và trả checkout preview version.
2. `AC-FR-FOOD-005-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: món hết, giá đổi, quán offline, quote expired yêu cầu user xem/chốt lại.
3. `AC-FR-FOOD-005-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: sửa số tiền client không bypass pricing; không tạo order với cấu hình chưa chấp nhận.

#### `FR-FOOD-006` — Đặt FoodOrder một cách idempotent.
- **Nguồn:** `UC-FOOD-006` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-04`.
- **Actor / trigger:** Customer / xác nhận đặt FoodOrder.
- **Tiền điều kiện / input:** Checkout snapshot được xác nhận, quote/payment intent rule đã duyệt.
- **Kết quả chấp nhận:** Commit đúng một FoodOrder với line-item snapshot và response tracking.
- **Trường hợp từ chối / lỗi:** Double-submit, request trễ hay callback lặp không tạo đơn thứ hai.
- **Minimum acceptance trong PRD:** Retry/double tap không tạo đơn trùng trái ý định.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-006-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: commit đúng một FoodOrder với line-item snapshot và response tracking.
2. `AC-FR-FOOD-006-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: double-submit, request trễ hay callback lặp không tạo đơn thứ hai.
3. `AC-FR-FOOD-006-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: không đồng nhất đã đặt đơn với quán đã nhận hoặc tài xế đã được phân công.

#### `FR-FOOD-007` — Theo dõi merchant nhận/từ chối và thời gian chuẩn bị có phân biệt estimate.
- **Nguồn:** `UC-FOOD-007` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-04/06/08`, `TBD: merchant accept/timeout`.
- **Actor / trigger:** Customer / theo dõi merchant xử lý.
- **Tiền điều kiện / input:** FoodOrder hợp lệ; merchant nhận/từ chối; preparation estimate.
- **Kết quả chấp nhận:** Hiển thị chính xác pending merchant, accepted, preparing, ready/rejected.
- **Trường hợp từ chối / lỗi:** Quán từ chối/hết món/timeout phải thể hiện fail/recovery hợp lệ, không báo đang làm.
- **Minimum acceptance trong PRD:** Khi bị từ chối/hết món, hiển thị lý do/đường xử lý, không giả vờ đơn đang được làm.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-007-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị chính xác pending merchant, accepted, preparing, ready/rejected.
2. `AC-FR-FOOD-007-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: quán từ chối/hết món/timeout phải thể hiện fail/recovery hợp lệ, không báo đang làm.
3. `AC-FR-FOOD-007-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: eTA preparation là ước tính; khi merchant không phản hồi phải có state/case rõ theo policy.

#### `FR-FOOD-008` — Theo dõi giao món và tài xế theo quyền.
- **Nguồn:** `UC-FOOD-008` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-08`.
- **Actor / trigger:** Customer / xem giao hàng.
- **Tiền điều kiện / input:** DeliveryTask gắn FoodOrder và assignment đủ quyền, location có timestamp.
- **Kết quả chấp nhận:** Hiển thị tài xế được gán, các bước pickup/delivering và ETA ước tính.
- **Trường hợp từ chối / lỗi:** Driver location stale/reassigned: bỏ vị trí cũ và hiển thị fallback đáng tin.
- **Minimum acceptance trong PRD:** Tracking stale/offline được hiển thị phù hợp; reconnect cập nhật từ backend.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-008-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị tài xế được gán, các bước pickup/delivering và ETA ước tính.
2. `AC-FR-FOOD-008-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: driver location stale/reassigned: bỏ vị trí cũ và hiển thị fallback đáng tin.
3. `AC-FR-FOOD-008-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: không bao giờ suy ra giao thành công chỉ vì GPS tới gần điểm đến.

#### `FR-FOOD-009` — Nhận thông báo kết quả giao hàng/không thành công.
- **Nguồn:** `UC-FOOD-009` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-09`, `OPEN-011`.
- **Actor / trigger:** Customer / kết quả giao.
- **Tiền điều kiện / input:** Server có terminal event hợp lệ, proof-of-delivery theo OPEN-011.
- **Kết quả chấp nhận:** Hiển thị delivered hoặc delivery failed theo trạng thái authoritative.
- **Trường hợp từ chối / lỗi:** Thiếu proof/tài xế bấm lặp không được tự tạo delivered.
- **Minimum acceptance trong PRD:** Chỉ hiển thị `delivered` khi server đã chấp nhận proof/transition.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-009-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị delivered hoặc delivery failed theo trạng thái authoritative.
2. `AC-FR-FOOD-009-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: thiếu proof/tài xế bấm lặp không được tự tạo delivered.
3. `AC-FR-FOOD-009-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: đơn đã delivered vẫn có thể pending payment/settlement; nhãn tiền độc lập.

#### `FR-FOOD-010` — Được yêu cầu hỗ trợ, hủy, refund/dispute trong tình huống được duyệt.
- **Nguồn:** `UC-FOOD-010` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-10`, `OPEN-003/010/016`.
- **Actor / trigger:** Customer / hủy/yêu cầu hỗ trợ/hoàn tiền.
- **Tiền điều kiện / input:** Actor owns order, cancellation/refund eligibility theo policy.
- **Kết quả chấp nhận:** Nếu hợp lệ tạo request/case riêng; hiển thị pending/resolved với lý do.
- **Trường hợp từ chối / lỗi:** Không hoàn tiền tự động theo giá trị client; thiếu quyền/policy thì fail closed.
- **Minimum acceptance trong PRD:** Mỗi yêu cầu có trạng thái và hệ quả tài chính có thể tra cứu.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-010-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: nếu hợp lệ tạo request/case riêng; hiển thị pending/resolved với lý do.
2. `AC-FR-FOOD-010-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không hoàn tiền tự động theo giá trị client; thiếu quyền/policy thì fail closed.
3. `AC-FR-FOOD-010-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: nếu món đã làm nhưng không có tài xế thì chuyển Ops theo OPEN-016, không âm thầm refund.

#### `FR-FOOD-011` — Xem chi tiết đơn, món, phí, receipt, lịch sử.
- **Nguồn:** `UC-FOOD-011` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-12`.
- **Actor / trigger:** Customer / xem đơn cũ.
- **Tiền điều kiện / input:** Order/line item immutable snapshot, fee/receipt/payment references.
- **Kết quả chấp nhận:** Lịch sử phân biệt merchant status, delivery status, finance status theo thời điểm.
- **Trường hợp từ chối / lỗi:** Không được đổi giá món cũ khi quán chỉnh menu; không lộ đơn người khác.
- **Minimum acceptance trong PRD:** Phân biệt merchant accepted, courier assigned, delivered, payment settled.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-011-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: lịch sử phân biệt merchant status, delivery status, finance status theo thời điểm.
2. `AC-FR-FOOD-011-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không được đổi giá món cũ khi quán chỉnh menu; không lộ đơn người khác.
3. `AC-FR-FOOD-011-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: trạng thái ledger chưa settled không hiển thị tiền đã thanh toán cho đối tác.

#### `FR-FOOD-012` — Có thông điệp dễ hiểu khi không thể đặt/giao.
- **Nguồn:** `UC-FOOD-012` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-10`, `CAP-CORE-11`.
- **Actor / trigger:** Customer / gặp lỗi đặt hay giao.
- **Tiền điều kiện / input:** Không tìm được quán/tài xế, thất bại mạng, địa chỉ không hợp lệ.
- **Kết quả chấp nhận:** Hiển thị lý do có thể hiểu và một bước tiếp theo an toàn (retry/modify/contact).
- **Trường hợp từ chối / lỗi:** Không spinner vô thời hạn hoặc thông báo thành công giả.
- **Minimum acceptance trong PRD:** Không để trạng thái kẹt spinner; có retry an toàn hoặc hành động phù hợp.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-FOOD-012-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị lý do có thể hiểu và một bước tiếp theo an toàn (retry/modify/contact).
2. `AC-FR-FOOD-012-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không spinner vô thời hạn hoặc thông báo thành công giả.
3. `AC-FR-FOOD-012-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: retry network timeout phải đối chiếu order intent trước khi cho người dùng tạo lại.

### 5.4. Merchant Operations (9 yêu cầu)

#### `FR-MER-001` — Đăng ký/hoàn thiện hồ sơ cửa hàng, thông tin và giấy tờ được yêu cầu.
- **Nguồn:** `UC-MER-001` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-03`, `OPEN-006/008`.
- **Actor / trigger:** Merchant owner / tạo hồ sơ cửa hàng.
- **Tiền điều kiện / input:** Account được phép đăng ký; danh mục thông tin/giấy tờ theo OPEN-006.
- **Kết quả chấp nhận:** Lưu hồ sơ, trạng thái xét duyệt và business profile đúng owner.
- **Trường hợp từ chối / lỗi:** Chưa KYB/không đạt eligibility: không bật nhận FoodOrder live.
- **Minimum acceptance trong PRD:** Chỉ cửa hàng đủ điều kiện mới bật nhận đơn.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-001-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: lưu hồ sơ, trạng thái xét duyệt và business profile đúng owner.
2. `AC-FR-MER-001-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: chưa KYB/không đạt eligibility: không bật nhận FoodOrder live.
3. `AC-FR-MER-001-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: mở file giấy tờ từ cửa hàng khác hoặc role Customer phải bị chặn.

#### `FR-MER-002` — Cửa hàng được bật/tắt khả năng nhận đơn và quản lý giờ hoạt động.
- **Nguồn:** `UC-MER-002` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-11`.
- **Actor / trigger:** Merchant có quyền / bật/tắt nhận đơn.
- **Tiền điều kiện / input:** Cửa hàng eligible, giờ làm việc và serviceability config hợp lệ.
- **Kết quả chấp nhận:** Set availability trên server, storefront phản ánh trạng thái gần hiện tại.
- **Trường hợp từ chối / lỗi:** Cửa hàng closed/suspended không được nhận order mới trừ scheduled policy được duyệt.
- **Minimum acceptance trong PRD:** Không nhận đơn mới khi unavailable, trừ logic đặt trước đã được duyệt.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-002-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: set availability trên server, storefront phản ánh trạng thái gần hiện tại.
2. `AC-FR-MER-002-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: cửa hàng closed/suspended không được nhận order mới trừ scheduled policy được duyệt.
3. `AC-FR-MER-002-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: tắt nhận đơn mới không tự hủy order đang accepted; có hướng xử lý in-flight.

#### `FR-MER-003` — Quản lý món/giá/options/tình trạng còn-hết trong cửa hàng được ủy quyền.
- **Nguồn:** `UC-MER-003` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-02/11`, `OPEN-013`.
- **Actor / trigger:** Merchant có quyền / sửa menu.
- **Tiền điều kiện / input:** Món/biến thể/options thuộc đúng store, quyền quản lý phù hợp.
- **Kết quả chấp nhận:** Lưu revision/menu state, price và availability; khách đọc version phù hợp.
- **Trường hợp từ chối / lỗi:** Sai store, menu item đang bị khóa, payload giả priceRef bị từ chối.
- **Minimum acceptance trong PRD:** Không sửa menu cửa hàng khác; thay giá không sửa ngầm giá đơn đã xác nhận.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-003-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: lưu revision/menu state, price và availability; khách đọc version phù hợp.
2. `AC-FR-MER-003-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: sai store, menu item đang bị khóa, payload giả priceRef bị từ chối.
3. `AC-FR-MER-003-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: thay giá hiện tại không sửa order snapshot/receipt đã commit.

#### `FR-MER-004` — Xem inbox đơn thuộc merchant/store hợp lệ.
- **Nguồn:** `UC-MER-004` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-05`, `OPEN-013`.
- **Actor / trigger:** Merchant / xem hàng chờ đơn.
- **Tiền điều kiện / input:** Đã được cấp quyền chính xác tới store/branch theo OPEN-013.
- **Kết quả chấp nhận:** Danh sách order của store, trạng thái merchant mới nhất, chi tiết cần xử lý.
- **Trường hợp từ chối / lỗi:** Merchant B không thể thấy inbox Merchant A bằng sửa filter.
- **Minimum acceptance trong PRD:** Merchant B không thể truy cập order merchant A; có phân biệt trạng thái.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-004-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: danh sách order của store, trạng thái merchant mới nhất, chi tiết cần xử lý.
2. `AC-FR-MER-004-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: merchant B không thể thấy inbox Merchant A bằng sửa filter.
3. `AC-FR-MER-004-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: push đến lặp không tạo card duplicate và query refresh giữ trạng thái authoritative.

#### `FR-MER-005` — Chấp nhận hoặc từ chối đơn theo quy tắc.
- **Nguồn:** `UC-MER-005` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-05`, `TBD: merchant accept/timeout`.
- **Actor / trigger:** Merchant / chấp nhận hoặc từ chối order.
- **Tiền điều kiện / input:** Order đang chờ merchant decision, actor được quyền, availability hợp lệ.
- **Kết quả chấp nhận:** Server ghi merchant decision một lần với time/reason theo policy.
- **Trường hợp từ chối / lỗi:** Chấp nhận sau khi order đã cancel/timeout, accept và reject cùng lúc phải conflict.
- **Minimum acceptance trong PRD:** Chỉ hành động khi order đang ở state hợp lệ; phải có reason nếu policy yêu cầu.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-005-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: server ghi merchant decision một lần với time/reason theo policy.
2. `AC-FR-MER-005-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: chấp nhận sau khi order đã cancel/timeout, accept và reject cùng lúc phải conflict.
3. `AC-FR-MER-005-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: cạnh tranh 2 nhân viên xử lý: chỉ một quyết định terminal hợp lệ, mọi phía sync kết quả.

#### `FR-MER-006` — Đánh dấu preparing/ready và sẵn sàng handoff.
- **Nguồn:** `UC-MER-006` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-06`, `OPEN-011`.
- **Actor / trigger:** Merchant / chế biến và bàn giao món.
- **Tiền điều kiện / input:** FoodOrder đã được chấp nhận, stage hợp lệ; assignment/handoff token hợp lệ.
- **Kết quả chấp nhận:** Đánh dấu preparing/ready, xác nhận bàn giao đúng DeliveryTask và tài xế.
- **Trường hợp từ chối / lỗi:** Không có assignment hợp lệ hoặc nhầm driver/store không cho xác nhận handoff.
- **Minimum acceptance trong PRD:** Không handoff cho sai driver/order; retry không tạo sự kiện giao trùng.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-006-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: đánh dấu preparing/ready, xác nhận bàn giao đúng DeliveryTask và tài xế.
2. `AC-FR-MER-006-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không có assignment hợp lệ hoặc nhầm driver/store không cho xác nhận handoff.
3. `AC-FR-MER-006-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: bấm ready/handoff lặp không phát sinh hai pickup/handoff event nghiệp vụ.

#### `FR-MER-007` — Biết trạng thái tài xế lấy hàng, đơn giao thành công/thất bại.
- **Nguồn:** `UC-MER-007` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-08/09/12`.
- **Actor / trigger:** Merchant / theo dõi sau bàn giao.
- **Tiền điều kiện / input:** Có food order cùng store; trạng thái delivery đọc từ server.
- **Kết quả chấp nhận:** Hiển thị đã pickup, đang giao, delivered/failed kèm thông tin được cấp quyền.
- **Trường hợp từ chối / lỗi:** Thông báo push đơn lẻ không cho phép merchant tự đánh dấu customer received.
- **Minimum acceptance trong PRD:** Không suy đoán delivered chỉ dựa vào notification.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-007-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị đã pickup, đang giao, delivered/failed kèm thông tin được cấp quyền.
2. `AC-FR-MER-007-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: thông báo push đơn lẻ không cho phép merchant tự đánh dấu customer received.
3. `AC-FR-MER-007-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: deliveryTask assigned mới chưa chứng minh driver đã nhận món; sự kiện phải đúng stage.

#### `FR-MER-008` — Xem khoản phải thu/đã thu/đối soát và lịch sử theo quyền.
- **Nguồn:** `UC-MER-008` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-12`, `OPEN-002/003`.
- **Actor / trigger:** Merchant / xem khoản phải thu và đối soát.
- **Tiền điều kiện / input:** Owner/finance staff được quyền, ledger records và payout period hợp lệ.
- **Kết quả chấp nhận:** Trình bày gross, fees, adjustments, payable, pending, paid đúng source.
- **Trường hợp từ chối / lỗi:** Chưa có settlement event không báo đã chi; đối tác khác không xem được.
- **Minimum acceptance trong PRD:** Số tiền theo trạng thái và chính sách, không báo đã nhận nếu ledger chưa settled.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-008-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trình bày gross, fees, adjustments, payable, pending, paid đúng source.
2. `AC-FR-MER-008-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: chưa có settlement event không báo đã chi; đối tác khác không xem được.
3. `AC-FR-MER-008-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: reconciliation mismatch phải hiện chưa xử lý và case/reference cho Finance/Ops.

#### `FR-MER-009` — Báo vấn đề đơn/hết món/không có tài xế hoặc tranh chấp bàn giao.
- **Nguồn:** `UC-MER-009` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-FOOD-10`, `OPEN-016`.
- **Actor / trigger:** Merchant / báo vấn đề đơn hoặc giao nhận.
- **Tiền điều kiện / input:** Order/store đúng quyền, loại issue/reason/evidence hợp lệ.
- **Kết quả chấp nhận:** Case được tạo gắn order/merchant, có người xử lý và trạng thái.
- **Trường hợp từ chối / lỗi:** Merchant không tự đổi item/price của order đã accepted qua report issue.
- **Minimum acceptance trong PRD:** Có ticket/case và owner xử lý; không âm thầm đổi đơn.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-MER-009-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: case được tạo gắn order/merchant, có người xử lý và trạng thái.
2. `AC-FR-MER-009-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: merchant không tự đổi item/price của order đã accepted qua report issue.
3. `AC-FR-MER-009-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: trường hợp thiếu tài xế sau ready phải giữ evidence/timestamp và escalation OPEN-016.

### 5.5. Driver Operations (10 yêu cầu)

#### `FR-DRV-001` — Đăng ký và theo dõi trạng thái xét duyệt/giấy tờ/xe/dịch vụ đủ điều kiện.
- **Nguồn:** `UC-DRV-001` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-01`, `OPEN-006/008`.
- **Actor / trigger:** Driver / đăng ký & gửi giấy tờ.
- **Tiền điều kiện / input:** Account và tài liệu license/vehicle/identity theo OPEN-006/008.
- **Kết quả chấp nhận:** Có hồ sơ xác minh và eligibility tách theo dịch vụ Ride/Food.
- **Trường hợp từ chối / lỗi:** Hồ sơ expired/rejected/suspended không bật nhận dịch vụ bị giới hạn.
- **Minimum acceptance trong PRD:** Không được online nhận job Ride/Food nếu thiếu quyền bắt buộc.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-001-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: có hồ sơ xác minh và eligibility tách theo dịch vụ Ride/Food.
2. `AC-FR-DRV-001-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: hồ sơ expired/rejected/suspended không bật nhận dịch vụ bị giới hạn.
3. `AC-FR-DRV-001-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: cập nhật hồ sơ trong lúc active job xử lý theo safety SOP, không tiếp nhận job mới trái policy.

#### `FR-DRV-002` — Bật/tắt availability theo dịch vụ được phép.
- **Nguồn:** `UC-DRV-002` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-02`, `OPEN-005`.
- **Actor / trigger:** Driver / bật/tắt trạng thái nhận việc.
- **Tiền điều kiện / input:** Driver được duyệt cho service và không có capacity conflict.
- **Kết quả chấp nhận:** Backend cập nhật availability theo role/service, phát trạng thái tới dispatch.
- **Trường hợp từ chối / lỗi:** Role không eligible, suspended, capacity full không bật online thành công.
- **Minimum acceptance trong PRD:** Hệ thống backend quyết định driver eligible/available, không dựa vào switch local.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-002-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: backend cập nhật availability theo role/service, phát trạng thái tới dispatch.
2. `AC-FR-DRV-002-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: role không eligible, suspended, capacity full không bật online thành công.
3. `AC-FR-DRV-002-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: tắt online không đồng nghĩa tự hủy active assignment; phải có runbook an toàn.

#### `FR-DRV-003` — Xem thông tin cần thiết của offer có hạn nhận.
- **Nguồn:** `UC-DRV-003` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-03`, `OPEN-004`.
- **Actor / trigger:** Driver / xem job offer.
- **Tiền điều kiện / input:** Offer chưa hết hạn, thuộc đúng driver/driver group, đủ quyền.
- **Kết quả chấp nhận:** Thông tin tối thiểu pickup/destination hoặc merchant/delivery, loại job và deadline.
- **Trường hợp từ chối / lỗi:** Offer expired/revoked hoặc job bị phân công không cho CTA accept hoạt động.
- **Minimum acceptance trong PRD:** Không lộ thông tin ngoài quyền; offer expired/revoked hiện trạng thái đúng.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-003-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: thông tin tối thiểu pickup/destination hoặc merchant/delivery, loại job và deadline.
2. `AC-FR-DRV-003-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: offer expired/revoked hoặc job bị phân công không cho CTA accept hoạt động.
3. `AC-FR-DRV-003-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: không phát tán số điện thoại/địa chỉ quá mức được duyệt trước assignment.

#### `FR-DRV-004` — Nhận/từ chối offer và biết kết quả chính thức.
- **Nguồn:** `UC-DRV-004` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-03`, `CAP-CORE-06`.
- **Actor / trigger:** Driver / nhận hoặc từ chối offer.
- **Tiền điều kiện / input:** Offer ID, actor eligible, version/deadline và capacity policy hợp lệ.
- **Kết quả chấp nhận:** Server commit assignment thắng, trả accepted/lost/rejected; UI chỉ vào job khi thắng.
- **Trường hợp từ chối / lỗi:** Nhận 2 offer đồng thời, offer stale hoặc bị revoke phải có kết quả không thành công rõ.
- **Minimum acceptance trong PRD:** Accept cạnh tranh chỉ có một assignment được commit; không mở job nếu thua.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-004-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: server commit assignment thắng, trả accepted/lost/rejected; UI chỉ vào job khi thắng.
2. `AC-FR-DRV-004-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: nhận 2 offer đồng thời, offer stale hoặc bị revoke phải có kết quả không thành công rõ.
3. `AC-FR-DRV-004-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: test 2 driver accept cùng nhiệm vụ và một driver dùng 2 thiết bị: không duplicate assignment.

#### `FR-DRV-005` — Đến pickup Ride, bắt đầu/kết thúc chuyến hợp lệ.
- **Nguồn:** `UC-DRV-005` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-04`, `OPEN-017`.
- **Actor / trigger:** Driver / tiến tới khách và thực hiện Ride.
- **Tiền điều kiện / input:** Driver được gán trip, đúng trạng thái, proof start/finish theo OPEN-017.
- **Kết quả chấp nhận:** Chuyển tiến trình arrived/start/completed hợp lệ với timestamp/actor.
- **Trường hợp từ chối / lỗi:** Sai driver, chưa pickup, trip đã canceled/completed không hoàn tất lại.
- **Minimum acceptance trong PRD:** Thứ tự chuyển state được kiểm soát server và ghi dấu vết.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-005-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: chuyển tiến trình arrived/start/completed hợp lệ với timestamp/actor.
2. `AC-FR-DRV-005-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: sai driver, chưa pickup, trip đã canceled/completed không hoàn tất lại.
3. `AC-FR-DRV-005-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: offline input nếu cho phép phải reconcile theo server, không fake completed dựa vào local queue.

#### `FR-DRV-006` — Đến merchant, xác nhận lấy món, giao và hoàn tất theo proof policy.
- **Nguồn:** `UC-DRV-006` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-05`, `OPEN-011`.
- **Actor / trigger:** Driver / lấy và giao Food.
- **Tiền điều kiện / input:** Assignment đúng DeliveryTask/store, proof pickup/delivery theo OPEN-011.
- **Kết quả chấp nhận:** Chuyển picked_up/en_route/delivered hợp lệ, cập nhật order projection.
- **Trường hợp từ chối / lỗi:** Không đúng merchant/order, proof sai, job canceled không hoàn thành được.
- **Minimum acceptance trong PRD:** Không giả hoàn tất vì offline hoặc chỉ nhấn nút; proof được kiểm tra.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-006-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: chuyển picked_up/en_route/delivered hợp lệ, cập nhật order projection.
2. `AC-FR-DRV-006-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không đúng merchant/order, proof sai, job canceled không hoàn thành được.
3. `AC-FR-DRV-006-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: driver khác gửi proof/delivery cho job không được assign phải bị chặn toàn bộ.

#### `FR-DRV-007` — Xem bản đồ/ETA/định hướng phù hợp quyền, xử lý mất GPS/mạng.
- **Nguồn:** `UC-DRV-007` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-06`, `OPEN-012`.
- **Actor / trigger:** Driver / dùng định vị và điều hướng.
- **Tiền điều kiện / input:** Quyền GPS hiện hành, event có accuracy/timestamp và active job.
- **Kết quả chấp nhận:** Có bản đồ/ETA ước tính, cảnh báo quyền thiếu và refresh khi reconnect.
- **Trường hợp từ chối / lỗi:** GPS stale/spoof suspicion không được coi là lộ trình chính xác để xử tiền.
- **Minimum acceptance trong PRD:** Stale location có biểu thị; hệ thống không cố dùng GPS cũ làm hiện tại.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-007-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: có bản đồ/ETA ước tính, cảnh báo quyền thiếu và refresh khi reconnect.
2. `AC-FR-DRV-007-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: gPS stale/spoof suspicion không được coi là lộ trình chính xác để xử tiền.
3. `AC-FR-DRV-007-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: không tracking nền ngoài điều kiện consent, OS permission và chính sách OPEN-012.

#### `FR-DRV-008` — Tránh nhận job chồng chéo trái policy Ride/Food.
- **Nguồn:** `UC-DRV-008` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-ROLE-02`, `OPEN-005`.
- **Actor / trigger:** Driver / quản lý công việc cạnh tranh.
- **Tiền điều kiện / input:** Driver có role nhiều service, active assignment/capacity state authoritative.
- **Kết quả chấp nhận:** Job mới chỉ được assign nếu rule capacity OPEN-005 cho phép.
- **Trường hợp từ chối / lỗi:** Hai offer thắng riêng đồng thời nhưng vượt quota phải rollback/deny 1 kết quả.
- **Minimum acceptance trong PRD:** Server từ chối assignment gây conflict theo policy, kể cả khi 2 thiết bị nhận đồng thời.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-008-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: job mới chỉ được assign nếu rule capacity OPEN-005 cho phép.
2. `AC-FR-DRV-008-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: hai offer thắng riêng đồng thời nhưng vượt quota phải rollback/deny 1 kết quả.
3. `AC-FR-DRV-008-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: server thực thi policy dù driver bật online Ride+Food trên hai thiết bị.

#### `FR-DRV-009` — Xem lịch sử công việc, earnings estimate và khoản đã quyết toán.
- **Nguồn:** `UC-DRV-009` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-DRV-07`, `OPEN-002/003/018`.
- **Actor / trigger:** Driver / xem thu nhập.
- **Tiền điều kiện / input:** Driver được cấp quyền, job/finance refs và kỳ xem.
- **Kết quả chấp nhận:** Bảng tiền dự kiến, đã ghi nhận, công nợ, đã chi tách nghĩa.
- **Trường hợp từ chối / lỗi:** Pending/unknown/reconciliation không trở thành đã nhận chỉ vì job delivered.
- **Minimum acceptance trong PRD:** Không hiển thị `estimated` như khoản tiền đã chi trả.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-009-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: bảng tiền dự kiến, đã ghi nhận, công nợ, đã chi tách nghĩa.
2. `AC-FR-DRV-009-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: pending/unknown/reconciliation không trở thành đã nhận chỉ vì job delivered.
3. `AC-FR-DRV-009-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: driver không xem payout của driver khác; COD ledger nếu áp dụng phải có ref riêng.

#### `FR-DRV-010` — Báo sự cố khách vắng, merchant chưa sẵn, không giao được, tranh chấp tiền.
- **Nguồn:** `UC-DRV-010` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-CORE-11`, `OPEN-015/016/018`.
- **Actor / trigger:** Driver / báo sự cố vận hành.
- **Tiền điều kiện / input:** Active/completed job đủ quyền, loại incident và bằng chứng được phép.
- **Kết quả chấp nhận:** Sinh case có jobRef, actor, loại và escalation, giữ lịch sử.
- **Trường hợp từ chối / lỗi:** Không tự đổi paid/settled hoặc delivered thành success vì driver mở ticket.
- **Minimum acceptance trong PRD:** Có reason/case/proof path và ops escalation; không tự xử tiền trái quyền.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-DRV-010-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: sinh case có jobRef, actor, loại và escalation, giữ lịch sử.
2. `AC-FR-DRV-010-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không tự đổi paid/settled hoặc delivered thành success vì driver mở ticket.
3. `AC-FR-DRV-010-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: đơn khách vắng, quán chưa sẵn, không giao được phải có outcome/runbook tùy policy OPEN-015/016.

### 5.6. Admin & Financial Operations (10 yêu cầu)

#### `FR-OPS-001` — Nhân sự vận hành đăng nhập và được phân quyền theo chức năng.
- **Nguồn:** `UC-OPS-001` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-01`.
- **Actor / trigger:** Nhân sự Admin / đăng nhập và thao tác.
- **Tiền điều kiện / input:** Admin session có MFA hoặc cơ chế bảo vệ theo approved policy, role/permission rõ.
- **Kết quả chấp nhận:** Đăng nhập Admin Web, thấy menu/API theo quyền thực tế và scope.
- **Trường hợp từ chối / lỗi:** Account Customer không có quyền admin không thể dùng endpoint nội bộ.
- **Minimum acceptance trong PRD:** Không có quyền không xem/sửa; không phụ thuộc chỉ ẩn menu.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-001-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: đăng nhập Admin Web, thấy menu/API theo quyền thực tế và scope.
2. `AC-FR-OPS-001-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: account Customer không có quyền admin không thể dùng endpoint nội bộ.
3. `AC-FR-OPS-001-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: không chỉ ẩn nút ở UI; thử gọi thẳng API admin phải kiểm cùng permission.

#### `FR-OPS-002` — Xem, duyệt, từ chối, tạm khóa hồ sơ Driver/Merchant hợp lệ.
- **Nguồn:** `UC-OPS-002` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-02`, `OPEN-006/008`.
- **Actor / trigger:** Reviewer/Admin / duyệt hoặc khóa đối tác.
- **Tiền điều kiện / input:** Hồ sơ tồn tại, reviewer được ủy quyền, version/reason đầy đủ.
- **Kết quả chấp nhận:** Thay trạng thái eligibility có audit và thông báo đối tác thích hợp.
- **Trường hợp từ chối / lỗi:** Không quyền, conflict reviewer hoặc thiếu reason không chấp nhận thao tác.
- **Minimum acceptance trong PRD:** Mọi quyết định có actor, reason, audit, hồ sơ nhạy cảm được bảo vệ.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-002-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: thay trạng thái eligibility có audit và thông báo đối tác thích hợp.
2. `AC-FR-OPS-002-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không quyền, conflict reviewer hoặc thiếu reason không chấp nhận thao tác.
3. `AC-FR-OPS-002-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: duyệt Driver không tự duyệt Merchant; mỗi service có eligibility độc lập.

#### `FR-OPS-003` — Tra cứu Ride/Order/Delivery với timeline và actor liên quan.
- **Nguồn:** `UC-OPS-003` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-03`.
- **Actor / trigger:** Support/Ops / tra cứu transaction timeline.
- **Tiền điều kiện / input:** Có scope theo quyền, bộ lọc/correlation ID và record hợp lệ.
- **Kết quả chấp nhận:** Hiển thị timeline RideRequest/Trip/FoodOrder/Delivery/Finance mà không trộn lifecycle.
- **Trường hợp từ chối / lỗi:** Nhân viên không có quyền dữ liệu nhạy cảm không được thấy giấy tờ/PII thô.
- **Minimum acceptance trong PRD:** Có xác định source-of-truth, giới hạn dữ liệu theo nhân viên.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-003-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: hiển thị timeline RideRequest/Trip/FoodOrder/Delivery/Finance mà không trộn lifecycle.
2. `AC-FR-OPS-003-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: nhân viên không có quyền dữ liệu nhạy cảm không được thấy giấy tờ/PII thô.
3. `AC-FR-OPS-003-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: tìm bằng id của merchant/driver ngoài scope phải bị giới hạn dữ liệu hoặc từ chối.

#### `FR-OPS-004` — Xử lý yêu cầu hỗ trợ, sự cố và hoàn/hủy có kiểm soát.
- **Nguồn:** `UC-OPS-004` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-04/05`, `OPEN-003/015`.
- **Actor / trigger:** Admin có quyền / xử lý hủy, hoàn, khiếu nại.
- **Tiền điều kiện / input:** Case có owner, actor có permission theo action, policy tài chính đã chốt.
- **Kết quả chấp nhận:** Ghi quyết định/audit, tạo refund/adjustment thông qua nghiệp vụ được ủy quyền.
- **Trường hợp từ chối / lỗi:** Hủy job hoặc refund mà thiếu policy, thiếu reason, thiếu quyền thì từ chối.
- **Minimum acceptance trong PRD:** Không có quyền tự tạo refund bất hợp lệ; can thiệp có audit/reason.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-004-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: ghi quyết định/audit, tạo refund/adjustment thông qua nghiệp vụ được ủy quyền.
2. `AC-FR-OPS-004-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: hủy job hoặc refund mà thiếu policy, thiếu reason, thiếu quyền thì từ chối.
3. `AC-FR-OPS-004-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: retry hành động refund không tạo hai khoản hoàn; case close không chứng minh tiền đã hoàn.

#### `FR-OPS-005` — Quan sát offer/assignment stuck, thất bại, trạng thái giao dịch lệch.
- **Nguồn:** `UC-OPS-005` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-03/04`.
- **Actor / trigger:** Ops / giám sát job kẹt, offer trễ, mismatch.
- **Tiền điều kiện / input:** Có telemetry/state và correlationId/case liên kết.
- **Kết quả chấp nhận:** Truy vết timeline và lý do lỗi, chọn recovery action trong danh sách được duyệt.
- **Trường hợp từ chối / lỗi:** Unknown state không tự đánh dấu fixed khi warning tạm biến mất.
- **Minimum acceptance trong PRD:** Có khả năng điều tra theo correlation ID, không cần đọc trực tiếp DB để vận hành thường nhật.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-005-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: truy vết timeline và lý do lỗi, chọn recovery action trong danh sách được duyệt.
2. `AC-FR-OPS-005-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: unknown state không tự đánh dấu fixed khi warning tạm biến mất.
3. `AC-FR-OPS-005-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: reassign sau offline phải giữ một assignment hữu hiệu và đủ audit chứng minh.

#### `FR-OPS-006` — Đối soát giao dịch khách/merchant/driver/payment provider.
- **Nguồn:** `UC-OPS-006` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-06`, `OPEN-002/003`.
- **Actor / trigger:** Finance / đối soát nhiều bên.
- **Tiền điều kiện / input:** Có statement PSP/ledger/merchant/driver, xác nhận thời kỳ đối soát.
- **Kết quả chấp nhận:** Tạo kết quả matched/unmatched/review với reference và các điều chỉnh riêng.
- **Trường hợp từ chối / lỗi:** Thiếu bản ghi, tiền lệch, duplicate event không được mark matched.
- **Minimum acceptance trong PRD:** Chênh lệch có trạng thái unresolved và owner; không tự đánh dấu matched.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-006-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: tạo kết quả matched/unmatched/review với reference và các điều chỉnh riêng.
2. `AC-FR-OPS-006-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: thiếu bản ghi, tiền lệch, duplicate event không được mark matched.
3. `AC-FR-OPS-006-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: thực thi lặp reconciliation batch cho một kỳ không cộng tiền hoặc payout 2 lần.

#### `FR-OPS-007` — Quản lý cấu hình vùng/dịch vụ/feature/merchant eligibility trong quyền duyệt.
- **Nguồn:** `UC-OPS-007` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-07`, `OPEN-001/004`.
- **Actor / trigger:** Ops / cấu hình vùng, dịch vụ và feature.
- **Tiền điều kiện / input:** Admin có scope, change request đã duyệt, phiên bản cấu hình.
- **Kết quả chấp nhận:** Lưu config có hiệu lực/actor/reason, tác động admission phù hợp ranh giới.
- **Trường hợp từ chối / lỗi:** Không có quyền hoặc vùng chưa được phê duyệt không được kích hoạt production.
- **Minimum acceptance trong PRD:** Không cấu hình ngoài phạm vi được duyệt hoặc bỏ qua gate `OPEN-001`.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-007-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: lưu config có hiệu lực/actor/reason, tác động admission phù hợp ranh giới.
2. `AC-FR-OPS-007-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không có quyền hoặc vùng chưa được phê duyệt không được kích hoạt production.
3. `AC-FR-OPS-007-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: thay geofence phải kiểm lại Ride/Food ở thời điểm tạo yêu cầu mới, không đổi âm thầm job active.

#### `FR-OPS-008` — Có audit trail và phân loại sự cố/anomaly.
- **Nguồn:** `UC-OPS-008` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-08`.
- **Actor / trigger:** Admin auditor / đọc lịch sử thao tác và cảnh báo.
- **Tiền điều kiện / input:** Có quyền xem audit theo scope và tiêu chí tìm kiếm.
- **Kết quả chấp nhận:** Trả actor/action/time/resource/reason/correlation với phần nhạy cảm masked.
- **Trường hợp từ chối / lỗi:** Không cho sửa/xóa log qua UI bình thường và không lộ secrets.
- **Minimum acceptance trong PRD:** Tra được ai/thời điểm/hành động/lý do; không lưu mật khẩu/token/CCCD đầy đủ trong log.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-008-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: trả actor/action/time/resource/reason/correlation với phần nhạy cảm masked.
2. `AC-FR-OPS-008-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: không cho sửa/xóa log qua UI bình thường và không lộ secrets.
3. `AC-FR-OPS-008-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: audit tìm được quyết định đã đổi trạng thái Driver/Merchant hay refund kèm người thực hiện.

#### `FR-OPS-009` — Tạm dừng tiếp nhận giao dịch mới theo vùng/service khi có sự cố nghiêm trọng.
- **Nguồn:** `UC-OPS-009` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc PRD:** `CAP-OPS-07/08`, `OPEN-007`.
- **Actor / trigger:** Incident commander/Ops / tạm dừng dịch vụ.
- **Tiền điều kiện / input:** Có quyền emergency/approval policy, vùng/service đang hoạt động.
- **Kết quả chấp nhận:** Chặn job mới theo phạm vi và log lý do; giao dịch in-flight còn đường xử lý.
- **Trường hợp từ chối / lỗi:** Lệnh disable không xóa nhiệm vụ, không tự refund/cancel hàng loạt.
- **Minimum acceptance trong PRD:** Stop admission không phá dữ liệu giao dịch đã được tạo; xử lý in-flight theo runbook.
**Acceptance criteria có thể kiểm thử:**
1. `AC-FR-OPS-009-01` — **Given** tiền điều kiện hợp lệ và dữ liệu đủ quyền; **When** actor thực hiện hành vi nêu trên; **Then** backend trả/lưu kết quả: chặn job mới theo phạm vi và log lý do; giao dịch in-flight còn đường xử lý.
2. `AC-FR-OPS-009-02` — **Given** dữ liệu không hợp lệ, state sai hoặc không đủ quyền; **When** yêu cầu được gửi qua API, kể cả bỏ qua UI; **Then** hệ thống từ chối an toàn và không có side effect trái phép: lệnh disable không xóa nhiệm vụ, không tự refund/cancel hàng loạt.
3. `AC-FR-OPS-009-03` — **Given** ca cạnh tranh/offline/stale hoặc quyền không hợp lệ tương ứng; **When** lặp thử nghiệm theo tình huống; **Then** phải chứng minh rằng: gửi RideRequest/FoodOrder mới trong vùng suspended phải bị từ chối có mã lỗi rõ.

#### `FR-OPS-010` — Admin được phân quyền quản lý trạng thái auth methods.
- **Nguồn:** `UC-OPS-010` · **Phạm vi:** `PROPOSED_P0` · **Phụ thuộc:** `DEC-PROD-006`, `OPEN-020`.
- **Actor / trigger:** Security Admin (và Config Manager nếu được cấp grant cụ thể) / xử lý outage hoặc rủi ro xác thực.
- **Yêu cầu:** Bật/tắt enrollment và authentication theo method ở mức platform/environment; Security Admin được revoke một credential/contact method của account cụ thể sau xác minh grounds. Thay đổi toàn hệ thống phải có step-up, reason, preview blast radius và dual approval theo policy; account-level action có case reference/audit. Toggle một method không âm thầm xóa credential hay session; thu hồi session là command riêng. Không thể tắt mọi method cho mọi người dùng ngoài emergency lock/suspend có recovery path.
- **Acceptance criteria:**
1. `AC-FR-OPS-010-01` — Admin không có permission bị deny; admin được cấp có thể disable/enable đúng method/scope và tạo audit event có before/after/version/reason/actor.
2. `AC-FR-OPS-010-02` — Disable method chặn enrollment/login mới theo cache/version guard; không xóa account, transaction, credential history hoặc tự logout mọi user.
3. `AC-FR-OPS-010-03` — Disable method cuối của account/global scope bị chặn hoặc yêu cầu emergency workflow có dual approval, recovery/lockout communications và explicit session-revocation choice.

## 6. Ma trận hậu điều kiện và loại đối tượng (để ngăn gộp sai lifecycle)

| Hành động | Đối tượng có thể tạo/thay đổi | Không được suy ra | Kiểm tra bắt buộc |
|---|---|---|---|
| Gửi yêu cầu gọi xe | `RideRequest` | Có `RideTrip`, đã gán tài xế | create idempotent, quote/zone, actor |
| Tài xế phản hồi giá Ride | `FareCounterOffer` / `RideFareNegotiation` | Dispatch assignment hoặc Trip đã bắt đầu | actor/time/amount/version/expiry; không coi là dispatch accept |
| Khách chọn đề nghị giá Ride | `AcceptedFareAgreement` + `DriverAssignment` | `RideTrip` đã bắt đầu hoặc payment captured | atomic single winner; immutable agreed fare |
| Tài xế nhận dispatch job | `DispatchOffer`/`Assignment` | `RideTrip` đã bắt đầu, order đã giao | transaction race, eligibility, expiry |
| Bắt đầu Ride | `RideTrip` lifecycle | Customer đã trả tiền | permission, transition, evidence |
| Checkout đặt Food | `FoodOrder` + item snapshot | Merchant đã nhận, có courier | cart revalidation, price version, idempotency |
| Quán xác nhận món | `FoodOrder` merchant lifecycle | `DeliveryTask` đã picked_up | right store, state guard, concurrency |
| Dispatch Food | `DeliveryTask` + offer/assignment | Merchant đã ready, đơn đã delivered | state separation, reassign policy |
| Xác nhận handoff | `DeliveryTask` pickup/handoff event | Đã giao cho khách | đúng driver, đúng store/order, proof |
| Xác nhận delivered | `DeliveryTask`/order projection | PSP đã capture, merchant đã settled | proof, status transition, audit |
| PSP báo payment success | payment/ledger reference | Food delivered, Ride completed, payout xong | webhook verify, dedupe, reconciliation |
| Refund được chấp thuận | refund intent và tài chính | Tiền đã về tài khoản khách ngay lập tức | authorization, state tracking, reconcile |

## 7. Cross-functional negative-case matrix (bắt buộc trước release gate)

| Test seed | FR chịu tác động | Điều kiện đưa vào test | Expected invariant | Release gate |
|---|---|---|---|---|
| `SEED-01` Double tap booking | `FR-CORE-006`, `FR-RIDE-003`, `FR-FOOD-006` | Hai POST cùng key, mạng retry | Một business intent → tối đa một object | G2/G3 |
| `SEED-02` Key trùng payload khác | `FR-CORE-006` | Cùng key, body khác | Conflict; không transaction thứ hai | G1/G4 |
| `SEED-03` Hai tài xế accept | `FR-CORE-005`, `FR-DRV-004`, `FR-DRV-008` | Requests cạnh tranh | Một assignment hữu hiệu/job | G2/G3 |
| `SEED-04` Hủy vs assign | `FR-RIDE-008`, `FR-CORE-005` | Hai transaction đồng thời | Không có trip vừa cancelled vừa active | G2 |
| `SEED-05` Merchant accept vs customer cancel | `FR-MER-005`, `FR-FOOD-010` | Cross-role conflicting commit | One authoritative outcome + compensating flow theo policy | G3 |
| `SEED-06` Item sold-out after add-to-cart | `FR-FOOD-003..006`, `FR-MER-003` | Menu revision sau cart | Không checkout theo snapshot giá/món cũ không hợp lệ | G3 |
| `SEED-07` Merchant prepared, no driver | `FR-MER-006/009`, `FR-FOOD-010/012` | Dispatch không tìm được supply | Không tự delivered/refunded; case xử lý `OPEN-016` | G3/G5 |
| `SEED-08` Swap store ID | `FR-CORE-010`, `FR-MER-003/004/008` | Sửa resource ID trong API | 403/404 theo policy, không lộ dữ liệu store | G3/G4 |
| `SEED-09` Swap driver assignment ID | `FR-DRV-004/005/006` | Driver B gọi API của Driver A | Không thay task; không nhận proof | G2/G3 |
| `SEED-10` PSP callback replay/out of order | `FR-CORE-008`, `FR-OPS-006` | Trùng event ID, đảo thứ tự | Ledger không double post; trạng thái pending/reconcile | G4/G5 |
| `SEED-11` Duplicate refund request | `FR-OPS-004`, `FR-CORE-008` | Retry sau timeout | Không double refund; đúng case status | G4/G5 |
| `SEED-12` Stale push after completion | `FR-CORE-009/014`, `FR-FOOD-009` | Push searching gửi sau delivered | UI không lùi state/không lộ sensitive data | G4 |
| `SEED-13` Kill app during active trip | `FR-CORE-009`, `FR-RIDE-007`, `FR-DRV-005` | Force stop / relaunch | Khôi phục session/job từ backend | G2/G4 |
| `SEED-14` Permission revoked on active driver | `FR-DRV-001/002`, `FR-OPS-002` | KYC/eligibility revoke | Không nhận job mới, active task xử lý an toàn | G4/G5 |
| `SEED-15` GPS stale / permission denied | `FR-CORE-004`, `FR-DRV-007` | Location cũ, giả hoặc thiếu quyền | Không đánh dấu live/đích đến giả; đường hỗ trợ | G2/G3 |
| `SEED-16` Emergency pause zone | `FR-OPS-009`, `FR-OPS-007` | Disable vùng giữa active jobs | Chặn booking mới; không phá in-flight | G4/G5 |
| `SEED-17` Partial outage / reconnect | `FR-CORE-009`, `FR-FOOD-008`, `FR-RIDE-009` | Socket mất, HTTP hoạt động | Re-fetch source-of-truth và cảnh báo stale | G4 |
| `SEED-18` Payment unknown at receipt | `FR-RIDE-010`, `FR-FOOD-011`, `FR-DRV-009` | PSP timeout | Không hiển thị PAID/SETTLED giả | G4/G5 |
| `SEED-19` Role switch while busy | `FR-CORE-002`, `FR-DRV-008` | Customer/Merchant/Driver in-progress | Tôn trọng rule `OPEN-005`, không mất active job | G4 |
| `SEED-20` Admin without permission | `FR-OPS-001/002/004/008` | Đổi role bằng payload/token | Backend từ chối, audit attempt thích hợp | G4/G5 |

> Dải `FR-FOOD-003..006` và ký hiệu `FR-MER-003/004/008` ở bảng trên là cách viết gọn **trỏ đến các FR riêng lẻ đã tồn tại**, không phải mã FR mới. Test implementation sẽ có `TC-*` tách từng case trong tài liệu QA chuyên trách.

## 8. Phân tích dữ liệu đầu vào/đầu ra theo capability

| Capability | Inputs tối thiểu (logic, chưa khóa schema) | Outputs quan sát được | Source of truth | Failure handling |
|---|---|---|---|---|
| Authentication / eligibility | Account credential, role requested, partner document refs | Auth state, granted roles, eligibility, review status | IAM + Partner domain | Deny/reauth/support, không cấp role qua client |
| Maps, Coverage, ETA | Pickup/destination/location age, zone, service | normalized point, serviceability, estimated route/ETA | Backend + map adapter | invalid/unknown/stale có trạng thái riêng |
| Quote / Checkout | Ride intent hoặc cart snapshot, price policy revision | quoteRef/version, line breakdown, expiry theo policy | Pricing domain | requote/confirm lại, không lấy giá client |
| Ride booking | actor, points, valid quote, intent key | RideRequest ID, request state | Ride domain | retry-safe, blocked coverage, no driver |
| Food booking | verified cart, address, merchant, quote, intent key | FoodOrder ID + item snapshot | Food domain | item changed, merchant unavailable, retry-safe |
| Merchant order processing | store ID, order ID, expected version, action | merchant decision/preparation/handoff state | Food domain | stale/unauthorized/conflict |
| Dispatch and driver capacity | job, candidate eligibility, offer, version | offer state, assignment ID/owner | Dispatch domain | expire/revoke/reassign, atomic winner |
| Tracking and realtime | active assignment, location+timestamp, event version | privacy-scoped status, latest safe location | Domain state + tracking adapter | stale indicator, reconnect read |
| Customer support | actor, transaction reference, category/evidence | case ID, assignee, state | Support domain | validation, wrong owner, escalation |
| Payment/settlement | internal reference, provider event, finance policy | ledger reference, state, reconciliation item | Finance ledger/PSP verified state | unknown/pending, dedupe, reconcile |
| Admin intervention | admin permission, reason, target, expected version | audited intervention result | Ops + domain authority | denied/approval required/conflict |

## 9. Decision blockers: có thể triển khai gì trước khi chốt?

| Decision | Các FR bị ảnh hưởng điển hình | Sandbox/architecture được làm | Phải chặn production hoặc khóa policy trước |
|---|---|---|---|
| `OPEN-001` Vùng phục vụ | CORE-004; RIDE-001; FOOD-001; OPS-007/009 | Adapter geofence và zones fixtures | Vùng phục vụ live và nhận booking thật |
| `OPEN-002` Kênh thu tiền | CORE-008; FOOD-005/006; OPS-006 | PSP interface, sandbox, callback dedupe | Thu hộ/capture/refund real |
| `OPEN-003` Giá/phí/hủy | CORE-007/008; RIDE-002/008/010; FOOD-005/010 | Quote snapshots & rules config `TEST_ONLY` | Fare/cancel/refund/settlement thật |
| `OPEN-004` Dispatch | CORE-005; RIDE-004; DRV-003/004 | Atomic assignment, simulated offers | Timeout/radius/strategy live |
| `OPEN-005` Multi-role/capacity | CORE-002; DRV-002/008 | Authorization + capacity guard, fail-closed | Đồng thời job/chuyển role khi busy |
| `OPEN-006` Mô hình đối tác | CORE-003; MER-001; DRV-001; OPS-002 | Onboarding/status + masked sandbox | Cấp quyền đối tác nhận việc thật |
| `OPEN-007` Load/SLO | CORE-012; OPS-005/009 | Metrics, alerts, load harness | G4/G5 threshold sign-off |
| `OPEN-008` Tích hợp provider | CORE-001/003/004/014; DRV-001 | Interface mocks, official SDK evaluation | OTP/KYC/maps/payment/push live |
| `OPEN-009` Một hay nhiều cửa hàng/giỏ | FOOD-003..006 | Cart model phân ranh tenant; 1-merchant fixture gắn giả định | Checkout multi-merchant nếu chưa duyệt |
| `OPEN-010` Food collection point | FOOD-005/006/010; MER-005 | Separate order/payment lifecycles | Capture/collect timeline thật |
| `OPEN-011` Proof | FOOD-009; MER-006; DRV-006 | Proof adapter/placeholder theo test fixture | Food delivered/pickup evidence thật |
| `OPEN-012` Tracking nền | CORE-009; FOOD-008; DRV-007 | Permission UX, foreground tracking giả lập | Background location live + retention |
| `OPEN-013` Staff/multi-store | MER-003/004/008; CORE-010 | Store-scoped authorization, seed multiple stores | Staff grants và live multibranch |
| `OPEN-014` Contact channel | CORE-011/014; RIDE-006 | Support fallback, privacy boundaries | Unmasked calling/chat direct |
| `OPEN-015` Safety support | CORE-011/012; RIDE-012; DRV-010 | Case metadata, escalation interface | Cam kết support/SLA khẩn cấp thật |
| `OPEN-016` Food no-driver risk | FOOD-007/010; MER-009 | Exception queues, distinct state | Refund/merchant compensation/cost allocation |
| `OPEN-017` Ride start/end proof | RIDE-007/008; DRV-005 | Transition guards, sandbox proof | Trip start/end chứng cứ thật |
| `OPEN-018` COD/driver advances | CORE-008; DRV-009; OPS-006 | Separate finance instruments/config | Thu hộ COD/payout/công nợ thật |

> Dùng `OPEN-*` ở đây là **bản sao chỉ mục** để reviewer tìm nhanh. Khi một quyết định được giải quyết, sửa trạng thái **chỉ** tại `decisions-and-assumptions.md`, ghi impact analysis rồi cập nhật yêu cầu liên quan. Agent không thay thế chủ dự án trong việc duyệt policy.

## 10. Requirement traceability and quality gates

### 10.1. Trace contract

Một vertical slice sẵn sàng triển khai khi có đường nối:

`DEC/OPEN → CAP → FR → AC-FR → UC → BR/WF → SCR → API/EVT/DATA → TC → Code/PR → Evidence → Gate`.

Chỉ `CAP/FR/UC/AC-FR` từ docs hiện có được ghi như **đã định danh**. `SCR/API/EVT/DATA/TC/Code` chỉ là target downstream `[PLANNED]` khi chưa có artifact tương ứng; không tạo đường dẫn giả.

### 10.2. Gate-wise FR review

| Gate | Nội dung review cốt lõi | Bằng chứng tối thiểu |
|---|---|---|
| `G0` Product baseline | Scope, ID, open decisions và ownership | PO sign-off scope, không có FR vô nguồn |
| `G1` Technical foundation | Authz, idempotency, state boundaries, API schemas | Contract tests + negative tests dùng fixtures |
| `G2` Ride slice | Customer ↔ Driver ↔ Dispatch, trip lifecycle | Ride E2E + no-driver, cancel-race, offline |
| `G3` Food slice | Customer ↔ Merchant ↔ Driver ↔ Finance | Food E2E + no-driver-after-prep, merchant race |
| `G4` Integrated MVP | Multi-role + cross-module, recoverability | Concurrent/race/security/load smoke, audit |
| `G5` Commercial/pilot | Law, finance, partner, provider, safety operations | Policy resolved, legal/ops/finance sign-off; không chỉ test xanh |

### 10.3. Checklist cho một FR được giao AI Agent

- [ ] `FR` và `UC` nguồn là ID thực, không tạo feature ngoài phạm vi.
- [ ] Đã xem `CAP-*` và trạng thái `OPEN-*` trong Governance bản mới nhất.
- [ ] Có actor, precondition, input/output, server authorization, state guard và negative path.
- [ ] Có `AC-FR-...-01/02/03` được BA/QA review; policy chưa duyệt được đánh dấu rõ.
- [ ] Có API/schema/event/data contract hoặc ghi `[PLANNED]`, không giả định endpoint.
- [ ] Có integration test + role/object authorization negative test + replay/race nếu mutating.
- [ ] Có UI loading/empty/error/retry/reconnect với thông điệp dễ hiểu.
- [ ] Có security/privacy/audit/observability phù hợp rủi ro.
- [ ] Có evidence test thực tế và trace ID trong pull request.
- [ ] Không báo `DONE` hoặc `PRODUCTION_READY` khi phụ thuộc P0 bị blocked bởi `OPEN-*`.

## 11. Test fixtures và dữ liệu giả lập chuẩn

Các ID và giá trị dưới là **test fixture ví dụ**, không định nghĩa ID thật, phí thật hoặc trạng thái production. Dữ liệu mẫu phải được sinh trong test environment:

```yaml
fixture_set: TEST_ONLY_DEALGO_FR_001
accounts:
  customer_a: {roles: [CUSTOMER], eligible: true}
  customer_b: {roles: [CUSTOMER], eligible: true}
  merchant_a: {roles: [MERCHANT], store: store_a, eligible: true}
  merchant_b: {roles: [MERCHANT], store: store_b, eligible: true}
  driver_a: {roles: [DRIVER], services: [RIDE, FOOD], eligible: true}
  driver_b: {roles: [DRIVER], services: [RIDE, FOOD], eligible: true}
  suspended_driver: {roles: [DRIVER], services: [RIDE], eligible: false}
  ops_support: {roles: [OPS_SUPPORT], permission_scope: limited}
  ops_finance: {roles: [OPS_FINANCE], permission_scope: finance}
scenario_flags:
  sandbox_dispatch_timeout: CONFIG_REQUIRED
  sandbox_quote: FIXTURE_VERSIONED
  sandbox_payment: MOCK_ONLY
  concurrency_policy: MUST_BE_APPROVED
  real_customer_data: FORBIDDEN
```

### 11.1. Mẫu acceptance để chuyển sang QA automation

```gherkin
@ride @idempotency @FR-RIDE-003
Scenario: Retrying the same ride intent must not create a second request
  Given a customer has a valid test quote and booking intent key
  When the customer submits the same booking request twice concurrently
  Then exactly one RideRequest exists for that business intent
  And both replies are consistent with the committed outcome
  And there is no RideTrip before an accepted assignment
```

```gherkin
@food @authorization @FR-MER-004
Scenario: Merchant cannot read orders from another store
  Given Merchant A is eligible only for Store A
  And Store B has a FoodOrder owned by Merchant B
  When Merchant A requests Store B's FoodOrder through the API
  Then the request is denied without exposing Store B's order details
  And Store B's order state remains unchanged
```

```gherkin
@dispatch @race @FR-DRV-004
Scenario: Concurrent offer acceptance has a single winner
  Given two eligible drivers can see a still-valid offer for the same job
  When both drivers accept at the same time
  Then at most one active assignment is committed
  And the other driver receives a non-winning result
  And replaying either request creates no second assignment
```

## 12. Những điều tài liệu này cố ý chưa quyết định

- Không chỉ định thành phố pilot; bán kính, thời gian chờ, cách xếp hạng ứng viên tài xế, hoặc chi phí tài xế.
- Không chốt số tiền, VAT, phụ phí, tỉ lệ chia doanh thu, COD, thời điểm capture, refund/cancellation fee, chargeback.
- Không tự chốt merchant đa chi nhánh, role staff, bảng quyền đặc biệt hay số lượng job đồng thời.
- Không chọn provider OTP, bản đồ, KYC, thanh toán, thông báo; không tuyên bố ứng dụng đã đủ giấy phép kinh doanh.
- Không định nghĩa proof-of-delivery bắt buộc là ảnh/OTP/chữ ký hoặc cho phép foreground/background location trái policy.
- Không giả vờ các file `02-domain/*`, `03-workflows/*`, `04-experience/*`, `06-data-api/*`, `08-quality/*` đã hoàn thiện.

## 13. Chuẩn đối chiếu và tài liệu tham khảo

Nguồn nghiên cứu chỉ xác nhận **phương pháp đặc tả**, không thay thế quyết định chính sách DealGo:

1. [OpenAPI Specification — version registry](https://spec.openapis.org/oas/) — thiết kế API contracts; tham khảo danh sách phiên bản đã phát hành. Việc chọn version project cần ADR và tương thích tooling.
2. [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html) — đề xuất format lỗi máy đọc được.
3. [OWASP API Security Top 10 (2023)](https://api-security.owasp.org/editions/2023/en/0x11-t10/) — object-level authorization, broken authentication, property authorization.
4. [Google Maps Routes API](https://developers.google.com/maps/documentation/routes) — dữ liệu tuyến đường/ETA ước tính, **không** mặc định lựa chọn vendor.
5. Tài liệu nội bộ đã tồn tại: `../00-governance/decisions-and-assumptions.md`, `./product-requirements.md`, `./use-case-catalog.md`.

## 14. Document QA, approvers, changelog

### 14.1. Kiểm tra cấu trúc bắt buộc

- [x] Có chính xác 71 `FR-*` nguồn theo PRD và 71 `UC-*` tương ứng trong Use Case Catalog.
- [x] Mỗi FR có 3 AC định danh duy nhất (213 AC), gồm positive/negative/edge.
- [x] Đánh dấu trạng thái `DRAFT`, `PROPOSED_P0` và liên kết chính sách còn mở.
- [x] Không phát sinh `FR-*` mới ngoài PRD; không sửa bản gốc trong ZIP.
- [ ] Product Owner/BA/Tech/QA duyệt toàn bộ acceptance và policy gates.
- [ ] Chuyển yêu cầu đã duyệt sang downstream API/schema/test bản có evidence.

### 14.2. Approval record

| Vai trò | Người duyệt | Ngày | Trạng thái |
|---|---|---|---|
| Product Owner | `TBD` | `TBD` | `PENDING` |
| Tech Lead | `TBD` | `TBD` | `PENDING` |
| QA Lead | `TBD` | `TBD` | `PENDING` |
| Operations/Finance/Security theo phạm vi | `TBD` | `TBD` | `PENDING` |

### 14.3. Lịch sử

| Phiên bản | Ngày | Thay đổi |
|---|---|---|
| 0.2.0 | 2026-10-12 | Thêm 4 FR cho passkey/verified contacts, in-app chat/voice, admin auth-method controls; tăng baseline lên 71 FR / 213 AC. |
| 0.1.0 | 2026-10-11 | Tạo FRS 67 FR / 201 AC, trace UC, failure cases, open-policy gates. |

**Tiếp theo theo master index:** `docs/01-product/non-functional-requirements.md` (11/69), tập trung NFR, reliability, security, performance, realtime/latency, privacy, accessibility và giới hạn đo lường; không tự đặt SLO production khi `OPEN-007` chưa chốt.

