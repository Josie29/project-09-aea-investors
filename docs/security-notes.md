# Security & Privacy Notes

Running record of security-relevant decisions and verifications, captured as each issue
lands. Feeds the README's compliance section (#43) and the security issues (#35, #37,
#38, #39).

**Assumed domain:** behavioral health. **Regime:** HIPAA. See [tech-stack.md](./tech-stack.md).

---

## Encryption

| Layer | Mechanism | Verified |
|---|---|---|
| In transit — browser → frontend | TLS, Vercel-managed | pending #8 |
| In transit — frontend → API | TLS, Railway-managed edge | pending #8 |
| In transit — API → database | TLS enforced by Neon; non-TLS connections are rejected outright. Connection strings carry `sslmode=require&channel_binding=require`. | ✅ #5 |
| At rest — database | Neon encrypts all stored data and backups at rest (AES-256), on every plan including free. | ✅ #5 |
| At rest — document images | Backblaze B2 server-side encryption, private bucket | pending #13 |

`channel_binding=require` is worth keeping rather than trimming: it binds the TLS channel
to the authentication exchange, so a man-in-the-middle holding valid credentials still
cannot complete the handshake.

## Database access

- **No public database credentials anywhere in the repo.** `DATABASE_URL` is environment-only;
  `.env.example` documents the shape with placeholders and is the only committed env file.
- The **direct (non-pooled)** Neon endpoint is used for all connections. Beyond the
  advisory-lock issue that motivated it, this also means one fewer network component
  between the application and the data.
- Local development and the test suite run against a **local Docker Postgres**, never Neon.
  The test suite truncates and rolls back every table, so pointing it at a shared hosted
  database risks destroying real data. `TEST_DATABASE_URL` is a separate database from
  `DATABASE_URL` even locally.

## Authentication

- Identity is delegated to **Clerk**; the application never stores a password.
- Rails verifies Clerk's RS256 JWTs against a cached JWKS. Verified reachable at
  `https://inviting-mammal-81.clerk.accounts.dev/.well-known/jwks.json` (1 key, RS256).
- Tokens travel as `Authorization: Bearer`, never cookies. This removes the CSRF surface
  entirely and avoids `SameSite=None` third-party-cookie exposure across the Vercel and
  Railway origins.
- **Rails holds no Clerk credential.** Verification uses the *public* JWKS, so a leak of
  the API's environment does not expose anything that can mint tokens.

### `azp` handling — verified empirically

`azp` pins a token to the frontend origin that requested it. Clerk's documentation does
not state what happens for tokens minted server-side, so this was measured rather than
assumed: a token minted through the Backend API carries **no `azp` claim at all**
(confirmed 2026-08-11 against the dev instance).

The verifier therefore enforces the allowlist **only when `azp` is present** — a token
naming a foreign origin is rejected, an absent one falls back to signature, issuer, and
expiry. Rejecting absent `azp` would break every Server Component call.

The same measurement confirmed **`exp - iat` is exactly 60 seconds**, which is why the
API client resolves a token per request rather than caching one.
- **Third-party PII processors, for disclosure:** Clerk receives identity data (email,
  authentication events). It never receives document images or extracted identity fields —
  OCR runs in our own container, which is why Tesseract is self-hosted rather than a cloud
  OCR API.

## Outstanding

Tracked as issues, listed here so the gaps are explicit rather than implied:

- PII log scrubbing — #12
- Private document storage with signed URLs — #13
- Consent capture and hard gate before upload — #11
- Purge-after-confirm and deletion receipts — #24
- Consent revocation and verifiable deletion — #37
- Role-scoped staff access with audit logging — #38
- PII-never-in-logs regression specs — #39
