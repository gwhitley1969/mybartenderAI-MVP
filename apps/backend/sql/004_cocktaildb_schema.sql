CREATE TABLE IF NOT EXISTS drinks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT,
  alcoholic TEXT,
  glass TEXT,
  instructions TEXT,
  thumbnail TEXT,
  raw JSONB,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS glasses (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS tags (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS ingredients (
  drink_id TEXT NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  name TEXT NOT NULL,
  PRIMARY KEY (drink_id, position)
);

CREATE TABLE IF NOT EXISTS measures (
  drink_id TEXT NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  measure TEXT,
  PRIMARY KEY (drink_id, position)
);

CREATE TABLE IF NOT EXISTS drink_categories (
  drink_id TEXT NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (drink_id, category_id)
);

CREATE TABLE IF NOT EXISTS drink_glasses (
  drink_id TEXT NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
  glass_id INTEGER NOT NULL REFERENCES glasses(id) ON DELETE CASCADE,
  PRIMARY KEY (drink_id, glass_id)
);

CREATE TABLE IF NOT EXISTS drink_tags (
  drink_id TEXT NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (drink_id, tag_id)
);

CREATE TABLE IF NOT EXISTS snapshot_metadata (
  id SERIAL PRIMARY KEY,
  schema_version TEXT NOT NULL,
  snapshot_version TEXT NOT NULL,
  blob_path TEXT NOT NULL,
  size_bytes BIGINT NOT NULL,
  sha256 TEXT NOT NULL,
  counts JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (schema_version, snapshot_version)
);

CREATE INDEX IF NOT EXISTS snapshot_metadata_created_idx ON snapshot_metadata (created_at DESC);
