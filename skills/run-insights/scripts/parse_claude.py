"""Parse Claude Code sessions using a tiered approach.

Tier 1: Read pre-analyzed insights from usage-data (fast path).
Tier 2: Fall back to raw JSONL parsing for sessions without insights.
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
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

SKIP_TYPES = frozenset({"progress", "file-history-snapshot", "last-prompt"})
SKILL_RE = re.compile(r"<command-name>\s*(\S+)\s*</command-name>")


# ---------------------------------------------------------------------------
# Tier 1: pre-analyzed insights
# ---------------------------------------------------------------------------

def _load_json_dir(directory: Path) -> dict[str, dict]:
    """Load all JSON files from a directory, keyed by stem (session id)."""
    result: dict[str, dict] = {}
    if not directory.is_dir():
        return result
    for p in directory.iterdir():
        if p.suffix != ".json":
            continue
        try:
            data = json.loads(p.read_text(encoding="utf-8", errors="replace"))
            if isinstance(data, dict):
                result[p.stem] = data
        except (json.JSONDecodeError, OSError):
            logger.warning("Failed to read %s, skipping", p)
    return result


def _build_tier1_sessions(
    since: datetime, until: datetime | None, verbose: bool,
) -> tuple[dict[str, dict], int]:
    """Return {session_id: session_dict} from usage-data insights."""
    home = Path.home()
    facets_dir = home / ".claude" / "usage-data" / "facets"
    meta_dir = home / ".claude" / "usage-data" / "session-meta"

    facets = _load_json_dir(facets_dir)
    metas = _load_json_dir(meta_dir)

    if verbose:
        print(f"[tier1] facets files: {len(facets)}, meta files: {len(metas)}", file=sys.stderr)

    all_ids = set(facets) | set(metas)
    sessions: dict[str, dict] = {}

    for sid in all_ids:
        meta = metas.get(sid, {})
        facet = facets.get(sid, {})

        start_time = normalize_timestamp(meta.get("start_time"))
        if not start_time:
            continue

        try:
            dt = datetime.fromisoformat(start_time)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
        except ValueError:
            continue

        if dt < since:
            continue
        if until and dt >= until:
            continue

        tool_counts = meta.get("tool_counts", {})
        friction_detail = facet.get("friction_detail", [])
        if isinstance(friction_detail, dict):
            friction_detail = list(friction_detail.keys())

        errors: list[str] = []
        tool_errors = meta.get("tool_errors", 0)
        tool_error_cats = meta.get("tool_error_categories", {})
        if isinstance(tool_error_cats, dict):
            errors = [f"{k}: {v}" for k, v in tool_error_cats.items()]
        elif tool_errors:
            errors = [f"tool_errors: {tool_errors}"]

        first_prompt = meta.get("first_prompt", "")
        user_prompts = [truncate_text(first_prompt, 500)] if first_prompt else []

        files = meta.get("files_modified", [])
        if isinstance(files, list):
            files = sorted(files)[:20]
        else:
            files = []

        tokens: dict[str, Any] = {}
        inp = meta.get("input_tokens")
        out = meta.get("output_tokens")
        if inp is not None:
            tokens["input"] = inp
        if out is not None:
            tokens["output"] = out

        session: dict[str, Any] = {
            "id": sid[:12],
            "provider": "claude",
            "project": project_name(meta.get("project_path", "")) if meta.get("project_path") else "unknown",
            "timestamp": start_time,
            "duration_minutes": meta.get("duration_minutes", 0),
            "user_prompts": user_prompts,
            "tool_calls": tool_counts if isinstance(tool_counts, dict) else {},
            "files_touched": files,
            "skills_used": [],
            "errors": errors,
            "subagent_count": meta.get("subagent_count", 0),
            "outcome": facet.get("outcome", ""),
            "friction": list(facet.get("friction_counts", {}).keys()) if isinstance(facet.get("friction_counts"), dict) else [],
            "goal_categories": list(facet.get("goal_categories", {}).keys()) if isinstance(facet.get("goal_categories"), dict) else [],
            "tokens": tokens,
        }

        # Carry extra facet fields
        for key in ("underlying_goal", "claude_helpfulness", "session_type", "brief_summary"):
            val = facet.get(key)
            if val:
                session[key] = val

        sat = facet.get("user_satisfaction_counts")
        if isinstance(sat, dict):
            session["user_satisfaction"] = sat

        sessions[sid] = session

    return sessions, len(all_ids)


# ---------------------------------------------------------------------------
# Tier 2: raw JSONL parsing
# ---------------------------------------------------------------------------

def _parse_jsonl_session(path: Path) -> dict[str, Any] | None:
    """Parse a single JSONL file into a session dict."""
    user_prompts: list[str] = []
    tool_counts: dict[str, int] = {}
    files_touched: set[str] = set()
    skills_used: set[str] = set()
    subagent_count = 0
    cwd: str = ""
    session_id: str = ""
    timestamp: str | None = None
    duration_seconds: float = 0
    errors: dict[str, int] = {}
    tool_id_to_name: dict[str, str] = {}
    tokens: dict[str, int] = {}

    for record in iter_jsonl(path):
        rec_type = record.get("type", "")

        # Grab metadata from first occurrence
        if not cwd and record.get("cwd"):
            cwd = record["cwd"]
        if not session_id and record.get("sessionId"):
            session_id = record["sessionId"]
        if not timestamp:
            raw_ts = record.get("timestamp")
            if raw_ts:
                timestamp = normalize_timestamp(raw_ts)

        if rec_type == "queue-operation":
            subagent_count += 1
            continue

        if rec_type in SKIP_TYPES:
            continue

        if rec_type == "user":
            message = record.get("message", {})
            content = message.get("content") if isinstance(message, dict) else None
            if content is None:
                continue
            if isinstance(content, str):
                blocks = [{"type": "text", "text": content}]
            elif isinstance(content, list):
                blocks = content
            else:
                continue

            for block in blocks:
                if not isinstance(block, dict) or block.get("type") != "text":
                    continue
                text = block.get("text", "")
                # Detect skill invocations
                skill_match = SKILL_RE.search(text)
                if skill_match:
                    skills_used.add(skill_match.group(1))
                if is_real_prompt(text) and len(user_prompts) < 10:
                    user_prompts.append(truncate_text(text, 500))

            for block in blocks:
                if not isinstance(block, dict) or block.get("type") != "tool_result":
                    continue
                if block.get("is_error"):
                    tool_use_id = block.get("tool_use_id", "")
                    tool_name = tool_id_to_name.get(tool_use_id, "unknown")
                    errors[tool_name] = errors.get(tool_name, 0) + 1

        elif rec_type == "assistant":
            message = record.get("message", {})
            content = message.get("content") if isinstance(message, dict) else None
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                name = block.get("name", "unknown")
                tool_counts[name] = tool_counts.get(name, 0) + 1
                tool_id_to_name[block.get("id", "")] = name
                inp = block.get("input", {})
                if not isinstance(inp, dict):
                    continue
                for key in ("file_path", "command", "path", "pattern"):
                    val = inp.get(key)
                    if isinstance(val, str):
                        for fp in extract_file_paths(val):
                            files_touched.add(fp)

        elif rec_type == "system":
            data = record.get("data", {})
            if isinstance(data, dict) and data.get("type") == "turn_duration":
                dur = data.get("duration_seconds", 0)
                if isinstance(dur, (int, float)):
                    duration_seconds += dur

        # Accumulate token usage
        usage = record.get("usage", {}) or record.get("message", {}).get("usage", {})
        if isinstance(usage, dict):
            for tok_key in ("input_tokens", "output_tokens"):
                val = usage.get(tok_key)
                if isinstance(val, (int, float)):
                    short = tok_key.replace("_tokens", "")
                    tokens[short] = tokens.get(short, 0) + int(val)

    if not timestamp:
        return None

    sorted_files = sorted(files_touched)[:20]

    return {
        "id": (session_id or path.stem)[:12],
        "provider": "claude",
        "project": project_name(cwd) if cwd else "unknown",
        "timestamp": timestamp,
        "duration_minutes": round(duration_seconds / 60) if duration_seconds else 0,
        "user_prompts": user_prompts,
        "tool_calls": tool_counts,
        "files_touched": sorted_files,
        "skills_used": sorted(skills_used),
        "errors": [f"{k}: {v}" for k, v in sorted(errors.items(), key=lambda x: x[1], reverse=True)[:10]],
        "subagent_count": subagent_count,
        "outcome": "",
        "friction": [],
        "goal_categories": [],
        "tokens": tokens,
    }


def _build_tier2_sessions(
    since: datetime, until: datetime | None, covered_short_ids: set[str], verbose: bool,
) -> list[dict]:
    """Parse raw JSONL files for sessions not already covered by tier 1."""
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.is_dir():
        if verbose:
            print("[tier2] projects dir not found, skipping", file=sys.stderr)
        return []

    jsonl_files: list[Path] = []
    for p in projects_dir.rglob("*.jsonl"):
        if "subagents" in p.parts:
            continue
        jsonl_files.append(p)

    if verbose:
        print(f"[tier2] JSONL files found: {len(jsonl_files)}", file=sys.stderr)

    sessions: list[dict] = []
    skipped = 0

    for path in jsonl_files:
        session = _parse_jsonl_session(path)
        if session is None:
            skipped += 1
            continue

        # Check if already covered by tier 1 (O(1) lookup via pre-computed set)
        if session["id"] in covered_short_ids:
            skipped += 1
            continue

        ts = session.get("timestamp")
        if ts:
            try:
                dt = datetime.fromisoformat(ts)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
                if dt < since:
                    skipped += 1
                    continue
                if until and dt >= until:
                    skipped += 1
                    continue
            except ValueError:
                skipped += 1
                continue

        sessions.append(session)

    if verbose:
        print(f"[tier2] parsed: {len(sessions)}, skipped: {skipped}", file=sys.stderr)

    return sessions


# ---------------------------------------------------------------------------
# Enrichment: post-merge, pre-write
# ---------------------------------------------------------------------------


def _enrich_history(sessions: list[dict], session_index: dict[str, dict]) -> None:
    """Enrich sessions with history.jsonl data (prompt counts, slash commands)."""
    history_path = Path.home() / ".claude" / "history.jsonl"
    if not history_path.is_file():
        return

    per_session: dict[str, dict] = {}
    for record in iter_jsonl(history_path):
        sid = record.get("sessionId")
        if not isinstance(sid, str) or not sid:
            continue
        short_id = sid[:12]
        if short_id not in session_index:
            continue
        bucket = per_session.setdefault(short_id, {"prompt_count": 0, "slash_commands": {}})
        bucket["prompt_count"] += 1
        display = record.get("display")
        if isinstance(display, str) and display.startswith("/"):
            cmd = display.split()[0]
            bucket["slash_commands"][cmd] = bucket["slash_commands"].get(cmd, 0) + 1

    for sid, data in per_session.items():
        session = session_index.get(sid)
        if session is not None:
            session["prompt_count"] = data["prompt_count"]
            if data["slash_commands"]:
                session["slash_commands"] = data["slash_commands"]


def _enrich_subagent_meta(sessions: list[dict], session_index: dict[str, dict]) -> None:
    """Enrich sessions with subagent type distribution from meta files."""
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.is_dir():
        return

    per_session: dict[str, dict] = {}
    for meta_path in projects_dir.rglob("agent-*.meta.json"):
        sid = meta_path.parent.parent.name[:12]
        if sid not in session_index:
            continue
        try:
            data = json.loads(meta_path.read_text(encoding="utf-8", errors="replace"))
        except (json.JSONDecodeError, OSError):
            logger.warning("Skipping malformed subagent meta: %s", meta_path)
            continue
        if not isinstance(data, dict):
            continue
        agent_type = data.get("agentType", "unknown")
        bucket = per_session.setdefault(sid, {"types": {}, "count": 0})
        bucket["types"][agent_type] = bucket["types"].get(agent_type, 0) + 1
        bucket["count"] += 1

    for sid, data in per_session.items():
        session = session_index.get(sid)
        if session is not None:
            session["subagent_types"] = sorted(data["types"].keys())
            session["subagent_count"] = data["count"]


DEBUG_DIRS = ("debug", "debug-logs")
DEBUG_PATTERNS = {
    "rate_limit": re.compile(r"status[=: ]*429|\brate[._-]?limit", re.IGNORECASE),
    "streaming_stall": re.compile(r"stall\s+detect", re.IGNORECASE),
    "mcp_error": re.compile(r"mcp[^\n]{0,80}(?:error|fail)", re.IGNORECASE),
    "timeout": re.compile(r"timed?\s*out|timeout\s+(?:error|exceed|reach)", re.IGNORECASE),
    "auth_error": re.compile(r"(?:oauth|auth)[^\n]{0,80}(?:error|fail|expired|invalid|denied)|\b401\b|\b403\b", re.IGNORECASE),
}


def _enrich_debug_logs(sessions: list[dict], session_index: dict[str, dict]) -> None:
    """Enrich sessions with debug log error categories."""
    home = Path.home()
    debug_dir = None
    for name in DEBUG_DIRS:
        candidate = home / ".claude" / name
        if candidate.is_dir():
            debug_dir = candidate
            break
    if debug_dir is None:
        return

    per_session: dict[str, dict[str, int]] = {}
    for log_path in debug_dir.iterdir():
        if not log_path.is_file():
            continue
        sid = log_path.stem[:12]
        if sid not in session_index:
            continue
        counts: dict[str, int] = {}
        try:
            with log_path.open(encoding="utf-8", errors="replace") as f:
                for line in f:
                    # Skip verbose debug lines (93.6% of content) before regex
                    if line.find("[DEBUG]", 0, 60) != -1:
                        continue
                    for category, pattern in DEBUG_PATTERNS.items():
                        if pattern.search(line):
                            counts[category] = counts.get(category, 0) + 1
        except OSError:
            continue
        if counts:
            existing = per_session.get(sid, {})
            for k, v in counts.items():
                existing[k] = existing.get(k, 0) + v
            per_session[sid] = existing

    for sid, counts in per_session.items():
        session = session_index.get(sid)
        if session is not None:
            session["debug_issues"] = counts


def _enrich_security_warnings(sessions: list[dict], session_index: dict[str, dict]) -> None:
    """Enrich sessions with security warning types."""
    claude_dir = Path.home() / ".claude"
    if not claude_dir.is_dir():
        return

    for path in claude_dir.glob("security_warnings_state_*.json"):
        sid_full = path.stem.replace("security_warnings_state_", "")
        sid = sid_full[:12]
        if sid not in session_index:
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
        except (json.JSONDecodeError, OSError):
            continue
        if not isinstance(data, list):
            logger.debug("security_warnings: unexpected structure in %s: %s", path.name, type(data).__name__)
            continue
        warning_types: set[str] = set()
        for item in data:
            if not isinstance(item, str):
                continue
            parts = item.rsplit("-", 1)
            if len(parts) == 2:
                wtype = parts[1].strip()[:60]
                if wtype and "/" not in wtype and "\\" not in wtype:
                    warning_types.add(wtype)
        if warning_types:
            session = session_index.get(sid)
            if session is not None:
                session["security_warnings"] = sorted(warning_types)


def _enrich_task_outputs(sessions: list[dict], session_index: dict[str, dict]) -> None:
    """Enrich sessions with task output stats from /tmp.

    Layout: /tmp/claude-{uid}/<project>/<session-uuid>/tasks/*.output
    """
    if not hasattr(os, "getuid"):
        return
    base = Path(f"/tmp/claude-{os.getuid()}")
    if not base.is_dir():
        return
    resolved_base = base.resolve()

    per_session: dict[str, dict] = {}
    for project_dir in base.iterdir():
        if not project_dir.is_dir():
            continue
        try:
            for session_dir in project_dir.iterdir():
                if not session_dir.is_dir():
                    continue
                if not session_dir.resolve().is_relative_to(resolved_base):
                    continue
                sid = session_dir.name[:12]
                if sid not in session_index:
                    continue
                tasks_dir = session_dir / "tasks"
                if not tasks_dir.is_dir():
                    continue
                bucket = per_session.setdefault(sid, {"task_count": 0, "completed": 0, "empty": 0})
                for output_file in tasks_dir.glob("*.output"):
                    if output_file.name.startswith("a"):
                        continue  # subagent task outputs — duplicates of main session
                    bucket["task_count"] += 1
                    try:
                        with output_file.open(encoding="utf-8", errors="replace") as fh:
                            text = fh.read(4096)
                        if not text.strip():
                            bucket["empty"] += 1
                        else:
                            bucket["completed"] += 1
                    except OSError:
                        continue
        except OSError:
            continue

    for sid, data in per_session.items():
        session = session_index.get(sid)
        if session is not None and data["task_count"] > 0:
            session["task_outputs"] = data


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _parse_date(s: str) -> datetime:
    """Parse YYYY-MM-DD into a timezone-aware datetime."""
    dt = datetime.strptime(s, "%Y-%m-%d")
    return dt.replace(tzinfo=timezone.utc)


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse Claude Code sessions")
    parser.add_argument("--since", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--until", help="End date exclusive (YYYY-MM-DD)")
    parser.add_argument("--output", required=True, help="Output directory")
    parser.add_argument("--verbose", action="store_true", help="Log parsing stats to stderr")
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG, stream=sys.stderr)
    else:
        logging.basicConfig(level=logging.WARNING, stream=sys.stderr)

    since = _parse_date(args.since)
    until = _parse_date(args.until) if args.until else None

    # Tier 1
    tier1_sessions, tier1_total = _build_tier1_sessions(since, until, args.verbose)
    covered_ids = set(tier1_sessions.keys())
    covered_short_ids = {sid[:12] for sid in covered_ids}

    if args.verbose:
        print(f"[tier1] sessions after filter: {len(tier1_sessions)} / {tier1_total}", file=sys.stderr)

    # Tier 2
    tier2_sessions = _build_tier2_sessions(since, until, covered_short_ids, args.verbose)

    # Merge
    all_sessions = list(tier1_sessions.values()) + tier2_sessions

    # Sort by timestamp descending
    all_sessions.sort(key=lambda s: s.get("timestamp", ""), reverse=True)

    # Enrich with additional data sources
    session_index = {s["id"]: s for s in all_sessions}

    for name, fn in [
        ("history", _enrich_history),
        ("subagent_meta", _enrich_subagent_meta),
        ("security_warnings", _enrich_security_warnings),
        ("debug_logs", _enrich_debug_logs),
        ("task_outputs", _enrich_task_outputs),
    ]:
        try:
            fn(all_sessions, session_index)
        except Exception:
            logger.warning("Enrichment %s failed", name, exc_info=True)

    if args.verbose:
        print(f"[total] sessions: {len(all_sessions)}", file=sys.stderr)

    # Write output
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    output_path = output_dir / "claude_sessions.json"
    output_data = {
        "provider": "claude",
        "sessions": all_sessions,
    }
    output_path.write_text(
        json.dumps(output_data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    if args.verbose:
        print(f"[output] {output_path} ({len(all_sessions)} sessions)", file=sys.stderr)


if __name__ == "__main__":
    main()
