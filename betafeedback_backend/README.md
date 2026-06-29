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
   code. With `OTP_DEBUG=true` the code is returned as `debug_code` (dev only;
   a real deployment emails it instead).
2. `POST /v1/auth/email/verify` `{ "email", "code" }` — returns a JWT and the
   user; creates the user on first sign-in.

Send the token as `Authorization: Bearer <token>` on all `/v1/*` routes below.

## Endpoints

| Method & path | Notes |
|---|---|
| `GET /healthz` | liveness |
| `POST /v1/auth/email/start` | request OTP |
| `POST /v1/auth/email/verify` | exchange OTP for JWT |
| `GET /v1/me` | current user |
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

## Not yet implemented (schema is ready)

Tables exist for `structured_bugs`, `test_items`, and `subscriptions`; handlers
for AI bug structuring, the test plan, and billing are the next slices. Future
roadmap (tester discovery, ranking, compensation) also builds on this schema.
