# Round 4 UX research (t40u) — sources & decisions

Labels: **VERIFIED** = read on the cited public page this round; **ASSUMED** = common pattern / inference, not confirmed from an official source.

| Topic | Finding | Label | Source | DealGo decision |
|---|---|---|---|---|
| Driver accept (bidding model) | inDrive drivers tap "accept" for the passenger's price or use bidding to counter-offer; declining has no penalty. | VERIFIED | https://blog.indrive.com/en-na/article/drivers-101-how-to-use-our-app ; https://indrive.com/en-in/help/passengers/how-fares-are-calculated ; https://indrive.com/driver | Ride detail footer: primary **"Nhận giá {X}"** (one tap → offer at customer's price), secondary **"Chào giá khác"**; skip = back. Test `driver_flow_test.dart: one-tap accept…` |
| Driver accept countdown | Grab/Be show a timed job card for auto-dispatch. | ASSUMED (no official doc found this round) | — | Not added: DealGo uses bidding (customer chooses), offers expire server-side. |
| Reorder | GrabFood has "Re-Order" on past orders. Lunchbox (a restaurant-ordering platform) restricts Quick Reorder to completed orders, not ongoing or cancelled ones. | VERIFIED (Grab feature exists); Lunchbox rule VERIFIED for Lunchbox only | https://en.gizmologi.id/News/grabfood-don%27t-forget-to-eat-new-features/ ; https://support.lunchbox.io/en/articles/12986159-quick-reorder-lb-2-0 | Reorder only on **DELIVERED**, behind a confirm dialog; the cart re-prices at current prices. Test `food_reorder_confirm_test.dart` |
| Checkout recipient | Delivery apps show the recipient's name + phone on the address card. | ASSUMED | — | "Tên · SĐT". Test `checkout_recipient_name_test.dart` |
| Merchant "to handle" list | Closed orders belong in history, not the active queue. | ASSUMED | — | CANCELLED/DELIVERED/FAILED filtered. Test `merchant_queue_cancelled_hidden_test.dart` |
| Driver online status | The server is the source of truth (status re-syncs on open). | ASSUMED | — | `DriverDutyCubit.syncFromServer` runs on open, socket reconnect and resume. Test `driver_duty_server_sync_test.dart` |
| Order code | One short code everywhere. | ASSUMED | — | The last 4 characters everywhere (`shortRef` == `handoverRef`). |
| Mapbox VN labels | Mapbox's data contains "Jalan …" street prefixes. Fixed by proximity bias and `country=vn`. | VERIFIED (observed in our DEV responses) | Mapbox Geocoding API docs: https://docs.mapbox.com/api/search/geocoding/ | `cleanMapboxVnLabel`, proximity = device location or `ip`. |
