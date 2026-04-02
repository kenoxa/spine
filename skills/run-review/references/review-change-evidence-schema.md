# Review change evidence (optional artifact)

Path: `.scratch/<session>/review-change-evidence.md` — after Gate A, when `standard`/`deep` and a concrete change exists.

**Purpose:** Real change surface (unified diff, `git show`/`git diff`, or hunks + paths) so `inspect-envoy` + `inspect-synthesis` share one plane with internal inspectors. Does not replace seven-field `review-brief.md`.

**Content:** Prefer full unified diff; else per-file excerpts; thin new-file-only changes → key excerpts or minimal tree note.

**Omitted:** `inspect-envoy` prompt still runs; gap string in [inspect-envoy.md](inspect-envoy.md).
