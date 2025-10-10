CREATE TABLE IF NOT EXISTS token_quotas (
  sub TEXT NOT NULL,
  month TEXT NOT NULL,
  tokens_used BIGINT NOT NULL DEFAULT 0,
  monthly_cap BIGINT NOT NULL,
  window_start TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (sub, month)
);
