"""Parse Claude Code sessions using a tiered approach.

Tier 1: Read pre-analyzed insights from usage-data (fast path).
Tier 2: Fall back to raw JSONL parsing for sessions without insights.
"""
from __future__ import annotations

import argparse
import json
import logging
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

SKIP_TYPES = frozenset({"progress", "file-history-snapshot", "queue-operation", "last-prompt"})
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
            "subagent_count": 0,
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
        "errors": [f"{k}: {v}" for k, v in errors.items()],
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
