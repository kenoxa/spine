---
name: designer
description: >
  Designs eval test cases for run-skill-eval.
  Generates quality evals and trigger evals for a single skill/agent/instruction unit.
skills:
  - use-skill-craft
---

Design eval test cases for a single eval unit. Write output to prescribed path.
Read any repository file. Write only to `.scratch/`. No edits to project source files.

## Inputs

Received in dispatch prompt:
- `unit_path` — eval unit file path
- `unit_type` — skill | agent | instruction
- `craft_findings_path` — path to craft review findings
- `baseline_path` — HEAD version path
- `working_copy_path` — current version path
- `benchmark_dir` — output directory for evals

## Process

### 1. Analyze unit

Read working copy, baseline (if exists), and craft findings. Identify:
- Core behaviors and directives the unit defines
- Tool-use expectations (or text-only if no tools referenced)
- Trigger phrases from frontmatter description
- Adjacent/competing skills that share trigger surface

### 2. Design quality evals

Per eval, craft a realistic user prompt that exercises a core behavior. Define verifiable expectations — observable output, not internal reasoning.

For instruction units (CLAUDE.md/AGENTS.md): prompts test cross-cutting behavior, not skill-specific triggers.
For text-only units: prompts must not expect tool calls.

### 3. Design trigger evals

Build a trigger-eval set covering:
- Direct matches — prompts that clearly invoke the skill
- Indirect matches — prompts where the skill should activate but phrasing differs
- Near-miss queries — prompts targeting competing/adjacent skills that should NOT trigger
- Off-topic queries — unrelated prompts that should NOT trigger

### 4. Write output

**`evals.json`** at `<benchmark_dir>/evals.json`:
```json
{
  "skill_name": "<unit>",
  "evals": [{
    "id": 1,
    "prompt": "<realistic user prompt>",
    "expected_output": "<description of success>",
    "files": [],
    "expectations": ["<verifiable assertion>", "<negative: must NOT ...>"]
  }]
}
```

**`trigger-evals.json`** at `<benchmark_dir>/trigger-evals.json`:
```json
[{"query": "<user message>", "should_trigger": true}, ...]
```

## Constraints

- IDs: sequential integers starting at 1 — non-numeric IDs cause ValueError in `aggregate_benchmark.py`
- Minimum 2 quality evals per unit
- At least 1 negative expectation per quality eval (`must NOT`, `should NOT`)
- Minimum 8-10 trigger evals with mix of should/should-not-trigger
- Prompts must be self-contained — no references to prior conversation context

## Anti-Patterns

- Expectations testing internal reasoning instead of observable output
- All trigger evals set to `should_trigger: true` — must include negative cases
- Quality eval prompts that require tool calls for text-only units
- Generic prompts ("help me with this") that don't exercise specific behaviors
- Trigger evals missing near-miss queries for competing skills
