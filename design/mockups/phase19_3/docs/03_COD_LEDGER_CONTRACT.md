# DealGo – COD, doanh thu Shop và thu nhập tài xế

**Golden transaction:** `DG123456`, tiền món 125.000đ; khách trả phí ship 25.000đ; COD 150.000đ. Tài xế giao món được hưởng 20.000đ, phí ship nền tảng giữ lại 5.000đ.

| Khoản | VND | Nguyên tắc |
|---|---:|---|
| COD thu từ khách | 150.000 | Cash custody của tài xế, không phải doanh thu tài xế |
| Phải trả Shop (gross ví dụ) | 125.000 | Có thể trừ phí Shop theo hợp đồng thực tế, không tự suy đoán |
| Thu nhập tài xế | 20.000 | Chỉ được ghi earned khi đủ điều kiện |
| Phí giao của nền tảng | 5.000 | Cần chính sách/tax thực tế |
| Tiền tài xế cần nộp | 130.000 | = 125.000 + 5.000; sau khi giữ thu nhập 20.000 |

Phương trình kiểm tra:

`150000 = 125000 + 20000 + 5000` và `130000 = 150000 - 20000`.

**Sổ cái chuẩn phải double-entry**, các tài khoản/cột ở trên chỉ là phép phân bổ minh họa để UI hiểu, không thay cho ledger kế toán. Thời điểm doanh thu được ghi nhận, khấu trừ phí, đối soát tiền mặt, payout, thuế và hoàn tiền cần được thiết kế theo chính sách DealGo thực tế.

### Guardrails

- Không gắn nhãn “đã thanh toán COD” khi order mới SUBMITTED/PREPARING.
- Không cộng COD đang giữ vào số dư ví có thể rút của tài xế.
- Không báo Shop “đã nhận tiền” khi payout chưa confirmed.
- Từ sự kiện nhận tiền hay giao thành công, mỗi `idempotencyKey` xử lý đúng một lần dù push/webhook đến lặp hoặc khác thứ tự.
- Nếu giao thất bại, không ghi COD collected mặc định; xử lý COD đã thu trước đó như một trường hợp đối soát hoàn tiền riêng, có chứng cứ.
- Số tiền dùng integer VND, không dùng `double` cho tiền; mọi bản ghi giữ `orderVersion`, `quoteVersion`, `currency`.
