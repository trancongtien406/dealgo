# Parcel delivery (Giao hàng) — competitor research

Owner request t58u (2026-10-30). Sources read 2026-10-30 (Asia/Saigon) via public web pages; every figure below is quoted from
the linked page on that date. Anything not confirmed on a primary page is marked **UNVERIFIED**. No figure here is a DealGo
tariff; DealGo defaults are DRAFT (DEC-PROD-071).

## Sources

| # | Source | URL |
|---|--------|-----|
| S1 | Ahamove — bảng giá xe máy | https://ahamove.com/service/aha-delivery/price |
| S2 | Ahamove — giao hàng cồng kềnh | https://ahamove.com/giao-hang-cong-kenh |
| S3 | Ahamove — điều khoản & chính sách | https://ahamove.com/policy |
| S4 | Ahamove — giao hàng trong ngày (bảng phí đầy đủ, xe tải tiết kiệm) | https://ahamove.com/giao-hang-nhanh-trong-1-ngay |
| S5 | Grab VN help — kích thước/trọng lượng/hàng cấm GrabExpress | https://help.grab.com/passenger/vi-vn/360000169087 |
| S6 | Grab VN help — COD | https://help.grab.com/passenger/en-vn/360001932327 |
| S7 | GrabExpress Vietnam landing | https://www.grab.com/vn/express/ |
| S8 | GrabExpress merchant partner | https://www.grab.com/vn/express-merchant-partner/ |
| S9 | Grab driver help — ảnh xác thực giao hàng (GrabFood) | https://help.grab.com/driver/vi-vn/40001541 |
| S10 | Lalamove VN — loại xe | https://www.lalamove.com/vi-vn/ |
| S11 | Lalamove VN — bảng giá | https://www.lalamove.com/en-vn/all-vehicle-pricing-detail |
| S12 | Be — quy định hàng gửi beDelivery | https://be.com.vn/uncategorized/quy-dinh-ve-hang-gui-dich-vu-giao-hang-bedelivery-va-be-di-cho/ |
| S13 | Be — beDelivery landing | https://be.com.vn/dich-vu-giao-hang-nhanh |
| S14 | FPT article on beDelivery fees (secondary) | https://fpt.vn/tin-tuc/bedelivery-la-gi-huong-dan-giao-hang-va-cuoc-phi-moi-nhat-14562.html |
| S15 | Xanh SM bike — sổ tay Xanh Express (secondary/driver community) | https://xanhsmbike.com/so-tay-van-hanh-dich-vu-giao-hang-xanh-express/ |
| S16 | Xanh SM — Xanh Express 2H | https://www.xanhsm.com/news/huong-dan-van-doanh-xanh-express-2h |
| S17 | Green SM — Shopee 2H vận hành | https://www.greensm.com/vn-vi/news/xanh-express-huong-dan-van-hanh-dich-vu-giao-hang-shopee-2h |

## 1. Booking flow

- GrabExpress: choose pickup (sender) and drop-off (recipient) address → fare shown immediately → book → wait for driver; fare
  computed by distance and time (S7). Add-ons (e.g. COD) chosen in an "Add-ons" section (S6).
- Ahamove / Be / Xanh: same A→B flow with a service tier (Siêu tốc / 2H / 4H) chosen before booking (S1, S13, S16).
- Common minimum: pickup, drop-off, recipient name + phone, package type/size, notes, payment, optional COD (S6, S13). Exact
  form fields per app: **UNVERIFIED** (not on public pages read).

## 2. Size / weight classes (motorbike)

| Provider | Standard bike | Small/saver tier | Large bike |
|---|---|---|---|
| Ahamove | 50×40×50 cm, ≤30 kg (S3) | 4H/tiết kiệm 25×32×12 cm ≤5 kg (S4) | bulky to 90×70×90 cm / 80 kg with surcharge (S2) |
| GrabExpress | 50×40×50 cm, 30 kg (S5) | Tiết kiệm 20×25×20 cm, 5 kg (S5) | Ưu tiên cỡ lớn 60×70×60 cm, 50 kg (S5) |
| beDelivery | <40×40×40 cm, <30 kg, ≤0.05 m³ (S12) | 4H 25×25×12 cm, 5 kg (Be news) | — |
| Xanh Express | ≤50×40×50 cm, <30 kg (S15, secondary) | 2H 20×25×20 cm, 5 kg (S16) | — |

Consensus: a ~5 kg "small" tier, a ~30 kg / 50×40×50 cm standard bike tier, and a bulky bike tier with a surcharge.

## 3. Vehicle types

- Bike for parcels ≤30 kg (all). Ba gác (≤400 kg) and van/truck 500 kg–1000 kg at Grab (S5); Lalamove van 500 kg
  (170×120×120 cm), van 1 t, trucks to 8 t+ (S10). Ahamove truck tiers 100/200/300 kg (S4).
- Car (4/7-seat) as a parcel vehicle: not a published tier at any provider read → **UNVERIFIED** for VN market. DealGo has
  MOTORBIKE / CAR_4 / CAR_7 only; vans/trucks are out of scope until a vehicle class exists.

## 4. Pricing model

- Distance-based, first-N-km block then per km: Ahamove Siêu tốc 15.709đ/2 km đầu, +5.400đ/km (S1); Xanh Express
  14.000đ/2 km, +5.000đ/km (S15, secondary); beDelivery 15.351đ/2 km, +5.015đ/km (S14, secondary); Lalamove van 500 kg
  111.780đ/5 km then tiered per-km (S11).
- Surcharges seen: bulky 10.000–30.000đ/lượt (S1); fragile 10.000đ (S1); extra stop 5.400đ (S1) / 5.000đ (S14); return to
  sender 80% of the outbound fee (S1, S4); waiting 60.000đ/h (S4); Lalamove waiting after 15 min free (S10 snippet,
  exact rate **UNVERIFIED**); night 22h–6h 10.000đ (S14, S15).
- COD fee: Grab 5.000đ/đơn, cap 2.000.000đ standard (S6); Ahamove free under 500k, 0.6–0.88% above (S4), cap 10.000.000đ
  Siêu tốc (S1); Be cap 3.000.000đ (S13); Xanh 2H cap 1.000.000đ/điểm (S16).
- Bid/offer pricing for parcels (inDrive Courier): not researched on a primary page → **UNVERIFIED**.

## 5. Proof of pickup / delivery

- Grab: delivery photo is mandatory for cashless orders and optional for cash (documented for GrabFood) (S9); GrabExpress
  explicit photo rule **UNVERIFIED**.
- Xanh (Shopee 2H): pickup photo mandatory showing parcel condition (S17).
- Recipient OTP/signature: not found on the pages read → **UNVERIFIED**.

## 6. Multi-stop

Ahamove up to 10 stops/order (S3, S4); beDelivery multi-stop with per-stop fee (S14); Xanh 2H multi pick/drop (S16).

## 7. Scheduling

Ahamove 4H and "khung hẹn lấy" pickup windows (S1); Be 4H service hours (Be news). Scheduled pickup at an exact time:
**UNVERIFIED**.

## 8. Insurance / declared value

Grab compensation up to 5.000.000đ (Siêu tốc), up to 30.000.000đ for Premium (S8). Ahamove/Be details **UNVERIFIED**.

## 9. Prohibited items

Grab list (S5): undeclared-value goods, drugs, precious metals, dangerous goods, weapons, tobacco, perishables (except
flowers/food), illegal publications, flammables, live animals, fur, banned imports, cash/valuable papers, antiques, mail.

## 10. Failed delivery / return

GrabExpress: driver calls recipient 3 times within 15 minutes; if no answer, notifies the sender to arrange a return (S7).
Ahamove: "quay lại điểm lấy hàng" charged 80% of the outbound fee (S1). Xanh: driver may cancel oversize orders with a photo
(S15). Bike law: Luật TTATGT đường bộ 34/2024/QH15 Điều 33 limits load width/length on the rack (quoted on S2; primary law
text not opened → **UNVERIFIED** wording).

## Takeaways applied in DealGo (DEC-PROD-071 DRAFT)

1. One "Giao hàng" entry, A→B map first, size class chips, fare shown before booking.
2. Size classes S (≤5 kg), M (≤30 kg, 50×40×50), L (≤50 kg, 60×70×60, bike bulky surcharge), XL (car only); surcharges
   admin-editable, defaults within the researched 10–30k range.
3. Pickup photo + delivery photo mandatory; optional 4-digit recipient code behind a setting (off by default like rides).
4. Failed delivery → return to sender; return fee OPEN (owner decides; competitors charge 80%).
5. Goods COD (driver advances money) OPEN — needs a settlement design; not built.
6. Van/truck, multi-stop parcels, scheduling, insurance: OPEN / later.
