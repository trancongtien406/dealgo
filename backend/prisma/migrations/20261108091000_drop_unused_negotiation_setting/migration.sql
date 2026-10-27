-- RIDE_NEGOTIATION_MAX_ROUNDS is no longer in the settings catalog; its value was copied to
-- RIDE_MAX_LIVE_OFFERS_PER_RIDE by an earlier migration. Remove the orphan row.
DELETE FROM "platform_settings" WHERE "key" = 'RIDE_NEGOTIATION_MAX_ROUNDS';
