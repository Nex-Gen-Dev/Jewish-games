-- Cloudflare D1 schema for the Shtick Games backend.
CREATE TABLE IF NOT EXISTS users (
  user_id TEXT PRIMARY KEY, name TEXT NOT NULL, username TEXT NOT NULL UNIQUE,
  email TEXT, phone TEXT, token_hash TEXT NOT NULL, platform TEXT, model TEXT,
  created_at INTEGER NOT NULL, last_seen INTEGER, disabled INTEGER NOT NULL DEFAULT 0,
  progress TEXT, points INTEGER DEFAULT 0, last_level TEXT, last_played INTEGER,
  terms_version INTEGER, terms_at INTEGER, app_version TEXT, content_version INTEGER
);
CREATE TABLE IF NOT EXISTS user_profile (user_id TEXT PRIMARY KEY REFERENCES users(user_id), patch TEXT NOT NULL DEFAULT '{}', updated INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS broadcast (id INTEGER PRIMARY KEY CHECK (id = 1), patch TEXT NOT NULL DEFAULT '{}');
INSERT OR IGNORE INTO broadcast (id, patch) VALUES (1, '{}');
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, kind TEXT, message TEXT, logs TEXT, level TEXT,
  device TEXT, app_version TEXT, content_version INTEGER, created_at INTEGER, resolved INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, title TEXT, body TEXT, created_at INTEGER);
CREATE TABLE IF NOT EXISTS legal (id INTEGER PRIMARY KEY CHECK (id = 1), version INTEGER, terms TEXT, privacy TEXT, updated INTEGER);
