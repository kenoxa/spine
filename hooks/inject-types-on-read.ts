/**
 * inject-types-on-read.ts
 * PostToolUse hook: inject type signatures when reading TypeScript/Svelte files.
 *
 * Uses `probe symbols` (tree-sitter) for extraction, then applies smart prioritization
 * inspired by type-inject's tier system. Never cuts mid-symbol.
 *
 * Portable: runs on bun, node ≥22, or deno. No npm install needed for the core logic.
 * For Svelte: dynamically imports svelte/compiler from the project's node_modules.
 */

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";

// --- Types ---

interface HookInput {
  tool_input?: {
    file_path?: string;
    offset?: number;
    limit?: number;
  };
}

export interface ProbeSymbol {
  name: string;
  kind: string;
  signature: string;
  line: number;
  end_line: number;
}

interface ProbeResult {
  file: string;
  symbols: ProbeSymbol[];
}

export interface ClassifiedSymbol {
  name: string;
  realName: string;
  realKind: string;
  signature: string;
  exported: boolean;
  line: number;
  endLine: number;
  tier: number;
  tokens: number;
  typeRefs?: Set<string>; // cached PascalCase type references from signature
  source?: string; // file label for imported symbols
}

// --- Constants ---

export const SUPPORTED_EXTENSIONS = /\.(ts|tsx|mts|cts|svelte)$/;
export const SVELTE_EXTENSION = /\.svelte$/;
export const CHARS_PER_TOKEN = 4;
export const DEFAULT_TOKEN_BUDGET = 1500;
export const MAX_IMPORT_FILES = 10;
export const MAX_IMPORT_RESOLVE_MS = 200;
export const MAX_TIER1_SYMBOLS = 15;

// Built-in types to exclude from cross-referencing
const BUILTIN_TYPES = new Set([
  "String", "Number", "Boolean", "Object", "Array", "Function", "Promise",
  "Date", "Map", "Set", "WeakMap", "WeakSet", "RegExp", "Error", "Symbol",
  "BigInt", "Record", "Partial", "Required", "Readonly", "Pick", "Omit",
  "Exclude", "Extract", "NonNullable", "Parameters", "ReturnType",
  "InstanceType", "ThisType", "Uppercase", "Lowercase", "Capitalize",
  "Uncapitalize", "Awaited", "ReadonlyArray", "PropertyKey", "Iterator",
  "AsyncIterator", "Generator", "AsyncGenerator",
]);

// --- Portable stdin reader (bun, node, deno) ---

async function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.setEncoding("utf-8");
    process.stdin.on("data", (chunk: string) => { data += chunk; });
    process.stdin.on("end", () => resolve(data));
    process.stdin.resume();
  });
}

// --- Main ---

async function main(): Promise<void> {
  try {
    const raw = await readStdin();
    if (!raw.trim()) {
      emit({});
      return;
    }

    const input: HookInput = JSON.parse(raw);
    const filePath = input.tool_input?.file_path;

    if (!filePath || !existsSync(filePath) || !SUPPORTED_EXTENSIONS.test(filePath)) {
      emit({});
      return;
    }

    // Q2: Skip files outside project root or within the plugin directory
    const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT;
    if (pluginRoot && filePath.startsWith(pluginRoot)) {
      emit({});
      return;
    }
    const projectRoot = findProjectRoot(filePath);
    if (!projectRoot) {
      emit({});
      return;
    }

    const offset = input.tool_input?.offset;
    const limit = input.tool_input?.limit;

    const result = await processFile(filePath, offset, limit);

    if (result) {
      emit({ systemMessage: result });
    } else {
      emit({});
    }
  } catch {
    // Silent failure — never block the workflow
    emit({});
  }
}

// Only run when executed directly (not when imported for testing)
// import.meta.main is portable: bun, node ≥22, deno
if ((import.meta as unknown as { main?: boolean }).main) {
  await main();
}

// --- Core ---

async function processFile(filePath: string, offset?: number, limit?: number): Promise<string | null> {
  let scriptContent: string | undefined;
  let lineOffset = 0;

  // For Svelte files, extract <script lang="ts"> content
  if (SVELTE_EXTENSION.test(filePath)) {
    const extracted = await extractSvelteScript(filePath);
    if (!extracted) return null;
    scriptContent = extracted.content;
    lineOffset = extracted.lineOffset;
  }

  // Get symbols from probe
  const localSymbols = probeSymbols(filePath, scriptContent);
  if (!localSymbols.length) return null;

  // Apply line offset for Svelte
  if (lineOffset > 0) {
    for (const sym of localSymbols) {
      sym.line += lineOffset;
      sym.end_line += lineOffset;
    }
  }

  // Classify symbols into tiers
  const classified = classifySymbols(localSymbols);

  // Resolve 1-hop imports
  const importedSymbols = resolveImports(filePath);

  // Merge: local classified + imported (promote imports referenced in local signatures)
  const allSymbols = promoteImportedSymbols(classified, importedSymbols);

  // Filter out symbols already visible in the read range
  const visible = filterVisible(allSymbols, offset, limit);

  // Apply token budget — never cut mid-symbol
  const { included, omittedCount } = applyBudget(visible, DEFAULT_TOKEN_BUDGET);

  if (!included.length) return null;

  // Format as XML
  return formatOutput(basename(filePath), included, omittedCount);
}

// --- Symbol Extraction ---

function probeSymbols(filePath: string, scriptContent?: string): ProbeSymbol[] {
  try {
    // If we have extracted script content (Svelte), write to temp file in os.tmpdir()
    if (scriptContent !== undefined) {
      const hash = createHash("md5").update(scriptContent).digest("hex").slice(0, 8);
      const tmpPath = join(tmpdir(), `svelte-extract-${hash}.ts`);
      writeFileSync(tmpPath, scriptContent);
      try {
        const json = execFileSync("probe", ["symbols", "--format", "json", tmpPath], {
          timeout: 5000,
          stdio: ["pipe", "pipe", "pipe"],
        }).toString();
        const results: ProbeResult[] = JSON.parse(json);
        return results[0]?.symbols ?? [];
      } finally {
        try { unlinkSync(tmpPath); } catch {}
      }
    }

    const json = execFileSync("probe", ["symbols", "--format", "json", filePath], {
      timeout: 5000,
      stdio: ["pipe", "pipe", "pipe"],
    }).toString();
    const results: ProbeResult[] = JSON.parse(json);
    return results[0]?.symbols ?? [];
  } catch {
    return [];
  }
}

// --- Svelte ---

async function extractSvelteScript(filePath: string): Promise<{ content: string; lineOffset: number } | null> {
  const fileContent = readFileSync(filePath, "utf-8");

  // Try to use nearest svelte/compiler — walk up from file, not project root (monorepo safe)
  const svelteCompilerPath = findNearestModule(filePath, "svelte/compiler/index.js");
  if (svelteCompilerPath) {
    try {
      {
        const svelteCompiler = await import(svelteCompilerPath);
        const ast = svelteCompiler.parse(fileContent, { modern: true, filename: filePath });

        // Prefer instance script, fall back to module script
        const script = ast.instance ?? ast.module;
        if (!script) return null;

        // Check for lang="ts"
        const langAttr = script.attributes?.find((a: any) => a.name === "lang");
        const isTS = langAttr?.value?.[0]?.data === "ts" || langAttr?.value?.[0]?.data === "typescript";
        if (!isTS) return null;

        const scriptTag = fileContent.slice(script.start, script.end);
        const openTagEnd = scriptTag.indexOf(">") + 1;
        const closeTagStart = scriptTag.lastIndexOf("</script>");
        const content = scriptTag.slice(openTagEnd, closeTagStart);

        const lineOffset = fileContent.slice(0, script.start + openTagEnd).split("\n").length - 1;
        return { content, lineOffset };
      }
    } catch {
      // Fall through to regex
    }
  }

  // Fallback: regex-based extraction
  const scriptMatch = fileContent.match(/<script\s+[^>]*lang=["'](?:ts|typescript)["'][^>]*>([\s\S]*?)<\/script>/);
  if (!scriptMatch) return null;

  const content = scriptMatch[1];
  const beforeScript = fileContent.slice(0, scriptMatch.index! + scriptMatch[0].indexOf(content));
  const lineOffset = beforeScript.split("\n").length - 1;
  return { content, lineOffset };
}

// --- Classification ---

export function classifySymbols(symbols: ProbeSymbol[]): ClassifiedSymbol[] {
  const classified: ClassifiedSymbol[] = [];

  for (const sym of symbols) {
    const { realName, realKind, exported } = parseSymbol(sym);

    classified.push({
      name: sym.name,
      realName,
      realKind,
      signature: sym.signature,
      exported,
      line: sym.line,
      endLine: sym.end_line,
      tier: 0, // assigned below
      tokens: estimateTokens(sym.signature),
    });
  }

  // --- Tier assignment (inspired by type-inject) ---
  // Tier 1: exported functions (the API surface — always included)
  // Tier 2: types referenced in tier 1 signatures
  // Tier 3: types referenced in tier 2 signatures (transitive)
  // Tier 4: other exported types/interfaces/enums/classes/consts
  // Tier 5: non-exported symbols

  // Cache typeRefs on each symbol (Q6 — avoid redundant regex calls)
  for (const s of classified) {
    s.typeRefs = extractTypeReferences(s.signature);
  }

  const tier1 = classified.filter(s => s.exported && s.realKind === "function");
  for (const s of tier1) s.tier = 1;

  // Collect type references from tier 1 signatures (using cached refs)
  const tier1Refs = new Set<string>();
  for (const s of tier1) {
    for (const ref of s.typeRefs!) tier1Refs.add(ref);
  }

  // Tier 2: types referenced in tier 1 signatures
  const tier2Names = new Set<string>();
  for (const s of classified) {
    if (s.tier > 0) continue;
    if (tier1Refs.has(s.realName)) {
      s.tier = 2;
      tier2Names.add(s.realName);
    }
  }

  // Collect type references from tier 2 signatures (using cached refs)
  const tier2Refs = new Set<string>();
  for (const s of classified) {
    if (s.tier === 2) {
      for (const ref of s.typeRefs!) {
        if (!tier1Refs.has(ref) && !tier2Names.has(ref)) {
          tier2Refs.add(ref);
        }
      }
    }
  }

  // Tier 3: transitive deps of tier 2
  for (const s of classified) {
    if (s.tier > 0) continue;
    if (tier2Refs.has(s.realName)) {
      s.tier = 3;
    }
  }

  // Tier 4: remaining exported symbols
  for (const s of classified) {
    if (s.tier > 0) continue;
    if (s.exported) s.tier = 4;
  }

  // Tier 5: everything else
  for (const s of classified) {
    if (s.tier === 0) s.tier = 5;
  }

  return classified.sort((a, b) => a.tier - b.tier);
}

export function parseSymbol(sym: ProbeSymbol): { realName: string; realKind: string; exported: boolean } {
  if (sym.kind === "export") {
    const match = sym.signature.match(
      /^export\s+(?:default\s+)?(?:async\s+)?(?:abstract\s+)?(function|interface|type|class|const|enum|let|var)\s+(\w+)/
    );
    if (match) {
      return { realName: match[2], realKind: match[1], exported: true };
    }
    return { realName: sym.name, realKind: "unknown", exported: true };
  }
  return { realName: sym.name, realKind: sym.kind, exported: false };
}

export function extractTypeReferences(signature: string): Set<string> {
  const refs = new Set<string>();
  const regex = /\b([A-Z][a-zA-Z0-9]*)\b/g;
  let match: RegExpExecArray | null;
  while ((match = regex.exec(signature)) !== null) {
    const name = match[1];
    if (!BUILTIN_TYPES.has(name)) {
      refs.add(name);
    }
  }
  return refs;
}

// --- Import Resolution ---

function resolveImports(filePath: string): ClassifiedSymbol[] {
  const fileContent = readFileSync(filePath, "utf-8");
  const fileDir = dirname(filePath);
  const imported: ClassifiedSymbol[] = [];

  // Match import lines with relative paths
  const importRegex = /^import\s+.+\s+from\s+['"](\.\.?\/[^'"]+)['"]/gm;
  let match: RegExpExecArray | null;
  let resolvedCount = 0;
  const startTime = Date.now();

  while ((match = importRegex.exec(fileContent)) !== null) {
    // Q3: Cap resolved import files and total resolution time
    if (resolvedCount >= MAX_IMPORT_FILES) break;
    if (Date.now() - startTime > MAX_IMPORT_RESOLVE_MS) break;

    const importPath = match[1];
    const resolved = resolveImportPath(fileDir, importPath);
    if (!resolved) continue;

    resolvedCount++;
    const symbols = probeSymbols(resolved);
    const sourceLabel = basename(resolved);

    for (const sym of symbols) {
      // Only include exported symbols from imports
      if (sym.kind !== "export") continue;

      const { realName, realKind } = parseSymbol(sym);

      imported.push({
        name: sym.name,
        realName,
        realKind,
        signature: sym.signature,
        exported: true,
        line: sym.line,
        endLine: sym.end_line,
        tier: 5, // default tier for imports, may be promoted
        tokens: estimateTokens(sym.signature),
        source: sourceLabel,
      });
    }
  }

  return imported;
}

function resolveImportPath(dir: string, importPath: string): string | null {
  const extensions = [".ts", ".tsx", ".mts", "/index.ts", "/index.tsx", ""];
  for (const ext of extensions) {
    const candidate = resolve(dir, importPath + ext);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

/**
 * Promote imported symbols referenced in local function signatures.
 * If an imported type appears in a local exported function signature → tier 2.
 * If it appears in a tier 2 signature → tier 3.
 */
function promoteImportedSymbols(
  local: ClassifiedSymbol[],
  imported: ClassifiedSymbol[],
): ClassifiedSymbol[] {
  // Reuse cached typeRefs from classifySymbols (Q6)
  const tier1Refs = new Set<string>();
  for (const s of local) {
    if (s.tier === 1) {
      for (const ref of s.typeRefs ?? extractTypeReferences(s.signature)) tier1Refs.add(ref);
    }
  }

  const tier2Refs = new Set<string>();
  for (const s of local) {
    if (s.tier === 2) {
      for (const ref of s.typeRefs ?? extractTypeReferences(s.signature)) tier2Refs.add(ref);
    }
  }

  for (const s of imported) {
    if (tier1Refs.has(s.realName)) {
      s.tier = 2;
    } else if (tier2Refs.has(s.realName)) {
      s.tier = 3;
    }
  }

  return [...local, ...imported].sort((a, b) => a.tier - b.tier);
}

// --- Visibility Filtering ---

export function filterVisible(
  symbols: ClassifiedSymbol[],
  offset: number | undefined,
  limit: number | undefined,
): ClassifiedSymbol[] {
  // Q7: Full-file read (no offset/limit) — skip all local symbols, keep only imports.
  // The AI already sees the full file content; local signatures are redundant.
  if (offset === undefined || limit === undefined) {
    return symbols.filter(s => !!s.source);
  }

  // Partial read — keep locals outside the visible range + all imports.
  // Bug fix: probe uses 1-based lines, Read uses 0-based offset.
  const rangeStart = offset + 1; // convert to 1-based
  const rangeEnd = offset + limit; // end line in 1-based

  return symbols.filter(s => {
    if (s.source) return true;
    // Skip local symbols fully visible in the read range
    const fullyVisible = s.line >= rangeStart && s.endLine <= rangeEnd;
    return !fullyVisible;
  });
}

// --- Token Budget ---

export function estimateTokens(signature: string): number {
  return Math.ceil((signature.length + 10) / CHARS_PER_TOKEN);
}

export function applyBudget(
  symbols: ClassifiedSymbol[],
  budget: number,
): { included: ClassifiedSymbol[]; omittedCount: number } {
  const included: ClassifiedSymbol[] = [];
  let totalTokens = 0;
  let tier1Count = 0;
  const seen = new Set<string>();

  for (const sym of symbols) {
    // Deduplicate by real name
    if (seen.has(sym.realName)) continue;
    seen.add(sym.realName);

    // Q4: Tier 1 gets priority but respects a symbol cap and the budget
    if (sym.tier === 1) {
      if (tier1Count >= MAX_TIER1_SYMBOLS) continue;
      tier1Count++;
    }

    // All tiers checked against budget — never cut mid-symbol
    if (totalTokens + sym.tokens <= budget) {
      included.push(sym);
      totalTokens += sym.tokens;
    }
    // Skip if doesn't fit, but keep checking — smaller symbols might still fit
  }

  const omittedCount = symbols.length - included.length;
  return { included, omittedCount };
}

// --- Output ---

export function formatOutput(fileName: string, symbols: ClassifiedSymbol[], omittedCount: number): string {
  const lines: string[] = [];
  let hasImports = false;

  for (const sym of symbols) {
    if (sym.source && !hasImports) {
      lines.push("");
      lines.push("// --- Imported types ---");
      hasImports = true;
    }

    if (sym.source) {
      lines.push(`// from ${sym.source}`);
    }

    lines.push(sym.signature);
  }

  if (omittedCount > 0) {
    lines.push(`\n<!-- ${omittedCount} types omitted (token budget: ${DEFAULT_TOKEN_BUDGET}) -->`);
  }

  return `<type-context file="${fileName}" budget="${DEFAULT_TOKEN_BUDGET}">\n${lines.join("\n")}\n</type-context>`;
}

// --- Utilities ---

export function findProjectRoot(filePath: string): string | null {
  let dir = dirname(filePath);
  while (dir !== "/") {
    if (existsSync(resolve(dir, "package.json"))) return dir;
    if (existsSync(resolve(dir, ".git"))) return dir;
    dir = dirname(dir);
  }
  return null;
}

/** Walk up from filePath to find nearest node_modules/<modulePath>. Monorepo safe. */
function findNearestModule(filePath: string, modulePath: string): string | null {
  let dir = dirname(filePath);
  while (dir !== "/") {
    const candidate = resolve(dir, "node_modules", modulePath);
    if (existsSync(candidate)) return candidate;
    dir = dirname(dir);
  }
  return null;
}

function emit(obj: object): void {
  console.log(JSON.stringify(obj));
}
