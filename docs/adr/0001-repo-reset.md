
## `/docs/adr/0001-repo-reset.md`
```md
# 0001 — Greenfield Repo with Contracts-First Source of Truth
Status: Proposed

## Context
The prior repo accumulated UI placeholders and shifting AI/vision assumptions; AI endpoints and scanner flows were not contract-defined, leading to agent thrash.

## Decision
Create a new repo with `/spec` as the single source of truth; all code generation and implementation must follow OpenAPI and schemas.

## Consequences
- Faster iteration; fewer reverts
- Requires discipline: every feature begins with an OpenAPI change set
