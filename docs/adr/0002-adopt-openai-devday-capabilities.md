# 0002 — Adopt GPT-4.1 family + Prompt Caching (DevDay)
Status: Proposed
Date: 2025-10-08

## Context
We want better cost and reliability for production. OpenAI’s DevDay introduced GPT-4.1 models and platform features
that improve instruction following and enable prompt caching for repeated system/tool prompts.

## Decision
1) Use `gpt-4.1-mini` as default for recommendation reasoning; `gpt-4.1` for long-context tasks.
2) Implement Prompt Caching for stable system/tool prompts and schema-driven tool definitions.
3) Defer Realtime API to a later feature slice; document integration seam only.

## Consequences
- Lower per-request cost and steadier latencies on repeated prompts.
- Requires strict versioning of prompt templates and schemas to maximize cache hits.
- No change to mobile app security posture (all keys remain server-side).

## Data model & storage plan (notes)
- No new entities persisted. Cache-key details are not PII and are logged only as a hash.
- App Insights: capture `cacheKeyHash`, `cacheHit:boolean`, `model`, `traceId`.

## Security & privacy
- No PII in prompts or cache keys; redact all user inputs from logs.
- Secrets via Key Vault; never logged; use managed identity for Functions.

## Implementation tasks
- Backend: implement cache-key derivation; add `X-Cache-Hit` response header; quota enforcement before model calls.
- Mobile: propagate `X-Client-Request-Id`; no SDK/model calls from device.
