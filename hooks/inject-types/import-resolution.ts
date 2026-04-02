import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { SUPPORTED_EXTENSIONS } from "./constants.ts";
import { getLanguageFamily } from "./language-family.ts";

export function getImportCandidates(
	filePath: string,
	fileContent: string,
	projectRoot: string | null,
): string[] {
	const language = getLanguageFamily(filePath);
	if (language === "python") {
		return dedupePaths(resolvePythonImportPaths(filePath, fileContent, projectRoot));
	}
	if (language === "java") {
		return dedupePaths(resolveJavaImportPaths(projectRoot, fileContent));
	}
	return dedupePaths(resolveJavaScriptImportPaths(filePath, fileContent));
}

function resolveJavaScriptImportPaths(filePath: string, fileContent: string): string[] {
	const fileDir = dirname(filePath);
	const imports = new Set<string>();
	const regexes = [
		/^(?:import|export)\s+.+?\s+from\s+['"]([^'"]+)['"]/gm,
		/\brequire\(\s*['"]([^'"]+)['"]\s*\)/g,
	];

	for (const regex of regexes) {
		let match: RegExpExecArray | null;
		while ((match = regex.exec(fileContent)) !== null) {
			const importPath = match[1];
			if (!importPath.startsWith(".")) continue;
			const resolved = resolveJavaScriptImportPath(fileDir, importPath);
			if (resolved) imports.add(resolved);
		}
	}

	return [...imports];
}

function resolveJavaScriptImportPath(dir: string, importPath: string): string | null {
	const extensions = [
		"",
		".js",
		".jsx",
		".mjs",
		".cjs",
		".ts",
		".tsx",
		".mts",
		".cts",
		"/index.js",
		"/index.jsx",
		"/index.mjs",
		"/index.cjs",
		"/index.ts",
		"/index.tsx",
		"/index.mts",
		"/index.cts",
	];

	for (const ext of extensions) {
		const candidate = resolve(dir, importPath + ext);
		if (existsSync(candidate) && SUPPORTED_EXTENSIONS.test(candidate)) return candidate;
	}
	return null;
}

function resolvePythonImportPaths(filePath: string, fileContent: string, projectRoot: string | null): string[] {
	const imports = new Set<string>();

	let match: RegExpExecArray | null;
	const fromRegex = /^from\s+([.\w]+)\s+import\s+([^\n#]+)/gm;
	while ((match = fromRegex.exec(fileContent)) !== null) {
		const modulePath = match[1];
		const importedNames = match[2]
			.split(",")
			.map((name) => name.trim().replace(/\s+as\s+\w+$/, ""))
			.filter(Boolean);

		const resolvedModule = resolvePythonModulePath(filePath, projectRoot, modulePath);
		if (resolvedModule) imports.add(resolvedModule);

		for (const importedName of importedNames) {
			if (importedName === "*") continue;
			const nestedModule = resolvePythonModulePath(
				filePath,
				projectRoot,
				joinPythonImportPath(modulePath, importedName),
			);
			if (nestedModule) imports.add(nestedModule);
		}
	}

	const importRegex = /^import\s+([A-Za-z_][\w.,\s]*)$/gm;
	while ((match = importRegex.exec(fileContent)) !== null) {
		const modules = match[1]
			.split(",")
			.map((name) => name.trim().replace(/\s+as\s+\w+$/, ""))
			.filter(Boolean);

		for (const modulePath of modules) {
			const resolved = resolvePythonModulePath(filePath, projectRoot, modulePath);
			if (resolved) imports.add(resolved);
		}
	}

	return [...imports];
}

function resolvePythonModulePath(filePath: string, projectRoot: string | null, modulePath: string): string | null {
	const relativeMatch = modulePath.match(/^(\.+)(.*)$/);
	let baseDir: string;
	let remainder = modulePath;

	if (relativeMatch) {
		const dots = relativeMatch[1].length;
		remainder = relativeMatch[2].replace(/^\./, "");
		baseDir = dirname(filePath);
		for (let i = 1; i < dots; i++) {
			baseDir = dirname(baseDir);
		}
	} else {
		if (!projectRoot) return null;
		baseDir = projectRoot;
	}

	const relativePath = remainder ? remainder.replace(/\./g, "/") : "";
	const candidates = [
		resolve(baseDir, `${relativePath}.py`),
		resolve(baseDir, relativePath, "__init__.py"),
	];

	for (const candidate of candidates) {
		if (existsSync(candidate)) return candidate;
	}
	return null;
}

function joinPythonImportPath(modulePath: string, importedName: string): string {
	if (/^\.+$/.test(modulePath)) {
		return `${modulePath}${importedName}`;
	}
	return `${modulePath}.${importedName}`;
}

function resolveJavaImportPaths(projectRoot: string | null, fileContent: string): string[] {
	if (!projectRoot) return [];

	const imports = new Set<string>();
	const regex = /^import\s+(?:static\s+)?([\w.]+);$/gm;
	let match: RegExpExecArray | null;
	while ((match = regex.exec(fileContent)) !== null) {
		const importPath = match[1];
		if (/^(java|javax|kotlin|android)\./.test(importPath)) continue;
		const resolved = resolveJavaImportPath(projectRoot, importPath);
		if (resolved) imports.add(resolved);
	}
	return [...imports];
}

function resolveJavaImportPath(projectRoot: string, importPath: string): string | null {
	const relativePath = `${importPath.replace(/\./g, "/")}.java`;
	const candidates = [
		resolve(projectRoot, relativePath),
		resolve(projectRoot, "src", "main", "java", relativePath),
		resolve(projectRoot, "src", "test", "java", relativePath),
	];

	for (const candidate of candidates) {
		if (existsSync(candidate)) return candidate;
	}
	return null;
}

function dedupePaths(paths: Array<string | null>): string[] {
	const seen = new Set<string>();
	const unique: string[] = [];
	for (const path of paths) {
		if (!path || seen.has(path)) continue;
		seen.add(path);
		unique.push(path);
	}
	return unique;
}
