// spine:managed — do not edit
// Spine hook plugin for OpenCode — delegates to central hook scripts.
// Installed to ~/.config/opencode/plugins/ by install.sh.
//
// Hooks reference: hooks/ directory (shared across all providers).
// Shell hooks run through _env.sh for PATH setup in restricted environments.
// TS hooks run through _ts.sh for runtime resolution (bun → node ≥22 → deno).

import { execFileSync } from "node:child_process";
import { join } from "node:path";

const HOOKS_DIR = join(process.env.HOME ?? "", ".config/spine/hooks");
const ENV_SH = join(HOOKS_DIR, "_env.sh");
const TS_SH = join(HOOKS_DIR, "_ts.sh");

function runShellHook(hookName: string, input: string): string {
  try {
    return execFileSync(ENV_SH, [join(HOOKS_DIR, hookName)], {
      input,
      encoding: "utf-8",
      timeout: 30000,
    });
  } catch (e: unknown) {
    if (e && typeof e === "object" && "stdout" in e && typeof e.stdout === "string") {
      return e.stdout;
    }
    return "";
  }
}

function runTsHook(hookName: string, input: string): string {
  try {
    return execFileSync(TS_SH, [join(HOOKS_DIR, hookName)], {
      input,
      encoding: "utf-8",
      timeout: 30000,
    });
  } catch (e: unknown) {
    if (e && typeof e === "object" && "stdout" in e && typeof e.stdout === "string") {
      return e.stdout;
    }
    return "";
  }
}

export const SpineHooks = async () => {
  return {
    // Security deny-list for shell commands + large file read guard
    "tool.execute.before": async (input: {
      tool: string;
      args: Record<string, unknown>;
    }) => {
      const hookInput = JSON.stringify({ tool_input: input.args });

      if (input.tool === "bash" || input.tool === "shell") {
        const result = runShellHook("guard-shell.sh", hookInput);
        if (result.includes('"deny"')) {
          try {
            const parsed = JSON.parse(result);
            throw new Error(parsed.hookSpecificOutput?.permissionDecisionReason ?? "Blocked by guard-shell");
          } catch (e) {
            if (e instanceof Error && e.message !== "Blocked by guard-shell") throw e;
            throw new Error("Blocked by guard-shell");
          }
        }
      }

      if (input.tool === "read") {
        const result = runShellHook("guard-read-large.sh", hookInput);
        if (result.includes("WARNING")) {
          try {
            const parsed = JSON.parse(result);
            if (parsed.hookSpecificOutput?.additionalContext) {
              return { systemMessage: parsed.hookSpecificOutput.additionalContext };
            }
          } catch {
            // ignore parse errors
          }
        }
      }
    },

    // Post-tool hooks: type injection on read, checkers on edit
    "tool.execute.after": async (input: {
      tool: string;
      args: Record<string, unknown>;
    }) => {
      const hookInput = JSON.stringify({ tool_input: input.args });

      if (input.tool === "read") {
        // Inject type signatures when reading TS/Svelte files
        const result = runTsHook("inject-types-on-read.ts", hookInput);
        if (result.trim() && result !== "{}") {
          try {
            const parsed = JSON.parse(result);
            if (parsed.systemMessage) {
              return { systemMessage: parsed.systemMessage };
            }
          } catch {
            // ignore parse errors
          }
        }
      }

      if (input.tool === "edit" || input.tool === "write") {
        // Run project-appropriate checkers after file edits
        const result = runShellHook("check-on-edit.sh", hookInput);
        if (result.trim() && result !== "{}") {
          try {
            const parsed = JSON.parse(result);
            if (parsed.systemMessage) {
              return { systemMessage: parsed.systemMessage };
            }
          } catch {
            // ignore parse errors
          }
        }
      }
    },
  };
};
