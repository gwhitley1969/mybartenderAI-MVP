# MyBartenderAI — MVP (Flutter + Azure + Riverpod + OpenAPI)

This repo is **contracts-first**. Implementers (Cursor/Codex) must code **only** from `/spec` and `/docs`.

## Stack
- Mobile: Flutter, Riverpod, GoRouter, dio, Freezed/json_serializable
- Backend: Azure Functions (HTTP), Azure Blob (images), Azure Database for PostgreSQL, Azure Key Vault
- Identity: Microsoft Entra External ID (claims for authZ)
- Contracts: `/spec/openapi.yaml` + `/spec/schemas/*` are the single source of truth

## How to work in this repo
1. Start with `/spec/openapi.yaml`. Update contracts before any feature code.
2. Follow `/docs/ARCHITECTURE.md` and `/docs/cursor-rules.mdc` exactly.
3. All PRs must include: OpenAPI diff + ADR update + PLAN test notes.

## MVP scope (short)
- Local SQLite cache for CocktailDB subset
- “Scan your bar” → recommend cocktails (sync path first)
- Tiering: Free (DB only) vs Premium (AI features with token cap)

See `/docs/PLAN.md` for acceptance criteria.

