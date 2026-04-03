# Workflow Patterns

Five patterns for multi-phase workflow skills. Choose by decision structure, not domain.

## Pattern Selection

```
How many distinct paths?
|
+-- One path, always the same
|   +-- Destructive actions?
|       +-- YES -> Safety Gate
|       +-- NO  -> Linear Progression
|
+-- Multiple independent paths from shared setup
|   +-- Routing
|
+-- Multiple dependent steps in sequence
    +-- Complex dependencies / partial failure tolerance?
        +-- YES -> Task-Driven
        +-- NO  -> Sequential Pipeline
```

## Patterns

### Routing

Single entry dispatches to specialized sub-skills based on input classification.
Intake form collects context; routing table maps intent to workflow file via numeric option + keyword synonyms.
Each workflow self-contained — adding capability = adding a file, not modifying existing ones.
Must handle "none of the above" case. Include "follow it exactly" instruction to prevent LLM improvisation.

### Sequential Pipeline

Ordered dependent steps; output of N feeds N+1. Skipping steps produces bad results.
Auto-detection logic resumes from partial progress (check existing artifacts before restarting).
Each step documents own entry/exit criteria. Ask user only when correct action is ambiguous (e.g., stale artifacts).

### Linear Progression

Fixed numbered phases, no branching. Every execution follows same path.
Entry/exit criteria on every phase. Actions numbered within phases.
If branching needed — wrong pattern; use Routing or Pipeline instead.
Simplest pattern; use when single path suffices.

### Safety Gate

Critical checkpoints before destructive/irreversible actions. Two gates minimum:
1. Present complete analysis — user reviews categorized plan
2. Show exact commands — user confirms execution

Analysis MUST complete before any gate. Execute each action individually (partial failure tolerance).
Report phase shows what changed and what was left untouched.

### Task-Driven

Parallel independent tasks with fan-out/fan-in. Dependencies declared upfront via blockedBy/blocks.
Each task independently completable. Failed tasks block dependents but not unrelated work.
Check for newly unblocked tasks after each completion. Progress visible and resumable.
Overhead only justified for complex dependency graphs — not for linear flows.

## Dispatch Taxonomy

| Type | Definition | Audit |
|------|-----------|-------|
| Checklist (C) | All listed agents fire | Artifact count == agent count |
| Routing (R) | Input determines agent(s) | Classification logged + artifact exists |
| Gated (G) | Phase condition; inner C/R when open; zero-dispatch when closed | Gate outcome in Phase Trace |

`G -> C` = gated then checklist (apply inner audit). Reactive = gated by prior output.

## Anti-Patterns

| ID | Anti-Pattern | Fix |
|----|-------------|-----|
| AP-1 | No goals/anti-goals — skill activates for wrong tasks | Add When to Use AND When NOT to Use with named alternatives |
| AP-2 | Monolithic SKILL.md >5000 tokens — LLM loses focus | Split into references/ and workflows/ |
| AP-3 | Reference chains (A->B->C) — context breaks | All files one hop from SKILL.md |
| AP-4 | Unnumbered phases — unreliable execution order | Number every phase with entry/exit criteria |
| AP-5 | Missing exit criteria — "done" undefined | Define completion condition per phase |
| AP-6 | No verification step — errors undetected | Add validation at end of every workflow |
| AP-7 | Vague routing keywords — wrong workflow selected | Use distinctive keywords per route |
| AP-8 | Bash/Shell for file ops — fragile encoding/permissions | Use Glob/Grep/Read/Write/Edit/StrReplace instead |
| AP-9 | Overprivileged tools — unnecessary attack surface | List only tools instructions actually reference |
| AP-10 | Vague subagent prompts — garbage output | Specify what to analyze, look for, and return |
| AP-11 | Reference dumps — raw docs instead of judgment | Teach decision-making, not documentation |
| AP-12 | No concrete examples — ambiguous instructions | Show input->output for key directives |
| AP-13 | Cartesian product tool calls (N files x M patterns) | Combine patterns into single regex, filter results |
| AP-14 | Unbounded subagent spawning — one per file | Batch items into groups, one subagent per batch |
| AP-15 | Description summarizes workflow steps | Description = triggering conditions only |
| AP-16 | Phase without Phase Trace entry — zero-dispatch leaves no audit trail | Every phase logs to Phase Trace — including zero-dispatch |
| AP-17 | Completion without phase coverage check — phases execute but completion doesn't verify | Gate completion on Phase Trace row count == declared phases |
