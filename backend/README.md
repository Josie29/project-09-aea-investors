# Backend — Rails 8 API

JSON API for the AI-powered onboarding assistant. API-only mode; the Next.js app in
`../frontend` is the only client. See [`../docs/tech-stack.md`](../docs/tech-stack.md)
for why each piece was chosen and [`../docs/repo-layout.md`](../docs/repo-layout.md)
for what belongs where.

## Requirements

- Ruby 3.4.10 (see `.ruby-version`; rbenv or equivalent)
- Docker, for the local Postgres
- `libpq` on the load path so the `pg` gem can build
  (`brew install libpq`, then add `/opt/homebrew/opt/libpq/bin` to `PATH`)

## Setup

```sh
bin/setup --skip-server
```

That installs gems, copies the repo-root `.env.example` to `backend/.env`, starts the
Docker Postgres, and runs migrations. Then:

```sh
bin/rails server     # http://localhost:3000
bin/jobs             # Solid Queue worker, in a second terminal
```

## Local database

`docker-compose.yml` runs Postgres 17 with a named volume. It backs both development
and test; nothing else uses it.

```sh
docker compose up -d      # start
docker compose down       # stop, keep data
docker compose down -v    # stop, destroy data
```

Two databases are created on first boot: `aea_onboarding_development` and
`aea_onboarding_test` (see `docker/postgres-init/`). `TEST_DATABASE_URL` must always
point at a local database — the suite truncates and rolls back every table, so aiming
it at a hosted database would wipe it.

## Background jobs

Solid Queue is the Active Job adapter in development and production. Its tables live in
the **primary** database, not a separate queue database: there is no `queue:` tier in
`config/database.yml` and no `config.solid_queue.connects_to` anywhere. The schema is a
normal migration (`db/migrate/*_create_solid_queue_tables.rb`) rather than the
`db/queue_schema.rb` the installer defaults to, so one `DATABASE_URL` is enough.

The test environment uses Rails' built-in `:test` adapter, as usual.

## Checks

```sh
bin/rspec        # tests
bin/rubocop      # style (rubocop-rails-omakase + rubocop-rspec)
bin/ci           # everything, the way CI runs it
```

Specs live in `spec/`, never beside source. Request specs are the default for
controllers; `config/application.rb` turns off view, helper, routing, and controller
spec generation.

## Environment variables

All of them are documented in [`../.env.example`](../.env.example). Copy it to
`backend/.env` (`bin/setup` does this) — dotenv loads it in development and test only.
Real credentials never go in `.env.example`.
