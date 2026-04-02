import { describe, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { extractCommonJsExportNames } from "../inject-types/commonjs-exports";
import {
  applyBudget,
  classifySymbols,
  extractTypeReferences,
  estimateTokens,
  filterVisible,
  findProjectRoot,
  formatOutput,
  MAX_HOOK_FILE_BYTES,
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

  test("parses CommonJS function export", () => {
    const result = parseSymbol(sym({
      name: "expression_statement",
      kind: "variable",
      signature: "module.exports.loadUser = function loadUser() {}",
    }));
    expect(result).toEqual({ realName: "loadUser", realKind: "function", exported: true });
  });

  test("parses Python exports using __all__", () => {
    const result = parseSymbol(sym({
      name: "public_api",
      kind: "function",
      signature: "def public_api(user: User) -> User:",
    }), {
      filePath: "/tmp/example.py",
      fileContent: "__all__ = ['public_api']",
      language: "python",
      publicNames: new Set(["public_api"]),
    });
    expect(result).toEqual({ realName: "public_api", realKind: "function", exported: true });
  });

  test("parses Java public methods as exported functions", () => {
    const result = parseSymbol(sym({
      name: "load",
      kind: "method",
      signature: "public User load(User input) { return input; }",
    }), {
      filePath: "/tmp/Service.java",
      language: "java",
    });
    expect(result).toEqual({ realName: "load", realKind: "function", exported: true });
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

  test("uses Python __all__ to keep private helpers out of exported tiers", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "expression_statement", kind: "variable", signature: "__all__ = ['public_api']", line: 1, end_line: 1 }),
      sym({ name: "public_api", kind: "function", signature: "def public_api(user: User) -> User:", line: 3, end_line: 4 }),
      sym({ name: "User", kind: "class", signature: "class User:", line: 6, end_line: 7 }),
      sym({ name: "_hidden", kind: "function", signature: "def _hidden():", line: 9, end_line: 10 }),
    ];
    const result = classifySymbols(symbols, {
      filePath: "/tmp/example.py",
      fileContent: "__all__ = ['public_api']",
      language: "python",
    });

    expect(result.find((s) => s.realName === "public_api")?.tier).toBe(1);
    expect(result.find((s) => s.realName === "User")?.tier).toBe(2);
    expect(result.find((s) => s.realName === "_hidden")?.tier).toBe(5);
  });

  test("treats Java public methods as API surface", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "User", kind: "class", signature: "public class User {}", line: 1, end_line: 1 }),
      sym({ name: "Service", kind: "class", signature: "public class Service { ... }", line: 2, end_line: 4 }),
      sym({ name: "load", kind: "method", signature: "public User load(User input) { return input; }", line: 3, end_line: 3 }),
      sym({ name: "helper", kind: "method", signature: "private User helper(User input) { return input; }", line: 4, end_line: 4 }),
    ];
    const result = classifySymbols(symbols, {
      filePath: "/tmp/Service.java",
      language: "java",
    });

    expect(result.find((s) => s.realName === "load")?.tier).toBe(1);
    expect(result.find((s) => s.realName === "User")?.tier).toBe(2);
    expect(result.find((s) => s.realName === "helper")?.tier).toBe(5);
  });

  test("treats module.exports object members as exported JS API", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "loadUser", kind: "function", signature: "function loadUser(user) { return user; }", line: 3, end_line: 3 }),
      sym({ name: "UserRepo", kind: "class", signature: "class UserRepo {}", line: 4, end_line: 4 }),
    ];
    const result = classifySymbols(symbols, {
      filePath: "/tmp/worker.cjs",
      fileContent: "module.exports = { loadUser, UserRepo };",
    });

    expect(result.find((s) => s.realName === "loadUser")?.tier).toBe(1);
    expect(result.find((s) => s.realName === "UserRepo")?.tier).toBe(4);
  });

  test("does not treat expression-valued CommonJS exports as local API symbols", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "makeApi", kind: "function", signature: "function makeApi() { return {}; }", line: 3, end_line: 3 }),
    ];
    const direct = classifySymbols(symbols, {
      filePath: "/tmp/direct-call.cjs",
      fileContent: "module.exports = makeApi();",
    });
    const objectLiteral = classifySymbols(symbols, {
      filePath: "/tmp/object-call.cjs",
      fileContent: "module.exports = { api: makeApi() };",
    });

    expect(direct.find((s) => s.realName === "makeApi")?.tier).toBe(5);
    expect(objectLiteral.find((s) => s.realName === "makeApi")?.tier).toBe(5);
  });

  test("treats module.exports members as exported when object literal contains nested braces", () => {
    const symbols: ProbeSymbol[] = [
      sym({ name: "loadUser", kind: "function", signature: "function loadUser(user) { return user; }", line: 20, end_line: 20 }),
    ];
    const result = classifySymbols(symbols, {
      filePath: "/tmp/nested.cjs",
      fileContent: [
        "module.exports = {",
        "  config: { a: 1, b: { c: 2 } },",
        "  loadUser,",
        "};",
      ].join("\n"),
    });

    expect(result.find((s) => s.realName === "loadUser")?.tier).toBe(1);
  });
});

// --- extractCommonJsExportNames ---

describe("extractCommonJsExportNames", () => {
  test("parses shorthand after nested object property", () => {
    const src = [
      "module.exports = {",
      "  config: { a: 1, b: { c: 2 } },",
      "  loadUser,",
      "};",
    ].join("\n");
    const names = extractCommonJsExportNames(src);
    expect(names?.has("loadUser")).toBe(true);
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
  function makeTempProject(files: Record<string, string>): string {
    const root = mkdtempSync(join(tmpdir(), "inject-types-"));
    writeFileSync(join(root, "package.json"), JSON.stringify({ name: "tmp-project" }));

    for (const [relativePath, content] of Object.entries(files)) {
      const absolutePath = join(root, relativePath);
      mkdirSync(dirname(absolutePath), { recursive: true });
      writeFileSync(absolutePath, content);
    }

    return root;
  }

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

  test("injects CommonJS symbols for .cjs reads", () => {
    const root = makeTempProject({
      "src/worker.cjs": [
        "",
        "module.exports.loadUser = function loadUser() {};",
        "module.exports.UserRepo = class UserRepo {};",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/worker.cjs"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("loadUser");
    expect(stdout).toContain("UserRepo");
  });

  test("injects JS exports from module.exports object literals", () => {
    const root = makeTempProject({
      "src/object-export.cjs": [
        "module.exports = { loadUser, UserRepo };",
        "",
        "function loadUser(user) { return user; }",
        "class UserRepo {}",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/object-export.cjs"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("function loadUser");
    expect(stdout).toContain("class UserRepo");
  });

  test("returns {} when source file exceeds byte limit", () => {
    const root = makeTempProject({
      "src/huge.ts": "export const x = 1;\n" + " ".repeat(MAX_HOOK_FILE_BYTES),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/huge.ts"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toBe("{}");
  });

  test("does not emit CommonJS helpers for expression-valued exports", () => {
    const root = makeTempProject({
      "src/direct-call.cjs": [
        "module.exports = makeApi();",
        "",
        "function makeApi() { return {}; }",
      ].join("\n"),
      "src/object-call.cjs": [
        "module.exports = { api: makeApi() };",
        "",
        "function makeApi() { return {}; }",
      ].join("\n"),
    });

    const direct = runHook({
      tool_input: { file_path: join(root, "src/direct-call.cjs"), offset: 0, limit: 1 },
    });
    const objectLiteral = runHook({
      tool_input: { file_path: join(root, "src/object-call.cjs"), offset: 0, limit: 1 },
    });

    expect(direct.exitCode).toBe(0);
    expect(objectLiteral.exitCode).toBe(0);
    expect(direct.stdout).toBe("{}");
    expect(objectLiteral.stdout).toBe("{}");
  });

  test("injects Python symbols using __all__", () => {
    const root = makeTempProject({
      "pkg/api.py": [
        "__all__ = [",
        "    'public_api',",
        "]",
        "",
        "class User:",
        "    pass",
        "",
        "def public_api(user: User) -> User:",
        "    return user",
        "",
        "def _hidden():",
        "    pass",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "pkg/api.py"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("public_api");
    expect(stdout).toContain("class User:");
    expect(stdout).not.toContain("_hidden");
  });

  test("resolves Python sibling relative imports", () => {
    const root = makeTempProject({
      "pkg/api.py": [
        "from . import models",
        "",
        "def public_api(user: models.User) -> models.User:",
        "    return user",
      ].join("\n"),
      "pkg/models.py": [
        "class User:",
        "    pass",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "pkg/api.py"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("class User:");
  });

  test("injects Java public API symbols", () => {
    const root = makeTempProject({
      "src/main/java/com/example/Service.java": [
        "package com.example;",
        "",
        "public class User {}",
        "public class Service {",
        "  public User load(User input) { return input; }",
        "  private User helper(User input) { return input; }",
        "}",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/main/java/com/example/Service.java"), offset: 0, limit: 2 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("public User load");
    expect(stdout).toContain("public class User");
    expect(stdout).not.toContain("private User helper");
  });

  test("does not flatten methods from package-private Java classes", () => {
    const root = makeTempProject({
      "src/main/java/com/example/Service.java": [
        "package com.example;",
        "",
        "public class User {}",
        "class Service {",
        "  public User load(User input) { return input; }",
        "}",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/main/java/com/example/Service.java"), offset: 0, limit: 2 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).not.toContain("public User load");
  });

  test("does not flatten methods from nested public Java classes", () => {
    const root = makeTempProject({
      "src/main/java/com/example/Outer.java": [
        "package com.example;",
        "",
        "public class User {}",
        "public class Outer {",
        "  public static class Inner {",
        "    public User load(User input) { return input; }",
        "  }",
        "}",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/main/java/com/example/Outer.java"), offset: 0, limit: 2 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).not.toContain("public User load");
  });

  test("remaps unsupported .mts files through probe", () => {
    const root = makeTempProject({
      "src/types.mts": [
        "",
        "export type User = { id: string };",
        "export function loadUser(user: User): User { return user; }",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/types.mts"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("export function loadUser");
    expect(stdout).toContain("export type User");
  });

  test("extracts every Svelte script block, not only lang=ts", () => {
    const root = makeTempProject({
      "src/Component.svelte": [
        "<script context=\"module\">",
        "  export function loadThing() { return true; }",
        "</script>",
        "",
        "<script>",
        "  export let name;",
        "</script>",
      ].join("\n"),
    });

    const { stdout, exitCode } = runHook({
      tool_input: { file_path: join(root, "src/Component.svelte"), offset: 0, limit: 1 },
    });

    expect(exitCode).toBe(0);
    expect(stdout).toContain("loadThing");
    expect(stdout).toContain("export let name");
  });
});
