"""Cursor session parser with SQLite-first approach.

Extracts AI session data from Cursor's local SQLite tracking database
and agent transcript files. Falls back to transcripts when the database
is unavailable or locked.
"""
from __future__ import annotations

import argparse
import json
import logging
import re
import sqlite3
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from common import (
    extract_file_paths,
    is_real_prompt,
    iter_jsonl,
    normalize_timestamp,
    project_name,
    truncate_text,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_PROMPTS_PER_SESSION = 10
MAX_PROMPT_CHARS = 500
MAX_FILES_PER_SESSION = 20

CURSOR_DB_PATH = Path.home() / ".cursor" / "ai-tracking" / "ai-code-tracking.db"
CURSOR_PROJECTS_DIR = Path.home() / ".cursor" / "projects"

_USER_QUERY_RE = re.compile(r"<user_query>(.*?)</user_query>", re.DOTALL)
_TOOL_CALL_RE = re.compile(r"\[Tool call\]\s+(\w+)")
_TOOL_PATH_RE = re.compile(r"(?:path|file_path):\s*(.+)")
_NOISE_BLOCK_RE = re.compile(
    r"<(?:cursor_commands|agent_transcripts_context|agent_skill)>.*?"
    r"</(?:cursor_commands|agent_transcripts_context|agent_skill)>",
    re.DOTALL,
)

# ---------------------------------------------------------------------------
# SQLite helpers
# ---------------------------------------------------------------------------


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    cur = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    )
    return cur.fetchone() is not None


def _query_conversations(conn: sqlite3.Connection) -> dict[str, dict[str, Any]]:
    if not _table_exists(conn, "conversation_summaries"):
        return {}
    rows = conn.execute(
        "SELECT conversationId, title, tldr, overview, summaryBullets, model, mode "
        "FROM conversation_summaries"
    ).fetchall()
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        cid = row[0]
        if not cid:
            continue
        result[cid] = {
            "title": row[1],
            "tldr": row[2],
            "overview": row[3],
            "summary_bullets": row[4],
            "model": row[5],
            "mode": row[6],
        }
    return result


def _query_commits(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    if not _table_exists(conn, "scored_commits"):
        return []
    rows = conn.execute(
        "SELECT commitHash, branchName, linesAdded, linesDeleted, "
        "composerLinesAdded, humanLinesAdded, tabLinesAdded, commitMessage "
        "FROM scored_commits"
    ).fetchall()
    return [
        {
            "commit_hash": r[0],
            "branch_name": r[1],
            "lines_added": r[2] or 0,
            "lines_deleted": r[3] or 0,
            "composer_lines_added": r[4] or 0,
            "human_lines_added": r[5] or 0,
            "tab_lines_added": r[6] or 0,
            "commit_message": r[7],
        }
        for r in rows
    ]


def _query_code_hashes(conn: sqlite3.Connection) -> dict[str, list[dict[str, Any]]]:
    if not _table_exists(conn, "ai_code_hashes"):
        return {}
    rows = conn.execute(
        "SELECT source, model, conversationId FROM ai_code_hashes"
    ).fetchall()
    by_conv: dict[str, list[dict[str, Any]]] = {}
    for r in rows:
        cid = r[2]
        if not cid:
            continue
        by_conv.setdefault(cid, []).append({"source": r[0], "model": r[1]})
    return by_conv


def load_sqlite_data() -> tuple[dict[str, dict], list[dict], dict[str, list[dict]]] | None:
    """Load data from Cursor's SQLite database. Returns None on failure."""
    db_path = CURSOR_DB_PATH
    if not db_path.is_file():
        logger.info("SQLite database not found at %s", db_path)
        return None
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=5)
        try:
            conversations = _query_conversations(conn)
            commits = _query_commits(conn)
            code_hashes = _query_code_hashes(conn)
            return conversations, commits, code_hashes
        finally:
            conn.close()
    except sqlite3.OperationalError as exc:
        logger.warning("SQLite error, falling back to transcripts: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Transcript parsing
# ---------------------------------------------------------------------------


def _project_from_path(transcript_path: Path) -> str:
    """Derive project name from transcript parent directory structure."""
    # Pattern: ~/.cursor/projects/<encoded-project-path>/agent-transcripts/...
    parts = transcript_path.parts
    try:
        proj_idx = parts.index("projects")
        if proj_idx + 1 < len(parts):
            encoded = parts[proj_idx + 1]
            decoded = encoded.replace("-", "/")
            return project_name(decoded)
    except ValueError:
        pass
    return "unknown"


def _parse_txt_transcript(path: Path) -> dict[str, Any]:
    """Parse a .txt agent transcript."""
    text = path.read_text(encoding="utf-8", errors="replace")

    # Strip noise blocks
    text_clean = _NOISE_BLOCK_RE.sub("", text)

    # Remove thinking blocks
    text_clean = re.sub(r"\[Thinking\].*?(?=\[|$)", "", text_clean, flags=re.DOTALL)

    # Extract user queries
    queries = _USER_QUERY_RE.findall(text_clean)
    prompts = [
        truncate_text(q.strip(), MAX_PROMPT_CHARS)
        for q in queries
        if is_real_prompt(q.strip())
    ][:MAX_PROMPTS_PER_SESSION]

    # Extract tool calls
    tool_counts: Counter[str] = Counter()
    for match in _TOOL_CALL_RE.finditer(text_clean):
        tool_counts[match.group(1)] += 1

    # Extract file paths from tool call regions
    files: list[str] = []
    for match in _TOOL_PATH_RE.finditer(text_clean):
        fp = match.group(1).strip().strip('"').strip("'")
        if fp and fp not in files:
            files.append(fp)
    # Also extract from general text
    for fp in extract_file_paths(text_clean):
        if fp not in files:
            files.append(fp)

    mtime = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)

    return {
        "id": path.stem[:12] if len(path.stem) >= 12 else path.stem,
        "full_id": path.stem,
        "project": _project_from_path(path),
        "timestamp": mtime.isoformat(),
        "user_prompts": prompts,
        "tool_calls": dict(tool_counts),
        "files_touched": sorted(files)[:MAX_FILES_PER_SESSION],
    }


def _parse_jsonl_transcript(path: Path) -> dict[str, Any]:
    """Parse a .jsonl agent transcript."""
    prompts: list[str] = []
    tool_counts: Counter[str] = Counter()
    files: list[str] = []
    is_first = True

    for record in iter_jsonl(path):
        role = record.get("role", "")
        message = record.get("message", {})
        content_list = message.get("content", []) if isinstance(message, dict) else []

        for block in content_list:
            if not isinstance(block, dict):
                continue
            if block.get("type") != "text":
                continue
            text = block.get("text", "")
            if not text:
                continue

            # Strip cursor_commands noise (especially first record)
            if is_first:
                text = _NOISE_BLOCK_RE.sub("", text)

            if role == "user":
                for q in _USER_QUERY_RE.findall(text):
                    q_clean = q.strip()
                    if is_real_prompt(q_clean) and len(prompts) < MAX_PROMPTS_PER_SESSION:
                        prompts.append(truncate_text(q_clean, MAX_PROMPT_CHARS))

            if role == "assistant":
                for m in _TOOL_CALL_RE.finditer(text):
                    tool_counts[m.group(1)] += 1
                for m in _TOOL_PATH_RE.finditer(text):
                    fp = m.group(1).strip().strip('"').strip("'")
                    if fp and fp not in files:
                        files.append(fp)
                for fp in extract_file_paths(text):
                    if fp not in files:
                        files.append(fp)

        is_first = False

    mtime = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)

    return {
        "id": path.stem[:12] if len(path.stem) >= 12 else path.stem,
        "full_id": path.stem,
        "project": _project_from_path(path),
        "timestamp": mtime.isoformat(),
        "user_prompts": prompts,
        "tool_calls": dict(tool_counts),
        "files_touched": sorted(files)[:MAX_FILES_PER_SESSION],
    }


def load_transcript_sessions(
    since: datetime, until: datetime
) -> dict[str, dict[str, Any]]:
    """Scan transcript files and return sessions keyed by full_id."""
    sessions: dict[str, dict[str, Any]] = {}

    if not CURSOR_PROJECTS_DIR.is_dir():
        logger.info("Cursor projects directory not found at %s", CURSOR_PROJECTS_DIR)
        return sessions

    # Collect all transcript files grouped by stem for deduplication
    # Search both direct children and nested subdirectories (some JSONL files
    # are stored as agent-transcripts/<uuid>/<uuid>.jsonl)
    by_stem: dict[str, dict[str, Path]] = {}
    for transcript_dir in CURSOR_PROJECTS_DIR.glob("*/agent-transcripts"):
        for f in transcript_dir.rglob("*"):
            if not f.is_file() or f.suffix not in (".txt", ".jsonl"):
                continue
            mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
            if mtime < since or mtime >= until:
                continue
            by_stem.setdefault(f.stem, {})[f.suffix] = f

    # Parse, preferring .txt over .jsonl when both exist (txt has structured tool call markers)
    for stem, ext_map in by_stem.items():
        if ".txt" in ext_map:
            path = ext_map[".txt"]
            session = _parse_txt_transcript(path)
        else:
            path = ext_map[".jsonl"]
            session = _parse_jsonl_transcript(path)

        sessions[session["full_id"]] = session

    return sessions


# ---------------------------------------------------------------------------
# Merging & output
# ---------------------------------------------------------------------------


def _build_summary(conv: dict[str, Any]) -> str | None:
    """Build a summary string from SQLite conversation data."""
    tldr = conv.get("tldr")
    if tldr:
        return tldr
    overview = conv.get("overview")
    if overview:
        return truncate_text(overview, MAX_PROMPT_CHARS)
    bullets = conv.get("summary_bullets")
    if bullets:
        return truncate_text(bullets, MAX_PROMPT_CHARS)
    return None


def _build_commit_stats(commits: list[dict[str, Any]]) -> dict[str, Any]:
    total_added = sum(c.get("lines_added", 0) for c in commits)
    total_deleted = sum(c.get("lines_deleted", 0) for c in commits)
    composer = sum(c.get("composer_lines_added", 0) for c in commits)
    human = sum(c.get("human_lines_added", 0) for c in commits)
    tab = sum(c.get("tab_lines_added", 0) for c in commits)
    return {
        "total_commits": len(commits),
        "total_lines_added": total_added,
        "total_lines_deleted": total_deleted,
        "ai_vs_human": {
            "composer_lines": composer,
            "human_lines": human,
            "tab_lines": tab,
        },
    }


def merge_and_build(
    sqlite_data: tuple[dict, list[dict], dict[str, list[dict]]] | None,
    transcript_sessions: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    """Merge SQLite and transcript data into final output structure."""
    conversations: dict[str, dict] = {}
    commits: list[dict] = []
    code_hashes: dict[str, list[dict]] = {}

    if sqlite_data is not None:
        conversations, commits, code_hashes = sqlite_data

    # Build sessions from SQLite conversations
    sessions_by_id: dict[str, dict[str, Any]] = {}
    for cid, conv in conversations.items():
        short_id = cid[:12] if len(cid) >= 12 else cid
        model = conv.get("model")
        # Check code_hashes for model if not in conversation
        if not model and cid in code_hashes:
            hashes = code_hashes[cid]
            if hashes:
                model = hashes[0].get("model")

        session: dict[str, Any] = {
            "id": short_id,
            "provider": "cursor",
            "project": None,
            "timestamp": None,
            "duration_minutes": None,
            "title": conv.get("title"),
            "summary": _build_summary(conv),
            "user_prompts": [],
            "tool_calls": {},
            "files_touched": [],
            "model": model,
            "ai_attribution": None,
        }
        sessions_by_id[cid] = session

    # Merge transcript sessions into SQLite sessions or add new ones
    for full_id, t_session in transcript_sessions.items():
        matched = False
        for cid in conversations:
            if cid.startswith(full_id) or full_id.startswith(cid) or cid[:12] == t_session["id"]:
                # Merge: transcript enriches SQLite data
                existing = sessions_by_id[cid]
                if not existing.get("timestamp"):
                    existing["timestamp"] = t_session.get("timestamp")
                if not existing.get("project"):
                    existing["project"] = t_session.get("project")
                if not existing.get("user_prompts"):
                    existing["user_prompts"] = t_session.get("user_prompts", [])
                if not existing.get("tool_calls"):
                    existing["tool_calls"] = t_session.get("tool_calls", {})
                if not existing.get("files_touched"):
                    existing["files_touched"] = t_session.get("files_touched", [])
                matched = True
                break
        if not matched:
            # New session from transcript only
            session = {
                "id": t_session["id"],
                "provider": "cursor",
                "project": t_session.get("project"),
                "timestamp": t_session.get("timestamp"),
                "duration_minutes": None,
                "title": None,
                "summary": None,
                "user_prompts": t_session.get("user_prompts", []),
                "tool_calls": t_session.get("tool_calls", {}),
                "files_touched": t_session.get("files_touched", []),
                "model": None,
                "ai_attribution": None,
            }
            sessions_by_id[full_id] = session

    # Sort sessions by timestamp descending (most recent first)
    sessions_list = list(sessions_by_id.values())
    sessions_list.sort(
        key=lambda s: s.get("timestamp") or "", reverse=True
    )

    commit_stats = _build_commit_stats(commits)

    return {
        "provider": "cursor",
        "sessions": sessions_list,
        "commit_stats": commit_stats,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parse Cursor AI session data from SQLite and transcripts."
    )
    parser.add_argument(
        "--since",
        required=True,
        help="Start date (YYYY-MM-DD, inclusive)",
    )
    parser.add_argument(
        "--until",
        default=None,
        help="End date (YYYY-MM-DD, exclusive). Defaults to now.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output directory for cursor_sessions.json",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Log detailed stats to stderr",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format="%(levelname)s: %(message)s",
        stream=sys.stderr,
    )

    since = datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    if args.until:
        until = datetime.strptime(args.until, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    else:
        until = datetime.now(tz=timezone.utc)

    # Tier 1: SQLite
    sqlite_data = load_sqlite_data()
    if sqlite_data is not None:
        convs, commits, hashes = sqlite_data
        logger.info(
            "SQLite: %d conversations, %d commits, %d code hashes",
            len(convs),
            len(commits),
            sum(len(v) for v in hashes.values()),
        )

    # Tier 2: Transcripts
    transcript_sessions = load_transcript_sessions(since, until)
    logger.info("Transcripts: %d sessions found", len(transcript_sessions))

    # Merge and build output
    output = merge_and_build(sqlite_data, transcript_sessions)
    logger.info(
        "Output: %d sessions, %d commits",
        len(output["sessions"]),
        output["commit_stats"]["total_commits"],
    )

    # Write output
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "cursor_sessions.json"
    output_path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    logger.info("Wrote %s", output_path)


if __name__ == "__main__":
    main()
