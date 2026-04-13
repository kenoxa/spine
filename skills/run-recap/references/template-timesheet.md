# Template: Timesheet

Format-specific prompt template for `@miner` timesheet dispatch. Combined with [dispatch-preamble.md](dispatch-preamble.md) at dispatch time.

## Prompt

```
Produce a billable timesheet from AI-assisted work sessions.

{preamble}

## Duration & Time Rules
- Time slots strictly within 09–17; never outside this window
- Every working day in output must total exactly **8h** (Total: 8h)
- If estimated session data for a day is < 8h, extend the primary customer project entry to fill to 8h
- Consolidate sub-hour same-project sessions; round to whole hours (min 1h per entry)

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

## Description Rules
Entries are for billing. Never mention internal tooling: do not name `do-plan`, `run-advise`, `envoy`, `Exa`, `Context7`, `subagent`, `@miner`, `handoff`, `SKILL.md`, skill names, or internal file paths.

Describe the **outcome and nature of work**:
- ✓ `Security audit: authentication module review across 24 files`
- ✗ `run-review with 5 envoy advisors on auth-hardening diff`

`spine` sessions → label as: `Internal R&D: AI development platform — [brief topic]`

## Multi-Day Themes
When multiple days show the same project with related work, use a consistent theme prefix:
- Identify the overarching customer-initiated initiative
- Apply the same prefix across those days (e.g. all days in a release week: `Release 3.0.0-rc.1: …`)

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
