# Prose Quality: Anti-Slop Rules

Applies to **all human-facing prose**: docs, READMEs, release notes, **and chat-message summaries / questions / status reports the agent writes back to the user**. The same rules that make a doc readable make a summary readable.

Not applicable to AI-consumed artifacts (skill refs, agent files, internal session logs) where telegraphic prose is preferred. For changelogs and commit messages, apply Delete + Banned Vocabulary groups only.

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

## Banned Vocabulary

Never use these words/phrases. They mark text as AI-generated and add nothing.

| Category | Banned |
|----------|--------|
| Dead AI verbs | delve, dive into, unpack, harness, leverage, utilize, supercharge, unlock, future-proof |
| Dead AI nouns/adjs | landscape, realm, robust, game-changer, cutting-edge, straightforward, seamless, paradigm |
| Marketing cringe | "10x your X", "X revolution", "in the age of X", "in today's [anything]", "transform your X" |
| Dead transitions | Furthermore, Additionally, Moreover, "Moving forward", "At the end of the day", "To put this in perspective", "In other words", "It goes without saying", "What makes this particularly interesting is" |
| Softeners | "It's important to note", "It's worth noting", "I'd be happy to help" |
| Engagement bait | "This changes everything", "You're not ready for this", "Are you paying attention" |
| False insider | "Here's what nobody's talking about", "What nobody tells you", "Most people don't realize" |

## Principles

- **Lead with the point.** No throat-clearing, no preamble.
- **Contractions natural** (don't, can't, won't). They read human.
- **Vary sentence length.** Mix short punchy with longer. Three medium sentences in a row reads as AI cadence.
- **Specific over abstract.** Numbers, names, file paths beat "various", "improvements", "significant".
- **Hedge honestly** when uncertain ("I think", "probably", "roughly"). False confidence is worse than admitted uncertainty. Does not conflict with "lead with clear takes" — hedge IS the clear take when the data is thin.
- **Physical verbs for abstract processes** when they land: "sanded down" not "improved", "bolted on" not "added", "stripped" not "simplified". Use sparingly; forced metaphor reads worse than plain language.
- **Parenthetical asides** for editorial commentary, honest reactions, deflating own seriousness (like this) are good.
- **Em-dashes:** avoid as dramatic reveal devices ("The real problem — nobody talks about this — is..."). Parenthetical em-dashes are fine.
- **Trust readers.** Skip softening qualifiers.
- **Every sentence advances purpose.** If removing it changes nothing, remove it.
- **Never pad** to seem more thorough. Shorter and accurate beats longer and fluffy.
