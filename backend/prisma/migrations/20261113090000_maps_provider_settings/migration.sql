-- Map provider per capability (Admin › Cài đặt › Bản đồ): mapbox | google. Default mapbox.
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES
  (gen_random_uuid(), 'MAPS_SEARCH_PROVIDER', 'mapbox', 'string', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'MAPS_REVERSE_PROVIDER', 'mapbox', 'string', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'MAPS_ROUTE_PROVIDER', 'mapbox', 'string', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
