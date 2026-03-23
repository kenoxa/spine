# Frame Phase

Concurrent dispatch: 2 `@framer` agents + `@envoy`, then sequential `@synthesizer`.

**Concurrent** (3 agents):
- `@framer` + `frame-evidence-mapper.md` → `.scratch/<session>/discuss-frame-evidence-mapper.md`
- `@framer` + `frame-dialogue-tracker.md` → `.scratch/<session>/discuss-frame-dialogue-tracker.md`
- `@envoy` (via `use-envoy`) → `references/frame-envoy.md`: prompt = problem framing + final inventory + `key_decisions` + explore summary + signals (self-contained) → `.scratch/<session>/discuss-frame-envoy.md`

**Then sequential** (1 agent):
- `@synthesizer` + `frame-synthesis.md`: all frame outputs + session state + explore envoy if exists → `.scratch/<session>/brief.md` per `template-brief.md`.
  When producing the brief, evaluate whether scope evidence meets spec-creation criteria (multiple phases, cross-cutting concerns [3+ unrelated modules], multi-day signals). If met, set `Recommended Next Step` to `spec-creation`.

Main thread validates self-sufficiency contract: understandable without chat history, terms defined, no conversation references, evidence levels present. Re-dispatch on failure with gap list. Cap: framers (2) + envoy (1) + synthesizer (1) <= 4.

> Anti-pattern: Fire-and-forward navigator with no `external_signals` handoff.
