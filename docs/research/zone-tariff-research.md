# Zone tariff research (t50u)

Status: `DRAFT` research. Collected 2026-10-29 (Asia/Saigon). **Reference only. None of these numbers are DealGo fares** and none are seeded into `ride_zone_tariffs` (DEC-PROD-069). Competitor prices change often, include VAT/platform fees differently and use a "first 2 km" opening fare, whereas DealGo uses per-km + minimum fare with customer bidding.

Labels:
- **VERIFIED** = read on the operator's own page or a national newspaper quoting the operator, on the date above.
- **UNVERIFIED** = aggregator / third-party blog, or not found. Check in the app before using.

## 1. Findings

| Operator | Area | Motorbike (2 km đầu / km tiếp) | 4-seat (2 km đầu / km tiếp) | 7-seat | Label | Source |
|---|---|---|---|---|---|---|
| Grab | Hà Nội | 13.255đ / 4.222đ (+344đ/phút) | 28.473đ / 9.818đ | not found | VERIFIED (bike, Grab page); car VERIFIED via VnExpress | [G1], [V1] |
| Grab | TP.HCM | 12.273đ / 4.222đ | 28.473đ / 9.818đ | 30.000đ / 11.000đ (marketing page, may be stale) | bike VERIFIED; car VERIFIED via VnExpress; 7-seat UNVERIFIED | [G1], [V1], [G2] |
| Grab | Đà Nẵng | 12.273đ / 4.222đ | not found | not found | bike VERIFIED | [G1] |
| Grab | Other provinces | 12.273đ / 4.222đ in many provinces; 12.027đ / 3.878đ in some smaller provinces (see [G1] for the list) | not found | not found | VERIFIED | [G1] |
| Be | HN / HCM | 14.472đ (HN), 13.817đ (HCM) / 4.633–4.918đ | 31.501–31.704đ / 10.568–11.805đ | not found | VERIFIED via VnExpress (May update; +10.5% platform fee) | [V1] |
| Be | ĐN, provinces | not found | not found | not found | UNVERIFIED | — |
| Xanh SM | Hà Nội | 13.200đ / 4.200đ | Taxi 30.500đ / 14.700đ | LuxuryCar (VF8) — price not found | UNVERIFIED (aggregator) | [A1], [A2] |
| Xanh SM | TP.HCM | 10.200đ / 4.150đ | 30.500đ / 15.200đ | not found | UNVERIFIED | [A1] |
| Xanh SM | Đà Nẵng | 12.000đ / 4.500đ | 30.500đ / 15.300đ (another blog: Xanh SM Car tiered, ≈17.000đ/km up to km 12) | not found | UNVERIFIED | [A1], [A2] |
| Xanh SM | Other provinces | e.g. Hải Phòng 15.200đ / 4.200đ; other provinces listed in [A1] | listed per province in [A1] | not found | UNVERIFIED | [A1] |
| inDrive | All | No published tariff: customer proposes the price, driver accepts or counters; app shows a "recommended fare" that the bid must be ≥ (per a retailer blog) | same | same | model VERIFIED (inDrive page); floor rule UNVERIFIED | [I1], [B1] |
| Gojek | — | Stopped operating in Vietnam on 16/9/2024. No current tariff. | — | — | VERIFIED | [N1], [N2] |

## 2. What this means for DealGo (no numbers adopted)

1. Every operator that publishes a tariff varies it by province, mostly the opening fare and per-km for cars; motorbike per-km is nearly flat nationally (≈3.9k–4.9k/km).
2. The car per-km spread between provinces is larger (≈9.8k–17k/km across the sources above), so per-zone overrides matter most for CAR_4/CAR_7.
3. Competitors also add time-based fees, surcharges (night, holiday, extra stop) and platform fees; DealGo's model is per-km + min fare + bid band only. Any extra component needs an owner decision.
4. DealGo global defaults stay `DRAFT` (MOTORBIKE 5.000đ/km min 10.000đ; CAR_4 9.000đ/km min 20.000đ; CAR_7 13.000đ/km min 25.000đ). Zone overrides start empty; ops/owner enter approved values in Admin › Cài đặt › Giá theo khu vực.

## 3. Open owner decisions

- Approve per-province per-km/min fares (or keep national defaults).
- Whether to model an opening fare for the first N km and/or a per-minute fee.
- Whether 7-seat pricing should derive from 4-seat (multiplier) or be entered separately.

## Sources (accessed 2026-10-29)

- [G1] Grab VN, "Bảng dịch vụ cập nhật Thuế suất VAT 8%": https://www.grab.com/vn/en/blog/driver/thongtindichvu/ (VAT 8% included)
- [G2] Grab VN, GrabCar page: https://www.grab.com/vn/transport/car/ (undated marketing copy)
- [V1] VnExpress, "Xe ôm công nghệ đồng loạt tăng giá": https://vnexpress.net/xe-om-cong-nghe-dong-loat-tang-gia-5070596.html (Be update 5/5, Grab platform fee from 28/4; year as published by VnExpress)
- [A1] Giá Nhanh aggregator: https://gianhanh.net/doi-song/xe-om-taxi ("updated 1 day ago" at access)
- [A2] xanhsm.net (unofficial blog, 2026-06-26): https://www.xanhsm.net/ (article on Xanh SM fares, 06/2026)
- [I1] inDrive VN: https://indrive.com/vi-vn/fair-services
- [B1] FPT Shop blog (fptshop.com.vn), article explaining inDrive
- [N1] VTV (vtv.vn), 2024-09-04: Gojek stops operating in Vietnam from 16/9/2024
- [N2] VnExpress (vnexpress.net), 2024-09-04: same announcement
