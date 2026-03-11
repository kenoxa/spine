# TODO

- svelte skill with autofixer script like we have in nestor
- auto-loading per glob like min description?
- ensure we cleanup after renames/removals of skills
- visual-explainer: write to session directory!
- addtional core tools:
	- agent-browser: https://github.com/vercel-labs/agent-browser
		- `/plugin marketplace add vercel-labs/agent-browser`
		- `/plugin install agent-browser@agent-browser`
- second option (codex, gemini, cursor agent): https://github.com/trailofbits/skills/tree/main/plugins/second-opinion

## Prehook gets triggered for skill evals:

```
Write(.scratch/eval-do-skill-eval-7585/run-evals.sh)
  ⎿  Error: PreToolUse:Write hook error: [python3 ${CLAUDE_PLUGIN_ROOT}/hooks/security_reminder_hook.py]: ⚠️  Security
     Warning: eval() executes arbitrary code and is a major security risk. Consider using JSON.parse() for data parsing or
     alternative design patterns that don't require code evaluation. Only use eval() if you truly need to evaluate
     arbitrary code.
⏺ Security hook false positive on "eval" in the filename (it's "evaluation", not eval()). Let me rename to avoid the
  pattern.
```

## Provide Shared System Setup for MacOS dotfiles

- zsh setup
- recommended cli: jq, fd, rg, mole, bun, topgrade, pbcopy, nvm, ....
- auto-cleanup: https://github.com/tw93/Mole
	- scripts and launcher/cron
- auto-upgrade using topgrade: https://github.com/topgrade-rs/topgrade
	- scripts and launcher/cron
- nvm default-packages
- ni: https://github.com/antfu-collective/ni
- taze: https://github.com/antfu-collective/taze
- Portless: https://github.com/vercel-labs/portless
- zed editor settings
- claude code, codex, cursor settings
- brew install --cask steipete/tap/codexbar
