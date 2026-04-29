#!/usr/bin/env bash
# generate-dashboard.sh — generate a self-contained HTML dashboard from queue-state.json
#
# Usage: generate-dashboard.sh <queue-directory>
#   Reads:  <queue-directory>/queue-state.json
#   Writes: <queue-directory>/queue-report.html
#
# The HTML is fully self-contained (inline CSS/JS only) with no external dependencies.
# Designed with the visual-explainer skill; CSS and structure frozen from prototype.

set -euo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────
if [ "$#" -lt 1 ]; then
    printf 'Usage: %s <queue-directory>\n' "${0##*/}" >&2
    exit 1
fi

_qdir="$1"
_state_file="$_qdir/queue-state.json"
_report_file="$_qdir/queue-report.html"

if [ ! -f "$_state_file" ]; then
    printf 'error: queue-state.json not found in %s\n' "$_qdir" >&2
    exit 1
fi

# ── helpers ───────────────────────────────────────────────────────────────────
# Extract a top-level scalar from state JSON
_st() { jq -r "$1" "$_state_file"; }

# Extract task array length
_task_count() { jq '(.tasks // []) | length' "$_state_file"; }

# Count tasks matching a status
_count_status() {
    jq --arg s "$1" '([.tasks[]? | select(.status == $s)] | length)' "$_state_file"
}

# Format a short git SHA (first 8 chars)
_short_sha() {
    local s="$1"
    if [ -n "$s" ] && [ "$s" != "null" ]; then
        printf '%s' "${s:0:8}"
    else
        printf '%s' "&mdash;"
    fi
}

# Map queue status to CSS modifier
_status_class() {
    case "$1" in
        merged)          printf '%s' "merged" ;;
        complete)        printf '%s' "complete" ;;
        failed)          printf '%s' "failed" ;;
        blocked)         printf '%s' "blocked" ;;
        in_progress)     printf '%s' "in-progress" ;;
        pending)         printf '%s' "pending" ;;
        skipped)         printf '%s' "skipped" ;;
        pending_retry)   printf '%s' "retry" ;;
        *)               printf '%s' "pending" ;;
    esac
}

# Map status to timeline dot symbol
_status_symbol() {
    case "$1" in
        merged|complete) printf '%s' "&#10003;" ;;
        failed)          printf '%s' "&#10007;" ;;
        blocked)         printf '%s' "!" ;;
        in_progress)     printf '%s' "&#9654;" ;;
        pending)         printf '%s' "&#9679;" ;;
        skipped)         printf '%s' "&#8856;" ;;
        pending_retry)   printf '%s' "&#8635;" ;;
        *)               printf '%s' "&#9679;" ;;
    esac
}

# ── scalar extraction ─────────────────────────────────────────────────────────
_run_id=$(_st '.run_id')
_started=$(_st '.started_utc')
_base_rev=$(_st '.base_rev')
_total=$(_task_count)

_now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

_merged=$(_count_status "merged")
_complete=$(_count_status "complete")
_failed=$(_count_status "failed")
_blocked=$(_count_status "blocked")
_in_progress=$(_count_status "in_progress")
_pending=$(_count_status "pending")
_skipped=$(_count_status "skipped")
_retry=$(_count_status "pending_retry")

# Treat "complete" as done for progress calculation
_done=$(( _merged + _complete ))
if [ "$_total" -gt 0 ]; then
    _pct=$(( (_done * 100) / _total ))
else
    _pct=0
fi

# ── atomic write helper ───────────────────────────────────────────────────────
_atomic_write() {
    local dest="$1"
    local tmp
    tmp="${dest}.tmp.$$"
    cat > "$tmp"
    mv "$tmp" "$dest"
}

# ═══════════════════════════════════════════════════════════════════════════════
# HTML generation
# ═══════════════════════════════════════════════════════════════════════════════

{
# ── head + CSS ────────────────────────────────────────────────────────────────
cat <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Queue Report:
EOF
printf ' %s</title>\n' "$_run_id"

cat <<'EOF'
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&family=Fira+Code:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  :root {
    --font-body: 'DM Sans', system-ui, -apple-system, sans-serif;
    --font-mono: 'Fira Code', 'SF Mono', Consolas, monospace;
    --bg: #f0f4f8; --surface: #ffffff; --surface2: #f8fafc; --surface-elevated: #ffffff;
    --border: rgba(0,0,0,0.06); --border-bright: rgba(0,0,0,0.12);
    --text: #0f172a; --text-dim: #64748b; --text-muted: #94a3b8;
    --accent: #0e7490; --accent-dim: rgba(14,116,144,0.08);
    --merged: #059669; --merged-dim: rgba(5,150,105,0.10);
    --failed: #dc2626; --failed-dim: rgba(220,38,38,0.10);
    --blocked: #d97706; --blocked-dim: rgba(217,119,6,0.10);
    --in-progress: #2563eb; --in-progress-dim: rgba(37,99,235,0.10);
    --pending: #64748b; --pending-dim: rgba(100,116,139,0.10);
    --skipped: #94a3b8; --skipped-dim: rgba(148,163,184,0.10);
    --retry: #ca8a04; --retry-dim: rgba(202,138,4,0.10);
    --timeline-line: #cbd5e1; --timeline-active: #0e7490;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0f172a; --surface: #1e293b; --surface2: #334155; --surface-elevated: #1e293b;
      --border: rgba(255,255,255,0.06); --border-bright: rgba(255,255,255,0.10);
      --text: #f1f5f9; --text-dim: #94a3b8; --text-muted: #64748b;
      --accent: #22d3ee; --accent-dim: rgba(34,211,238,0.10);
      --merged: #34d399; --merged-dim: rgba(52,211,153,0.12);
      --failed: #f87171; --failed-dim: rgba(248,113,113,0.12);
      --blocked: #fbbf24; --blocked-dim: rgba(251,191,36,0.12);
      --in-progress: #60a5fa; --in-progress-dim: rgba(96,165,250,0.12);
      --pending: #94a3b8; --pending-dim: rgba(148,163,184,0.12);
      --skipped: #64748b; --skipped-dim: rgba(100,116,139,0.12);
      --retry: #facc15; --retry-dim: rgba(250,204,21,0.12);
      --timeline-line: #475569; --timeline-active: #22d3ee;
    }
  }
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:var(--bg);background-image:radial-gradient(ellipse at 20% 0%,var(--accent-dim) 0%,transparent 50%),radial-gradient(ellipse at 80% 100%,var(--merged-dim) 0%,transparent 40%);color:var(--text);font-family:var(--font-body);padding:32px 24px;min-height:100vh;line-height:1.5}
  @media (prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:0.01ms!important;animation-delay:0ms!important;transition-duration:0.01ms!important}}
  @keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
  @keyframes progressFill{from{width:0%}}
  .animate{animation:fadeUp .4s ease-out both}
  .container{max-width:1100px;margin:0 auto}
  .report-header{margin-bottom:28px}
  .report-header h1{font-size:28px;font-weight:600;letter-spacing:-.5px;margin-bottom:8px}
  .report-header .meta{display:flex;flex-wrap:wrap;gap:16px;font-family:var(--font-mono);font-size:12px;color:var(--text-dim)}
  .report-header .meta span{display:flex;align-items:center;gap:6px}
  .report-header .meta code{background:var(--accent-dim);color:var(--accent);padding:1px 6px;border-radius:4px;font-size:11px}
  .progress-section{margin-bottom:28px}
  .progress-label{display:flex;justify-content:space-between;align-items:center;font-family:var(--font-mono);font-size:11px;color:var(--text-dim);margin-bottom:8px;text-transform:uppercase;letter-spacing:.8px}
  .progress-label strong{color:var(--text);font-size:13px}
  .progress-track{height:8px;background:var(--surface2);border-radius:4px;overflow:hidden;border:1px solid var(--border)}
  .progress-fill{height:100%;background:linear-gradient(90deg,var(--accent),var(--merged));border-radius:4px;animation:progressFill .8s ease-out both}
  .kpi-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:12px;margin-bottom:28px}
  .kpi-card{background:var(--surface-elevated);border:1px solid var(--border);border-radius:10px;padding:16px;box-shadow:0 1px 3px rgba(0,0,0,0.04);transition:transform .15s ease,box-shadow .15s ease}
  .kpi-card:hover{transform:translateY(-1px);box-shadow:0 3px 8px rgba(0,0,0,0.06)}
  .kpi-card__value{font-size:28px;font-weight:600;line-height:1.1;font-variant-numeric:tabular-nums}
  .kpi-card__label{font-family:var(--font-mono);font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:.8px;color:var(--text-dim);margin-top:6px}
  .kpi-card--merged .kpi-card__value{color:var(--merged)}
  .kpi-card--failed .kpi-card__value{color:var(--failed)}
  .kpi-card--blocked .kpi-card__value{color:var(--blocked)}
  .kpi-card--in-progress .kpi-card__value{color:var(--in-progress)}
  .kpi-card--pending .kpi-card__value{color:var(--pending)}
  .timeline-section{margin-bottom:28px}
  .section-title{font-family:var(--font-mono);font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:var(--text-dim);margin-bottom:14px}
  .timeline{display:flex;align-items:stretch;gap:0;overflow-x:auto;padding-bottom:8px}
  .timeline__item{display:flex;flex-direction:column;align-items:center;min-width:100px;flex:1;position:relative;padding:0 8px}
  .timeline__item::before{content:'';position:absolute;top:14px;left:0;right:0;height:2px;background:var(--timeline-line);z-index:0}
  .timeline__item:first-child::before{left:50%}
  .timeline__item:last-child::before{right:50%}
  .timeline__dot{width:28px;height:28px;border-radius:50%;background:var(--surface);border:2px solid var(--timeline-line);display:flex;align-items:center;justify-content:center;z-index:1;position:relative;font-size:11px}
  .timeline__dot--merged{border-color:var(--merged);background:var(--merged-dim);color:var(--merged)}
  .timeline__dot--failed{border-color:var(--failed);background:var(--failed-dim);color:var(--failed)}
  .timeline__dot--blocked{border-color:var(--blocked);background:var(--blocked-dim);color:var(--blocked)}
  .timeline__dot--in-progress{border-color:var(--in-progress);background:var(--in-progress-dim);color:var(--in-progress)}
  .timeline__dot--pending{border-color:var(--pending);background:var(--pending-dim);color:var(--pending)}
  .timeline__dot--complete{border-color:var(--merged);background:var(--merged-dim);color:var(--merged)}
  .timeline__dot--skipped{border-color:var(--skipped);background:var(--skipped-dim);color:var(--skipped)}
  .timeline__dot--retry{border-color:var(--retry);background:var(--retry-dim);color:var(--retry)}
  .timeline__label{margin-top:8px;font-size:11px;font-weight:500;color:var(--text-dim);text-align:center;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .table-wrap{background:var(--surface);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin-bottom:20px}
  .table-scroll{overflow-x:auto;-webkit-overflow-scrolling:touch}
  .data-table{width:100%;border-collapse:collapse;font-size:13px;line-height:1.5}
  .data-table thead{position:sticky;top:0;z-index:2}
  .data-table th{background:var(--surface2);font-family:var(--font-mono);font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:var(--text-dim);text-align:left;padding:12px 14px;border-bottom:2px solid var(--border-bright);white-space:nowrap}
  .data-table td{padding:12px 14px;border-bottom:1px solid var(--border);vertical-align:middle}
  .data-table tbody tr:last-child td{border-bottom:none}
  .data-table tbody tr{transition:background .12s ease}
  .data-table tbody tr:hover{background:var(--accent-dim)}
  .data-table code{font-family:var(--font-mono);font-size:11px;background:var(--accent-dim);color:var(--accent);padding:1px 5px;border-radius:3px}
  .data-table small{display:block;color:var(--text-muted);font-size:11px;margin-top:2px}
  .status{display:inline-flex;align-items:center;gap:5px;font-family:var(--font-mono);font-size:10px;font-weight:600;padding:3px 10px;border-radius:6px;white-space:nowrap;letter-spacing:.3px}
  .status::before{content:'';width:6px;height:6px;border-radius:50%;background:currentColor}
  .status--merged{background:var(--merged-dim);color:var(--merged)}
  .status--failed{background:var(--failed-dim);color:var(--failed)}
  .status--blocked{background:var(--blocked-dim);color:var(--blocked)}
  .status--in-progress{background:var(--in-progress-dim);color:var(--in-progress)}
  .status--pending{background:var(--pending-dim);color:var(--pending)}
  .status--complete{background:var(--merged-dim);color:var(--merged)}
  .status--skipped{background:var(--skipped-dim);color:var(--skipped)}
  .status--retry{background:var(--retry-dim);color:var(--retry)}
  details.collapsible{border:1px solid var(--border);border-radius:10px;overflow:hidden;margin-bottom:12px}
  details.collapsible summary{padding:14px 18px;background:var(--surface);font-family:var(--font-mono);font-size:12px;font-weight:600;cursor:pointer;list-style:none;display:flex;align-items:center;gap:8px;color:var(--text);transition:background .12s ease}
  details.collapsible summary:hover{background:var(--surface2)}
  details.collapsible summary::-webkit-details-marker{display:none}
  details.collapsible summary::before{content:'\25B8';font-size:11px;color:var(--text-dim);transition:transform .15s ease}
  details.collapsible[open] summary::before{transform:rotate(90deg)}
  details.collapsible .collapsible__body{padding:14px 18px;border-top:1px solid var(--border);font-size:13px;line-height:1.6}
  details.collapsible .collapsible__body strong{color:var(--text);font-weight:600}
  a{color:var(--accent);text-decoration:none;transition:opacity .12s ease}
  a:hover{text-decoration:underline;opacity:.85}
  @media (max-width:768px){body{padding:16px}.report-header h1{font-size:22px}.kpi-row{grid-template-columns:repeat(2,1fr)}.timeline__item{min-width:80px}.data-table th,.data-table td{padding:10px 12px}}
</style>
</head>
<body>
<div class="container">
EOF

# ── header ────────────────────────────────────────────────────────────────────
printf '  <header class="report-header animate">\n'
printf '    <h1>Queue Report: %s</h1>\n' "$_run_id"
printf '    <div class="meta">\n'
printf '      <span>Started: %s</span>\n' "$_started"
printf '      <span>Ended: %s</span>\n' "$_now"
printf '      <span>Base: <code>%s</code></span>\n' "$(_short_sha "$_base_rev")"
printf '      <span>%s tasks</span>\n' "$_total"
printf '    </div>\n'
printf '  </header>\n'

# ── KPI cards ─────────────────────────────────────────────────────────────────
printf '  <section class="kpi-row animate">\n'

_kpi_card() {
    local cls="$1" val="$2" label="$3"
    # Show if numeric value > 0, or if label is Complete/Progress (always show)
    if [ "$label" = "Complete" ] || [ "$label" = "Progress" ] || [ "$val" -gt 0 ] 2>/dev/null; then
        printf '    <div class="kpi-card%s">\n' "${cls:+ kpi-card--}${cls}"
        printf '      <div class="kpi-card__value">%s</div>\n' "$val"
        printf '      <div class="kpi-card__label">%s</div>\n' "$label"
        printf '    </div>\n'
    fi
}

_kpi_card "merged"     "$_merged"     "Merged"
_kpi_card ""           "$_done"       "Complete"
_kpi_card "failed"     "$_failed"     "Failed"
_kpi_card "blocked"    "$_blocked"    "Blocked"
_kpi_card "in-progress" "$_in_progress" "In Progress"
_kpi_card "pending"    "$_pending"    "Pending"
_kpi_card ""           "${_pct}%"    "Progress"

printf '  </section>\n'

# ── progress bar ──────────────────────────────────────────────────────────────
printf '  <section class="progress-section animate">\n'
printf '    <div class="progress-label"><span>Overall Progress</span><strong>%s / %s tasks</strong></div>\n' "$_done" "$_total"
printf '    <div class="progress-track"><div class="progress-fill" style="width:%s%%"></div></div>\n' "$_pct"
printf '  </section>\n'

# ── timeline ──────────────────────────────────────────────────────────────────
printf '  <section class="timeline-section animate">\n'
printf '    <div class="section-title">Task Timeline</div>\n'
printf '    <div class="timeline">\n'

jq -r 'def h: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;") | gsub("\"";"&quot;");
.tasks[] |
  "      <div class=\"timeline__item\">" +
  "<div class=\"timeline__dot timeline__dot--" + (.status | gsub("_";"-")) + "\">" +
  (if .status == "merged" or .status == "complete" then "&#10003;"
   elif .status == "failed" then "&#10007;"
   elif .status == "blocked" then "!"
   elif .status == "in_progress" then "&#9654;"
   elif .status == "pending" then "&#9679;"
   elif .status == "skipped" then "&#8856;"
   elif .status == "pending_retry" then "&#8635;"
   else "&#9679;" end) +
  "</div><div class=\"timeline__label\">" + (.id | h) + "</div></div>"
' "$_state_file"

printf '    </div>\n'
printf '  </section>\n'

# ── task table ────────────────────────────────────────────────────────────────
printf '  <section class="animate">\n'
printf '    <div class="section-title">Tasks</div>\n'
printf '    <div class="table-wrap">\n'
printf '      <div class="table-scroll">\n'
printf '        <table class="data-table">\n'
printf '          <thead><tr><th>Task</th><th>Status</th><th>Outcome</th><th>Branch</th><th>Head</th><th>Exit Reason</th><th>Model</th></tr></thead>\n'
printf '          <tbody>\n'

jq -r 'def h: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;") | gsub("\"";"&quot;");
.tasks[] |
  "<tr>" +
  "<td><strong>" + (.id | h) + "</strong></td>" +
  "<td><span class=\"status status--" + (.status | gsub("_";"-")) + "\">" + (.status | h) + "</span></td>" +
  "<td>" + ((.outcome // "&mdash;") | h) + "</td>" +
  "<td>" + (if .branch then "<code>" + (.branch | h) + "</code>" else "&mdash;" end) + "</td>" +
  "<td>" + (if .head_rev then "<code>" + (.head_rev[0:8] | h) + "</code>" else "&mdash;" end) + "</td>" +
  "<td>" + ((.exit_reason // "&mdash;") | h) + "</td>" +
  "<td>" + ((.model // "&mdash;") | h) + "</td>" +
  "</tr>"
' "$_state_file"

printf '          </tbody>\n'
printf '        </table>\n'
printf '      </div>\n'
printf '    </div>\n'
printf '  </section>\n'

# ── conflicts / blockers collapsible ──────────────────────────────────────────
_conflicts=$(jq '[.tasks[]? | select(.status == "blocked" or .status == "failed" or .exit_reason != null)] | length' "$_state_file")

if [ "$_conflicts" -gt 0 ]; then
    printf '  <details class="collapsible animate">\n'
    printf '    <summary>Conflicts &amp; Blockers (%s)</summary>\n' "$_conflicts"
    printf '    <div class="collapsible__body">\n'

    jq -r 'def h: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;") | gsub("\"";"&quot;");
    .tasks[] | select(.status == "blocked" or .status == "failed" or .exit_reason != null) |
      "      <p><strong>" + (.id | h) + "</strong> &mdash; " +
      (if .status == "blocked" then "blocked" +
         (if .exit_reason then " (" + (.exit_reason | h) + ")" else "" end) +
         "."
       elif .status == "failed" then "failed" +
         (if .exit_reason then " (" + (.exit_reason | h) + ")" else "" end) +
         "."
       elif .exit_reason then "exited with " + (.exit_reason | h) + "."
       else "" end) +
      (if .branch then " <a href=\"" + (.branch | h) + "/review.md\">review</a>" else "" end) +
      "</p>"
    ' "$_state_file"

    printf '    </div>\n'
    printf '  </details>\n'
fi

# ── action items collapsible ──────────────────────────────────────────────────
# Action items: pending merge, review-passed-pending-merge, failed tasks, blocked tasks
_action_items=$(jq '[.tasks[]? | select(.outcome == "review-passed-pending-merge" or .status == "failed" or .status == "blocked")] | length' "$_state_file")

if [ "$_action_items" -gt 0 ]; then
    printf '  <details class="collapsible animate">\n'
    printf '    <summary>Action Items (%s)</summary>\n' "$_action_items"
    printf '    <div class="collapsible__body">\n'
    printf '      <ul>\n'

    jq -r 'def h: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;") | gsub("\"";"&quot;");
    .tasks[] | select(.outcome == "review-passed-pending-merge" or .status == "failed" or .status == "blocked") |
      "      <li>" +
      (if .outcome == "review-passed-pending-merge" then
         "Merge <code>" + (.id | h) + "</code> (review passed, pending merge)"
       elif .status == "failed" then
         "Re-run <code>" + (.id | h) + "</code> after addressing failure"
        elif .status == "blocked" then
          "Unblock <code>" + (.id | h) + "</code>" +
          (if .exit_reason then " (" + (.exit_reason | h) + ")" else "" end)
        else "" end) +
      "</li>"
    ' "$_state_file"

    printf '      </ul>\n'
    printf '    </div>\n'
    printf '  </details>\n'
fi

# ── footer ────────────────────────────────────────────────────────────────────
cat <<'EOF'
</div>
</body>
</html>
EOF

} | _atomic_write "$_report_file"

printf 'wrote %s\n' "$_report_file"
