---
name: with-backend
description: >-
  Backend standards. Use when: 'server code', 'API routes', 'schemas', 'migrations'.
argument-hint: "[API, migration, or backend task]"
---

Server-side implementation standards for database changes and API boundaries.

## Database Changes

- Flag lock-risk operations (large table ALTERs, index rebuilds on hot tables) before executing.
- Include verification SQL or test confirming each schema change took effect.

## Anti-Patterns

- Migrations without verification evidence of schema change
