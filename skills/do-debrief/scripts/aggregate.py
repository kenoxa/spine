"""Combine per-provider session data into cross-session analytics JSON."""
from __future__ import annotations

import argparse
import json
import logging
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

from common import normalize_timestamp, write_output

logger = logging.getLogger(__name__)

TOOL_ALIASES: dict[str, str] = {
    "exec_command": "bash",
    "apply_patch": "edit",
    "ReadFile": "read",
    "StrReplace": "edit",
    "SearchFiles": "grep",
    "ListFiles": "glob",
    "Bash": "bash",
    "Read": "read",
    "Edit": "edit",
    "Write": "write",
    "Grep": "grep",
    "Glob": "glob",
    "Agent": "agent",
    "Subagent": "agent",
}


def _normalize_tool(name: str) -> str:
    return TOOL_ALIASES.get(name, name.lower())


def _parse_iso(ts: str | None) -> datetime | None:
    iso = normalize_timestamp(ts)
    if iso is None:
        return None
    try:
        return datetime.fromisoformat(iso)
    except ValueError:
        return None


def _pick_diverse_prompts(prompts: list[str], max_count: int) -> list[str]:
    """Pick prompts preferring longest unique ones for diversity."""
    seen: set[str] = set()
    unique: list[str] = []
    for p in prompts:
        normalized = p.strip().lower()
        if normalized not in seen:
            seen.add(normalized)
            unique.append(p)
    unique.sort(key=len, reverse=True)
    return unique[:max_count]


def _load_provider_files(input_dir: Path) -> tuple[list[dict], list[str], dict | None]:
    """Load all *_sessions.json files. Returns (sessions, providers_found, commit_stats)."""
    all_sessions: list[dict] = []
    providers_found: list[str] = []
    commit_stats: dict | None = None

    for path in sorted(input_dir.glob("*_sessions.json")):
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Skipping %s: %s", path.name, exc)
            continue

        provider = raw.get("provider", path.stem.replace("_sessions", ""))
        providers_found.append(provider)
        sessions = raw.get("sessions", [])
        for s in sessions:
            s.setdefault("provider", provider)
        all_sessions.extend(sessions)

        if "commit_stats" in raw and commit_stats is None:
            commit_stats = raw["commit_stats"]

    return all_sessions, providers_found, commit_stats


def _normalize_tools_in_sessions(sessions: list[dict]) -> None:
    """Normalize tool names in-place across all sessions."""
    for s in sessions:
        if "tool_calls" in s and isinstance(s["tool_calls"], dict):
            normalized: dict[str, int] = {}
            for name, count in s["tool_calls"].items():
                key = _normalize_tool(name)
                normalized[key] = normalized.get(key, 0) + count
            s["tool_calls"] = normalized


def _build_summary(sessions: list[dict], providers: list[str]) -> dict:
    timestamps: list[datetime] = []
    total_prompts = 0
    durations: list[float] = []
    provider_counts: Counter[str] = Counter()

    for s in sessions:
        provider_counts[s.get("provider", "unknown")] += 1
        for field in ("start", "timestamp", "started_at"):
            dt = _parse_iso(s.get(field))
            if dt:
                timestamps.append(dt)
                break
        for field in ("end", "ended_at"):
            dt = _parse_iso(s.get(field))
            if dt:
                timestamps.append(dt)
                break
        total_prompts += s.get("prompt_count", 0) or len(s.get("user_prompts", []))
        dur = s.get("duration_minutes")
        if dur is not None:
            durations.append(float(dur))

    date_range = None
    if timestamps:
        date_range = {
            "min": min(timestamps).isoformat(),
            "max": max(timestamps).isoformat(),
        }

    return {
        "total_sessions": len(sessions),
        "date_range": date_range,
        "provider_breakdown": dict(provider_counts),
        "avg_duration_minutes": round(sum(durations) / len(durations), 1) if durations else None,
        "total_prompts": total_prompts,
    }


def _build_per_project(sessions: list[dict]) -> list[dict]:
    groups: dict[str, list[dict]] = defaultdict(list)
    for s in sessions:
        name = s.get("project") or s.get("cwd") or "unknown"
        groups[name].append(s)

    # Sort by session count descending, take top 15
    sorted_projects = sorted(groups.items(), key=lambda kv: len(kv[1]), reverse=True)[:15]
    result: list[dict] = []

    for name, proj_sessions in sorted_projects:
        tool_counter: Counter[str] = Counter()
        error_count = 0
        skills: Counter[str] = Counter()
        durations: list[float] = []
        all_prompts: list[str] = []
        providers_used: set[str] = set()

        for s in proj_sessions:
            providers_used.add(s.get("provider", "unknown"))
            if isinstance(s.get("tool_calls"), dict):
                for t, c in s["tool_calls"].items():
                    tool_counter[t] += c
            error_count += len(s.get("errors", []))
            if isinstance(s.get("skills_used"), list):
                for sk in s["skills_used"]:
                    skills[sk] += 1
            dur = s.get("duration_minutes")
            if dur is not None:
                durations.append(float(dur))
            for p in s.get("user_prompts", []):
                text = p if isinstance(p, str) else p.get("text", "")
                if text:
                    all_prompts.append(text)

        result.append({
            "project": name,
            "session_count": len(proj_sessions),
            "providers": sorted(providers_used),
            "tool_calls": dict(tool_counter.most_common(10)),
            "error_count": error_count,
            "skills_used": dict(skills),
            "avg_duration_minutes": round(sum(durations) / len(durations), 1) if durations else None,
            "sample_prompts": _pick_diverse_prompts(all_prompts, 5),
        })

    return result


def _build_tool_patterns(sessions: list[dict]) -> dict:
    freq: Counter[str] = Counter()
    by_provider: dict[str, Counter[str]] = defaultdict(Counter)
    error_counts: Counter[str] = Counter()

    for s in sessions:
        provider = s.get("provider", "unknown")
        if isinstance(s.get("tool_calls"), dict):
            for t, c in s["tool_calls"].items():
                freq[t] += c
                by_provider[provider][t] += c
        if isinstance(s.get("tool_errors"), dict):
            for t, c in s["tool_errors"].items():
                error_counts[_normalize_tool(t)] += c

    return {
        "tool_frequency": dict(freq.most_common(20)),
        "tool_by_provider": {p: dict(c.most_common(20)) for p, c in sorted(by_provider.items())},
        "tool_error_counts": dict(error_counts) if error_counts else None,
    }


def _build_workflow_patterns(sessions: list[dict]) -> dict:
    skill_counts: Counter[str] = Counter()
    subagent_total = 0
    turns_by_provider: dict[str, list[int]] = defaultdict(list)

    for s in sessions:
        provider = s.get("provider", "unknown")
        if isinstance(s.get("skills_used"), list):
            for sk in s["skills_used"]:
                skill_counts[sk] += 1
        subagent_total += s.get("subagent_count", 0)
        turns = s.get("turn_count") or s.get("turns")
        if turns is not None:
            turns_by_provider[provider].append(int(turns))

    avg_turns: dict[str, float] = {}
    for p, vals in sorted(turns_by_provider.items()):
        if vals:
            avg_turns[p] = round(sum(vals) / len(vals), 1)

    return {
        "skill_invocations": dict(skill_counts),
        "subagent_usage": subagent_total,
        "avg_turns_per_session_by_provider": avg_turns,
    }


def _build_temporal_trends(sessions: list[dict]) -> dict:
    per_day: Counter[str] = Counter()
    by_provider_day: dict[str, Counter[str]] = defaultdict(Counter)

    for s in sessions:
        provider = s.get("provider", "unknown")
        for field in ("start", "timestamp", "started_at"):
            dt = _parse_iso(s.get(field))
            if dt:
                day = dt.strftime("%Y-%m-%d")
                per_day[day] += 1
                by_provider_day[provider][day] += 1
                break

    return {
        "sessions_per_day": dict(sorted(per_day.items())),
        "sessions_by_provider_per_day": {
            p: dict(sorted(c.items())) for p, c in sorted(by_provider_day.items())
        },
    }


def _build_friction_patterns(sessions: list[dict]) -> dict:
    error_categories: Counter[str] = Counter()
    friction_sessions: list[dict] = []
    interrupted = 0

    for s in sessions:
        errors = len(s.get("errors", []))
        friction = s.get("friction", [])
        if isinstance(friction, list):
            for tag in friction:
                error_categories[tag] += 1

        score = errors + len(friction) if isinstance(friction, list) else errors
        if score > 0:
            friction_sessions.append({
                "session_id": s.get("session_id", s.get("id")),
                "provider": s.get("provider"),
                "project": s.get("project"),
                "error_count": errors,
                "friction": friction,
                "score": score,
            })

        if s.get("interrupted") or s.get("exit_status") == "interrupted":
            interrupted += 1

    friction_sessions.sort(key=lambda x: x["score"], reverse=True)

    return {
        "error_categories": dict(error_categories.most_common()),
        "high_friction_sessions": friction_sessions[:10],
        "interrupted_sessions": interrupted,
    }


def _build_notable_sessions(sessions: list[dict]) -> dict:
    def _summary(s: dict) -> dict:
        return {
            "session_id": s.get("session_id", s.get("id")),
            "provider": s.get("provider"),
            "project": s.get("project"),
            "duration_minutes": s.get("duration_minutes"),
            "error_count": len(s.get("errors", [])),
            "tool_count": sum(s["tool_calls"].values()) if isinstance(s.get("tool_calls"), dict) else 0,
        }

    by_duration = sorted(
        sessions,
        key=lambda s: s.get("duration_minutes") or 0,
        reverse=True,
    )
    by_errors = sorted(sessions, key=lambda s: len(s.get("errors", [])), reverse=True)
    by_tools = sorted(
        sessions,
        key=lambda s: sum(s["tool_calls"].values()) if isinstance(s.get("tool_calls"), dict) else 0,
        reverse=True,
    )

    return {
        "longest": [_summary(s) for s in by_duration[:10]],
        "most_errors": [_summary(s) for s in by_errors[:10]],
        "most_tool_heavy": [_summary(s) for s in by_tools[:5]],
    }


def _build_cross_tool(sessions: list[dict]) -> list[dict]:
    groups: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for s in sessions:
        name = s.get("project") or s.get("cwd") or "unknown"
        provider = s.get("provider", "unknown")
        groups[name][provider].append(s)

    result: list[dict] = []
    for proj, by_provider in sorted(groups.items()):
        if len(by_provider) < 2:
            continue
        entry: dict = {"project": proj, "providers": {}}
        for provider, prov_sessions in sorted(by_provider.items()):
            durations = [
                float(s["duration_minutes"])
                for s in prov_sessions
                if s.get("duration_minutes") is not None
            ]
            tool_total = sum(
                sum(s["tool_calls"].values()) if isinstance(s.get("tool_calls"), dict) else 0
                for s in prov_sessions
            )
            entry["providers"][provider] = {
                "sessions": len(prov_sessions),
                "avg_duration_minutes": round(sum(durations) / len(durations), 1) if durations else None,
                "total_tool_calls": tool_total,
            }
        result.append(entry)

    return result


def _collect_sample_prompts(sessions: list[dict], max_total: int = 50) -> list[str]:
    all_prompts: list[str] = []
    for s in sessions:
        for p in s.get("user_prompts", []):
            text = p if isinstance(p, str) else p.get("text", "")
            if text:
                all_prompts.append(text)
    return _pick_diverse_prompts(all_prompts, max_total)


def aggregate(input_dir: Path, output: Path, budget_kb: int, verbose: bool) -> bool:
    """Aggregate sessions and write output. Returns True on success."""
    sessions, providers_found, commit_stats = _load_provider_files(input_dir)

    if not providers_found:
        print("No provider session files found in", input_dir, file=sys.stderr)
        return False

    if verbose:
        logger.info(
            "Loaded %d sessions from %d providers: %s",
            len(sessions), len(providers_found), ", ".join(providers_found),
        )

    _normalize_tools_in_sessions(sessions)

    data: dict = {
        "summary": _build_summary(sessions, providers_found),
        "per_project": _build_per_project(sessions),
        "tool_patterns": _build_tool_patterns(sessions),
        "workflow_patterns": _build_workflow_patterns(sessions),
        "temporal_trends": _build_temporal_trends(sessions),
        "friction_patterns": _build_friction_patterns(sessions),
        "notable_sessions": _build_notable_sessions(sessions),
        "cross_tool": _build_cross_tool(sessions),
        "sample_prompts": _collect_sample_prompts(sessions),
    }

    if commit_stats:
        data["commit_stats"] = commit_stats

    actual_size = len(json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8"))
    data["meta"] = {
        "generated_at": datetime.now(tz=timezone.utc).isoformat(),
        "providers_found": providers_found,
        "total_sessions": len(sessions),
        "budget": {
            "target_kb": budget_kb,
            "actual_kb": round(actual_size / 1024, 1),
            "truncated": False,
        },
    }

    max_bytes = budget_kb * 1024
    truncated = write_output(data, output, max_bytes=max_bytes)

    if verbose:
        actual = output.stat().st_size
        logger.info("Wrote %s (%.1f KB, truncated=%s)", output, actual / 1024, truncated)

    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Aggregate per-provider session data into cross-session analytics.",
    )
    parser.add_argument("--input", required=True, type=Path, help="Directory with *_sessions.json files")
    parser.add_argument("--output", required=True, type=Path, help="Output JSON path")
    parser.add_argument("--budget-kb", type=int, default=100, help="Max output size in KB (default: 100)")
    parser.add_argument("--verbose", action="store_true", help="Log stats to stderr")
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s", stream=sys.stderr)

    if not aggregate(args.input, args.output, args.budget_kb, args.verbose):
        sys.exit(1)


if __name__ == "__main__":
    main()
