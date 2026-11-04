# Store listing — English (en-US)

> Secondary listing language. Limits: title **30**, short description **80**, full description **4000**, "What's new" **500** characters.

## 1. App name

```
DealGo
```

## 2. Short description (74 characters)

```
Ride-hailing and food delivery in Vietnam — upfront prices, live tracking.
```

## 3. Full description (1,555 characters)

```
DealGo is a ride-hailing and food-delivery app for Vietnam, with customer, driver and merchant experiences in one app.

RIDES
• Choose a motorbike or car and see an upfront fare estimate before booking.
• Pin pickup and drop-off on the map and follow your driver live.
• Pay in cash or with a supported online payment method.
• Trip history, receipts and in-app support.

FOOD DELIVERY
• Find nearby restaurants and see menus, prices and delivery times.
• Add items, choose options, apply offers and track the order from acceptance to delivery.
• Rate the restaurant and driver after each order.

FOR DRIVERS
• Receive ride and food-delivery jobs in your area.
• See earnings, platform fees and your prepaid fee balance.
• Drivers may prepay platform fees, which are then applied against future fees. The balance can only offset fees owed to DealGo; it cannot be transferred to another person, withdrawn as cash, or used to buy goods.

FOR MERCHANTS
• Manage menus, accept and process orders, create offers and read customer reviews.

SAFETY AND TRANSPARENCY
• Accounts are verified and partner applications are reviewed.
• Location permission is used only while you use the app to book a ride or order food.
• Privacy Policy and Terms of Service are published on our website.
• You can request account deletion inside the app.

DealGo does not provide an e-wallet, loans, credit, money transfer or crypto services. Prices and payment methods shown in the app are those confirmed at booking time; cancellation and refund rules are in the Terms of Service.
```

> **Condition:** only keep the "Drivers may prepay" sentence if the submitted build has `DRIVER_TOP_UP_ENABLED=true` and a configured PSP. If the feature is off, remove it (and consider hiding the top-up card) so the listing matches the build; update both when enabling.

## 4. Category and tags

| Field | Value | Note |
|---|---|---|
| App category | **Maps & Navigation** | **ASSUMED** — do not use Finance |
| Tags | `ride-hailing`, `food delivery`, `transport`, `local services` | Use Play suggestions where available |
| App type | Application (not a game) | — |
| Free / paid | Free | No digital IAP |

## 5. Contact details

| Field | Value |
|---|---|
| Email | `support@dealgo.laptrinhapp.com` — **ASSUMED**, verify mailbox |
| Website | `https://dealgo.laptrinhapp.com` — **VERIFIED** (domain chosen 2026-11-04; point DNS + SSL before Submit) |
| Phone | `+84…` — real support number |
| Privacy Policy | `https://dealgo.laptrinhapp.com/privacy` |

## 6. What's new (248 characters)

```
First release on Google Play.
• Motorbike and car rides with live driver tracking.
• Food ordering, offers and live order tracking.
• Driver earnings and prepaid platform fees.
• Merchant menu, order and offer management.
• In-app account deletion.
```

## 7. Do not use

- "DealGo Wallet", "e-wallet", "top up / withdraw wallet" for customers.
- "Interest", "loan", "buy now pay later", "credit line".
- "100% secure", "cheapest", "fastest" — unverifiable.
- Invented user or partner numbers.
- Features not present in the uploaded build (customer wallet, intercity delivery, etc.).
