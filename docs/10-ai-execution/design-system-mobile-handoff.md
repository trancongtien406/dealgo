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

## 3. `DealGoTabBar` / bottom nav

**Code:** `core/design_system/components/dealgo_tab_bar.dart` (widget + `DealGoNotchedBarPainter`), metrics in `dealgo_nav_insets.dart`. `RoleShell` renders it for every role; `CustomerTabBar` is a thin wrapper that binds it to the customer `StatefulNavigationShell`.

| Role | Tabs (labels from l10n) | Notes |
|---|---|---|
| Customer | Trang · Chuyến · Đặt · Mua · Tôi | Bar hidden on the full-screen “Đặt” tab |
| Driver | Tổng quan · Việc nhận · Thu nhập · Thông báo · Tôi | Badge supported per destination |
| Merchant | Tổng quan · Đơn hàng · Thực đơn · Thống kê · Tôi | |

**Shape**

- Floating pill: inset `kDealGoNavSideMargin` (12) from the screen sides, height `kDealGoNavBarHeight` (58), radius `DealGoRadius.card`, fill `card`, 1 px `border` stroke, soft purple drop shadow.
- Active tab: 48 dp circle (gradient `primaryLight → primary`, white selected icon) raised `kDealGoNavOverhang` (20) above the pill top, sitting in a concave notch (`CircularNotchedRectangle` intersected with the rounded pill, 5 dp gap).
- Every tab shows icon + 11 sp label inside the pill; inactive = outline icon + `textSecondary` w500, active label = `primary` w700. The active outline icon fades out under the circle.
- Badge: `DealGoTabDestination.badgeCount` (> 99 → “99+”), `danger` fill.

**Behaviour**

- Notch + circle slide to the selected tab with `DealGoMotion.medium` (280 ms) / `DealGoMotion.standard` (easeOutCubic); reduced motion jumps without animating.
- Selecting a different tab fires `DealGoHaptics.selection()`.
- Semantics per tab: button, selected state, label (badge as value); each tab is a full-height column ≥ 44 pt wide.
- Label text scale is clamped to `kTabBarMaxTextScale` (1.15) by `RoleShell`.

**Insets / content clearance**

- `DealGoNavBarMetrics` = overhang + bar + bottom gap. Bottom gap: iOS `max(inset − 10, 8)` (pill sits in the home-indicator zone), Android `inset + 6` (above gesture/3-button nav), no inset → 10.
- `RoleShell` uses `extendBody: true` (the raised circle overlaps content) and wraps the branch in `FloatingNavBody`: the body ends at the pill top (`contentClearance`) and pages receive zero bottom padding. With the keyboard open no clearance is added.

**Tests:** `test/dealgo_tab_bar_test.dart` (selection, notch position, reduced motion, semantics, badge, labels, body clearance), `test/bottom_nav_insets_test.dart` (metrics per platform/inset), `test/large_text_chrome_test.dart` (five tabs at accessibility XL). PNG previews: `flutter test test/nav_bar_preview_test.dart --dart-define=NAV_PREVIEW_DIR=<dir>`.

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
5. `DealGoTabBar` floating notched bar (implemented, see §3)  
6. Primary/Secondary size variants  
7. Motion: extend fade-slide + sheet to remaining P0 routes  

**Owner:** `flutter-expert`  
**Verification:** Golden frames C001, C004, C007, C028, D016, M015, S007 side-by-side; `flutter analyze`; widget tests for chip/segment semantics.

**NOT_VERIFIED:** device screenshots, WCAG contrast lab measurement, custom icon SVG rasterization in Flutter.

## 11. Launch screen (cold start)

Rule: `DEC-PROD-066`. One brand screen from tap to first page; never a white frame or a second splash.

| Piece | Where | Value |
|---|---|---|
| Background | iOS `Assets.xcassets/LaunchBackground.colorset` (light/dark), Android `values/colors.xml` + `values-night/colors.xml` `splash_background`, Dart `dealGoLaunchBackground()` | `#6D28D9` (`DealGoColors.primary`), dark `#4C1D95` (`primaryDeep`) |
| Mark | iOS `LaunchImage.imageset`, Android `drawable-*dpi/launch_mark.png`, Dart `assets/images/launch_mark.png` | `design/brand/v3/app-icon.svg` without its tile, on a 288-unit canvas (Android 12 icon spec: mark inside the 192 dp circle). Same canvas everywhere so native and Flutter line up. |
| Android 12+ | `values-v31` and `values-night-v31` `styles.xml` | `windowSplashScreenBackground`, `windowSplashScreenAnimatedIcon`. The night folder is required: `night` outranks API level in resource lookup. |
| Pre-Android 12 | `drawable/launch_background.xml` (+ `drawable-v21`) | Layer list: colour + centred bitmap. `NormalTheme` window background is the app canvas `#FBFAFD`, not white. |
| Hand-off | `lib/core/launch/launch_splash.dart`, `main.dart`, `DealGoApp._maybeReleaseLaunch` | `deferFirstFrame()` before `runApp`; `allowFirstFrame()` once `launchRouteReady` (auth restored, post-auth flags loaded, router left `/splash`) or after 3 s. |
| `/splash` route | `splash_page.dart` | Pixel twin of the native screen; routes as soon as the session restore finishes (cap 6 s). Kept because deep links park on `/splash` and the login page reuses it while a session restores. |

Do: keep work before `runApp` to what the first page needs (prefs warm-up, Firebase init); FCM handler setup runs after.
Don't: add a minimum splash duration, a spinner, or a light Scaffold behind the launch route.
Regenerate the PNGs from the SVG (Chromium render, transparent background) if the mark changes.

