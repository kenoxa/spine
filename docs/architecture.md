# Architecture

> Why Spine is structured the way it is, and what the research says about each decision.

Spine routes coding tasks through a three-phase workflow with specialized subagents, graduated evidence requirements, and cross-provider verification. This document explains the rationale behind each architectural pattern, grounded in 2023--2026 multi-agent and software engineering research.

## Three-Phase Workflow

Spine separates every task into **discuss, plan, and execute** phases with gates between them.

**Planning before coding works.** The Self-Planning study (Jiang et al. 2024) measured 11--25% relative improvement in Pass@1 when LLMs generate an explicit plan before writing code. PlanSearch demonstrated that searching through plan space reaches 77% versus 60.6% pass@200 on LiveCodeBench. GitHub's internal testing found GPT-5 and Claude Sonnet 4 achieved 15% better success rates when using a planning workflow versus unstructured agent mode. The Bot-with-Plan study showed that separating planning from execution allows 7B models to perform at GPT-4 planning level. The evidence for plan-then-execute is among the strongest in the entire multi-agent literature.

**Execution-based verification is the highest-value pattern.** Phase gates earn their cost when they verify through execution. The TDAD study found baseline agents caused 6.5 broken tests per patch (562 pass-to-pass failures across 100 SWE-bench instances) without execution feedback. Static analysis feedback alone reduced GPT-4 vulnerability rates from 40.2% to 7.4%. In contrast, LLM-based review without execution is unreliable --- LLMs score under 0.3 F1 on self-detecting security vulnerabilities (MAST study). Every successful production tool (Devin, Codex, Cursor) depends on sandboxed execution with iterative feedback, not multi-agent debate.

**Discussion adds value for novel tasks.** No production coding tool implements a pre-planning exploration phase, and the Waterfall multi-agent study found that Requirement and Design stages had "comparatively modest effects" on correctness. Busemeyer's deliberation research from cognitive science explains when exploration pays off: when tasks are novel and prior knowledge is low. Recognition-primed decision-making outperforms deliberation for routine tasks. Spine addresses this through adaptive routing --- the discuss phase uses confidence-gated intake to redirect routine tasks directly to planning, preserving exploration value for the roughly 20% of tasks that are genuinely ambiguous while eliminating overhead for the rest.

## Quality Phase

The execute phase runs a quality gate with a specific composition: **2 analysts + 1 inspector + 1 verifier + 1 envoy = 5 agents**, followed by a sequential synthesizer.

**Two reviewers, not three.** Porter, Siy, Toman, and Votta's Bell Labs experiment --- the most rigorous controlled study on inspection team size --- found that inspection teams of more than two reviewers found no additional significant defects. Dos Santos and Nunes (2018) confirmed this with 201 developers: more than two active reviewers does not significantly improve comment density. However, the same Porter study found that two sequential sessions outperformed one, supporting sequential gating in principle. This is why Spine uses a single parallel batch followed by sequential synthesis, rather than multiple review passes.

**The verifier absorbs spec and correctness review with E3 probes.** The verifier combines structural review with targeted execution --- a two-part process that first reviews, then runs specific probes to confirm behavior. This merges the two most valuable review perspectives (does it match the spec? does it work correctly?) into one agent that can produce E3 evidence. Only 13% of inspection findings in the Bell Labs study were actual bugs, which means review gates must be precision-calibrated. The verifier's execution capability filters noise.

**The risk inspector stays read-only.** A dedicated inspector examines risk surfaces (security, breaking changes, data integrity) without executing code. This separation follows from the Bell Labs finding that sequential passes with different focus areas outperform single comprehensive reviews.

**The envoy provides holistic cross-provider review.** A different model from a different provider examines the changes. The rationale is covered in the cross-provider section below.

**Analysts are advisory-only.** The two analysts (conventions, complexity) produce observations that inform the synthesizer but carry no gate authority. Their findings require E2+ evidence to be promoted to blocking status. This prevents low-confidence style opinions from blocking implementation.

**The mainthread gates PASS/BLOCK after synthesis.** The synthesizer merges all five outputs into a single assessment. The mainthread --- not any individual subagent --- holds sole gate authority for the final PASS or BLOCK decision.

## Evidence Gating

Spine requires graduated evidence for claims, tagged E0 through E3:

- **E0** --- intuition or best practice. Advisory only; never blocks a decision alone.
- **E1** --- documentation reference with path and quote.
- **E2** --- code reference with file and symbol.
- **E3** --- executed command with observed output.

Blocking claims require E2+. Verification claims require E3.

**Without execution feedback, agents break things.** The TDAD study is the most direct evidence: 6.5 broken tests per patch without execution feedback. Static analysis feedback reduced vulnerability rates from 40.2% to 7.4%. METR found approximately 50% of SWE-bench-passing patches would not be merged by real maintainers --- patches that pass automated tests can still be wrong, but patches without any execution verification are far worse.

**This parallels evidence-based medicine.** The EBM hierarchy --- from expert opinion (lowest) through randomized controlled trials to systematic reviews (highest) --- transformed medical decision-making over three decades by requiring stronger evidence for higher-stakes claims. Spine's E0--E3 maps to the same principle: opinions inform, but decisions require proof. The specific risk is over-gating --- requiring E3 for every claim creates bottlenecks when execution is expensive. Spine mitigates this by requiring E3 only for blocking and verification claims, accepting E2 for non-blocking observations.

**Early defect detection has outsized payoff.** Fagan inspection research demonstrates a 30:1 payback ratio for early defect detection, and finding defects later costs 10--100x more. Evidence gating at phase boundaries catches defects early, before they compound through implementation.

## Multi-Perspective Analysis

Spine's plan phase dispatches three debaters (thesis champion, counterpoint dissenter, tradeoff analyst) plus a cross-provider envoy. These agents use **distinct analytical frameworks**, not adversarial debate framing.

**Adversarial debate hurts coding performance.** The ICLR 2025 systematic review tested 5 debate frameworks across 9 benchmarks. On MBPP, all debate methods scored lower than single-agent chain-of-thought. On HumanEval, Du et al.'s debate scored 68.09% versus 78.05% for CoT --- debate actively reduced performance. The Multi-Persona adversarial framing (angel/devil) was consistently the worst method tested, sometimes catastrophically (10.3% on MATH with Llama 3.1-8b versus 40.13% for CoT). Wu et al. (2025) demonstrated that debate cannot exceed the accuracy of its strongest participant --- it is fundamentally an ensembling technique with a hard ceiling. Kim et al. (2025) found that when single-agent accuracy exceeds approximately 45% on non-decomposable tasks, adding agents likely degrades performance, and on sequential reasoning tasks, all multi-agent variants degraded performance by 39--70%.

**Heterogeneous analytical frameworks outperform adversarial framing.** The A-HMAD study (2025) showed heterogeneous agents with distinct roles (Solver, Checker, Guru) achieve 4--6% absolute accuracy gains over standard debate. The key difference: each agent embodies a genuinely different analytical perspective rather than being instructed to "argue against." Charlan Nemeth's research confirms that designated devil's advocates are less effective than genuine dissenters --- agents need different frameworks, not role-played opposition. The M3MAD-Bench study (2026) identified "collective delusion" --- all agents converging on a wrong answer through debate --- as a primary failure mode that distinct analytical roles help prevent.

**3--4 agents is the optimal count.** Google DeepMind's 180-configuration controlled experiment found per-agent reasoning capacity becomes "prohibitively thin beyond 3--4 agents" under fixed computational budgets. Communication cost dominates reasoning capability beyond optimal message density (c*=0.39 messages/turn). Debate accuracy peaks at 2--3 rounds and degrades at 4--5 rounds. Spine's 3 debaters + 1 envoy sits at the empirically supported sweet spot.

## Cross-Provider Envoy

The envoy dispatches to a different AI provider (Claude, GPT, Gemini, Qwen) for an independent perspective. This is not optional diversity --- it is always multi-provider.

**Model heterogeneity is the strongest positive finding in multi-agent research.** Heterogeneous agents using different foundation models yield 91% versus 82% accuracy on GSM-8K. EnsLLM's 14-model ensemble achieves 90.2% on HumanEval versus GPT-4o's 83.5% single-model baseline --- a +6.7% absolute gain. The "Stop Overvaluing Multi-Agent Debate" position paper (NeurIPS 2025) identifies model heterogeneity as the "universal antidote" for multi-agent debate limitations. Different training data, architectures, and RLHF processes produce genuinely different failure modes --- Sonar 2026 data shows 4x variation in error types (resource leaks, control flow mistakes) across providers.

**Diversity at verification, not generation.** For coding specifically, Archon (Stanford) found that test-based verification produces a 44.3% improvement where model ensembling showed "limited impact." Self-MoA research (Li et al. 2025) found that multiple samples from a single top model outperform mixtures of different models by 3.8--6.6% on general quality. The reconciliation: model diversity adds the most value when models evaluate each other's work rather than when they generate competing solutions. Spine uses the envoy for review and challenge, not for alternative implementation generation.

**Weak models degrade strong outputs.** "Talk Isn't Always Cheap" (2025) warns that introducing a weaker model into debate with a stronger one can degrade outcomes below the strong model's solo performance through sycophancy effects. The envoy dispatches to models of comparable capability (Standard tier), not weaker alternatives.

## Thin Orchestrator and Synthesizer Firewall

The orchestrator skill (mainthread) never reads full subagent outputs. It dispatches a synthesizer with file paths and reads only the synthesized result.

**Separate synthesizers outperform last-worker output.** Chain-of-Agents (NeurIPS 2024) found that using the last worker to directly generate final output leads to performance drops. A dedicated synthesizer, processing all worker outputs together, produces measurably better results. This validates Spine's pattern of dispatching a synthesizer as a distinct step after parallel subagent work.

**Information degrades through chained communications.** The telephone game literature confirms that content degrades when passed through multiple agents in sequence. Some models collapse to cosine similarity of 0.19 within 30 paraphrase steps. The thin orchestrator pattern limits chain length: subagents write to files, the synthesizer reads those files, and the orchestrator reads only the synthesis. No information passes through more than two hops. AgentTaxo found that 72% of tokens in multi-agent systems go to verification --- the "communication tax" is real, and the firewall limits it.

**Context bleed is the primary cause of instruction forgetting in large skills.** When orchestrators read full subagent outputs into their context, downstream behavior drifts. The firewall prevents this: the orchestrator's context contains only dispatch instructions and synthesized summaries, never raw subagent reasoning. Cognition (Devin's creators) identified this problem directly: "context isn't able to be shared thoroughly enough" in multi-agent systems.

## Agent Tier System

Each subagent role has an assigned model tier. The tier determines the model automatically --- users configure only their session model.

| Tier | Agents | Rationale |
|------|--------|-----------|
| **Frontier** | planner, debater, inspector, verifier | Gate authority. Quality of judgment must exceed quality of implementation. |
| **Standard** | analyst, researcher, navigator, framer, visualizer, envoy | Advisory and research. Pattern matching without gate authority. |
| **Fast** | scout, miner | Reconnaissance and extraction. Speed over depth. |
| **Adaptive** | implementer, synthesizer | Tracks the user's session model. Respects the user's quality/cost choice. |

**Gate authority requires frontier reasoning.** The planner, debaters, inspector, and verifier make decisions that constrain all downstream work. A plan approved by a weaker model than the one implementing it inverts the quality hierarchy --- the gate becomes less rigorous than the work it gates. Frontier models (Opus, GPT-5.4) at these roles ensure that the hardest reasoning happens at decision points, not at implementation.

**Implementation tracks the session model.** The implementer and synthesizer use Adaptive tier, inheriting whatever model the user chose for their session. If a user runs on Sonnet for cost efficiency, their implementer uses Sonnet. If they upgrade to Opus for a complex task, the implementer upgrades with them. This respects the user's cost/quality tradeoff without forcing frontier prices for routine implementation.

**Fast agents handle reconnaissance.** Scouts and miners search files, extract patterns, and gather context. These tasks are bounded and factual --- model quality matters less than speed and token efficiency.

Provider-specific mappings are documented in [model-selection.md](model-selection.md).

## Adaptive Routing

The discuss phase classifies task complexity at intake and routes accordingly.

- **Routine tasks** (clear requirements, small scope, no ambiguity) skip discuss and go directly to `do-plan`.
- **Ambiguous tasks** (vague problem statements, novel domains, multiple valid approaches) run the full discuss workflow.

**Routing by complexity reduces cost without sacrificing quality.** Google's hybrid SAS-MAS study (2025) found that routing simple tasks to single agents and complex tasks to multi-agent pipelines improved accuracy by 1--12% while reducing costs by up to 20%. The insight: not every task needs multi-agent coordination. Routine single-file edits with clear specifications gain nothing from a seven-phase discussion --- they need a plan and an implementation.

**Capability saturation limits multi-agent value.** Kim et al. (2025) established a capability saturation threshold at approximately 45% single-agent accuracy, beyond which adding agents yields diminishing or negative returns. Frontier models now achieve 78--81% on SWE-Bench Verified with minimal scaffolding --- well past the saturation point for most coding tasks. Multi-agent coordination adds the most value for tasks where a single agent struggles, which increasingly means novel architectural decisions rather than routine implementation.

**The discuss phase handles the long tail.** The roughly 20% of tasks that are genuinely ambiguous --- unclear requirements, competing architectural approaches, unfamiliar codebases --- benefit from structured exploration before planning. Busemeyer's deliberation research confirms that exploration adds maximal value when prior knowledge is low. Spine's adaptive intake preserves this value without imposing the cost on every task.

## Research Context

The decisions above draw on a body of 2023--2026 research. Several cross-cutting findings shaped the overall architecture.

**Orchestration failures dominate.** Cemri et al. (2025) analyzed 1,642 execution traces and found that orchestration failures account for 36.9% of all multi-agent system failures. The MAST framework study found 79% of multi-agent failures stem from specification and coordination issues, not capability gaps. Every additional agent and phase adds to this failure surface. Spine mitigates orchestration risk through the thin orchestrator pattern, self-contained subagent prompts, and file-based communication rather than chained message passing.

**Multi-agent systems are expensive.** Multi-agent token consumption runs 4--220x higher than single-agent baselines (Gao et al. 2025). Heavy multi-agent sessions can exhaust Claude Code Max's Opus budget in 2--3 days and Cursor Pro credits in a single day. Spine's tier system, adaptive routing, and Standard-tier defaults keep costs manageable for daily use.

**Production tools converge on simplicity.** Devin, Codex CLI, Cursor, Windsurf, and Augment all default to single-agent architectures with tool access. None use adversarial debate or systematic cross-provider verification. Copilot Workspace uses the most structured pipeline (spec, plan, implement, validate) but with human review gates, not agent review gates. The pattern production tools converge on: one capable agent, good context, execution feedback, human oversight. Multi-agent features in these tools (Cursor's parallel agents, Codex's optional subagents) target task parallelism --- multiple independent tasks --- not quality improvement on a single task.

**The gap between single-agent and multi-agent narrows as models improve.** The multi-agent accuracy advantage has shrunk from approximately 10% to approximately 3% as frontier models improved (Gao et al. 2025). Wang et al. (ACL 2024) showed that multi-agent discussion outperformed single agents only when prompts lacked demonstrations --- multi-agent coordination is partly a workaround for inadequate prompting, not an inherent advantage. The "When Single-Agent with Skills Replace Multi-Agent Systems" study found compiled single-agent systems achieve accuracy within -2.0% to +4.0% of multi-agent systems while reducing token consumption by 53.7% and latency by 49.5%.

**Spine's bet is on the composition, not the count.** The individual patterns --- phased execution, evidence gating, heterogeneous models, thin orchestration --- each have independent empirical support. The risk is in their combination: whether the overhead of composing them exceeds the sum of their individual benefits. No study directly evaluates this composition. Spine-specific ablation studies --- running the full pipeline versus stripped versions on standardized task sets --- would resolve open questions more definitively than any external research.

## Key Citations

| Short name | Full reference | Used for |
|------------|---------------|----------|
| Self-Planning | Jiang et al. 2024 | 11--25% improvement from planning |
| ICLR 2025 review | Systematic review, 5 debate frameworks, 9 benchmarks | Debate vs. CoT on coding |
| A-HMAD | 2025, heterogeneous multi-agent debate | 4--6% gains from distinct roles |
| Porter et al. | Bell Labs inspection experiment | >2 reviewers find no more defects |
| TDAD | Test-driven agent development study | 6.5 broken tests/patch without execution |
| Chain-of-Agents | NeurIPS 2024 | Separate synthesizer outperforms last worker |
| EnsLLM | 14-model ensemble study | 90.2% vs 83.5% from model diversity |
| Archon | Stanford, multi-agent architecture search | 44.3% gain from test verification vs. ensembling |
| Kim et al. 2025 | Capability saturation study | 45% threshold, 39--70% degradation |
| Google SAS-MAS | Hybrid routing study, 2025 | +1--12% accuracy, 20% cost reduction |
| Cemri et al. 2025 | 1,642 execution trace analysis | 36.9% orchestration failures |
| Gao et al. 2025 | Multi-agent scaling study | 4--220x token consumption, narrowing gap |
| Fagan inspections | Software inspection research | 30:1 payback ratio for early detection |
| M3MAD-Bench | 2026, multi-model debate benchmark | Collective delusion failure mode |
| Busemeyer | Cognitive deliberation research | Exploration value when prior knowledge is low |
| Sonar 2026 | Cross-provider error analysis | 4x variation in error types |
| Self-MoA | Li et al. 2025 | Single-model sampling vs. mixed models |
| Nemeth | Dissent research | Designated adversaries vs. genuine dissenters |
