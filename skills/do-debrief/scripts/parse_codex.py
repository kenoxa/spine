"""Codex session parser.

Reads index files for metadata then parses session JSONL for detail.
Outputs structured JSON for downstream analysis.
"""
from __future__ import annotations

import argparse
import json
import logging
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path

from common import (
    extract_file_paths,
    is_real_prompt,
    iter_jsonl,
    normalize_timestamp,
    project_name,
    truncate_text,
)

logger = logging.getLogger(__name__)

CODEX_DIR = Path.home() / ".codex"
SESSIONS_DIR = CODEX_DIR / "sessions"


# ---------------------------------------------------------------------------
# Step 1: Load index files
# ---------------------------------------------------------------------------

def _load_session_index() -> dict[str, dict]:
    """Load session_index.jsonl → {session_id: {thread_name, updated_at}}."""
    path = CODEX_DIR / "session_index.jsonl"
    result: dict[str, dict] = {}
    if not path.is_file():
        logger.debug("session_index.jsonl not found, skipping")
        return result
    for rec in iter_jsonl(path):
        sid = rec.get("id")
        if sid:
            result[sid] = {
                "thread_name": rec.get("thread_name"),
                "updated_at": rec.get("updated_at"),
            }
    return result


def _load_history() -> dict[str, dict]:
    """Load history.jsonl → {session_id: {ts, text}}."""
    path = CODEX_DIR / "history.jsonl"
    result: dict[str, dict] = {}
    if not path.is_file():
        logger.debug("history.jsonl not found, skipping")
        return result
    for rec in iter_jsonl(path):
        sid = rec.get("session_id")
        if sid:
            result[sid] = {
                "ts": rec.get("ts"),
                "text": rec.get("text"),
            }
    return result


# ---------------------------------------------------------------------------
# Step 2: Pre-filter by date directory
# ---------------------------------------------------------------------------

_DATE_DIR_RE = re.compile(r"/(\d{4})/(\d{2})/(\d{2})/")


def _date_from_path(path: Path) -> date | None:
    """Extract date from .../YYYY/MM/DD/... directory structure."""
    m = _DATE_DIR_RE.search(str(path))
    if not m:
        return None
    try:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None


def _collect_session_files(since: date, until: date | None) -> list[Path]:
    """Gather session JSONL files within the date range."""
    if not SESSIONS_DIR.is_dir():
        logger.warning("Sessions directory %s does not exist", SESSIONS_DIR)
        return []

    effective_until = until or date.today()
    files: list[Path] = []

    for jsonl_file in SESSIONS_DIR.rglob("*.jsonl"):
        file_date = _date_from_path(jsonl_file)
        if file_date is not None:
            if file_date < since or file_date > effective_until:
                continue
        # If date can't be parsed, include the file (don't skip on ambiguity)
        files.append(jsonl_file)

    return files


# ---------------------------------------------------------------------------
# Step 3: Parse session JSONL
# ---------------------------------------------------------------------------

def _extract_uuid_from_filename(path: Path) -> str | None:
    """Extract trailing UUID from rollout-...-{uuid}.jsonl filename."""
    stem = path.stem
    # UUID is the last 36-char segment
    parts = stem.rsplit("-", 5)
    if len(parts) >= 5:
        candidate = "-".join(parts[-5:])
        if len(candidate) == 36:
            return candidate
    return stem


def _parse_session(path: Path, index: dict[str, dict], history: dict[str, dict]) -> dict | None:
    """Parse a single session JSONL file into a session record."""
    session_id: str | None = None
    cwd: str | None = None
    model_provider: str | None = None
    git_info: dict | None = None
    cli_version: str | None = None

    user_prompts: list[str] = []
    tool_calls: dict[str, int] = {}
    files_touched: set[str] = set()
    errors: list[str] = []
    turn_ids: set[str] = set()
    timestamps: list[float] = []

    for rec in iter_jsonl(path):
        ts_raw = rec.get("timestamp")
        if ts_raw is not None:
            # Handle both numeric (epoch) and ISO 8601 string timestamps
            if isinstance(ts_raw, (int, float)):
                ts_val = float(ts_raw)
                if ts_val > 1e12:
                    ts_val /= 1000.0
                timestamps.append(ts_val)
            elif isinstance(ts_raw, str):
                iso = normalize_timestamp(ts_raw)
                if iso:
                    try:
                        dt = datetime.fromisoformat(iso)
                        timestamps.append(dt.timestamp())
                    except (ValueError, OSError):
                        pass

        rec_type = rec.get("type")
        payload = rec.get("payload") or {}

        if rec_type == "session_meta":
            session_id = payload.get("id")
            cwd = payload.get("cwd")
            cli_version = payload.get("cli_version")
            model_provider = payload.get("model_provider")
            git_info = payload.get("git")

        elif rec_type == "response_item":
            item_type = payload.get("type")

            if item_type == "reasoning":
                continue

            if item_type == "message":
                role = payload.get("role")
                if role == "developer":
                    continue
                if role == "user":
                    content = payload.get("content")
                    if isinstance(content, list) and content:
                        text = content[0].get("text", "") if isinstance(content[0], dict) else ""
                    elif isinstance(content, str):
                        text = content
                    else:
                        text = ""
                    if text and is_real_prompt(text):
                        user_prompts.append(truncate_text(text, 500))

            elif item_type == "function_call":
                name = payload.get("name", "exec_command")
                tool_calls[name] = tool_calls.get(name, 0) + 1

                args_raw = payload.get("arguments")
                if isinstance(args_raw, str):
                    try:
                        args = json.loads(args_raw)
                    except (json.JSONDecodeError, TypeError):
                        args = {}
                elif isinstance(args_raw, dict):
                    args = args_raw
                else:
                    args = {}

                cmd = args.get("cmd", "")
                if cmd:
                    for fp in extract_file_paths(cmd):
                        files_touched.add(fp)

            elif item_type == "custom_tool_call":
                name = payload.get("name", "unknown_tool")
                tool_calls[name] = tool_calls.get(name, 0) + 1

            elif item_type == "function_call_output":
                output = payload.get("output", "")
                if isinstance(output, str) and "Process exited with code" in output:
                    # Check for non-zero exit code
                    m = re.search(r"Process exited with code (\d+)", output)
                    if m and m.group(1) != "0":
                        errors.append(truncate_text(output.strip(), 500))

        elif rec_type == "turn_context":
            tid = payload.get("turn_id")
            if tid:
                turn_ids.add(tid)

        elif rec_type == "event_msg":
            # Token usage extraction placeholder — skip if not present
            pass

        # Unknown types: skip silently

    # Determine session ID
    if not session_id:
        session_id = _extract_uuid_from_filename(path)

    if not session_id:
        return None

    short_id = session_id[:12] if len(session_id) >= 12 else session_id

    # Timestamp from first record
    first_ts = normalize_timestamp(min(timestamps)) if timestamps else None

    # Duration from first/last timestamp
    duration_minutes: float | None = None
    if len(timestamps) >= 2:
        span = max(timestamps) - min(timestamps)
        if span > 0:
            duration_minutes = round(span / 60.0, 1)

    # Merge index metadata
    idx = index.get(session_id, {})
    thread_name = idx.get("thread_name")

    # If no thread_name from index, try history text
    hist = history.get(session_id, {})
    if not thread_name and hist.get("text"):
        thread_name = truncate_text(hist["text"], 200)

    # Fallback timestamp from history
    if not first_ts and hist.get("ts"):
        first_ts = normalize_timestamp(hist["ts"])

    # Project name from cwd
    proj = project_name(cwd) if cwd else "unknown"

    # Cap and sort collections
    sorted_files = sorted(files_touched)[:20]
    capped_prompts = user_prompts[:10]

    return {
        "id": short_id,
        "provider": "codex",
        "project": proj,
        "timestamp": first_ts,
        "duration_minutes": duration_minutes,
        "thread_name": thread_name,
        "user_prompts": capped_prompts,
        "tool_calls": tool_calls,
        "files_touched": sorted_files,
        "errors": errors,
        "turn_count": len(turn_ids),
        "model_provider": model_provider,
        "collaboration_mode": "full-auto",
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Parse Codex session logs")
    parser.add_argument("--since", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--until", default=None, help="End date (YYYY-MM-DD, default: today)")
    parser.add_argument("--output", required=True, help="Output directory")
    parser.add_argument("--verbose", action="store_true", help="Log stats to stderr")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format="%(levelname)s: %(message)s",
        stream=sys.stderr,
    )

    since = date.fromisoformat(args.since)
    until = date.fromisoformat(args.until) if args.until else None

    # Step 1: Load indices
    index = _load_session_index()
    history = _load_history()
    logger.info("Loaded %d index entries, %d history entries", len(index), len(history))

    # Step 2: Collect session files
    session_files = _collect_session_files(since, until)
    logger.info("Found %d session files in date range", len(session_files))

    # Step 3: Parse sessions
    sessions: list[dict] = []
    errors_total = 0

    for sf in session_files:
        try:
            session = _parse_session(sf, index, history)
            if session:
                sessions.append(session)
                errors_total += len(session.get("errors", []))
        except Exception:
            logger.exception("Failed to parse %s", sf)

    # Sort by timestamp descending (None last)
    sessions.sort(key=lambda s: s.get("timestamp") or "", reverse=True)

    logger.info(
        "Parsed %d sessions, %d tool calls, %d errors",
        len(sessions),
        sum(sum(s.get("tool_calls", {}).values()) for s in sessions),
        errors_total,
    )

    # Write output
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "codex_sessions.json"

    data = {
        "provider": "codex",
        "sessions": sessions,
    }
    output_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    logger.info("Wrote %s", output_path)


if __name__ == "__main__":
    main()
