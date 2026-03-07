---
name: with-backend
description: >
  Backend development standards for APIs, databases, and infrastructure.
  Use when editing server code, API routes, database schemas, or migrations.
  Do NOT use for UI-only changes — see the with-frontend skill.
argument-hint: "[API, migration, or backend task]"
---

Server-side implementation standards for database changes and API boundaries.

## Database Changes

- Call out lock-risk operations (large table ALTERs, index rebuilds on hot tables) before executing.
- Include verification SQL or a test that confirms each schema change took effect.

## Anti-Patterns

- Migrations without verification evidence that the schema change took effect
