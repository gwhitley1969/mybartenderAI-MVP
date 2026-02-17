# Phase 2: Backend — Data Model, Enforcement & Voice Minutes

You are Claude Code acting as a senior engineer on "My AI Bartender".

## Context

We are replacing the old Free / Premium / Pro tier model with a single paid entitlement. This phase covers all backend changes: data model, migration, quota enforcement, voice minutes tracking, and webhook handling.

## Decisions (these are final — do not change them)

| Decision                             | Value                                                       |
| ------------------------------------ | ----------------------------------------------------------- |
| Entitlement value                    | `paid` (not `pro`, not `premium`)                           |
| Inactive value                       | `none`                                                      |
| Subscription states                  | `trialing`, `active`, `expired`, `none`                     |
| Consume order for voice              | Included minutes first, then purchased balance              |
| Included voice minutes per cycle     | 60 minutes per 30-day billing cycle                         |
| Voice add-on pack                    | +60 minutes for $4.99 (consumable, can buy multiple times)  |
| Non-subscribers can buy voice packs? | No — entitlement must be `paid` to purchase                 |
| Metering basis                       | Actual talk time (user + AI audio), not connected/idle time |
| User-facing label                    | "Subscriber" (not "Premium Access" or "Pro")                |

## Backward compatibility mapping (mandatory)

When migrating or evaluating existing users:

- `pro` → `paid` (entitled)
- `premium` → `paid` (entitled — do not lock these users out)
- `free` / `null` / missing → `none` (not entitled)

## Task A: Data model changes

Update the database schema to support:

### Subscription fields (on user or subscription table — use whichever exists today)

```
entitlement: text NOT NULL DEFAULT 'none'        -- 'paid' or 'none'
subscription_status: text NOT NULL DEFAULT 'none' -- 'trialing', 'active', 'expired', 'none'
billing_interval: text                            -- 'monthly', 'annual', null
```

### Voice minutes tracking (new table or columns — your call based on existing schema)

```
monthly_voice_minutes_included: integer DEFAULT 60
voice_minutes_used_this_cycle: numeric(8,2) DEFAULT 0
voice_minutes_purchased_balance: numeric(8,2) DEFAULT 0
voice_cycle_started_at: timestamptz              -- set on subscription start/renewal
```

### Consumable purchase ledger (new table for idempotency)

```
voice_purchase_transactions:
  id: serial primary key
  user_id: references users
  transaction_id: text UNIQUE NOT NULL           -- RevenueCat event ID or store transaction ID
  minutes_credited: numeric(8,2) NOT NULL
  credited_at: timestamptz DEFAULT now()
```

Write the migration as idempotent SQL (safe to re-run). Use safe defaults so existing rows are not broken.

## Task B: Backward compatibility migration

Write a migration that maps existing tier values:

- Any user with tier = `pro` or `premium` → set entitlement = `paid`, subscription_status = `active`
- Any user with tier = `free` or tier IS NULL → set entitlement = `none`, subscription_status = `none`
- Initialize voice_minutes_used_this_cycle = 0 and voice_cycle_started_at = now() for all paid users

## Task C: Quota enforcement updates

Find every backend function that checks tier/subscription and update:

- Replace any check like `tier == 'pro'` or `tier IN ('premium', 'pro')` with `entitlement == 'paid'`
- Voice endpoint authorization: `entitlement == 'paid'` AND `remaining_voice_minutes() > 0`
- Keep the existing pattern: APIM validates JWT → backend looks up user in PostgreSQL → enforces entitlement and quotas

### Voice minutes helper function (server-side)

Implement a function `get_remaining_voice_minutes(user_id)` that returns:

```
included_remaining = max(0, monthly_voice_minutes_included - voice_minutes_used_this_cycle)
purchased_remaining = voice_minutes_purchased_balance
total_remaining = included_remaining + purchased_remaining
```

Implement a function `consume_voice_minutes(user_id, minutes_used)`:

- Deduct from included minutes first
- If included is exhausted, deduct remainder from purchased balance
- Never allow balance to go negative — cap at 0
- Return updated remaining minutes

## Task D: Voice session lifecycle

Update voice session start/end logic:

**On session start:**

- Verify entitlement == `paid`
- Verify `get_remaining_voice_minutes(user_id).total_remaining > 0`
- If either fails, return 403 with appropriate error message
- Record session start timestamp

**On session end:**

- Calculate actual talk time (user + AI audio duration)
- Call `consume_voice_minutes(user_id, talk_time_minutes)`
- Record the usage event

## Task E: Webhook / sync endpoint

If RevenueCat webhooks are already implemented, extend the handler. If not, implement a minimal server-side verification endpoint.

**On subscription renewal event:**

- Reset `voice_minutes_used_this_cycle` to 0
- Set `voice_cycle_started_at` to now()
- Do NOT reset `voice_minutes_purchased_balance` (purchased minutes carry over)

**On consumable purchase event:**

- Check `transaction_id` against `voice_purchase_transactions` table
- If not found: insert record AND increment `voice_minutes_purchased_balance` by 60
- If found: skip (idempotent — no double credit)

**On subscription expiration/cancellation:**

- Set `entitlement` = `none`, `subscription_status` = `expired`
- Purchased minutes balance is preserved (they paid for those)
- Voice feature access is blocked (entitlement check fails)

## Task F: APIM review

Inspect APIM policies and Bicep/ARM templates:

- If APIM is only doing JWT validation + routing → **make no changes**
- If APIM references `Free`/`Premium`/`Pro` product names for rate limiting → leave them as-is for now and document what you found
- Do NOT rename or restructure APIM products in this phase

**Report:** At the end of your changes, provide a short summary of what APIM does today and whether any changes were needed.

## Output format

After completing all changes, provide:

1. List of files created or modified (with one-line description of each change)
2. Migration execution order (which SQL scripts to run and in what sequence)
3. Any manual steps required (e.g., environment variables, RevenueCat dashboard config)
4. APIM findings summary

## Constraints

- Do NOT refactor Riverpod state management, database connection logic, authentication flows, or any code unrelated to subscription/entitlement.
- Do NOT touch Flutter/mobile code — that is Phase 3.
- Do NOT update documentation files — that is Phase 4.
- Keep changes small, safe, and reversible.
- If you are unsure about an existing pattern, preserve it and add a TODO comment explaining the question.
