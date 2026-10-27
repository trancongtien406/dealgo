# Age rating

App Store Connect questionnaire (2025+ format). Answers derived from features in code:

| Item | Answer | Basis |
|---|---|---|
| Violence / sexual content / profanity / horror / drugs / gambling / contests | None | VERIFIED — no such content in app |
| Medical / wellness | None | VERIFIED |
| Unrestricted web access | No | VERIFIED — no in-app browser; links open externally via `url_launcher` |
| User-generated content | No public UGC; ratings shown to partners | VERIFIED |
| Messaging & chat | **Yes** — chat customer↔driver/merchant during an active trip/order (`features/chat`), and in-app voice calls between the customer and the assigned driver during an active trip/order (`features/voice`, LiveKit; audio only, not recorded). | VERIFIED |
| Advertising | No | VERIFIED — no ad SDK |
| Age assurance / parental controls | No | VERIFIED |

Expected result: **13+** because of chat with strangers (drivers). The exact tier depends on how App Store Connect weighs messaging, so this is ASSUMED. Verify the result shown in ASC.
Also: the Terms should require 18+ for drivers and merchants (ASSUMED — check the `/terms` text).
