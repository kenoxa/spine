---
name: with-frontend
description: >-
  Frontend standards. Use when: 'components', 'pages', 'styles', 'UI code'.
argument-hint: "[component or UI task]"
---

UI implementation with explicit state coverage and accessibility as first-class gate.

## Propose Before Building

Ambiguous frontend scope → propose ASCII sketch or block diagram showing layout,
interactions, and UI states before implementation. Ask one clarifying question if
critical UX intent unclear.

For visual craft (typography, color, motion, composition), use `frontend-design` skill.

For modern web-platform best-practice patterns and Baseline browser-support guidance, use `modern-web-guidance` skill before implementing.

## State Coverage

Every UI component MUST account for these states where applicable:

- **Loading** — skeleton or spinner, not blank screen
- **Error** — actionable message, not raw error
- **Empty** — guidance or call-to-action, not blank
- **Responsive** — functional across viewport sizes

## Accessibility

Accessibility gates completion — never defer to follow-up pass.

- Focus management on route changes and modal open/close — visible focus indicators required.

For comprehensive audits, use `wcag-audit-patterns` skill.

## Framework-Specific

For Svelte (`.svelte`, `.svelte.ts`, SvelteKit) work, see [references/svelte.md](references/svelte.md) — MCP workflow, delegation to `@svelte-file-editor`, runes-only, autofixer-before-commit, form actions preferred.

## Anti-Patterns

- Implementing without proposing layout when scope ambiguous
- Missing loading, error, or empty states
- Treating accessibility as follow-up task
