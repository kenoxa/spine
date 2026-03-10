# Skill Authoring Examples

## Directive concreteness

**Bad** — vague, fails authoring test:
```
Write clear pass/fail criteria.
```

**Good** — concrete, domain-specific:
```
Pass: email addresses client by name and references ≥1 property from saved search.
Fail: generic greeting ("Dear customer") or no property references.
```

---

## Cutting general knowledge

**Bad** — agent already knows this:
```
A trace is the complete record of an LLM interaction, including inputs, outputs,
and intermediate steps. Traces are useful because they let you replay and debug
model behavior across different conditions.
```

**Good** — directive only:
```
Read the full trace before writing an evaluator. Do not evaluate final output alone.
```

---

## Converting wisdom to anti-patterns

**Bad** — paragraph-style warning:
```
It's worth noting that using ROUGE scores as primary evaluation metrics is
problematic because they measure surface-level textual overlap, which often
fails to capture semantic meaning or task-specific quality.
```

**Good** — one-line anti-pattern:
```
- Using ROUGE or cosine similarity as primary evaluation metrics
```

---

## AGENTS.md before/after

**Before** (bloated root):
```markdown
# AGENTS.md
Use TypeScript strict mode. Prefer named exports over default exports.
Use Zod for all external input validation. Never use `any`. Run `tsc --noEmit`
before committing. Use Vitest for unit tests. Co-locate test files with source.
Run `pnpm test` to execute. API routes live in `src/routes/`. Follow REST
conventions. Use 400 for validation errors, 401 for auth, 404 for not found.
Commit messages follow Conventional Commits. Use `feat:`, `fix:`, `chore:`.
```

**After** (minimal root + references):
```markdown
# AGENTS.md
E-commerce API. Package manager: pnpm. Build: `tsc --noEmit`. Tests: `pnpm test`.

- [TypeScript conventions](docs/typescript.md)
- [API design](docs/api.md)
- [Testing patterns](docs/testing.md)
- [Git workflow](docs/git.md)
```

---

## Telegraphic prose

**Bad** — grammatically complete:
```
You should dispatch all three subagents in parallel and then wait for
their completion before synthesizing the results into a unified output.
```

**Good** — telegraphic:
```
Dispatch 3 subagents in parallel. Synthesize after all complete.
```
