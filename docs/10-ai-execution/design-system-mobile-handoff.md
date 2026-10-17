---
doc_id: DG-AI-011
title: "DealGo — Mobile design-system handoff (custom components)"
version: "1.0.0"
status: "ACTIVE"
owner: "UI Designer"
last_updated: "2026-10-14"
related:
  - screen-inventory.md
  - ui-mock-first-strategy.md
  - ../../mobile/lib/core/design_system/
---

# Mobile design-system handoff

> Spec for Flutter Expert. **Replace Material defaults** (`FilterChip`, `ChoiceChip`, raw `Chip`, default `NavigationBar` icons where mockups use brand assets) with DealGo primitives.  
> Tokens already in `mobile/lib/core/design_system/tokens/dealgo_tokens.dart`.  
> Visual authority: PNG under `design/mockups/screens/` + assets `design/assets/batch01|batch02`.  
> Do **not** invent fee/policy numbers from mockup copy.

## Current inventory (code)

| Component | Path | Gap vs mockups |
|---|---|---|
| `DealGoPrimaryButton` | `core/design_system/components/dealgo_primary_button.dart` | Exists: loading, disabled, trailing icon. Gap: compact / map-overlay size (D016 “Khu vực hoạt động”) |
| `DealGoSecondaryButton` | `…/dealgo_secondary_button.dart` | Exists. Gap: pill “Chuyển →” (S007) vs full-width secondary |
| `DealGoCard` | `…/dealgo_card.dart` | Exists. Gap: selected border (C004 vehicle), purple outline summary (C028 totals) |
| `DealGoIllustration` | `…/dealgo_illustration.dart` | Exists for empty/state art |
| Theme / colors | `tokens/dealgo_tokens.dart` | Primary `#6D28D9`, green `#16A34A`, warning/amber surfaces present |
| Motion | `core/motion/dealgo_motion.dart` + `dealgo_page_transitions.dart` + `dealgo_sheet.dart` | Fade-slide on key routes; most screens still default Material |
| Tab shell | `features/shell/presentation/role_shell.dart` | Custom-ish 5-tab; **Material Icons** only — mockups use brand/center FAB (C001) |
| Chips | scattered `AccountFilterChip`, Material `FilterChip`/`ChoiceChip`, ad-hoc containers | **No shared `DealGoChip` / segmented control** |

---

## 1. `DealGoChip` (status + meta chips) — REQUIRED

**Purpose:** Single status/meta label; never use color alone (always text).

**Reference frames**

| Tone | Example copy | Mockup |
|---|---|---|
| success / online | `Online`, `Đang xem`, `Bằng giá bạn đề xuất`, `Đang chế biến` | D016, S007, C007, M015 |
| selected / brand | `Đã chọn` | C004 |
| warning / pending | `COD · Chưa thu tiền`, `NEW · Chờ Shop xác nhận`, `PROCESSING` | C028, M015, C028__submitting |
| neutral | `Đề nghị khác`, `v1 · Dữ liệu đồng bộ` | C007, M015 |
| danger | rejected / blocked states | M011_REJECTED, D015_BLOCKED |
| promo | `Freeship 0đ` | C001 store cards |

**API (contract)**

```yaml
component: DealGoChip
variants:
  tone: [neutral, brand, success, warning, danger, promo]
  size: [sm, md]
properties:
  - label: String (required)
  - leading: Widget? (dot, icon — optional)
  - onTap: VoidCallback? (filter chips only)
states: [default, selected, disabled]
layout: height sm≈24 / md≈28; horizontal padding 8–12; radius pill (stadium)
accessibility:
  semantic_label: label
  selected: announce when used as filter
```

**Replace:** Material `Chip` / ad-hoc `Container`+`Text` status pills across ride/food/driver/merchant.

---

## 2. `DealGoSegmentedControl` — REQUIRED

**Purpose:** Exclusive filter / period / sort segments. **Do not use** Material `FilterChip` / `ChoiceChip` for this pattern.

**Reference frames**

| Usage | Mockup |
|---|---|
| Activity: Tất cả / Chuyến / Đơn / … | C043 (`AccountFilterChip` today) |
| Notifications filters | S008 / driver notifications |
| Earnings period | D035 (currently `FilterChip`) |
| KYB business type | M002 (currently `ChoiceChip`) |
| Sort pill “Giá thấp nhất ▼” | C007 (may be `DealGoChip` + menu; prefer segmented or menu button) |

**API**

```yaml
component: DealGoSegmentedControl
properties:
  - items: List<{id, label}>
  - value: String
  - onChanged: (String) -> void
  - scrollable: bool (default true for >3 items)
states: [idle, selected]
visual: track = card/border; selected = primary fill + white label (match AccountFilterChip selected)
touch: min 48h target
```

**Migrate:** `AccountFilterChip` → wrap or replace with this; delete Material filter usage in driver earnings/notifications/onboarding.

---

## 3. `DealGoTabBar` / bottom nav — REQUIRED polish

**Exists:** `RoleShell` + `ShellTab` paths for customer / merchant / driver.

**Gaps vs mockups**

| Role | Mockup tabs | Code today | Action |
|---|---|---|---|
| Customer C001 | Trang chủ · Chuyến đi · **Đặt** (center elevate) · Mua hàng · Tài khoản | Same labels; Material icons; center not elevated FAB | Elevate center “Đặt”; optional QR asset from batch02 |
| Driver D016 | Tổng quan · Công việc · Thu nhập · Thông báo · Tài khoản | Labels: Trang chủ / Công việc / … | Align label “Tổng quan” with D016 if product agrees; icons from assets if available |
| Merchant M013 | (shell) Tổng quan · Đơn hàng · Sản phẩm · Thống kê · Tài khoản | Matches | Tokenize active purple + label weight |

**Tokens**

- Active: `DealGoColors.primary` icon + label weight 600  
- Inactive: `textSecondary`  
- Bar surface: white + top hairline `border`  
- Center customer: circle `primary` ~56dp, white icon, slight elevation; do not use default `NavigationDestination` FAB styling only

**Icons:** Prefer `design/assets/batch01/svg/role_*.svg` / batch02 service PNGs where mock shows custom art; otherwise keep outlined Material **but** document as temporary. Do not mix stroke weights across tabs.

---

## 4. `DealGoPrimaryButton` / Secondary — gaps

**Keep** existing primary (full-width purple, trailing arrow common in C004/C007/C028/M015).

| Gap | Spec | Reference |
|---|---|---|
| Trailing arrow default CTA | Prefer `trailingIcon: Icons.arrow_forward` (or asset) on flow primaries | C004, C007, C028, M015 |
| Compact / overlay | `size: compact` minHeight 40, horizontal pad 12 — map overlays | D016 |
| Destructive secondary | Outline/danger text for cancel — not filled red primary | cancel flows C016/C035 |
| Secondary pill | Light purple fill (`subtlePurple`) + primary text “Chuyển →” | S007 |
| Loading lock | Already `isLoading`; checkout submitting should disable + optional full-screen state C028__submitting | C028 |

**Do not** use raw `FilledButton` / `ElevatedButton` outside design_system for product CTAs.

---

## 5. Cards & list rows — REQUIRED patterns

### 5.1 `DealGoCard` extensions

| Variant | Behavior | Reference |
|---|---|---|
| `plain` | white, radius 20, border `DealGoColors.border` | most screens |
| `selected` | `subtlePurple` fill + 1.5 primary border | C004 vehicle row |
| `emphasis` | light primary border (payment total) | C028 “Tổng thanh toán” |
| `pressable` | InkWell + 48dp semantics | store / offer / order rows |

### 5.2 List row recipes (feature widgets OK; share tokens)

| Row | Contents | Reference |
|---|---|---|
| Offer / driver | Avatar initial · name · rating · vehicle · ETA · price · `DealGoChip` · “Xem chi tiết →” | C007 |
| Order queue | Order id · status chip · key-value (khách, món, COD) | M015 |
| Job feed | Title · distance/earn · claim CTA | D018 |
| Service toggle | Icon tile · title · subtitle · Switch (green when on) | D016 |
| Route summary | Green pickup / red dropoff · dashed connector | C004, C007 |
| Store card | Photo · heart · title · rating · ETA · promo chip | C001 |

Empty / error art: reuse batch01 `state_no_orders`, `state_no_driver`, `state_offline`, `state_no_search`, `state_payment_error`, `state_success`, `state_kyc_*`.

---

## 6. Banners — empty / error / offline / info

**New shared:** `DealGoBanner` (or extend illustration+text pattern).

| Tone | BG / FG | Use | Reference |
|---|---|---|---|
| infoSuccess | `greenSurface` / green text | System notes, eligibility | C004 disclaimer, D016, M015, S007 |
| infoWarning | `amberSurface` / `warning` | Quote expiry, COD, idempotency | C007, C028__submitting, D030 |
| offline | `dangerSurface` or amber | Network lost | C011__tracking_offline, C028__checkout_offline |
| empty | illustration + title + optional CTA | No offers / empty queue / search | C007__offers_empty, M015__queue_empty, S015__search_empty |

**Rules:** Banner is not a toast replacement for fixable form errors. Keep copy honest (no fake “payment success” at place-order — C028 note).

---

## 7. Motion guidelines

Existing tokens (`DealGoMotion`):

| Token | Value | Use |
|---|---|---|
| `fast` | 150ms | press feedback, chip select |
| `medium` | 280ms | page fade-slide, sheet present |
| `slow` | 420ms | rare emphasis |
| `standard` | easeOutCubic | default |
| `emphasized` | easeInOutCubic | shared-element-ish |

### Page transition

- Continue `dealgoFadeSlidePage` on: role picker → customer shell, Ride/Food flow routes (already started).
- Apply same to: driver/merchant shell entry, KYC/KYB steps, account overlays.
- **Reduced motion:** instant swap / opacity-only (`DealGoMotion.prefersReducedMotion`).

### Sheet

- Use `showDealGoSheet` for: item options (C026), chat, voice, cancel reasons, offer detail if not full route.
- Snap: content-sized; keyboard insets respected; barrier dismissible unless submitting.

### Status morph (P0 later)

- Matching → assigned: crossfade status card (C010→C011) after **server** assignment.
- Checkout submitting: either full-screen state (C028__submitting) or button loading — not both competing.
- Never animate success before backend confirmation.

---

## 8. Color / type quick map (reuse tokens)

| Role | Token |
|---|---|
| Primary CTA / prices / active tab | `DealGoColors.primary` |
| Food / success / online | `brandGreen` + `greenSurface` |
| Pending / COD / NEW | `amber` / `warning` + surfaces |
| Danger | `danger` + `dangerSurface` |
| Body / secondary | `text` / `textSecondary` |
| Canvas | `canvas` |

Typography: follow `dealgo_theme.dart` text theme; titles bold; prices primary + w700.

---

## 9. Asset mapping (icons / heroes)

| Need | Prefer | Fallback |
|---|---|---|
| Home heroes / promo | `batch02/png/hero_*`, `promo_*` | placeholder |
| Ride / food / delivery tiles | `batch02/png/service_*`, `batch01/svg/card_*` | |
| Vehicles | `batch02/png/vehicle_scooter_*`, `batch01/svg/vehicle_*` | |
| Empty / KYC states | `batch01/svg/state_*` | `DealGoIllustration` |
| Role picker | `batch01/svg/role_*` | |

---

## 10. Implementation order (components)

1. `DealGoChip` + tones → replace status pills on C007, C028, M015, D016, S007  
2. `DealGoSegmentedControl` → replace FilterChip/ChoiceChip/AccountFilterChip call sites  
3. `DealGoBanner` info/warning/offline/empty  
4. `DealGoCard` selected/emphasis variants  
5. `DealGoTabBar` center elevate + icon pass  
6. Primary/Secondary size variants  
7. Motion: extend fade-slide + sheet to remaining P0 routes  

**Owner:** `flutter-expert`  
**Verification:** Golden frames C001, C004, C007, C028, D016, M015, S007 side-by-side; `flutter analyze`; widget tests for chip/segment semantics.

**NOT_VERIFIED:** device screenshots, WCAG contrast lab measurement, custom icon SVG rasterization in Flutter.
