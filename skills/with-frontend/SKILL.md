---
name: with-frontend
description: >
  Frontend development standards for UI implementation.
  Use when editing components, pages, or UI code.
  Do NOT use for API-only changes — see the with-backend skill.
argument-hint: "[component or UI task]"
---

UI implementation with explicit state coverage and accessibility as a first-class gate.

## Propose Before Building

When frontend scope is ambiguous: propose an ASCII sketch or block diagram showing layout,
key interactions, and UI states before implementation. Ask one clarifying question if
critical UX intent is unclear.

For distinctive visual craft (typography, color, motion, composition), use the
`frontend-design` skill.

## State Coverage

Every UI component MUST account for these states where applicable:

- **Loading** — skeleton or spinner, not blank screen
- **Error** — actionable message, not raw error
- **Empty** — guidance or call-to-action, not blank
- **Responsive** — functional across viewport sizes

## Accessibility

Accessibility gates completion — do not defer to a follow-up pass.

- Focus management on route changes and modal open/close — visible focus indicators required.

For comprehensive audits, use the `wcag-audit-patterns` skill.

## Anti-Patterns

- Implementing without proposing layout when scope is ambiguous
- Missing loading, error, or empty states
- Treating accessibility as a follow-up task
