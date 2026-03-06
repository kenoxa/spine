---
name: frontend
description: >
  Frontend development standards for UI implementation.
  Use when editing components, pages, or UI code.
  Do NOT use for API-only changes — see the backend skill.
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

Accessibility is a gate, not a polish step — build it in, don't bolt it on afterward.

- Prefer semantic HTML over ARIA. If a native element does the job, don't layer ARIA on top.
- Keyboard navigation for all interactive elements; no keyboard traps.
- Focus management on route changes and modal open/close — visible focus indicators required.
- Color contrast: 4.5:1 normal text, 3:1 large text (WCAG AA).

For comprehensive audits, use the `wcag-audit-patterns` skill.

## Anti-Patterns

- Implementing without proposing layout when scope is ambiguous
- Missing loading, error, or empty states
- Using divs with click handlers instead of buttons or links
- Treating accessibility as a follow-up task
- Inline styles where utility classes or design tokens exist
