---
name: with-backend
description: >
  Backend development standards for APIs, databases, and infrastructure.
  Use when editing server code, API routes, database schemas, or migrations.
  Do NOT use for UI-only changes — see the with-frontend skill.
argument-hint: "[API, migration, or backend task]"
---

Server-side implementation with rollback-safe changes and centralized security boundaries.

## Database Changes

- Every migration MUST have a rollback path. Destructive changes (drop column, drop table, data
  backfills that lose precision) require explicit user confirmation and a migration plan before execution.
- Call out data-loss or lock-risk operations (large table ALTERs, index rebuilds on hot tables)
  explicitly before executing.
- Include verification SQL or a test that confirms the schema change took effect.

## Security Boundaries

- Auth and authorization checks live at the handler/middleware level — never buried in business
  logic where they can be accidentally bypassed.
- Fail closed: deny by default when auth state is ambiguous or missing.

## API Responses

- Return consistent error shapes. Never expose internal details (stack traces, SQL errors, file
  paths) in responses — these leak implementation and aid attackers.

## Anti-Patterns

- Migrations without rollback path
- Destructive database operations without explicit confirmation
- Auth checks scattered across business logic instead of centralized middleware
- Exposing internal error details to API consumers
