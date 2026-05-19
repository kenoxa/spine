"""OpenCode session parser.

Reads session data from OpenCode's SQLite database.
Outputs structured JSON for downstream analysis.
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sqlite3
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from common import (
    extract_file_paths,
    is_real_prompt,
    normalize_timestamp,
    project_name,
    truncate_text,
    write_output,
)

logger = logging.getLogger(__name__)

BATCH_SIZE = 500
MAX_PROMPTS = 10
MAX_FILES = 20
MAX_PROMPT_CHARS = 500

# Regex for non-zero exit codes in tool output
_EXIT_CODE_RE = re.compile(r"(?:exit|exited|code)\s*[:=]?\s*(\d+)", re.IGNORECASE)


# ---------------------------------------------------------------------------
# DB path resolution
# ---------------------------------------------------------------------------


def _resolve_db_path() -> Path | None:
    """Resolve OpenCode SQLite DB path from environment."""
    data_dir = os.environ.get("OPENCODE_DATA_DIR")
    if data_dir:
        return Path(data_dir) / "opencode.db"

    appname = os.environ.get("OPENCODE_APPNAME", "opencode")
    xdg_data = os.environ.get("XDG_DATA_HOME")
    if xdg_data:
        return Path(xdg_data) / appname / "opencode.db"

    return Path.home() / ".local" / "share" / appname / "opencode.db"


# ---------------------------------------------------------------------------
# SQLite helpers
# ---------------------------------------------------------------------------


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    cur = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    )
    return cur.fetchone() is not None


def _query_sessions(
    conn: sqlite3.Connection, since_ms: int, until_ms: int
) -> list[dict[str, Any]]:
    """Query sessions within the date range."""
    if not _table_exists(conn, "session") or not _table_exists(conn, "project"):
        return []

    rows = conn.execute(
        """
        SELECT s.id, s.parent_id, s.title, s.slug, s.directory, s.time_created, p.worktree
        FROM session s
        JOIN project p ON s.project_id = p.id
        WHERE s.time_created >= ? AND s.time_created < ?
        """,
        (since_ms, until_ms),
    ).fetchall()

    sessions: list[dict[str, Any]] = []
    for row in rows:
        sessions.append({
            "id": row[0],
            "parent_id": row[1],
            "title": row[2],
            "slug": row[3],
            "directory": row[4],
            "time_created": row[5],
            "worktree": row[6],
        })
    return sessions


def _query_messages(
    conn: sqlite3.Connection, session_ids: list[str]
) -> dict[str, list[dict[str, Any]]]:
    """Query messages for given session IDs (batched)."""
    if not session_ids or not _table_exists(conn, "message"):
        return {}

    result: dict[str, list[dict[str, Any]]] = {}
    for i in range(0, len(session_ids), BATCH_SIZE):
        batch = session_ids[i : i + BATCH_SIZE]
        placeholders = ",".join("?" * len(batch))
        rows = conn.execute(
            f"SELECT id, session_id, time_created, data FROM message WHERE session_id IN ({placeholders})",
            batch,
        ).fetchall()

        for row in rows:
            sid = row[1]
            result.setdefault(sid, []).append({
                "id": row[0],
                "time_created": row[2],
                "data_raw": row[3],
            })
    return result


def _query_parts(
    conn: sqlite3.Connection, message_ids: list[str]
) -> dict[str, list[dict[str, Any]]]:
    """Query parts for given message IDs (batched)."""
    if not message_ids or not _table_exists(conn, "part"):
        return {}

    result: dict[str, list[dict[str, Any]]] = {}
    for i in range(0, len(message_ids), BATCH_SIZE):
        batch = message_ids[i : i + BATCH_SIZE]
        placeholders = ",".join("?" * len(batch))
        rows = conn.execute(
            f"SELECT id, message_id, time_created, data FROM part WHERE message_id IN ({placeholders})",
            batch,
        ).fetchall()

        for row in rows:
            mid = row[1]
            result.setdefault(mid, []).append({
                "id": row[0],
                "time_created": row[2],
                "data_raw": row[3],
            })
    return result


# ---------------------------------------------------------------------------
# JSON extraction helpers
# ---------------------------------------------------------------------------


def _safe_json_loads(raw: str) -> dict[str, Any] | None:
    """Parse JSON text, returning None on failure or non-dict result."""
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return None
    if not isinstance(data, dict):
        return None
    return data


def _extract_file_paths_from_input(input_data: Any) -> list[str]:
    """Extract file paths from structured tool input dict."""
    if not isinstance(input_data, dict):
        return []

    paths: list[str] = []
    for key in ("command", "filePath", "file", "path", "glob", "pattern"):
        val = input_data.get(key)
        if isinstance(val, str):
            paths.extend(extract_file_paths(val))
        elif isinstance(val, list):
            for item in val:
                if isinstance(item, str):
                    paths.extend(extract_file_paths(item))
    return paths


# ---------------------------------------------------------------------------
# Session builder
# ---------------------------------------------------------------------------


def _build_session(
    session: dict[str, Any],
    messages: list[dict[str, Any]],
    parts_by_message: dict[str, list[dict[str, Any]]],
) -> dict[str, Any] | None:
    """Assemble a single session record from raw DB rows."""
    session_id = session["id"]
    short_id = session_id[:12] if len(session_id) >= 12 else session_id

    # Project name
    directory = session.get("directory") or ""
    worktree = session.get("worktree") or ""
    proj = (
        project_name(directory)
        if directory
        else (project_name(worktree) if worktree else "unknown")
    )

    # Timestamp
    ts_raw = session.get("time_created")
    timestamp = None
    if isinstance(ts_raw, (int, float)):
        timestamp = normalize_timestamp(ts_raw / 1000.0)

    user_prompts: list[str] = []
    tool_calls: dict[str, int] = {}
    files_touched: set[str] = set()
    errors: list[str] = []
    message_times: list[int] = []

    for msg in messages:
        msg_time = msg.get("time_created")
        if isinstance(msg_time, (int, float)):
            message_times.append(int(msg_time))

        data = _safe_json_loads(msg.get("data_raw", "{}"))
        if data is None:
            continue

        role = data.get("role")

        msg_id = msg["id"]
        parts = parts_by_message.get(msg_id, [])
        for part in parts:
            part_data = _safe_json_loads(part.get("data_raw", "{}"))
            if part_data is None:
                continue

            part_type = part_data.get("type")

            if role == "user" and part_type == "text":
                text = part_data.get("text", "")
                if isinstance(text, str) and is_real_prompt(text):
                    user_prompts.append(truncate_text(text, MAX_PROMPT_CHARS))

            elif part_type == "tool":
                tool_name = part_data.get("tool", "unknown")
                tool_calls[tool_name] = tool_calls.get(tool_name, 0) + 1

                state = part_data.get("state", {})
                if isinstance(state, dict):
                    input_data = state.get("input")
                    if isinstance(input_data, dict):
                        for fp in _extract_file_paths_from_input(input_data):
                            files_touched.add(fp)

                    # Fallback: free-text fields in state
                    for key in ("input", "output", "result", "text", "error"):
                        val = state.get(key)
                        if isinstance(val, str):
                            for fp in extract_file_paths(val):
                                files_touched.add(fp)

                    status = state.get("status")
                    added_error = False

                    if status == "error":
                        err = (
                            state.get("error")
                            or state.get("output")
                            or state.get("result")
                            or ""
                        )
                        if isinstance(err, str) and err.strip():
                            errors.append(truncate_text(err.strip(), MAX_PROMPT_CHARS))
                            added_error = True

                    if not added_error:
                        output = state.get("output", "")
                        if isinstance(output, str):
                            m = _EXIT_CODE_RE.search(output)
                            if m and m.group(1) != "0":
                                errors.append(
                                    truncate_text(output.strip(), MAX_PROMPT_CHARS)
                                )

            elif part_type == "text":
                text = part_data.get("text", "")
                if isinstance(text, str):
                    for fp in extract_file_paths(text):
                        files_touched.add(fp)

            elif part_type == "file":
                file_path = (
                    part_data.get("filePath")
                    or part_data.get("path")
                    or part_data.get("file")
                )
                if isinstance(file_path, str):
                    files_touched.add(file_path)

            # "reasoning" type: intentionally skipped

    # Duration
    duration_minutes: float | None = None
    if message_times:
        max_msg_time = max(message_times)
        session_time = session.get("time_created")
        if isinstance(session_time, (int, float)) and max_msg_time > session_time:
            duration_minutes = round((max_msg_time - session_time) / 60000.0, 1)

    title = session.get("title") or session.get("slug") or ""

    out = {}
    for k, v in tool_calls.items():
        key = k.lower()
        out[key] = out.get(key, 0) + v

    result: dict[str, Any] = {
        "id": short_id,
        "provider": "opencode",
        "project": proj,
        "timestamp": timestamp,
        "duration_minutes": duration_minutes,
        "title": title,
        "user_prompts": user_prompts[:MAX_PROMPTS],
        "tool_calls": out,
        "files_touched": sorted(files_touched)[:MAX_FILES],
        "errors": errors,
        "subagent_count": 0,
    }

    if session.get("parent_id"):
        result["parent_id"] = session["parent_id"]

    return result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _write_empty(output_dir: Path) -> None:
    """Emit empty opencode_sessions.json."""
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "opencode_sessions.json"
    data: dict[str, Any] = {"provider": "opencode", "sessions": []}
    write_output(data, output_path, max_bytes=10_000_000)


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse OpenCode session logs")
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

    since_dt = datetime.combine(since, datetime.min.time(), tzinfo=timezone.utc)
    if until:
        # Make until inclusive by adding one day
        until_dt = datetime.combine(
            until + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc
        )
    else:
        until_dt = datetime.now(tz=timezone.utc)

    since_ms = int(since_dt.timestamp() * 1000)
    until_ms = int(until_dt.timestamp() * 1000)

    db_path = _resolve_db_path()

    if not db_path or not db_path.is_file():
        logger.warning("OpenCode DB not found at %s", db_path)
        _write_empty(Path(args.output))
        return

    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=5)
    except sqlite3.OperationalError as exc:
        logger.warning("SQLite error opening OpenCode DB: %s", exc)
        _write_empty(Path(args.output))
        return

    try:
        conn.execute("PRAGMA busy_timeout = 5000")
        sessions = _query_sessions(conn, since_ms, until_ms)
        logger.info("Found %d sessions in date range", len(sessions))

        if not sessions:
            _write_empty(Path(args.output))
            return

        session_ids = [s["id"] for s in sessions]
        messages_by_session = _query_messages(conn, session_ids)
        all_message_ids: list[str] = []
        for msg_list in messages_by_session.values():
            all_message_ids.extend(m["id"] for m in msg_list)
        parts_by_message = _query_parts(conn, all_message_ids)

        # Build session records
        results: list[dict[str, Any]] = []
        full_id_to_record: dict[str, dict[str, Any]] = {}
        parent_to_children: dict[str, list[str]] = {}

        for session in sessions:
            sid = session["id"]
            pid = session.get("parent_id")
            if pid:
                parent_to_children.setdefault(pid, []).append(sid)

            msgs = messages_by_session.get(sid, [])
            session_record = _build_session(session, msgs, parts_by_message)
            if session_record:
                results.append(session_record)
                full_id_to_record[sid] = session_record

        # Assign subagent counts to parents
        for parent_id, children in parent_to_children.items():
            parent_record = full_id_to_record.get(parent_id)
            if parent_record:
                parent_record["subagent_count"] = len(children)

        # Sort by timestamp descending (None last)
        results.sort(key=lambda s: s.get("timestamp") or "", reverse=True)

        output_dir = Path(args.output)
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / "opencode_sessions.json"
        data: dict[str, Any] = {"provider": "opencode", "sessions": results}
        write_output(data, output_path, max_bytes=10_000_000)

        if args.verbose:
            total_tools = sum(sum(s.get("tool_calls", {}).values()) for s in results)
            total_errors = sum(len(s.get("errors", [])) for s in results)
            logger.info(
                "Wrote %s (%d sessions, %d tools, %d errors)",
                output_path,
                len(results),
                total_tools,
                total_errors,
            )
    except sqlite3.OperationalError as exc:
        logger.warning("SQLite error querying OpenCode DB: %s", exc)
        _write_empty(Path(args.output))
        return
    finally:
        conn.close()


if __name__ == "__main__":
    main()
