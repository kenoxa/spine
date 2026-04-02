export type LanguageFamily = "javascript" | "python" | "java";

export function getLanguageFamily(filePath: string): LanguageFamily {
	if (/\.(py)$/i.test(filePath)) return "python";
	if (/\.(java)$/i.test(filePath)) return "java";
	return "javascript";
}
