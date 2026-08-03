-- Track last RevenueCat event applied for a user (idempotency / debugging).
ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS rc_event_id text,
  ADD COLUMN IF NOT EXISTS rc_product_id text;
