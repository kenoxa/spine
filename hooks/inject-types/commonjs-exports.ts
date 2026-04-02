/**
 * Heuristic extraction of names assigned via `module.exports = { ... }` and `module.exports = Foo`.
 * Object bodies use brace-depth matching so nested `{ ... }` does not truncate the outer literal.
 */

function findMatchingBrace(content: string, openBraceIndex: number): number | null {
	let depth = 0;
	for (let i = openBraceIndex; i < content.length; i++) {
		const c = content[i];
		if (c === "{") depth++;
		else if (c === "}") {
			depth--;
			if (depth === 0) return i;
		}
	}
	return null;
}

/** Split on commas that separate top-level properties (tracks `{}`, `()`, `[]` nesting). */
function splitTopLevelCommas(body: string): string[] {
	const parts: string[] = [];
	let depth = 0;
	let paren = 0;
	let square = 0;
	let start = 0;

	for (let i = 0; i < body.length; i++) {
		const c = body[i];
		if (c === "{") depth++;
		else if (c === "}") depth--;
		else if (c === "(") paren++;
		else if (c === ")") paren--;
		else if (c === "[") square++;
		else if (c === "]") square--;
		else if (c === "," && depth === 0 && paren === 0 && square === 0) {
			parts.push(body.slice(start, i));
			start = i + 1;
		}
	}
	parts.push(body.slice(start));
	return parts.map((p) => p.trim()).filter(Boolean);
}

function extractModuleExportsObjectBodies(fileContent: string): string[] {
	const bodies: string[] = [];
	const re = /module\.exports\s*=\s*\{/g;
	let m: RegExpExecArray | null;
	while ((m = re.exec(fileContent)) !== null) {
		const openBraceIndex = m.index + m[0].length - 1;
		const closeIndex = findMatchingBrace(fileContent, openBraceIndex);
		if (closeIndex === null) continue;
		bodies.push(fileContent.slice(openBraceIndex + 1, closeIndex));
	}
	return bodies;
}

function addNamesFromObjectBody(body: string, names: Set<string>): void {
	for (const rawProperty of splitTopLevelCommas(body)) {
		const property = rawProperty.trim();
		if (!property) continue;
		if (property.startsWith("...")) continue;

		const shorthandMatch = property.match(/^(\w+)$/);
		if (shorthandMatch) {
			names.add(shorthandMatch[1]);
			continue;
		}

		const aliasMatch = property.match(/^\w+\s*:\s*(\w+)$/);
		if (aliasMatch) {
			names.add(aliasMatch[1]);
		}
	}
}

export function extractCommonJsExportNames(fileContent: string): Set<string> | undefined {
	const names = new Set<string>();

	for (const body of extractModuleExportsObjectBodies(fileContent)) {
		addNamesFromObjectBody(body, names);
	}

	const directExportRegex = /module\.exports\s*=\s*(\w+)\s*(?:;|$)/gm;
	let match: RegExpExecArray | null;
	while ((match = directExportRegex.exec(fileContent)) !== null) {
		names.add(match[1]);
	}

	return names.size ? names : undefined;
}
