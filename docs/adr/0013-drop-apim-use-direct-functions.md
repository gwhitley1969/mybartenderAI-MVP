# 0013 — Drop APIM for MVP; use direct Azure Functions (HTTP)

Status: **Accepted**  
Date: 2025-10-09

## Context
Early drafts referenced Azure API Management (APIM) for gateway features (rate limiting, JWT validation, logging). APIM is out of scope due to cost.

## Decision
- Do **not** use APIM in MVP.
- Expose APIs directly via **Azure Functions (HTTP triggers)** over HTTPS.
- Bind production custom domain **`https://api.mybartender.ai`** directly to the Function App with a managed certificate.
- Perform **JWT validation inside Functions** (Microsoft Entra External ID); use claims for authZ.
- Implement **per-user and per-IP rate limiting** in Functions (sliding window using PostgreSQL counters) and basic abuse controls (request size caps, UA checks).
- Keep **Application Insights** with strict redaction.

## Consequences
- Reduced fixed cost and simpler deployment.
- Slightly more custom code for limits/validation (acceptable for MVP).
- Future-ready: can add Front Door/APIM later without changing mobile contracts.

## Security & Privacy
- TLS enforced end-to-end.
- JWT required for protected endpoints; claims map to roles/permissions.
- Telemetry redacts `Authorization` and potential PII.

## Alternatives
- APIM (rejected for cost).
- Front Door + Functions (deferred).
