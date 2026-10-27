# App Privacy (App Store Connect "nutrition label")

Source: mobile code (`pubspec.yaml`, `lib/features/*`, `lib/l10n`), Info.plist and backend endpoints. **Tracking: NO** (VERIFIED: no ad or analytics SDK; dependencies are firebase_core and firebase_messaging for push only, plus no IDFA or ATT prompt).
All types below are **linked to the user** and are **not used for tracking**.

| Category → Type | Collected? | Purpose | Evidence |
|---|---|---|---|
| Contact Info → Name | Yes | App Functionality | profile, edit_profile_page (VERIFIED) |
| Contact Info → Phone Number | Yes | App Functionality, account login via OTP | phone_login/otp pages (VERIFIED) |
| Contact Info → Email Address | Yes (optional) | App Functionality, login and password reset | email_login/forgot_password (VERIFIED) |
| Contact Info → Physical Address | Yes | App Functionality (pickup/drop-off, delivery, store address) | address_book, places (VERIFIED) |
| Location → Precise Location | Yes | App Functionality (booking, live tracking, driver presence) | geolocator, live_location, presence (VERIFIED) |
| User Content → Photos | Yes (partners) | App Functionality (KYC/KYB documents, store/menu images) | image_picker, onboarding KYC (VERIFIED) |
| User Content → Other User Content | Yes | App Functionality (chat messages, ratings/comments, support tickets) | chat, rating, support (VERIFIED) |
| User Content → Customer Support | Yes | App Functionality | features/support (VERIFIED) |
| User Content → Audio | **No**: in-app calls stream microphone audio live between the two parties through the LiveKit media server and nothing is recorded or stored, so under Apple's definition (data processed only in real time) it is not "collected". The server keeps call metadata only: who called whom, for which trip/order, and when (`VoiceCall` table) | VERIFIED code (`features/voice`, `integrations/voice`); keep this answer only while calls are not recorded |
| Financial Info → Other Financial Info | Yes (drivers/merchants: payout bank account) | App Functionality | `partnerBankAccount` (VERIFIED) |
| Purchases → Purchase History | Yes | App Functionality (ride/order history, receipts) | activity, driver_history (VERIFIED) |
| Identifiers → User ID | Yes | App Functionality | account id (VERIFIED) |
| Identifiers → Device ID | Declare **Yes** to be conservative (push token / session device list) | App Functionality | firebase_messaging, sessions_page (VERIFIED code; category choice ASSUMED) |
| Other Data → Government ID (CCCD number + photos) | Yes (partners) | App Functionality (identity verification) | `kycIdNumber` (VERIFIED) |
| Usage Data / Diagnostics / Health / Browsing / Search history / Contacts / Sensitive info | No | — | VERIFIED: no SDK collects these. Search queries are sent only to resolve places and are not stored per user (ASSUMED; confirm in the backend) |

The Privacy Policy at `/privacy` must list the same items, including retention and the deletion flow (ASSUMED: the policy text has not been checked against this table).
