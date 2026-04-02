import { readFileSync, statSync } from "node:fs";

/**
 * Reads a UTF-8 file when its size is at most maxBytes. Returns null if missing, unreadable, or too large.
 */
export function readFileUtf8IfUnderLimit(filePath: string, maxBytes: number): string | null {
	try {
		const st = statSync(filePath);
		if (st.size > maxBytes) return null;
		return readFileSync(filePath, "utf-8");
	} catch {
		return null;
	}
}
