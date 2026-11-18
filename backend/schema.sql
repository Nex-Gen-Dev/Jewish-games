-- Cloudflare D1 schema for the Private Games backend.
CREATE TABLE IF NOT EXISTS users (
  user_id      TEXT PRIMARY KEY,           -- e.g. PG-4V36W7CR (made by the app)
  name         TEXT NOT NULL,
  username     TEXT NOT NULL UNIQUE,
  email        TEXT,
  phone        TEXT,
  token_hash   TEXT NOT NULL,              -- sha256 of the user's secret token
  platform     TEXT,
  model        TEXT,
  created_at   INTEGER NOT NULL,
  last_seen    INTEGER,
  disabled     INTEGER NOT NULL DEFAULT 0
);
-- Private content for one user: JSON patch merged into their profile
-- (theme, entitlements, message, inventory, character ...).
CREATE TABLE IF NOT EXISTS user_profile (
  user_id TEXT PRIMARY KEY REFERENCES users(user_id),
  patch   TEXT NOT NULL DEFAULT '{}',
  updated INTEGER NOT NULL
);
-- Content sent to everyone.
CREATE TABLE IF NOT EXISTS broadcast (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  patch TEXT NOT NULL DEFAULT '{}'
);
INSERT OR IGNORE INTO broadcast (id, patch) VALUES (1, '{}');
