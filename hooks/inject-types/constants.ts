export const SUPPORTED_EXTENSIONS = /\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|svelte|py|java)$/;
export const SVELTE_EXTENSION = /\.svelte$/;
export const CHARS_PER_TOKEN = 4;
export const DEFAULT_TOKEN_BUDGET = 1500;
export const MAX_IMPORT_FILES = 10;
export const MAX_IMPORT_RESOLVE_MS = 200;
export const MAX_TIER1_SYMBOLS = 15;

/** Max UTF-8 byte length for any file read in this hook (primary file, imports, remap). */
export const MAX_HOOK_FILE_BYTES = 512 * 1024;
