import { describe, expect, test } from "bun:test";
import {
  applyBudget,
  classifySymbols,
  extractTypeReferences,
  estimateTokens,
  filterVisible,
  findProjectRoot,
  formatOutput,
  parseSymbol,
  MAX_TIER1_SYMBOLS,
  type ClassifiedSymbol,
  type ProbeSymbol,
} from "../inject-types-on-read";

// --- Helpers ---

function sym(overrides: Partial<ProbeSymbol> & { name: string; signature: string }): ProbeSymbol {
  return {
    kind: "export",
    line: 1,
    end_line: 1,
    ...overrides,
  };
}

function classified(overrides: Partial<ClassifiedSymbol> & { realName: string }): ClassifiedSymbol {
  return {
    name: overrides.realName,
    realKind: "function",
    signature: `export function ${overrides.realName}(): void { ... }`,
    exported: true,
    line: 1,
    endLine: 1,
    tier: 1,
    tokens: 10,
    ...overrides,
  };
}

// --- parseSymbol ---

describe("parseSymbol", () => {
  test("parses exported function", () => {
    const result = parseSymbol(sym({
      name: "export_statement",
      kind: "export",
      signature: "export function fetchUser(id: string): Promise<User> { ... }",
    }));
    expect(result).toEqual({ realName: "fetchUser", realKind: "function", exported: true });
  });

  test("parses exported async function", () => {
    const result = parseSymbol(sym({
      name: "export_statement",
      kind: "export",
      signature: "export async function loadData(): Promise<void> { ... }",
    }));
    expect(result).toEqual({ realName: "loadData", realKind: "function", exported: true });
  });

  test("parses exported interface", () => {
    const result = parseSymbol(sym({
      name: "export_statement",
      kind: "export",
      signature: "export interface UserConfig { ... }",
    }));
    expect(result).toEqual({ realName: "UserConfig", realKind: "interface", exported: true });
  });

  test("parses exported type alias", () => {
    const result = parseSymbol(sym({
      name: "export_statement",
      kind: "export",
      signature: "export type Status = 'active' | 'inactive'",
    }));
    expect(result).toEqual({ realName: "Status", realKind: "type", exported: true });
  });

  test("parses exported const", () => {
    const result = parseSymbol(sym({
      name: "export_statement",
      kind: "export",
      signature: "export const DEFAULT_TIMEOUT = 5000",
    }));
    expect(result).toEqual({ realName: "DEFAULT_TIMEOUT", realKind: "const", exported: true });
  });

  test("handles non-exported symbol", () => {
    const result = parseSymbol(sym({
      name: "helperFn",
      kind: "function",
      signature: "function helperFn(): void { ... }",
    }));
    expect(result).toEqual({ realName: "helperFn", realKind: "function", exported: false });
  });

  test("handles unrecognized export pattern", () => {
    const result = parseSymbol(sym({
      name: "export_statement",
      kind: "export",
      signature: "export default { ... }",
    }));
    expect(result.exported).toBe(true);
    expect(result.realKind).toBe("unknown");
  });
});

// --- extractTypeReferences ---

describe("extractTypeReferences", () => {
  test("extracts PascalCase identifiers", () => {
    const refs = extractTypeReferences("function fetch(id: string): Promise<User> { ... }");
    expect(refs.has("User")).toBe(true);
  });

  test("excludes built-in types", () => {
    const refs = extractTypeReferences("function fetch(): Promise<Record<string, Array<number>>> { ... }");
    expect(refs.has("Promise")).toBe(false);
    expect(refs.has("Record")).toBe(false);
    expect(refs.has("Array")).toBe(false);
  });

  test("finds multiple custom types", () => {
    const refs = extractTypeReferences("function process(input: RequestData): ResponseData { ... }");
    expect(refs.has("RequestData")).toBe(true);
    expect(refs.has("ResponseData")).toBe(true);
  });

  test("returns empty set for no types", () => {
    const refs = extractTypeReferences("function add(a: number, b: number): number { ... }");
    expect(refs.size).toBe(0);
  });
});

// --- classifySymbols ---

describe("classifySymbols", () => {
  test("assigns tier 1 to exported functions", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "export_statement", signature: "export function doWork(): void { ... }" }),
    ];
    const result = classifySymbols(symbols);
    expect(result[0].tier).toBe(1);
    expect(result[0].realName).toBe("doWork");
  });

  test("assigns tier 2 to types referenced in function signatures", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "export_statement", signature: "export function getUser(): UserData { ... }", line: 10, end_line: 15 }),
      sym({ name: "export_statement", signature: "export interface UserData { ... }", line: 1, end_line: 5 }),
    ];
    const result = classifySymbols(symbols);
    const fn = result.find(s => s.realName === "getUser");
    const iface = result.find(s => s.realName === "UserData");
    expect(fn!.tier).toBe(1);
    expect(iface!.tier).toBe(2);
  });

  test("assigns tier 3 to transitive deps", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "export_statement", signature: "export function getUser(): UserData { ... }", line: 20, end_line: 30 }),
      sym({ name: "export_statement", signature: "export interface UserData { role: RoleType; }", line: 10, end_line: 15 }),
      sym({ name: "export_statement", signature: "export type RoleType = 'admin' | 'user'", line: 1, end_line: 1 }),
    ];
    const result = classifySymbols(symbols);
    const role = result.find(s => s.realName === "RoleType");
    expect(role!.tier).toBe(3);
  });

  test("assigns tier 4 to other exported symbols", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "export_statement", signature: "export const MAX_RETRIES = 3" }),
    ];
    const result = classifySymbols(symbols);
    expect(result[0].tier).toBe(4);
  });

  test("assigns tier 5 to non-exported symbols", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "helper", kind: "function", signature: "function helper(): void { ... }" }),
    ];
    const result = classifySymbols(symbols);
    expect(result[0].tier).toBe(5);
  });

  test("caches typeRefs on each symbol", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "export_statement", signature: "export function fetch(): UserData { ... }" }),
    ];
    const result = classifySymbols(symbols);
    expect(result[0].typeRefs).toBeInstanceOf(Set);
    expect(result[0].typeRefs!.has("UserData")).toBe(true);
  });

  test("sorts by tier", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "helper", kind: "variable", signature: "const x = 1", line: 1, end_line: 1 }),
      sym({ name: "export_statement", signature: "export function main(): void { ... }", line: 5, end_line: 10 }),
    ];
    const result = classifySymbols(symbols);
    expect(result[0].tier).toBeLessThanOrEqual(result[1].tier);
  });
});

// --- filterVisible ---

describe("filterVisible", () => {
  const local = classified({ realName: "localFn", line: 5, endLine: 10, source: undefined });
  const imported = classified({ realName: "importedFn", line: 1, endLine: 3, source: "other.ts" });

  test("full-file read: keeps only imported symbols", () => {
    const result = filterVisible([local, imported], undefined, undefined);
    expect(result).toHaveLength(1);
    expect(result[0].source).toBe("other.ts");
  });

  test("partial read: keeps locals outside visible range", () => {
    // Read range: lines 1-4 (0-based offset=0, limit=4 → 1-based 1-4)
    const result = filterVisible([local, imported], 0, 4);
    expect(result).toContainEqual(expect.objectContaining({ realName: "localFn" }));
    expect(result).toContainEqual(expect.objectContaining({ realName: "importedFn" }));
  });

  test("partial read: removes locals fully within visible range", () => {
    // Read range: lines 1-15 (0-based offset=0, limit=15 → 1-based 1-15)
    // local is at lines 5-10, fully inside
    const result = filterVisible([local, imported], 0, 15);
    expect(result).toHaveLength(1);
    expect(result[0].source).toBe("other.ts");
  });

  test("partial read: keeps locals partially outside range", () => {
    // Read range covers only part of the local symbol
    // offset=6 → 1-based start=7, limit=3 → end=9. local is 5-10, NOT fully inside.
    const result = filterVisible([local, imported], 6, 3);
    expect(result).toContainEqual(expect.objectContaining({ realName: "localFn" }));
  });
});

// --- applyBudget ---

describe("applyBudget", () => {
  test("includes symbols within budget", () => {
    const symbols = [
      classified({ realName: "fn1", tokens: 100 }),
      classified({ realName: "fn2", tokens: 100 }),
    ];
    const { included, omittedCount } = applyBudget(symbols, 1500);
    expect(included).toHaveLength(2);
    expect(omittedCount).toBe(0);
  });

  test("never cuts mid-symbol", () => {
    const symbols = [
      classified({ realName: "fn1", tokens: 800 }),
      classified({ realName: "fn2", tokens: 800 }),
    ];
    const { included } = applyBudget(symbols, 1500);
    // Only first fits (800 <= 1500), second would be 1600 > 1500
    expect(included).toHaveLength(1);
    expect(included[0].realName).toBe("fn1");
  });

  test("fits smaller symbols after a large one is skipped", () => {
    const symbols = [
      classified({ realName: "fn1", tokens: 100, tier: 1 }),
      classified({ realName: "bigType", tokens: 2000, tier: 2 }),
      classified({ realName: "smallType", tokens: 50, tier: 3 }),
    ];
    const { included } = applyBudget(symbols, 1500);
    expect(included.map(s => s.realName)).toEqual(["fn1", "smallType"]);
  });

  test("deduplicates by realName", () => {
    const symbols = [
      classified({ realName: "Foo", tier: 1, tokens: 100 }),
      classified({ realName: "Foo", tier: 2, tokens: 100, source: "other.ts" }),
    ];
    const { included } = applyBudget(symbols, 1500);
    expect(included).toHaveLength(1);
  });

  test("caps tier 1 at MAX_TIER1_SYMBOLS", () => {
    const symbols = Array.from({ length: 20 }, (_, i) =>
      classified({ realName: `fn${i}`, tier: 1, tokens: 10 })
    );
    const { included } = applyBudget(symbols, 1500);
    const tier1 = included.filter(s => s.tier === 1);
    expect(tier1.length).toBe(MAX_TIER1_SYMBOLS);
  });

  test("tier 1 respects token budget", () => {
    const symbols = Array.from({ length: 10 }, (_, i) =>
      classified({ realName: `fn${i}`, tier: 1, tokens: 200 })
    );
    // 10 * 200 = 2000 > 1500 budget
    const { included } = applyBudget(symbols, 1500);
    expect(included.length).toBeLessThan(10);
    const totalTokens = included.reduce((sum, s) => sum + s.tokens, 0);
    expect(totalTokens).toBeLessThanOrEqual(1500);
  });

  test("reports omitted count", () => {
    const symbols = [
      classified({ realName: "fn1", tokens: 1400 }),
      classified({ realName: "fn2", tokens: 200, tier: 2 }),
    ];
    const { omittedCount } = applyBudget(symbols, 1500);
    expect(omittedCount).toBe(1);
  });
});

// --- estimateTokens ---

describe("estimateTokens", () => {
  test("estimates based on char length", () => {
    // 40 chars + 10 overhead = 50, / 4 = 12.5, ceil = 13
    const sig = "export function foo(): void { ... }"; // 35 chars
    const tokens = estimateTokens(sig);
    expect(tokens).toBe(Math.ceil((sig.length + 10) / 4));
  });

  test("short signature", () => {
    expect(estimateTokens("x")).toBe(Math.ceil(11 / 4)); // 3
  });
});

// --- formatOutput ---

describe("formatOutput", () => {
  test("wraps in type-context XML", () => {
    const symbols = [classified({ realName: "fn1", signature: "export function fn1(): void { ... }" })];
    const output = formatOutput("test.ts", symbols, 0);
    expect(output).toContain('<type-context file="test.ts"');
    expect(output).toContain("</type-context>");
    expect(output).toContain("export function fn1(): void { ... }");
  });

  test("includes omission footer when types omitted", () => {
    const symbols = [classified({ realName: "fn1", signature: "sig" })];
    const output = formatOutput("test.ts", symbols, 5);
    expect(output).toContain("5 types omitted");
  });

  test("no omission footer when nothing omitted", () => {
    const symbols = [classified({ realName: "fn1", signature: "sig" })];
    const output = formatOutput("test.ts", symbols, 0);
    expect(output).not.toContain("omitted");
  });

  test("groups imported symbols with header and source labels", () => {
    const symbols = [
      classified({ realName: "localFn", source: undefined }),
      classified({ realName: "importedFn", source: "other.ts", tier: 5 }),
    ];
    const output = formatOutput("test.ts", symbols, 0);
    expect(output).toContain("// --- Imported types ---");
    expect(output).toContain("// from other.ts");
  });
});

// --- findProjectRoot ---

describe("findProjectRoot", () => {
  test("finds root with package.json", () => {
    // This file is in the spine repo which has package.json
    const root = findProjectRoot(import.meta.path);
    expect(root).not.toBeNull();
  });

  test("returns null for system paths", () => {
    const root = findProjectRoot("/usr/bin/env");
    expect(root).toBeNull();
  });
});

// --- Integration: end-to-end hook via subprocess ---

describe("hook e2e", () => {
  function runHook(input: object, env?: Record<string, string>): { stdout: string; exitCode: number } {
    const proc = Bun.spawnSync(["bun", import.meta.dir + "/../inject-types-on-read.ts"], {
      stdin: Buffer.from(JSON.stringify(input)),
      env: { ...process.env, ...env },
    });
    return {
      stdout: proc.stdout.toString().trim(),
      exitCode: proc.exitCode,
    };
  }

  test("returns {} for empty input", () => {
    const proc = Bun.spawnSync(["bun", import.meta.dir + "/../inject-types-on-read.ts"], {
      stdin: Buffer.from(""),
    });
    expect(proc.stdout.toString().trim()).toBe("{}");
    expect(proc.exitCode).toBe(0);
  });

  test("returns {} for non-TS file", () => {
    const { stdout, exitCode } = runHook({ tool_input: { file_path: "/etc/hosts" } });
    expect(stdout).toBe("{}");
    expect(exitCode).toBe(0);
  });

  test("returns {} for nonexistent file", () => {
    const { stdout, exitCode } = runHook({ tool_input: { file_path: "/tmp/nonexistent.ts" } });
    expect(stdout).toBe("{}");
    expect(exitCode).toBe(0);
  });

  test("returns {} for malformed JSON", () => {
    const proc = Bun.spawnSync(["bun", import.meta.dir + "/../inject-types-on-read.ts"], {
      stdin: Buffer.from("not json"),
    });
    expect(proc.stdout.toString().trim()).toBe("{}");
    expect(proc.exitCode).toBe(0);
  });

  test("returns {} when CLAUDE_PLUGIN_ROOT matches file path", () => {
    const hooksDir = import.meta.dir + "/..";
    const hookPath = hooksDir + "/inject-types-on-read.ts";
    const { stdout } = runHook(
      { tool_input: { file_path: hookPath } },
      { CLAUDE_PLUGIN_ROOT: hooksDir },
    );
    expect(stdout).toBe("{}");
  });

  test("always exits 0", () => {
    const cases = [
      "",
      "not json",
      "{}",
      JSON.stringify({ tool_input: { file_path: "/nonexistent.ts" } }),
    ];
    for (const input of cases) {
      const proc = Bun.spawnSync(["bun", import.meta.dir + "/../inject-types-on-read.ts"], {
        stdin: Buffer.from(input),
      });
      expect(proc.exitCode).toBe(0);
    }
  });
});
