# Template: Consolidation

**When**: a subsystem contains multiple parallel implementations of overlapping logic (auth, state, SDK wrapper, component library) and the user wants one canonical version with all callers migrated.

**Not for**: watching external events (CI pipelines, deploys, long-running jobs) — `/goal` Stop hooks re-fire on polling with no productive work between fires. Use `/loop` or `gh run watch` instead.

**User-specific slots**: `[subsystem]`, `[canonical_choice]` (specified or sentinel `"recommend after inventory"`).

```
GOAL:
Collapse parallel implementations of [subsystem] into a single canonical implementation with all callers migrated and the non-canonical versions deleted.

CONTEXT:
Subsystem contains multiple implementations of overlapping logic in [subsystem].
Canonical choice: [canonical_choice] — user-specified or recommend after inventory.
Callers may span team or org boundaries.

CONSTRAINTS:
Preserve every behavior the legacy implementations had, including bugs callers depend on. Flag these explicitly.
Delete non-canonical implementations only after all callers are migrated and the test suite passes.
Migrate callers in dependency order. Leaf modules first, then parents.

PRIORITY:
1. Behavior preservation across all callers
2. Complete deletion of non-canonical implementations
3. No new duplication introduced by the migration

PLAN:
Inventory every parallel implementation. Output a comparison table: behavior, edge cases, callers.
Identify the canonical implementation: most complete, most tested, most idiomatic.
Map every caller of each non-canonical implementation.
Identify the ownership boundary of each caller. Cross-team callers require sign-off from affected owners before deletion.
Migrate callers in dependency order, smallest blast radius first.
Restate behavior-preservation flags before each migration.

DONE WHEN:
All callers migrated to the canonical implementation.
Test suite green across all migrated callers.
Cross-team caller migrations have explicit owner sign-off recorded.
Non-canonical implementations fully deleted, not commented out.
Behavior-preservation flags resolved (kept-as-bug or fixed-with-approval).
No new duplication introduced.

VERIFY:
Run build and full test suite after each caller migration.
Confirm deleted implementations have no remaining references via grep or symbol search.
Confirm cross-team sign-offs are documented.
State any behavior that could not be verified preserved and why.

OUTPUT:
Implementation inventory table.
Canonical-choice rationale.
Caller migration order with ownership boundaries marked.
First migration diff and its rollback.

STOP RULES:
Halt when behavior across implementations diverges in a way that cannot be reconciled without a product decision.
Halt when a caller crosses a team boundary and owner sign-off has not been obtained.
Surface ranked proposals when the canonical choice is ambiguous.
Do not delete a non-canonical implementation until every caller is migrated and verified.
```
