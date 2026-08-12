# AEA Investors — AI-Powered Onboarding Assistant

Take-home assessment for **AEA Investors**. Full requirements: [BRIEF.md](BRIEF.md).

Assumed domain: **behavioral health** (regime: **HIPAA**). See
[docs/tech-stack.md](docs/tech-stack.md) for stack decisions and
[docs/security-notes.md](docs/security-notes.md) for the privacy posture.

## Live

| | |
|---|---|
| Frontend | https://aea-onboarding.vercel.app |
| API | https://api-production-60414.up.railway.app |
| Health | https://api-production-60414.up.railway.app/api/v1/health |

## Status

Pass 1 foundation complete: deployed, authenticated, database-backed skeleton. The
onboarding wizard screens are not built yet — the live URL currently shows sign-in and a
proof-of-round-trip page. Progress is tracked as
[GitHub issues](https://github.com/Josie29/project-09-aea-investors/issues), grouped by
`pass-1` / `pass-2` / `pass-3`.

## Stack

Rails 8.1 API (Ruby 3.4.10) · Next.js 16 App Router (TypeScript) · Neon Postgres 17 ·
Clerk auth · Tesseract OCR · Solid Queue · Railway + Vercel · RSpec + Vitest + k6.

## Quick start

Prerequisites: Ruby 3.4.10 (via rbenv), Node 22+, Docker, and `libpq`
(`brew install rbenv ruby-build libpq`).

```bash
git clone https://github.com/Josie29/project-09-aea-investors.git
cd project-09-aea-investors
cp .env.example backend/.env      # then fill in the values it documents
```

### Backend

```bash
cd backend
docker compose up -d --wait       # local Postgres 17 (dev + test databases)
bin/setup                         # installs gems, prepares the database
bin/rails s -p 3001
```

### Frontend

```bash
cd frontend
npm install
cp .env.example .env.local        # see the "Frontend" section of .env.example
npm run dev                       # http://localhost:3000
```

Clerk keys can be generated without touching a dashboard:

```bash
npm i -g clerk
clerk auth login
clerk apps create "AEA Investors Onboarding" --json
clerk env pull --app <app_id>     # writes frontend/.env.local
```

`clerk env pull` does **not** emit `CLERK_ISSUER`, which the API needs. Derive it by
base64-decoding the part of the publishable key after `pk_test_` and stripping the
trailing `$`.

## Tests

```bash
cd backend  && bundle exec rspec && bundle exec rubocop
cd frontend && npm test && npm run lint && npm run build
```

CI runs all of the above on every push ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
A scheduled workflow probes the health endpoint every five minutes
([`.github/workflows/uptime.yml`](.github/workflows/uptime.yml)); note that GitHub only
runs scheduled workflows on the default branch.

The AI evaluation harness (`rake ai:eval`, OCR golden set and chatbot intent coverage)
lands with the OCR and chatbot issues and will be documented here.

## Deployment notes

Two things that are easy to get wrong and cost real debugging time:

- **Railway injects `$PORT` (8080), not 3000.** Puma reads it correctly, but the
  generated service domain defaults to targeting port 3000 and returns 502 until the
  domain's target port is corrected.
- **Always use Neon's direct (non-pooled) connection string.** Rails migrations take a
  session-level advisory lock, which Neon's transaction-mode PgBouncer does not support,
  so a pooled URL hangs the deploy rather than failing loudly.

## Documentation

- [BRIEF.md](BRIEF.md) — the assessment brief
- [docs/tech-stack.md](docs/tech-stack.md) — stack choices and rejected alternatives
- [docs/repo-layout.md](docs/repo-layout.md) — directory structure and deviations
- [docs/ux-decisions.md](docs/ux-decisions.md) — confidence display, assessment
  confirmation, supportive-content triggers
- [docs/security-notes.md](docs/security-notes.md) — encryption, PII handling, auth
- `AI_USAGE.md` — required disclosure, written before submission
