# BetaFeedback Backend

Go + Postgres API for the BetaFeedback app. Standard library HTTP routing
(Go 1.22+ `net/http`), `pgx` for Postgres, JWT sessions, and embedded SQL
migrations that run automatically on startup.

## Requirements

- Go 1.26+
- PostgreSQL 13+ (uses the built-in `gen_random_uuid()`)

## Quick start

```bash
cp .env.example .env          # adjust DATABASE_URL / JWT_SECRET
make db-create                # createdb betafeedback
make run                      # applies migrations, then serves on :8080
```

`DATABASE_URL` and `JWT_SECRET` are required. On a default Homebrew Postgres,
a working URL is `postgres://<your-macos-user>@localhost:5432/betafeedback?sslmode=disable`.

`OPENAI_API_KEY` is optional. When set, tester feedback is classified and
structured into bug reports with the OpenAI API (`OPENAI_MODEL`, default
`gpt-4o-mini`); when unset, the backend falls back to local heuristics.

## Layout

```
cmd/server            entrypoint (config, db, graceful shutdown)
internal/config       env-based configuration
internal/db           pgx pool + embedded migration runner
internal/db/migrations  *.sql, applied in lexical order
internal/model        domain types (shared by store + api)
internal/store        Postgres persistence layer
internal/api          routing, middleware, auth, handlers
```

## Auth

Passwordless email one-time-code, mirroring the mobile app:

1. `POST /v1/auth/email/start` `{ "email": "you@x.com" }` — issues a 6-digit
   code and emails it via Resend when `RESEND_API_KEY` is set. With
   `OTP_DEBUG=true` the code is also returned as `debug_code` (dev only).
2. `POST /v1/auth/email/verify` `{ "email", "code" }` — returns a JWT and the
   user; creates the user on first sign-in.

Send the token as `Authorization: Bearer <token>` on all `/v1/*` routes below.

## Email (Resend)

OTP sign-in codes and Pro/project notification emails go through
[Resend](https://resend.com). Set:

```bash
RESEND_API_KEY=re_xxxxxxxx
RESEND_FROM=BetaFeedback <noreply@betafeedback.com>
```

`RESEND_FROM` must use a domain verified in Resend. Without an API key, sends
are logged to stdout (useful locally with `OTP_DEBUG=true`).

## Endpoints

| Method & path | Notes |
|---|---|
| `GET /healthz` | liveness |
| `POST /v1/auth/email/start` | request OTP |
| `POST /v1/auth/email/verify` | exchange OTP for JWT |
| `POST /v1/auth/google` | exchange Google ID token for JWT |
| `POST /v1/auth/apple` | exchange Apple identity token for JWT |
| `GET /v1/me` | current user |
| `DELETE /v1/me` | delete account and personal data |
| `POST /v1/users/{id}/report` | report a user |
| `POST /v1/users/{id}/block` | block a user |
| `DELETE /v1/users/{id}/block` | unblock a user |
| `GET /v1/projects` | projects the caller belongs to |
| `POST /v1/projects` | create (caller becomes creator) |
| `GET /v1/projects/{id}` | project + members (members only) |
| `POST /v1/projects/{id}/members` | invite tester/developer (creator only) |
| `GET /v1/projects/{id}/feedback` | list reports (members only) |
| `POST /v1/projects/{id}/feedback` | submit report (tester/creator) |
| `GET /v1/projects/{id}/activity` | activity trail (members only) |
| `POST /v1/projects/{id}/releases` | announce a release (developer/creator); logs activity + notifies members |
| `GET /v1/notifications` | caller's notifications |
| `POST /v1/notifications/read` | mark all read |

## Roles

Roles are **per project** (`project_members.role`: `creator`, `tester`,
`developer`), not global — a user can be a creator on one project and a tester
on another.

## Subscriptions (RevenueCat)

Pro plan changes are driven by RevenueCat webhooks:

```
POST /v1/webhooks/revenuecat
```

Set `REVENUECAT_WEBHOOK_AUTH` (and optionally `REVENUECAT_ENTITLEMENT_ID=pro`)
in `.env`. See `../betafeedback_mobile/docs/REVENUECAT_SETUP.md`.

`PUT /v1/me/subscription` remains available only when `ENV=development` for
local plan testing without the App Stores.
