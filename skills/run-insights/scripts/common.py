"""Shared utilities for cross-tool AI session parsers.

Provides JSONL streaming, timestamp normalization, text processing,
output serialization, and source detection. Python 3.9+ stdlib only.
"""
from __future__ import annotations

import json
import logging
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

logger = logging.getLogger(__name__)


def iter_jsonl(path: Path, max_line_bytes: int = 10_000_000) -> Iterator[dict]:
    """Stream JSONL file line by line, skipping malformed entries."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        for lineno, raw_line in enumerate(fh, start=1):
            if lineno == 1:
                raw_line = raw_line.lstrip("\ufeff")
            line = raw_line.strip()
            if not line:
                continue
            if len(line.encode("utf-8", errors="replace")) > max_line_bytes:
                logger.warning("Line %d in %s exceeds %d bytes, skipping", lineno, path, max_line_bytes)
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                logger.warning("Malformed JSON at line %d in %s, skipping", lineno, path)


def normalize_timestamp(raw: Any) -> str | None:
    """Convert various timestamp formats to ISO 8601 UTC string."""
    if raw is None:
        return None

    if isinstance(raw, (int, float)):
        ts = float(raw)
        if ts > 1e12:
            ts /= 1000.0
        try:
            dt = datetime.fromtimestamp(ts, tz=timezone.utc)
            return dt.isoformat()
        except (OSError, OverflowError, ValueError):
            return None

    if not isinstance(raw, str):
        return None

    text = raw.strip()
    if not text:
        return None

    # Replace Z suffix for Python 3.9 compat
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"

    try:
        dt = datetime.fromisoformat(text)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc).isoformat()
    except ValueError:
        return None


def truncate_text(text: str, max_chars: int = 500) -> str:
    """Truncate text with ellipsis suffix if over limit."""
    if len(text) <= max_chars:
        return text
    return text[: max_chars - 1] + "\u2026"


_FILE_PATH_RE = re.compile(r"(?<!\w)/(?:[a-zA-Z0-9._-]+/)+[a-zA-Z0-9._-]+\.[a-zA-Z0-9]+")


def extract_file_paths(text: str) -> list[str]:
    """Extract unique /path/to/file.ext patterns from text."""
    seen: set[str] = set()
    result: list[str] = []
    for match in _FILE_PATH_RE.finditer(text):
        p = match.group(0)
        if p not in seen:
            seen.add(p)
            result.append(p)
    return result


_NOISE_MARKERS = (
    "<system-reminder>",
    "<local-command-caveat>",
    "<command-name>",
    "<command-message>",
    "<command-args>",
    "<local-command-stdout>",
    "<available-deferred-tools>",
    "[Request interrupted",
    "Base directory for this skill:",
    "ARGUMENTS:",
)


def is_real_prompt(text: str) -> bool:
    """Filter system-generated noise from user messages."""
    if not text or len(text) <= 5:
        return False
    stripped = text.lstrip()
    if stripped.startswith("<") and not stripped.startswith("<http"):
        return False
    for marker in _NOISE_MARKERS:
        if marker in text:
            return False
    if len(text) > 2000:
        return False
    return True


def write_output(data: Any, path: Path, max_bytes: int = 102400) -> bool:
    """Write JSON to file with priority-based truncation if oversized."""
    truncated = False

    def _serialize() -> bytes:
        return json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")

    blob = _serialize()

    if len(blob) > max_bytes:
        if isinstance(data, dict) and "notable_sessions" in data:
            del data["notable_sessions"]
            truncated = True
            blob = _serialize()

    if len(blob) > max_bytes:
        if isinstance(data, dict):
            for value in data.values():
                if isinstance(value, list) and len(value) > 20:
                    del value[10:]
                    truncated = True
            blob = _serialize()

    if len(blob) > max_bytes:
        if isinstance(data, dict):
            for value in data.values():
                if isinstance(value, dict):
                    for v2 in value.values():
                        if isinstance(v2, dict) and "sample_prompts" in v2:
                            v2["sample_prompts"] = v2["sample_prompts"][:5]
                            truncated = True
                if isinstance(value, list):
                    for item in value:
                        if isinstance(item, dict) and "sample_prompts" in item:
                            item["sample_prompts"] = item["sample_prompts"][:5]
                            truncated = True
            blob = _serialize()

    if truncated and isinstance(data, dict):
        data.setdefault("meta", {})["truncated"] = True
        blob = _serialize()

    # Atomic write: write to temp file then rename
    fd, tmp_path = tempfile.mkstemp(
        dir=path.parent, prefix=path.name, suffix=".tmp"
    )
    closed = False
    try:
        os.write(fd, blob)
        os.close(fd)
        closed = True
        os.replace(tmp_path, path)
    except BaseException:
        if not closed:
            os.close(fd)
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

    return truncated


_SKIP_COMPONENTS = frozenset({"", "/", "Users", "home"})


def project_name(cwd: str) -> str:
    """Extract short project name from working directory path."""
    parts = Path(cwd).parts
    meaningful = [p for p in parts if p not in _SKIP_COMPONENTS]
    # Skip username (first meaningful component after filtering root/Users/home)
    if len(meaningful) > 1:
        meaningful = meaningful[1:]
    return "/".join(meaningful[-2:]) if meaningful else "unknown"
