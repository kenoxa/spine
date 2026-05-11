# Template: Timesheet

Format-specific prompt template for `@miner` timesheet dispatch. Combined with [dispatch-preamble.md](dispatch-preamble.md) at dispatch time.

## Prompt

```
Produce a billable timesheet from AI-assisted work sessions.

{preamble}

## Duration & Time Rules
- Time slots strictly within 09–17; never outside this window
- Every working day in output must total exactly **8h** (Total: 8h)
- **Grand total = number of working days in range × 8h** — never calendar days
- If estimated session data for a day is < 8h, extend the primary customer project entry to fill to 8h
- Consolidate sub-hour same-project sessions; round to whole hours (min 1h per entry)
- **Hard-pinned entries** (from `--note` args): reproduce verbatim — date, time slot, description. These consume their stated hours within the 8h day. Never reposition for "fit".

## Project Attribution & Allocation
Do not collapse smaller customer project work into the dominant repo just because one repo has more sessions.

For every working day, preserve a meaningful block for each customer project that has explicit evidence from sessions, prompts, files, or same/adjacent-day commits. If a day contains a large customer project plus a smaller release/support project with explicit evidence, keep both and allocate realistic blocks (often 1-3h for the smaller project) instead of rounding it away.

If a project has both explicit sessions and git commits on a day, it must remain visible unless a hard-pinned note consumes the day. Release/backport days should look release/backport-heavy when commits or prompts show release preparation, compatibility backports, packaging, startup, licensing, or supported-platform work.

Treat release distribution repos/domains (`dl.identity-hub.io`, package registries, download-site repos) as release work for the product being published, not as separate internal work.

## Non-Working Day Redistribution
Non-working days: all Saturdays, Sundays, and Berlin public holidays.

Berlin Feiertage (recurring): Neujahr (Jan 1), Frauentag (Mar 8, Berlin only), Karfreitag, Ostermontag, Tag der Arbeit (May 1), Christi Himmelfahrt, Pfingstmontag, Tag der Deutschen Einheit (Oct 3), 1. Weihnachtstag (Dec 25), 2. Weihnachtstag (Dec 26).

Redistribution rules:
- Saturday → preceding Friday
- Sunday → following Monday
- Holiday on weekday → nearest working day (prefer day before)
- Merge into existing entries on target day (total still 8h — work happened over the non-working day but billed on the workday)
- Annotate target day header: `_(+DD.MM (Wochentag/Feiertag))_`

## Customer vs Internal R&D Priority
When a day has both customer project and `spine` (internal R&D):
- **Small** customer task (≤ 3h raw): customer 09–15, R&D 15–17 (max)
- **Medium** (4–5h) / **Large** (6–7h) / **Huge** (8h): customer fills full 8h; no R&D entry
- Never split a substantial task (refactor, security audit, performance investigation, release prep) across customer + R&D on the same day

## Final Pass: R&D Exclusion
After drafting the full timesheet, scan every day:
- If combined **customer work ≥ 4h** on a day, remove all R&D entries for that day and extend customer to fill 8h
- Apply this rule last — after redistribution, consolidation, and theme grouping

## Description Rules
Entries are for billing. Never mention internal tooling: do not name `do-plan`, `run-advise`, `envoy`, `Exa`, `Context7`, `subagent`, `@miner`, `handoff`, `SKILL.md`, skill names, or internal file paths.

Describe what the customer gets, not the internal process. Every line should answer: "What customer-visible problem did this work improve, validate, or unblock?"

Forbidden generic/internal labels unless translated into customer value:
- `benchmark review`
- `release-baseline follow-up`
- `phase planning`
- `blocker review`
- `alias allocation review`
- `handoff`
- skill, subagent, or tool names

Translate internal work into customer-facing outcomes:
- `benchmark review` → `validated performance for high-cost customer search patterns`
- `alias allocation review` → `refined SQL generation for complex search shapes`
- `release-baseline follow-up` → `checked release behavior against customer-like workloads`
- `planner refactor` → `prepared search planner refactor to keep complex queries maintainable and reliable`

Describe the **outcome and nature of work**:
- ✓ `Security audit: authentication module review across 24 files`
- ✗ `run-review with 5 envoy advisors on auth-hardening diff`

`spine` sessions → label as: `Internal R&D: AI development platform — [brief topic]`

### Scenario-First Product Wording
For product engineering work, prefer the customer scenario over the internal component. For Identity-Scribe/search-planner work, name the query behavior:
- compound prefix searches with ordering
- multi-attribute directory searches
- cursor continuation and first-page behavior
- substring or starts-with searches on indexed attributes
- release comparison under customer-like data volumes
- regression checks for slow query shapes

Good:
- `identity-scribe: validated fast first-page behavior for compound prefix searches with ordering`
- `identity-scribe: refined routing for multi-attribute directory searches to avoid slow customer-facing queries`

Bad:
- `identity-scribe: benchmark review and release-baseline follow-up`

### Release & Backport Wording
For release-heavy products such as Karma, describe release value directly:
- release preparation and validation
- compatibility backports
- supported platform updates
- customer environment fixes
- packaging/download validation
- license or startup failure investigation

Good:
- `karma/karma: Karma v2.43.1 / v2.43.2-rc.0 release work: RHEL 8.10 compatibility, LDAP TLS startup fixes, and packaging validation`
- `karma/karma: backported platform compatibility fixes and updated customer-facing supported OS guidance`

Bad:
- `karma/karma: customer response and compatibility notes`

## Multi-Day Themes
When multiple days show the same project with related work, use a consistent theme prefix:
- Identify the overarching customer-initiated initiative
- Apply the same prefix across those days (e.g. all days in a release week: `Release 3.0.0-rc.1: …`)

Avoid repeating the same generic phrase across multiple days. Reuse a theme prefix only when each day still names the specific customer-visible scenario, release, compatibility target, regression risk, or validation outcome.

## Final Description Lint
Before writing the final output, run this private lint pass and rewrite failures:
- No repeated generic phrases across multiple days
- No forbidden/internal labels from Description Rules
- Every line names the actual product scenario, release value, customer environment, or customer-visible risk
- Internal implementation details are allowed only after translation into customer value
- If a line could apply to any software project, rewrite it with the project-specific scenario or release/backport detail

## Output Format
Group by date (most recent first):
- `### YYYY-MM-DD (Weekday)` (append redistribution annotation if applicable)
- `HH-HH  project-name: task description`
- `**Total: 8h**` per day (always exactly 8h)
- Grand total at bottom

### Worked Example
Input: Claude, ~45 min, project "spine", brief_summary "Add recap skill"; customer "identity-scribe", ~6h, "Security audit: auth module"
→ Large customer task → identity-scribe fills full 8h:

    9-17  identity-scribe: Security audit: authentication module review
    **Total: 8h**

### Example Output

    ### 2026-03-12 (Thursday) _(+15.03 (Samstag))_
    9-15  identity-scribe: Release 3.0.0-rc.1: final integration and smoke testing
    15-17 spine: Internal R&D: AI development platform — recap skill implementation
    **Total: 8h**

    ### 2026-03-11 (Wednesday)
    9-17  identity-scribe: Release 3.0.0-rc.1: build pipeline validation and artifact publishing
    **Total: 8h**

    **Grand total: 16h**

All estimated → append: "Note: All durations are estimates based on session activity."
No sessions → "No AI sessions found in the last {date_range}."

Write complete output to {output_path}.
```
