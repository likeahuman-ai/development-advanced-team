# review-prompt

The common envelope dispatched at 4.3.1 — one cover note sent to the whole specialist roster in a single parallel batch. It is **thin by design.** Each reviewer agent file already owns its own mandate, its calibration, its self-assessment, and its output shape; this envelope adds only what no single agent file can know: the shape of *this run* and the names of the *other specialists* sharing it. Everything substantive arrives as injected context (named below) — never reproduced here.

---

## This run's roster

Your peers in this batch:

- **Floor (always):** `code-quality-reviewer`, `code-simplifier`
- **Conditional (only those the change triggered):** `silent-failure-hunter`, `type-design-reviewer`, `test-coverage-reviewer`, `comment-analyzer`, `history-reviewer`, `security-reviewer`, `standards-reviewer`

Your agent file owns your lane against each peer — work it, and trust them to work theirs.

## What the dispatch injects (context, not restated here)

Held in your prompt for this review only — read each, skip silently if absent:

- **The diff** — the target. The change you are reviewing.
- **The review standard** — the `.spec` slice for the touched modules, the governing `.adr` set in full, and the `.brief` quality goals. Judge against this.
- **The platform-as-fact line** — the framework, asserted bare (e.g. `Platform: Next.js 16 App Router`).
- **Your matched rules** — standards / security rule content, injected only into the specialists that use them.

These are context, not part of this envelope; the envelope names them so you know what to expect, nothing more.

You may read the local tree at your discretion — direction from this dispatch, discretion to you (your agent file holds how).

**Cite locations by the real tree line, not the diff.** The diff is the seed; the local working copy is already positioned at the PR head (the read-surface). Every `file:line` you report is the line in *that tree* (grep the symbol) — never a `gh pr diff` hunk offset, which overshoots the file and breaks the permalink.

## Output

Report in your own agent-file format. The session collects every report per `finding-report-format` (`${CLAUDE_PLUGIN_ROOT}/skills/sprint-review/formats/finding-report-format.md`) — that format owns the collected shape; you fill your block, the arbiter fills its.
