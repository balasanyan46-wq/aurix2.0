# Aurix 2.0 — Handoff Report for VS Code Cloud Code

## 1) Project Overview

Aurix is a multi-platform Flutter application with a hybrid backend:

- Flutter client: `aurix_flutter`
- Cloudflare Worker API/AI proxy: `cloudflare_worker`
- Supabase backend (DB/Auth/Storage/Edge Functions): `supabase`

Primary stack:

- Flutter (Dart), Riverpod, go_router, Supabase SDK
- TypeScript (Cloudflare Workers + Wrangler + Zod)
- PostgreSQL via Supabase migrations

## 2) Current Repository State (Important)

The working tree is in a heavy in-progress state:

- ~192 local changes (`modified + untracked`)
- Many new modules added recently (DNK tests, Navigator, Production, CRM/Promo, Legal Compliance)
- No CI workflows found in `.github/workflows` (only PR template exists)

Implication: do not treat current branch as release-ready. First objective is stabilization.

## 3) Key Paths You Must Understand

- Flutter app entry/config:
  - `aurix_flutter/lib/main.dart`
  - `aurix_flutter/lib/config/app_config.dart`
  - `aurix_flutter/lib/presentation/router/app_router.dart`
- Flutter data/services:
  - `aurix_flutter/lib/data/repositories/`
  - `aurix_flutter/lib/data/providers/`
  - `aurix_flutter/lib/data/services/tool_service.dart`
- AI integrations:
  - `aurix_flutter/lib/ai/ai_service.dart`
  - `aurix_flutter/lib/ai/cover_ai_service.dart`
- Worker:
  - `cloudflare_worker/src/index.ts`
  - `cloudflare_worker/src/dnk/*`
  - `cloudflare_worker/src/dnk_tests/*`
  - `cloudflare_worker/src/aai/*`
  - `cloudflare_worker/README.md`
- Supabase:
  - `supabase/migrations/*.sql` (60 files)
  - `supabase/functions/*/index.ts`
  - `supabase/functions/_shared/ai.ts`

## 4) Runtime Architecture (As-Is)

Current request flow is hybrid:

1. Flutter -> Supabase directly (auth/data/storage/functions) for core app operations.
2. Flutter -> Cloudflare Worker for AI, DNK, AAI and some tool flows.
3. Some Supabase functions can call Worker (or fallback to OpenAI directly).

Critical config variables:

- Flutter compile-time defines:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `CF_BASE_URL`
  - `STUDIO_TOOLS_DIRECT_WORKER`
- Worker secrets:
  - `OPENAI_API_KEY`
  - `AURIX_INTERNAL_KEY`
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `ALLOWED_ORIGINS`
  - `ENV`

## 5) Main Risks You Should Address First

1. No CI gate -> high regression risk.
2. Large unstructured change set -> difficult verification and rollback.
3. Mixed legacy/new Flutter structure (`lib/screens` + `lib/features`) -> maintainability risk.
4. Env/config drift across local/stage/prod.
5. Public operational endpoints and service-role powered flows require strict hardening review.

## 6) Priority Execution Plan (What Cloud Code Should Do)

### Phase A — Stabilization (Day 1-2)

- Freeze feature additions.
- Create a stabilization branch and split current changes into logical chunks:
  1) Core auth/router/config
  2) AI/Worker contract updates
  3) New feature modules
  4) SQL migrations
- Remove or quarantine unrelated root artifacts if not part of product deliverable.

Deliverable:
- Clean changelog and scoped PR units.

### Phase B — Build Quality Gates (Day 2-3)

Add CI workflows:

- Flutter:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
- Worker:
  - `npm ci`
  - `npm run check:api-contract`
  - `tsc --noEmit` (or equivalent compile check)

Deliverable:
- `.github/workflows` pipelines with required checks.

### Phase C — Contract and Integration Validation (Day 3-4)

Implement a smoke test matrix:

- Auth: register/login/logout/session restore
- Releases: create/update/list/details
- Storage: upload cover + track
- AI: `/api/ai/chat`, cover generation
- DNK: start/answer/finish flow
- Admin: role-based access + critical operations

Deliverable:
- Reproducible smoke script docs + pass/fail evidence.

### Phase D — Environment Normalization (Day 4)

- Enforce explicit environment config (no accidental prod defaults in developer flow).
- Document `dev/stage/prod` endpoint map in one source of truth.
- Verify all Worker/Supabase secrets and rotate if exposure risk exists.

Deliverable:
- Environment runbook.

### Phase E — Infra/Migration Readiness for RU Hosting (Day 5+)

If target is REG.RU / Russia-hosted backend:

- Prepare migration runbook:
  - DB dump/restore (`pg_dump` / `pg_restore`)
  - Storage objects migration (separate from DB)
  - Edge function redeploy
  - DNS/endpoint cutover + rollback
- Test staging cutover before production switch.

Deliverable:
- Signed cutover checklist with rollback timing.

## 7) Concrete Task Backlog (Cloud Code Tickets)

1. Create CI workflows for Flutter + Worker (blocking checks).
2. Introduce integration smoke test script/package.
3. Refactor `tool_service.dart` into smaller modules (transport, auth, parsing, fallback strategy).
4. Add API contract versioning tests for Worker responses.
5. Audit and restrict `/debug/env` and internal-only routes.
6. Consolidate docs into `docs/` and archive obsolete root reports.
7. Produce release candidate checklist and Go/No-Go template.

## 8) Definition of Done (Release Readiness)

Release can be considered ready only when:

- CI is green on all required workflows.
- No high-severity lint/type/test failures.
- Smoke matrix is fully passed in staging.
- Migration + rollback tested end-to-end.
- Secrets reviewed/rotated and debug/internal endpoints restricted.
- One deployment runbook exists and is validated by another engineer.

## 9) Quick Command Reference

Flutter:

```bash
cd aurix_flutter
flutter pub get
flutter analyze
flutter test
```

Worker:

```bash
cd cloudflare_worker
npm ci
npm run check:api-contract
npx wrangler deploy
```

Supabase migration (manual/project-specific):

```bash
cd supabase
# apply migrations in order per project process
```

## 10) Handoff Notes for Cloud Code Agent

- Start with repository audit and change segmentation, not feature work.
- Preserve current behavior where possible; prioritize regression containment.
- Keep every major change behind verifiable tests.
- Treat infrastructure and API contract updates as high-risk areas requiring explicit validation.

