# Prose Quality: Anti-Slop Rules

Applies to human-facing prose (docs, READMEs, user-facing content).
Not applicable to AI-consumed artifacts (skill refs, agent files) where telegraphic prose is preferred.
For changelogs and commit messages, apply Delete group only.

## Delete

Remove — no replacement needed.

| Detect | Action |
|--------|--------|
| Adverbs: really, just, literally, genuinely, honestly, simply, actually, -ly fillers | Delete the word. Sentence works without it. |
| Throat-clearing: "Here's the thing", "The truth is", "Let's be honest", "Look," | Delete. Start with the actual point. |
| Emphasis crutches: "Full stop", "Let that sink in", "Period." | Delete. Content carries its own weight. |
| Meta-commentary: "As we'll see", "This matters because", "Here's what I mean" | Delete. Proceed to content directly. |

## Replace

Swap for a specific alternative.

| Detect | Fix |
|--------|-----|
| False agency: "the data tells us", "the market rewards", "the decision emerges" | Name the human actor: "we concluded", "buyers prefer", "the team decided" |
| Passive voice: "was created by", "is handled by", "gets resolved" | Put actor first: "X created", "Y handles", "Z resolves" |
| Vague declaratives: "significant improvement", "various factors" | State the number. Name the factors. |

## Restructure

Sentence rewrite required.

| Detect | Fix |
|--------|-----|
| Binary contrast: "Not X. But Y.", "The answer isn't X. It's Y." | State the claim directly. One sentence, positive framing. |
| Wh- starters: "What makes this hard is...", "Where this breaks down..." | Lead with subject-verb: "This is hard because..." |

## Principles

- Avoid em-dashes as dramatic reveal devices ("The real problem — nobody talks about this — is..."). Parenthetical em-dashes are fine.
- Trust readers. Skip softening qualifiers ("It's worth noting that...").
- Every sentence advances the document's purpose. If removing it changes nothing, remove it.
