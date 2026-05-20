# Template: Hardening

**When**: existing codebase has gaps in test coverage, CI hygiene, security posture, or supply chain integrity — every fix needs a regression guardrail in the same change.

**Not for**: watching external events (CI pipelines, deploys, long-running jobs) — `/goal` Stop hooks re-fire on polling with no productive work between fires. Use `/loop` or `gh run watch` instead.

**Must-ask inputs**: `[scope]`, `[risk_threshold]`. Everything else below is a scaffold — adapt it to the task.

```
GOAL:
Raise the floor on test coverage, CI pinning, security posture, or supply chain integrity in [scope], with regression guardrails in place for every fix.

CONTEXT:
Existing codebase with gaps in test coverage, CI hygiene, security posture, or dependency hygiene.
Scope: [scope].
Risk threshold: [risk_threshold] — gaps above this trigger action; below are accepted or deferred.

CONSTRAINTS:
Every change includes the regression-preventing guardrail, not just the fix.
For test hardening: write the failing test before the fix.
For CI: pin every action, every base image, every dependency. No floating tags.
For supply chain: enumerate direct and transitive dependencies. Flag unmaintained, deprecated, or CVE-affected.

PRIORITY:
1. Highest blast-radius gaps closed first
2. Regression guardrails confirmed working
3. No floating tags or unpinned dependencies left in scope

PLAN:
Inventory current coverage in the specified scope.
Classify each gap by blast radius: one user, one tenant, all users, money, security, regulatory exposure, or reputational exposure.
Prioritize gaps by blast radius descending.
For each gap: implement the fix and the guardrail in the same change. Confirm the guardrail fails on the original gap before the fix lands.

DONE WHEN:
Every gap above the risk threshold has been closed or explicitly accepted.
Every fix has a corresponding guardrail (test, lint rule, CI check, dependency pin).
The guardrail was confirmed to fail on the original gap before the fix landed.
No floating tags or unpinned dependencies remain in the hardened scope.
A regression of the original gap would be caught automatically.

VERIFY:
Run the guardrail against the pre-fix state. Confirm it fails.
Run the guardrail against the post-fix state. Confirm it passes.
State any guardrail that could not be confirmed and why.

OUTPUT:
Current-state inventory.
Gap report with blast-radius classification.
Priority-ordered hardening plan.
First hardening diff plus the guardrail.

STOP RULES:
Halt on gaps that require a product decision to accept or close.
Surface ranked proposals when multiple guardrail shapes are valid.
Do not land a fix without its guardrail in the same change.
```
