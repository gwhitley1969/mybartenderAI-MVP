# 0002 — Adopt GPT-4.1 family + Prompt Caching (DevDay)
Status: Proposed

## Context
OpenAI’s DevDay introduced GPT-4.1 models and platform features that reduce cost and improve reliability for production apps.

## Decision
1) Use `gpt-4.1-mini` as default for recommendation reasoning; `gpt-4.1` for long-context tasks.
2) Implement Prompt Caching for stable system/tool prompts and schema-driven tool definitions.
3) Defer Realtime API to a later feature slice; document integration seam only.

## Consequences
- Lower per-request cost and steadier latencies on repeated prompts.
- Requires strict versioning of prompt templates and schemas to maximize cache hits.
- No change to mobile app security posture (all keys remain server-side).
