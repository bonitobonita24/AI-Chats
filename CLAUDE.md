# CLAUDE.md — AI-Chats Project Reference

This file is the persistent development log and reference for Claude Code sessions in this project.

---

## Project Overview

A self-hosted web app that aggregates, indexes, and searches markdown conversation exports from multiple AI platforms (ChatGPT, Claude AI, Cline, Copilot, Codex, etc.).

**Production domain:** your-domain.com

---

## Stack

- **Backend:** Node.js 18, Express 4, express-session, helmet, crypto (scrypt)
- **Frontend:** Vanilla JS (no framework), HTML5, CSS3 dark theme
- **Storage:** File-based — no database. Markdown files + generated JSON index.
- **Deployment:** Docker (multi-stage), Docker Compose, Traefik + Let's Encrypt

---

## Key Files & Roles

| File | Role |
|------|------|
| `server.js` | Express server — multi-user auth endpoints, sessions, static serving, rate limiting |
| `app/app.js` | Frontend SPA logic — state, filtering, search, rendering, export (27KB) |
| `app/index.html` | Three-panel UI — conversation list, viewer, code snippets |
| `app/styles.css` | Dark theme, platform badges, layout |
| `app/scripts/build-index.mjs` | Build step — walks `/logs/conversations/`, parses markdown, outputs `app/data/conversations.json` |
| `app/data/conversations.json` | Generated index (56 conversations, 14 snapshots as of 2026-03-22) |
| `logs/conversations/` | Markdown source files organized by platform (claudeai/, chatgpt/, snapshots/) |
| `.auth/users.json` | Scrypt-hashed multi-user credentials (id, email, username, salt, hash, verified, role, createdAt, changedAt). Migrated from legacy `credentials.json` on first run. |
| `scripts/reset-admin-password.mjs` | CLI utility to reset admin password |
| `.env` | Production env vars |

---

## API Endpoints

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| GET | `/health` | No | Docker health check |
| GET | `/api/auth/session` | No | Check auth status |
| POST | `/api/auth/login` | No | Authenticate (email + password) |
| POST | `/api/auth/logout` | Yes | Clear session |
| POST | `/api/auth/register` | No | Register new account (sends 6-digit code) |
| POST | `/api/auth/verify-email` | No | Verify email with 6-digit code, auto-login |
| POST | `/api/auth/resend-verification` | No | Resend verification code |
| POST | `/api/auth/forgot-password` | No | Send password reset link (1hr token) |
| POST | `/api/auth/reset-password` | No | Reset password with URL token |
| POST | `/api/auth/change-password` | Yes | Update password (logged-in users) |
| GET | `/*` | No | Static file serving |

---

## Environment Variables

| Var | Default | Notes |
|-----|---------|-------|
| `NODE_ENV` | development | |
| `PORT` | 4173 (dev) / 3000 (prod) | |
| `SESSION_SECRET` | fallback string | MUST override in production |
| `COOKIE_SECURE` | true | Set false for local HTTP |
| `COOKIE_DOMAIN` | (none) | Optional domain restriction |
| `APP_ADMIN_USERNAME` | admin | Username for initial admin seeded into users.json |
| `APP_ADMIN_EMAIL` | admin@localhost | Email for initial admin seeded into users.json |
| `APP_ADMIN_PASSWORD` | (see .env) | Password for initial admin seeded on first run |
| `SMTP_HOST` | (none) | SMTP server host — if unset, emails log to console |
| `SMTP_PORT` | 587 | SMTP port (use 465 for SSL) |
| `SMTP_USER` | (none) | SMTP username |
| `SMTP_PASS` | (none) | SMTP password |
| `SMTP_FROM` | SMTP_USER | From address for outbound emails |
| `APP_URL` | `http://localhost:PORT` | Base URL used in password reset links |

---

## Docker Compose Variants

| File | Use |
|------|-----|
| `docker-compose.dev.yml` | Dev/testing — builds `development` target, port `4287:4173`, volume `ai-chats-dev-auth` |
| `docker-compose.komodo.yml` | Production — pulls `your-dockerhub-username/ai-chats:latest` from Docker Hub, Traefik + SSL, volume `ai-chats-prod-auth` |
| `compose.yaml` | Legacy (builds production target locally) |
| `docker-compose.prod.yml` | Legacy (builds production target locally) |

**Docker Hub image:** `your-dockerhub-username/ai-chats:latest`

**Makefile commands:**
- `make dev` — start dev container (builds locally)
- `make dev-down` — stop dev container
- `make dev-logs` — stream dev logs
- `make build` — build production image
- `make push` — build + push to Docker Hub
- `make release` — alias for push

**Container naming (unique to avoid conflicts):**
- Dev container: `ai-chats-dev` | port `4287` | volume `ai-chats-dev-auth` | network `ai-chats-dev-net`
- Prod container: `ai-chats-prod` | no port (Traefik) | volume `ai-chats-prod-auth` | network `ai-chats-prod-net`

Production container: non-root user (`nodejs:1001`), read-only filesystem, tmpfs for `/tmp` and `/var/cache`. `.auth` is a named volume (persists password changes across restarts).

---

## Auth & Security Design

- **Multi-user**: open registration with email verification (6-digit code, 15min TTL)
- **Forgot password**: 64-char hex token, 1hr TTL, sent as `APP_URL/?reset=TOKEN`
- **Password hashing**: scrypt with random salt, timing-safe comparison
- **Session TTL**: 12 hours, HTTP-only SameSite cookies
- **Rate limiting**: IP-based, in-memory Map, exponential backoff (30s → 10min max)
- **Email**: nodemailer; if `SMTP_HOST` unset, emails printed to console (dev-friendly)
- **User store**: `.auth/users.json` (array). Auto-migrated from legacy `credentials.json` on first run.
- Helmet.js security headers (CSP currently disabled — known issue)

---

## Data Models

**Users (`.auth/users.json`):**
```json
[{ "id": "uuid", "email": "user@example.com", "username": "user", "salt": "hex32", "hash": "hex128", "verified": true, "role": "admin|user", "createdAt": "ISO8601", "changedAt": "ISO8601" }]
```

**Markdown conversation format:**
```markdown
# ChatGPT Conversation Log
- Conversation ID: url_xxxxx
- Title: ...
- Captured: ISO8601
- Platform: chatgpt
- URL: https://...
---
## User
...
## Assistant
...
```

---

## Known Issues / Technical Debt

1. **`.env` in git** — production `SESSION_SECRET` and `APP_ADMIN_PASSWORD` exposed in version control. Should be removed and rotated.
2. **CSP disabled** — `server.js` disables Content-Security-Policy in helmet config.
3. **In-memory rate limiting** — resets on server restart; won't work across multiple instances.
4. **Memory-only session store** — sessions lost on restart; no Redis/persistent store.
5. **CORS allows any localhost origin** — fine for dev, but not environment-scoped.
6. **Hardcoded default password** — fallback `APP_ADMIN_PASSWORD: '(see .env)'` in `server.js`.
7. **Fragile markdown parsing** — regex-based, assumes `## User` / `## Assistant` heading structure.
8. **No code snippets indexed** — build script extracts them but current data yields 0 (possible format mismatch).

---

## Change Log

### 2026-03-28
- **Feature:** Multi-user auth system — open registration, email verification (6-digit code), forgot/reset password (URL token)
- **Backend:** `server.js` fully rewritten. New routes: `/api/auth/register`, `/api/auth/verify-email`, `/api/auth/resend-verification`, `/api/auth/forgot-password`, `/api/auth/reset-password`. Login now uses email.
- **Storage:** `.auth/users.json` (array) replaces single `credentials.json`. Auto-migration on first run.
- **Email:** nodemailer added (`^6.10.1`). Falls back to console.log when `SMTP_HOST` unset.
- **Frontend:** 4 new auth overlays (register, verify-email, forgot-password, reset-password). `?reset=TOKEN` URL auto-triggers reset overlay.
- **New env vars:** `APP_ADMIN_EMAIL`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `APP_URL`

### 2026-03-27
- **Analysis:** Full codebase analysis performed by Claude Code (claude-sonnet-4-6).
  - Identified 56 conversations, 14 snapshots in `/logs/conversations/`
  - Documented all API endpoints, data models, env vars, Docker variants
  - Identified 8 known issues / technical debt items (see above)
- **Docs:** Created this `CLAUDE.md` as the persistent project reference and dev log.
- **Dev workflow changed:** All development/testing now runs via Docker Compose (`make dev`), not on the host directly.
- **Docker:** Restructured Docker Compose setup:
  - Created `docker-compose.dev.yml` — dev environment, port `4287`, named volume `ai-chats-dev-auth`, network `ai-chats-dev-net`
  - Updated `docker-compose.komodo.yml` — now pulls `your-dockerhub-username/ai-chats:latest` from Docker Hub (no local build), named volume `ai-chats-prod-auth`, network `ai-chats-prod-net`
  - Moved `.auth` from tmpfs → named volume in production so password changes survive restarts
  - Created `Makefile` with `make dev/dev-down/dev-logs/build/push/release`
  - Created `.env.dev` for local dev defaults (gitignored)
