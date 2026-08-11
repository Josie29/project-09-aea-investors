# Repo Layout

Directory scaffold only — no implementation yet. Empty directories are held by `.gitkeep`.
Stack rationale lives in [tech-stack.md](./tech-stack.md).

```
backend/          Rails 8, API-only
frontend/         Next.js App Router + TypeScript
infra/            Dockerfiles, k6 load scripts
docs/             Decision records
.github/workflows CI
```

## backend/

```
app/
  controllers/api/v1/    Versioned from day one — the frontend is a separate deploy
  serializers/           Explicit response shaping; keeps PII out of payloads by omission, not by luck
  services/
    ocr/                 Engine adapter, image preprocessing, field extraction + mapping
    llm/                 Provider adapter, prompt assembly, assessment orchestration
    onboarding/          Wizard state, step transitions, structured-record assembly
    scheduling/          Slot availability, booking, double-booking guard
    privacy/             Consent capture, revocation, PII purge, deletion verification
  jobs/                  OCR and LLM calls run async; requests must not block on them
  policies/              Per-user authZ — a user reaches only their own onboarding record
  validators/            Upload file-type and size checks, server-side
db/
  migrate/               Committed migrations; schema is reproducible from clean checkout
  seeds/                 Seed data incl. synthetic golden set, so the app is gradeable
lib/tasks/               `rake ai:eval` harness lives here
spec/
  fixtures/golden_set/
    ocr/images/          30 synthetic ID/documents — never real PII
    ocr/expected/        Labeled name/DOB/address per image
    intents/             Labeled utterances per chatbot intent
```

Four service namespaces mirror the brief's four core flows, plus `privacy/` because
consent, retention, and deletion are graded as first-class (20 of 100 pts) rather than
as a cross-cutting afterthought. Each is a plain-Ruby service so it can be unit-tested
without a controller — the ≥ 80% coverage bar applies to exactly this layer.

`ocr/` and `llm/` are adapter-shaped on purpose: the tech-stack doc keeps Gemini as an
LLM failover and PaddleOCR as an OCR fallback, and neither swap should reach
orchestration code.

## frontend/

```
src/
  app/(auth)/            Clerk-hosted sign-in/up routes
  app/(onboarding)/      The wizard itself — route groups keep layouts separate
  components/
    ui/                  Primitives — button, field, dialog
    chat/                Chatbot transcript + composer
    documents/           Upload, extraction review, per-field confirm/edit
    scheduling/          Slot picker, booking confirmation
    support/             Supportive content surfaced at friction points
  lib/api/               Typed Rails client — single place the Bearer token is attached
  lib/auth/              Clerk helpers, session access
  types/                 Shared API contract types
  styles/                Design tokens: colors, spacing scale, breakpoints
  __tests__/             Vitest + RTL, mirroring components/ and lib/
```

`documents/` is deliberately not called `ocr/` — the user-facing concern is confirming
extracted fields, and the brief makes that confirmation step a pass/fail criterion. The
component boundary should reflect the user's model, not the backend's.

## Conventions

- Tests live in dedicated directories, never beside source: `backend/spec/` (RSpec's
  default lookup path) and `frontend/src/__tests__/`.
- `db/seeds/` is a directory, not a single `seeds.rb` — the golden set alone will
  outgrow one file.
- API versioning starts at v1 rather than being retrofitted, since frontend and backend
  deploy independently (Vercel and Railway) and can drift between releases.

## Not yet created

Deferred until the relevant tooling generates them, so nothing hand-written gets
clobbered:

- `backend/` Rails app files — `rails new --api` writes `Gemfile`, `config/`, `bin/`
- `frontend/` Next.js app files — `create-next-app` writes `package.json`, configs
- `.env.example` — required by the brief; author once the first real env var exists
- `infra/docker/Dockerfile` — needs the Rails app present to build against
- `.github/workflows/ci.yml` — needs test commands that actually run
