/**
 * inject-types-on-read.ts
 * PostToolUse hook: inject symbol/signature context when reading supported code files.
 *
 * Uses `probe symbols` (tree-sitter) for extraction, then applies smart prioritization
 * inspired by type-inject's tier system. Never cuts mid-symbol.
 *
 * Returns hookSpecificOutput.additionalContext for model context injection.
 *
 * Portable: runs on bun, node ≥22, or deno. No npm install needed for the core logic.
 * For Svelte: dynamically imports svelte/compiler from the project's node_modules.
 *
 * Implementation is split under `hooks/inject-types/` (constants, import resolution, CommonJS heuristics).
 */

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { appendFileSync, existsSync, mkdirSync, renameSync, rmSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";

import { extractCommonJsExportNames } from "./inject-types/commonjs-exports.ts";
import {
	CHARS_PER_TOKEN,
	DEFAULT_TOKEN_BUDGET,
	MAX_HOOK_FILE_BYTES,
	MAX_IMPORT_FILES,
	MAX_IMPORT_RESOLVE_MS,
	MAX_TIER1_SYMBOLS,
	SUPPORTED_EXTENSIONS,
	SVELTE_EXTENSION,
} from "./inject-types/constants.ts";
import { readFileUtf8IfUnderLimit } from "./inject-types/fs-read.ts";
import { getImportCandidates } from "./inject-types/import-resolution.ts";
import type { LanguageFamily } from "./inject-types/language-family.ts";
import { getLanguageFamily } from "./inject-types/language-family.ts";

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
	children?: ProbeSymbol[];
}

interface ProbeResult {
	file: string;
	symbols: ProbeSymbol[];
}

interface ParseContext {
	filePath?: string;
	fileContent?: string;
	language?: LanguageFamily;
	publicNames?: Set<string>;
	commonJsExportNames?: Set<string>;
}

interface ProbeSource {
	content: string;
	extension: string;
}

interface ExtractedScriptBlock {
	content: string;
	lineOffset: number;
	probeExtension: ".js" | ".ts";
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
	typeRefs?: Set<string>;
	source?: string;
}

// Re-export constants for tests and tooling
export {
	CHARS_PER_TOKEN,
	DEFAULT_TOKEN_BUDGET,
	MAX_HOOK_FILE_BYTES,
	MAX_IMPORT_FILES,
	MAX_IMPORT_RESOLVE_MS,
	MAX_TIER1_SYMBOLS,
	SUPPORTED_EXTENSIONS,
	SVELTE_EXTENSION,
};

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
	return new Promise((resolvePromise) => {
		let data = "";
		process.stdin.setEncoding("utf-8");
		process.stdin.on("data", (chunk: string) => { data += chunk; });
		process.stdin.on("end", () => resolvePromise(data));
		process.stdin.resume();
	});
}

// --- Logging ---

function spineLog(): void {
	if (!process.env.SPINE_HOOK_LOG) return;
	try {
		const logPath = process.env.SPINE_LOG_FILE ?? join(homedir(), ".config", "spine", "logs", "hooks.jsonl");
		try { mkdirSync(dirname(logPath), { recursive: true }); } catch {}

		let size = 0;
		try { size = statSync(logPath).size; } catch {}
		if (size >= 512000) { // keep in sync with _spine_log() in hooks/_log.sh
			rmSync(logPath + ".2", { force: true });
			try { renameSync(logPath + ".1", logPath + ".2"); } catch {}
			try { renameSync(logPath, logPath + ".1"); } catch {}
		}

		const entry = JSON.stringify({ ts: new Date().toISOString(), event: "postToolUse", hook: "inject-types-on-read", tool: "Read" }) + "\n";
		appendFileSync(logPath, entry);
	} catch {}
}

// --- Main ---

async function main(): Promise<void> {
	spineLog();
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
			emit({ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: result } });
		} else {
			emit({});
		}
	} catch {
		emit({});
	}
}

if ((import.meta as unknown as { main?: boolean }).main) {
	await main();
}

// --- Core ---

async function processFile(filePath: string, offset?: number, limit?: number): Promise<string | null> {
	let localSymbols: ProbeSymbol[] = [];
	const fileContent = readFileUtf8IfUnderLimit(filePath, MAX_HOOK_FILE_BYTES);
	if (!fileContent) return null;

	if (SVELTE_EXTENSION.test(filePath)) {
		const extracted = await extractSvelteScripts(filePath);
		if (!extracted.length) return null;

		for (const block of extracted) {
			const symbols = probeSymbols(filePath, {
				content: block.content,
				extension: block.probeExtension,
			});

			for (const sym of symbols) {
				sym.line += block.lineOffset;
				sym.end_line += block.lineOffset;
			}

			localSymbols.push(...symbols);
		}
	} else {
		localSymbols = probeSymbols(filePath);
	}

	if (!localSymbols.length) return null;

	const classified = classifySymbols(localSymbols, {
		filePath,
		fileContent,
	});

	const importedSymbols = resolveImports(filePath);

	const allSymbols = promoteImportedSymbols(classified, importedSymbols);
	const relevantSymbols = pruneSymbolsForOutput(filePath, fileContent, allSymbols);

	const visible = filterVisible(relevantSymbols, offset, limit);

	const { included, omittedCount } = applyBudget(visible, DEFAULT_TOKEN_BUDGET);

	if (!included.length) return null;

	return formatOutput(basename(filePath), included, omittedCount);
}

// --- Symbol Extraction ---

function probeSymbols(filePath: string, source?: ProbeSource): ProbeSymbol[] {
	try {
		const inlineSource = source ?? getRemappedProbeSource(filePath);

		if (inlineSource) {
			const hash = createHash("md5").update(`${filePath}:${inlineSource.extension}:${inlineSource.content}`).digest("hex").slice(0, 8);
			const tmpPath = join(tmpdir(), `probe-remap-${hash}${inlineSource.extension}`);
			writeFileSync(tmpPath, inlineSource.content);
			try {
				const json = execFileSync("probe", ["symbols", "--format", "json", tmpPath], {
					timeout: 5000,
					stdio: ["pipe", "pipe", "pipe"],
				}).toString();
				const results: ProbeResult[] = JSON.parse(json);
				return flattenProbeSymbols(results[0]?.symbols ?? [], getLanguageFamily(filePath) === "java");
			} finally {
				try { unlinkSync(tmpPath); } catch {}
			}
		}

		const json = execFileSync("probe", ["symbols", "--format", "json", filePath], {
			timeout: 5000,
			stdio: ["pipe", "pipe", "pipe"],
		}).toString();
		const results: ProbeResult[] = JSON.parse(json);
		return flattenProbeSymbols(results[0]?.symbols ?? [], getLanguageFamily(filePath) === "java");
	} catch {
		return [];
	}
}

// --- Svelte ---

async function extractSvelteScripts(filePath: string): Promise<ExtractedScriptBlock[]> {
	const fileContent = readFileUtf8IfUnderLimit(filePath, MAX_HOOK_FILE_BYTES);
	if (!fileContent) return [];

	const scripts: ExtractedScriptBlock[] = [];

	const svelteCompilerPath = findNearestModule(filePath, "svelte/compiler/index.js");
	if (svelteCompilerPath) {
		try {
			{
				const svelteCompiler = await import(svelteCompilerPath);
				const ast = svelteCompiler.parse(fileContent, { modern: true, filename: filePath });

				for (const script of [ast.module, ast.instance].filter(Boolean)) {
					const scriptTag = fileContent.slice(script.start, script.end);
					const openTagEnd = scriptTag.indexOf(">") + 1;
					const closeTagStart = scriptTag.lastIndexOf("</script>");
					if (openTagEnd <= 0 || closeTagStart < 0) continue;

					const content = scriptTag.slice(openTagEnd, closeTagStart);
					const lineOffset = fileContent.slice(0, script.start + openTagEnd).split("\n").length - 1;
					scripts.push({
						content,
						lineOffset,
						probeExtension: getSvelteScriptProbeExtension(script.attributes),
					});
				}

				return scripts;
			}
		} catch {
			// Fall through to regex
		}
	}

	const regex = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
	let match: RegExpExecArray | null;
	while ((match = regex.exec(fileContent)) !== null) {
		const attrs = match[1] ?? "";
		const content = match[2] ?? "";
		const contentStart = match.index + match[0].indexOf(content);
		const beforeScript = fileContent.slice(0, contentStart);
		scripts.push({
			content,
			lineOffset: beforeScript.split("\n").length - 1,
			probeExtension: getSvelteScriptProbeExtension(attrs),
		});
	}

	return scripts;
}

// --- Classification ---

export function classifySymbols(symbols: ProbeSymbol[], context: ParseContext = {}): ClassifiedSymbol[] {
	const classified = normalizeSymbols(symbols, context);

	for (const s of classified) {
		s.typeRefs = extractTypeReferences(s.signature);
	}

	const tier1 = classified.filter(s => s.exported && s.realKind === "function");
	for (const s of tier1) s.tier = 1;

	const tier1Refs = new Set<string>();
	for (const s of tier1) {
		for (const ref of s.typeRefs!) tier1Refs.add(ref);
	}

	const tier2Names = new Set<string>();
	for (const s of classified) {
		if (s.tier > 0) continue;
		if (tier1Refs.has(s.realName)) {
			s.tier = 2;
			tier2Names.add(s.realName);
		}
	}

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

	for (const s of classified) {
		if (s.tier > 0) continue;
		if (tier2Refs.has(s.realName)) {
			s.tier = 3;
		}
	}

	for (const s of classified) {
		if (s.tier > 0) continue;
		if (s.exported) s.tier = 4;
	}

	for (const s of classified) {
		if (s.tier === 0) s.tier = 5;
	}

	return classified.sort((a, b) => a.tier - b.tier);
}

export function parseSymbol(sym: ProbeSymbol, context: ParseContext = {}): { realName: string; realKind: string; exported: boolean } {
	return parseSymbolWithContext(sym, context);
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

function resolveImports(filePath: string): ClassifiedSymbol[] {
	const fileContent = readFileUtf8IfUnderLimit(filePath, MAX_HOOK_FILE_BYTES);
	if (!fileContent) return [];

	const imported: ClassifiedSymbol[] = [];
	const projectRoot = findProjectRoot(filePath);
	const resolvedPaths = getImportCandidates(filePath, fileContent, projectRoot);
	let resolvedCount = 0;
	const startTime = Date.now();

	for (const resolved of resolvedPaths) {
		if (resolvedCount >= MAX_IMPORT_FILES) break;
		if (Date.now() - startTime > MAX_IMPORT_RESOLVE_MS) break;
		if (!resolved) continue;

		resolvedCount++;

		const resolvedContent = readFileUtf8IfUnderLimit(resolved, MAX_HOOK_FILE_BYTES);
		if (!resolvedContent) continue;

		const symbols = probeSymbols(resolved);
		const sourceLabel = basename(resolved);
		const normalized = normalizeSymbols(symbols, {
			filePath: resolved,
			fileContent: resolvedContent,
			language: getLanguageFamily(resolved),
		});

		for (const sym of normalized) {
			if (!sym.exported) continue;
			imported.push({
				name: sym.name,
				realName: sym.realName,
				realKind: sym.realKind,
				signature: sym.signature,
				exported: true,
				line: sym.line,
				endLine: sym.endLine,
				tier: 5,
				tokens: estimateTokens(sym.signature),
				source: sourceLabel,
				typeRefs: sym.typeRefs,
			});
		}
	}

	return imported;
}

function normalizeSymbols(symbols: ProbeSymbol[], context: ParseContext): ClassifiedSymbol[] {
	const language = context.language ?? getLanguageFamily(context.filePath ?? "");
	const publicNames = context.publicNames ?? (
		language === "python" ? extractPythonPublicNames(context.fileContent ?? "") : undefined
	);
	const commonJsExportNames = context.commonJsExportNames ?? (
		language === "javascript" ? extractCommonJsExportNames(context.fileContent ?? "") : undefined
	);

	return symbols.map((sym) => {
		const { realName, realKind, exported } = parseSymbolWithContext(sym, {
			...context,
			language,
			publicNames,
			commonJsExportNames,
		});
		const signature = normalizeSignature(sym.signature, language, realKind);

		return {
			name: sym.name,
			realName,
			realKind,
			signature,
			exported,
			line: sym.line,
			endLine: sym.end_line,
			tier: 0,
			tokens: estimateTokens(signature),
		};
	});
}

function parseSymbolWithContext(sym: ProbeSymbol, context: ParseContext): { realName: string; realKind: string; exported: boolean } {
	const language = context.language ?? getLanguageFamily(context.filePath ?? "");
	if (language === "python") {
		return parsePythonSymbol(sym, context.publicNames);
	}
	if (language === "java") {
		return parseJavaSymbol(sym);
	}
	return parseJavaScriptSymbol(sym, context.commonJsExportNames);
}

function parseJavaScriptSymbol(
	sym: ProbeSymbol,
	commonJsExportNames?: Set<string>,
): { realName: string; realKind: string; exported: boolean } {
	if (sym.kind === "export") {
		const match = sym.signature.match(
			/^export\s+(?:default\s+)?(?:async\s+)?(?:abstract\s+)?(function|interface|type|class|const|enum|let|var)\s+(\w+)/,
		);
		if (match) {
			return { realName: match[2], realKind: match[1], exported: true };
		}
		return { realName: sym.name, realKind: "unknown", exported: true };
	}

	const commonJsMatch = sym.signature.match(
		/^(?:module\.)?exports\.(\w+)\s*=\s*(?:async\s+)?(?:function|class)\b/,
	);
	if (commonJsMatch) {
		const realKind = /\bclass\b/.test(sym.signature) ? "class" : "function";
		return { realName: commonJsMatch[1], realKind, exported: true };
	}

	const commonJsValueMatch = sym.signature.match(/^(?:module\.)?exports\.(\w+)\s*=/);
	if (commonJsValueMatch) {
		return { realName: commonJsValueMatch[1], realKind: "const", exported: true };
	}

	const commonJsDefaultMatch = sym.signature.match(
		/^module\.exports\s*=\s*(?:async\s+)?(?:function|class)\s*(\w+)?/,
	);
	if (commonJsDefaultMatch) {
		const realKind = /\bclass\b/.test(sym.signature) ? "class" : "function";
		return {
			realName: commonJsDefaultMatch[1] || "module.exports",
			realKind,
			exported: true,
		};
	}

	if (commonJsExportNames?.has(sym.name)) {
		return {
			realName: sym.name,
			realKind: sym.kind === "method" ? "function" : sym.kind,
			exported: true,
		};
	}

	return { realName: sym.name, realKind: sym.kind === "method" ? "function" : sym.kind, exported: false };
}

function parsePythonSymbol(
	sym: ProbeSymbol,
	publicNames?: Set<string>,
): { realName: string; realKind: string; exported: boolean } {
	if (sym.signature.startsWith("__all__")) {
		return { realName: "__all__", realKind: "variable", exported: false };
	}

	const realName = sym.name;
	const exported = publicNames ? publicNames.has(realName) : !realName.startsWith("_");
	const realKind = sym.kind === "method" ? "function" : sym.kind;
	return { realName, realKind, exported };
}

function parseJavaSymbol(sym: ProbeSymbol): { realName: string; realKind: string; exported: boolean } {
	const realName = sym.name;
	const realKind = sym.kind === "method" ? "function" : sym.kind;
	const exported = /\bpublic\b/.test(sym.signature);
	return { realName, realKind, exported };
}

function getRemappedProbeSource(filePath: string): ProbeSource | undefined {
	const extension = getProbeRemapExtension(filePath);
	if (!extension) return undefined;
	const content = readFileUtf8IfUnderLimit(filePath, MAX_HOOK_FILE_BYTES);
	if (!content) return undefined;
	return {
		content,
		extension,
	};
}

function getProbeRemapExtension(filePath: string): string | undefined {
	if (/\.(mjs|cjs)$/i.test(filePath)) return ".js";
	if (/\.(mts|cts)$/i.test(filePath)) return ".ts";
	return undefined;
}

function flattenProbeSymbols(symbols: ProbeSymbol[], flattenChildren: boolean, depth = 0): ProbeSymbol[] {
	const flat: ProbeSymbol[] = [];
	for (const sym of symbols) {
		flat.push({
			name: sym.name,
			kind: sym.kind,
			signature: sym.signature,
			line: sym.line,
			end_line: sym.end_line,
		});
		const shouldFlattenChildren = flattenChildren
			&& sym.children?.length
			&& depth === 0
			&& (!["class", "interface", "enum"].includes(sym.kind) || /\bpublic\b/.test(sym.signature));
		if (shouldFlattenChildren) {
			flat.push(...flattenProbeSymbols(sym.children!, flattenChildren, depth + 1));
		}
	}
	return flat;
}

function getSvelteScriptProbeExtension(attrs: unknown): ".js" | ".ts" {
	const lang = extractSvelteLang(attrs);
	return lang === "ts" || lang === "typescript" ? ".ts" : ".js";
}

function extractSvelteLang(attrs: unknown): string | undefined {
	if (typeof attrs === "string") {
		const match = attrs.match(/\blang=["']([^"']+)["']/i);
		return match?.[1]?.toLowerCase();
	}

	if (Array.isArray(attrs)) {
		const langAttr = attrs.find((attr: any) => attr?.name === "lang");
		const value = langAttr?.value?.[0]?.data;
		if (typeof value === "string") return value.toLowerCase();
	}

	return undefined;
}

function extractPythonPublicNames(fileContent: string): Set<string> | undefined {
	const match = fileContent.match(/__all__\s*=\s*[\[(]([\s\S]*?)[\])]/m);
	if (!match) return undefined;

	const names = new Set<string>();
	const itemRegex = /["']([^"']+)["']/g;
	let item: RegExpExecArray | null;
	while ((item = itemRegex.exec(match[1])) !== null) {
		names.add(item[1]);
	}
	return names.size ? names : undefined;
}

function normalizeSignature(signature: string, language: LanguageFamily, realKind: string): string {
	if (language === "java" && ["class", "interface", "enum"].includes(realKind)) {
		const braceIndex = signature.indexOf("{");
		if (braceIndex >= 0) {
			return `${signature.slice(0, braceIndex).trimEnd()} { ... }`;
		}
	}
	return signature;
}

function pruneSymbolsForOutput(filePath: string, fileContent: string, symbols: ClassifiedSymbol[]): ClassifiedSymbol[] {
	const language = getLanguageFamily(filePath);
	if (language === "javascript") {
		if (isCommonJsSource(filePath, fileContent)) {
			return symbols.filter((symbol) => symbol.source || symbol.tier < 5);
		}
		return symbols;
	}
	return symbols.filter((symbol) => symbol.source || symbol.tier < 5);
}

function isCommonJsSource(filePath: string, fileContent: string): boolean {
	return /\.(cjs|cts)$/i.test(filePath) || /\bmodule\.exports\b|\bexports\./.test(fileContent);
}

function promoteImportedSymbols(
	local: ClassifiedSymbol[],
	imported: ClassifiedSymbol[],
): ClassifiedSymbol[] {
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
	if (offset === undefined || limit === undefined) {
		return symbols.filter(s => !!s.source);
	}

	const rangeStart = offset + 1;
	const rangeEnd = offset + limit;

	return symbols.filter(s => {
		if (s.source) return true;
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
		if (seen.has(sym.realName)) continue;
		seen.add(sym.realName);

		if (sym.tier === 1) {
			if (tier1Count >= MAX_TIER1_SYMBOLS) continue;
			tier1Count++;
		}

		if (totalTokens + sym.tokens <= budget) {
			included.push(sym);
			totalTokens += sym.tokens;
		}
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
