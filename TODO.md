# TODO

- Re-check if cursor-agent CLI re-adds `auto` model support (removed March 2026). If restored: consider re-adding model-level retry in run-cursor.sh and differentiating fast tier. Users with `SPINE_ENVOY_FAST_CURSOR=auto` in .env should update to `composer-2`.
- gemini envoy:
	- `brew install gemini-cli`
	- `gemini -p "Explain the architecture of this codebase"`
- GitHub Copilot envoy
	- I have pro but other in team migth only have free
	- https://github.com/features/copilot/cli/
	- Select Model
	  Claude Sonnet 4.6 (default) ✓        1x
	  Claude Sonnet 4.5                    1x
	  Claude Haiku 4.5                  0.33x
	  Claude Opus 4.6                      3x
	  Claude Opus 4.5                      3x
	  Claude Sonnet 4                      1x
	  Gemini 3 Pro (Preview)               1x
	  GPT-5.4                              1x
	❯ GPT-5.3-Codex                        1x
	  GPT-5.2-Codex                        1x
	  GPT-5.2                              1x
	  GPT-5.1-Codex-Max                    1x
	  GPT-5.1-Codex                        1x
	  GPT-5.1                              1x
	  GPT-5.4 mini                      0.33x
	  GPT-5.1-Codex-Mini (Preview)      0.33x
	  GPT-5 mini                           0x
	  GPT-4.1                              0x

	--effort, --reasoning-effort <level>  Set the reasoning effort level (choices: "low", "medium", "high", "xhigh")
	--allow-all                           Enable all permissions (equivalent to --allow-all-tools --allow-all-paths
                                        --allow-all-urls)
  --model <model>                       Set the AI model to use
  --no-ask-user                         Disable the ask_user tool (agent works autonomously without asking questions)
  --no-color                            Disable all color output
	--output-format <format>              Output format: 'text' (default) or 'json' (JSONL, one JSON object per line) (choices:
	                                      "text", "json")
	-p, --prompt <text>                   Execute a prompt in non-interactive mode (exits after completion)
	--yolo                                Enable all permissions (equivalent to --allow-all-tools --allow-all-paths
	                                      --allow-all-urls)

- envoy: normalize run.sh output to always use `{base}.{provider}.{md,log}` even for single mode — removes last mode-aware surface from callers/synthesis
- verify cross-skill references work, or move to ~/.agents/skills/run-explore/references/explore-scout.md
- run-skill-eval: on rewritten skills, reference files, and agents
	- run-insight is suspicous
- document handoff/clear/catchup after planning
- svelte skill with autofixer script like we have in nestor
- auto-loading per glob like min description?
- https://github.com/SocketDev/sfw-free
- merge/resolve merge conflict
- Sematic Search
	- https://github.com/tobi/qmd
	- https://github.com/cocoindex-io/cocoindex-code, https://github.com/cocoindex-io/cocoindex-code/issues/20
	- https://github.com/tirth8205/code-review-graph
	- https://github.com/thedotmack/claude-mem

## Provide Shared System Setup for MacOS dotfiles

- zsh setup
- recommended cli: jq, fd, rg, sd, ni, mole, bun, topgrade, pbcopy, nvm, ....
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
