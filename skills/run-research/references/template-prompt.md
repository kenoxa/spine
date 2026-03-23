# Research Prompt Template

Fill each section from user goal + gathered context. Apply UI adaptation before output.

## Required Sections

### 1. Objective + Decision Context

State what to research AND what decision this informs (without decision anchor, output drifts to topic description).

```
Research: [specific question]
Decision: [what will change based on findings]
```

### 2. Scope + Boundaries

Define in/out. Include: time range, domain, technology constraints, scale.

```
In scope: [explicit list]
Out of scope: [explicit list]
Current stack: {gathered_context.tech_stack}
```

### 3. Research Dimensions

4-6 numbered angles. Include at least one contrarian/risk angle.

```
1. [Primary dimension]
2. [Comparative — "how do X and Y compare on..."]
3. [Scale — "at what scale does Z break"]
4. [Contrarian — "arguments against..."]
5. [Build-vs-adopt — "existing solutions vs custom"]
```

### 4. Output Format

Select from named formats or specify custom. Include section structure and approximate word counts.

## Named Output Formats

| Format | Sections | Best for |
|--------|----------|----------|
| Executive Brief | Summary (200w) + Findings (800w) + Risks (300w) + Recommendations (300w) | Decision-makers |
| Comparative Analysis | Overview (200w) + Comparison Table + Per-Dimension (500w each) + Verdict (300w) | Evaluating alternatives |
| Decision Brief | Problem (200w) + Options (300w each) + Evidence (500w) + Uncertainties (200w) + Recommendation (300w) | Binary/ternary choices |
| Implementation Guide | Prerequisites (200w) + Steps (800w) + Pitfalls (300w) + Validation (200w) | Post-decision how-to |
| Landscape Review | Question (100w) + Methodology (100w) + Sources + Consensus (400w) + Conflicts (300w) + Gaps (200w) | Broad survey |

## UI Adaptation

Apply per `--target`. Default: `chatgpt`.

| Target | Length | Style | Role/Persona | Structure |
|--------|--------|-------|-------------|-----------|
| `chatgpt` | 200-500w | Keyword-dense, structured headers | Include | Section headers with word counts |
| `claude` | 300-600w | Prose context, numbered tasks | Optional | Numbered constraints, "list assumptions" |
| `gemini` | 100-300w | Goal-first, minimal | Omit | Goal + scope + dimensions only |

**ChatGPT**: pre-answer likely clarification questions inside the prompt.
**Gemini**: avoid procedural instructions — use the plan editor instead.

## Context Block

Insert gathered context between Scope and Research Dimensions:

```
## Project Context
{gathered_context}
```

Omit when Gather is zero-dispatch (purely external goal).

## Security Redaction

Apply before output on ALL compiled content.

**Auto-strip** (replace with `[REDACTED:type]`):
- API keys: `api[_-]?key|apikey|api[_-]?secret`
- Bearer tokens: `bearer\s+[a-zA-Z0-9_\-\.]+`
- Passwords: `password|passwd|pwd`
- Database URLs: `mongodb|postgres|mysql|redis://`
- Localhost/private URLs: `localhost`, `127.0.0.1`, internal domains

**Flag for review** (warn user, do not auto-strip):
- Private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Custom auth headers
- Internal hostnames not in public docs

**IP leakage**: omit proprietary algorithms and competitive architecture details unless the research goal requires them.
