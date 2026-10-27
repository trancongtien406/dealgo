# One app or separate apps? (Guidelines 4.2 / 4.3)

**Recommendation for v1: ship ONE app (customer + driver + merchant roles), and plan to split out "DealGo Tài xế" / "DealGo Cửa hàng" once the partner base grows.**

Why (rule text VERIFIED; risk judgement ASSUMED):
- 4.3 (Spam) targets many near-identical apps. Three apps built from one codebase that differ only by a role switch would be at risk. Uber/Uber Driver and Grab/Grab Driver are accepted because each app's functionality is clearly different. With the shared shell and theme today, splitting now needs real per-app scope work.
- 4.2 (Minimum functionality): a single app with the full customer experience clearly passes. A stand-alone merchant or driver app is also fine, but each needs its own review demo account and KYC path.
- One app means one review queue, one privacy label, and one set of screenshots.
- Costs of one app: the customer listing shows driver and merchant screenshots (keep those last, as screens 6 and 7), and partner KYC permissions (camera, ID) appear in the customer app's privacy label.
- When to split: when partner features need different permissions or background modes (for example, driver background location), or separate release cadence or ratings. Use distinct bundle IDs, names and icons, and real functional differences, to stay clear of 4.3.
