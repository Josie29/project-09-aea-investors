# Tech Stack — AEA Investors AI-Powered Onboarding Assistant

High-level decisions only. Library-level choices are deferred (see Open sub-decisions).

| Layer | Component | Choice | Reason |
|---|---|---|---|
| Repo | Layout | Monorepo: `backend/` (Rails) + `frontend/` (Next.js) | Single clone, single CI, matches the grader quick-start requirement |
| Backend | API framework | Ruby on Rails 8, API-only mode | Required by the brief; API-only drops view/asset layers we don't use |
| Backend | Async work | Solid Queue (Postgres-backed) | OCR and LLM calls must not block the request; no extra Redis service to host |
| Frontend | Framework | Next.js (App Router) + TypeScript | Required by the brief; TS per repo convention |
| Frontend | Rendering | Client-heavy SPA over a Rails JSON API | Onboarding is one stateful wizard, not content pages; keeps Rails the single source of truth |
| Data | Database | Neon Postgres | Genuine free tier with encryption at rest; branching gives CI an isolated DB per run |
| Data | Auth | Clerk free tier (Rails verifies the JWT via JWKS) | Managed identity keeps password/session security off our plate inside a 3-day box |
| Data | Document storage | Backblaze B2, private bucket + signed URLs | S3-compatible so ActiveStorage works unmodified; 10 GB free with no card on file |
| AI | LLM provider | Groq free tier (Llama-class model) | Fastest free-tier inference — the < 3 s p95 chatbot target is the binding constraint |
| AI | LLM abstraction | Provider adapter behind one service interface | Lets us fail over to Gemini or local Ollama without touching orchestration |
| AI | OCR engine | Tesseract, self-hosted in the API container | Free, runs in-infra so ID images never leave our boundary; brief's default |
| Infra | Backend hosting | Railway (Docker) | Brief-listed free tier; Docker image is what lets us ship Tesseract system deps |
| Infra | Frontend hosting | Vercel | Native Next.js target, free tier, zero build config — justified substitution |
| Infra | Containerization | Docker for the Rails API | OCR needs OS-level binaries; also gives graders a reproducible local run |
| Quality | Backend tests | RSpec | Brief-named; ≥ 80% coverage target on core services |
| Quality | Frontend tests | Vitest + React Testing Library | Vite-native, fast, standard for the Next.js/TS side |
| Quality | Load testing | k6 | Brief mandates it, with the script committed |
| Quality | CI | GitHub Actions | Runs RSpec + Vitest + RuboCop + ESLint on every push |

## Rejected alternatives

| Component | Option | Why not |
|---|---|---|
| API framework | Node/NestJS, FastAPI | Brief requires Ruby on Rails |
| Async work | Sidekiq | Needs a Redis service; extra hosting surface for no gain at this scale |
| Async work | Fully synchronous requests | OCR at ~seconds per image would blow the p95 targets and block workers |
| Frontend framework | Remix, plain Vite SPA | Brief requires Next.js |
| Rendering | Rails server-rendered views (Hotwire) | Contradicts the required Next.js frontend |
| Database | Supabase Postgres | Brief's default, but the account's free-tier limits are already exhausted |
| Database | Railway Postgres | One less vendor and private networking, but Railway has no ongoing free tier |
| Database | Render Postgres | Free instances expire after 30 days — outlives the build, not the review window |
| Auth | Supabase Auth | Same exhausted-limits problem as Supabase Postgres |
| Auth | Rails 8 native auth (`has_secure_password`) + own JWT | No vendor, but we'd own password hashing, resets, and token expiry for ~0.5 day |
| Auth | Neon Auth | Keeps DB and auth on one platform, but newest option with the thinnest Rails-side docs |
| Auth | Devise, Auth0 | Devise is session/cookie-first across origins; Auth0's free tier is tighter than Clerk's |
| Document storage | Supabase Storage | Same exhausted-limits problem as the rest of Supabase |
| Document storage | Cloudflare R2 | Equivalent free tier and better egress terms, but wants a card on file to activate |
| Document storage | AWS S3 | Adds an AWS account purely for a bucket; brief lists AWS as optional-only |
| Document storage | Local disk on Railway | Ephemeral filesystem; no encryption-at-rest or signed-URL story |
| LLM provider | Google Gemini free tier | Viable, kept as the failover; Groq wins on latency headroom |
| LLM provider | Ollama (local) | Best privacy story but too slow/heavy on a free-tier host to hit < 3 s p95 |
| LLM provider | Claude, OpenAI | Paid; brief explicitly requires no paid API |
| OCR engine | PaddleOCR | Better on skew/glare but a heavy Python runtime beside a Ruby app |
| OCR engine | Google Vision / AWS Textract | Sends raw ID images to a third party — the exact boundary the brief warns against |
| Backend hosting | Render | Equivalent free tier; Railway picked for faster Docker deploys and existing tooling |
| Backend hosting | AWS / GCP / Azure | Brief marks these optional-only; setup cost buys nothing inside a 3-day box |
| Frontend hosting | Railway (Next.js in Docker) | Would unify hosting, but Vercel is materially less config for the same free tier |
| Frontend tests | Jest | Slower and more config than Vitest; brief accepts either |
| CI | CircleCI, GitLab CI | Repo lives on GitHub; Actions is the zero-setup option |

## Open sub-decisions

- **Exact Groq model** (Llama 3.x variant) — pin once the intent-coverage eval set exists and we can measure quality vs latency.
- **OCR preprocessing pipeline** (deskew/threshold before Tesseract) — decide against the 30-doc golden set, since the ≥ 90% field accuracy bar is what forces it.
- ~~Assumed regulatory domain~~ — **resolved: behavioral health, HIPAA.** Set by the V0 UI design (sample clinic "Northline Behavioral Health"); drives retention, audit logging, and the no-third-party-AI-on-ID-images boundary.
- **Structured-output mechanism for the LLM** (tool/function calling vs JSON-schema prompting) — resolve when building the assessment record extractor.
- **Where the canonical user record lives** — Clerk owns identity, but onboarding records need a local `users` row; decide sync-on-first-request vs Clerk webhooks at auth implementation.
