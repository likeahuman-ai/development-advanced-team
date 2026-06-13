---
name: sprint-tickets
description: "Turns an approved sprint plan into AI-ready GitHub Issues plus a pinned build-order issue — hard-dependency wave analysis, PR grouping by coupling, and real provision/verify commands. Writes to GitHub via gh, with one human gate before any forge write. Use when the user has an approved sprint plan that needs implementation planning, or says 'break this down', 'create issues', 'make tickets', or 'turn this into tasks'."
argument-hint: "Path to the .sprint plan (optional — auto-detects the latest draft)"
---

# /sprint-tickets — Sprint Plan to Issues + Build Order

Phase 2 of the flow: turn the approved `.sprint` plan into AI-ready issues and a pinned build-order. Drive the sub-phases in order — 2.0 Phase setup → 2.1 Context → 2.2 Architecture → 2.3 Decomposition → 2.4 Issues → 2.5 Build order → 2.6 Phase close. Mostly autonomous: exactly one human gate (2.3.4), before any forge write.

Boundaries that hold for the whole phase:

- **Zero chain ops.** No commits, no pushes, no bookmark moves, no jj write of any kind. The session's only required vcs command is one read — `jj git remote list` (2.4.1); vcs reads are inspections, never writes, so explorers may read history (e.g. `git log`) for 2.1.1's spec-recency check. The plan stays `status: draft`; the `built` flip rides the final PR's close-out commit (Refine 5.2.1), never this phase.
- **Forge through `gh` via Bash** — no MCP servers (an MCP catalogue front-loads and rots context; prefer on-demand CLIs). Every dispatch runs on a capable tier — Sonnet or Opus, never Haiku.
- **Dispatch, don't do.** Exploration belongs to `codebase-explorer`, design to `code-architect`. Consolidate their reports; never do their specialist work inline.

## Trust the artifact

The `.sprint` plan and `.adr` are approved decisions — gated at Plan 1.3.1, committed at Plan 1.3.2. Execute them as written: never re-validate, re-confirm, or re-present them for approval — a check whose normal outcome is "confirmed, proceed" is noise. The one sanctioned deviation path is 2.1.2's reconcile: the code reveals what the plan didn't account for → flag → `/sprint-plan`. Never patch the plan here, never re-commit it; if the user wants a plan change → `/sprint-plan`.

The `.spec` is different in kind — a claim about code, and code is ground truth. Verify it on contact (2.1.1): drift detection, not distrust.

**Initial request:** $ARGUMENTS

---

## 2.0 Phase setup

**Goal:** gather intent context — what to build (the `.sprint` plan + the upstream want/why). No code, no `.spec` — that's 2.1.

1. **Find the `.sprint` plan (2.0.1).** $ARGUMENTS carries a path → use it; else take the latest `.sprint/sprint-v{N}.md` with `status: draft`; if ambiguous → confirm with the user. **No draft exists → stop** — nothing to ticket; run `/sprint-plan`. The plan is already committed (Plan 1.3.2): trust it, never re-commit; if the user wants a change → `/sprint-plan`.

2. **Read the plan + upstream (2.0.2).** Read the `.sprint` plan **in full** — it is the contract. Pull forward the working inputs: epics, the `US-###` slice, scope, success metric, DoD-ref. Then read upstream, each skip-if-absent:
   - `.stories` — only the referenced `US-###` (selective — it can be large);
   - `.brief` — the DoD + quality goals;
   - `.adr` — **in full** (standing law; scarce + terse by the ADR bar — which decisions govern emerges during decomposition, not at planning).

---

## 2.1 Context

**Goal:** gather code context for writing tickets.

1. **Explore for context (2.1.1).** Check whether a `.spec` exists (skip-if-absent) — its presence selects the mode. Dispatch `codebase-explorer` agents (parallel), each briefed per `codebase-explorer-prompt` (`${CLAUDE_PLUGIN_ROOT}/skills/sprint-tickets/prompts/codebase-explorer-prompt.md`) — thorough, **one fresh exploration every run**: never reuse another session's map. Two modes:
   - **With `.spec`** — the spec scopes the start, **never the limit** (*direction from the session, discretion to the agent*): don't re-derive what it documents, but **verify on contact** — check any spec claim this sprint rests on against the code; mismatch → report (feeds 2.1.2). Paths with commits newer than the spec's last patch → re-explore. Always read the code on correctness-critical paths.
   - **Without `.spec`** — the full sweep: all three explorer modes (Architecture Mapping · Pattern Matching · Integration Analysis).

   Either mode: **surface the shared seams** — modules 2+ epics touch — they feed seam-ownership in 2.2.1.

2. **Reconcile (2.1.2).** Reconcile the gathered context against the `.sprint` plan + `.adr` (the approved intent):
   - the code reveals what they didn't account for (anti-pattern, blocker, false assumption) → flag → `/sprint-plan`;
   - else **`.sprint`/`.adr` win** — execute as written, proceed silently.

   A **spec mismatch** from 2.1.1 does **not** bounce to `/sprint-plan` — carry it as a note into the tickets' context; the map is corrected at the spec patch (Refine 5.2.1).

---

## 2.2 Architecture

**Goal:** decide how to build it — *design before decomposition*: the approach is settled here, as its own act, before anything is sliced.

1. **Prepare architect prompts (2.2.1).** Per epic, distil 2.0 + 2.1 into one succinct dispatch prompt per `code-architect-prompt` (`${CLAUDE_PLUGIN_ROOT}/skills/sprint-tickets/prompts/code-architect-prompt.md`): scope (`.sprint`) · the governing `.adr` records · the module map · **the shared seams, each with a single-owner assignment** · the `.spec` slice (if present). Pointers + boundaries, not a code dump.

2. **Design per epic/feature (2.2.2).** Dispatch `code-architect` agents (parallel), one per epic/feature; each deep-reads its own slice. The design lives in the agent's **report** — no design-doc file is produced or persisted. Seam discipline rides in each prompt: consume owned-elsewhere interfaces as given; a needed change → flag, don't fork the seam; a *new* seam's consumer designs against the assigned owner's expected shape (parallel dispatch — the owner's design isn't back yet). Mismatches surface at 2.3.1's coherence check.

---

## 2.3 Decomposition

**Goal:** consolidate the architects' tickets into one coherent, right-sized, approved backlog.

1. **Assemble the draft ticket list (2.3.1).** Collect the architects' reports — each carries one epic's design as ticket-sized units: objective, hard deps, AC, S/M/L complexity, `US-###` refs. Combine into **one cross-epic draft ticket list**, in-session (it becomes Issues at 2.4.4). Check interface coherence: no seam defined two ways, no seam-ownership flag left unresolved. The hard-dependency + complexity notes pass forward to 2.5. No per-file attribution is collected anywhere — file overlap is no input under worktrees.

2. **Decide structure (2.3.2).** Mirror the breakdown's natural shape; collapse degenerate levels: 1 grouping → flat (labels only) · N groupings → 2-level (epic → tasks) · epics with sub-features → 3-level (epic → feature → tasks). Collapse any single-child level. No count threshold. Structure serves **traceability** (`US-### → issue → PR`, Refine 5.3.1) **+ human navigation** — no agent reads a parent issue → when in doubt, flatter.

3. **Present breakdown (2.3.3).** Present the grouped breakdown to the user — groups at the depth 2.3.2 chose, each ticket with title, complexity, and hard deps, plus anything the user should weigh.

4. **Gate — approve the breakdown (2.3.4).** The user must approve the breakdown **before any forge write**. Changes → amend the draft list, re-present. No `gh` write runs until this gate passes. The phase's only gate — it sits on acceptance of the breakdown's *content*, never on a vcs/forge op: the human approves the artifact, and the forge writes that publish it follow autonomously.

---

## 2.4 Issues

**Goal:** turn the approved breakdown into forge objects.

1. **Find the target repo (2.4.1).** `jj git remote list` → pin the repo every `gh` write in this phase targets (guards the multi-remote case); if no remote → stop — the Plan 1.0.2 bootstrap should have created it; route back to `/sprint-plan`. This read is the phase's only required vcs command.

2. **Seed the standing labels (2.4.2).** Seed the full standing set `labels-format` (`${CLAUDE_PLUGIN_ROOT}/skills/sprint-tickets/formats/labels-format.md`) enumerates — the sprint state machine (`needs-review` · `needs-refine` · `conflict-parked`) + the `type/*` and `complexity/*` taxonomies + `build-order`. Every create is `gh label create … --force` (create-or-update, idempotent: a no-op on an established repo, the full seed on a fresh one). Load-bearing — a missing label silently breaks a later `--add-label`.

3. **Seed the per-sprint labels (2.4.3).** Create `epic:*` / `feature:*` from the breakdown's groups — only the levels 2.3.2 kept — plus `v{N}` from the plan filename (`.sprint/sprint-v{N}.md` → `v{N}`); `--force`.

4. **Create the issues (2.4.4).** One `gh issue create` per ticket — body per `ticket-format` (`${CLAUDE_PLUGIN_ROOT}/skills/sprint-tickets/formats/ticket-format.md`), passed with `--body-file`. Parents before children at the depth 2.3.2 chose, in dependency order, threading the `#refs` (`Part of #N` · `Blocked by #N`). No milestone — `v{N}` is the sprint tie. Write discipline:
   - **One create per Bash call — never a generated batch script.** Sequential writes dodge GitHub's secondary rate limit and keep each failure legible: if #9 fails, #1–8 exist and the stop point is visible.
   - Write each body to a temp file first (bodies are markdown full of backticks and `$` — a heredoc mangles them), then point `--body-file` at it.
   - Read the returned `#N` from each create's output and write it **literally** into the next dependent body — shell variables don't survive between calls; if a create returns no number → stop and report — never create a child referencing a parent that doesn't exist.

5. **Present summary (2.4.5).** Present the created issues — grouped, with `#`numbers + their GitHub URLs.

---

## 2.5 Build order

**Goal:** write the self-contained build-order issue `/sprint-build` executes — Build trusts it as authoritative and never recomputes (Build 3.1.3).

1. **Collect per-ticket data (2.5.1).** For each ticket, pull exactly two things from its architect's report: **hard dependencies** — the tickets whose *created* artefacts this one consumes (it won't build or run without them; value must flow, nothing else counts) — and its **S/M/L complexity**. Rewrite the dep references as the created `#N`s → the input table for 2.5.2. Write-sets and soft deps are dropped — worktrees removed the file-clobber and implementers return diffs the session finishes, so nothing needs per-file attribution.

2. **Compute hard-dep waves (2.5.2).** Sort the tickets by dependency — every ticket after the tickets it depends on (a topological sort), layered: a **wave** = every ticket whose deps all sit in earlier waves. **Hard deps only — no file-disjointness checks of any kind** (worktrees + 3-way apply absorb file overlap; a rare same-line overlap surfaces at Build authoring as a recorded jj conflict, resolved there — a coupling signal, not something to pre-empt); if the sort stalls (a dependency cycle) → reclassify a mis-tagged dep, or combine truly co-dependent tickets into one. Dep-changes need no special handling — the lockfile regenerates at Build authoring (Build 3.2.4). → `## Parallel Waves`

3. **Group PRs (2.5.3).** Group the tickets into PRs by **coupling** — a shared runtime boundary: they ship one behaviour, and split, neither PR reviews alone — never by line count. And **dependency-closed**: a group includes everything it hard-depends on, or depends only on what's already on `development`, so each PR is independently reviewable **and independently landable**; a group with an external hard-dep joins the group it depends on. → `## PR Grouping`

4. **Decide scope (2.5.4).** State the build scope **as a decision, not a menu** — e.g. "build all N; #X is stretch (build only if the wave has room) unless told otherwise." Leaves Build no question to ask. → `## Scope`

5. **Write verify (2.5.5).** Write **two real, runnable commands — never placeholders** — repo-matched (detect the repo's own tooling):
   - **provision** — install/sync project deps (e.g. `pnpm install --frozen-lockfile`) — what a fresh worktree runs first;
   - **verify** — the single authoritative "did we break anything?" command, scoped to the touched package(s), **never workspace-wide**.

   Suites that only run after a deploy (e2e on a preview env) are listed **deploy-deferred** — the gate doesn't pretend to cover them. Consumers: self-verify Build 3.2.1 · integration gate Build 3.2.5 · fixed-tip Refine 5.1.5. → `## Verify`

6. **Create the build-order issue (2.5.6).** `gh issue create` per `build-order-format` (`${CLAUDE_PLUGIN_ROOT}/skills/sprint-tickets/formats/build-order-format.md`) — the body carries exactly the four sections written above: `## Parallel Waves` · `## PR Grouping` · `## Scope` · `## Verify`. Labels: `build-order` + `v{N}`. **No gate** — the build-order is deterministic from the approved breakdown; 2.3.4's acceptance covers it, and a forge write is never gated (gates sit on content acceptance, never on a vcs/forge op).

7. **Pin the build-order issue (2.5.7).** `gh issue pin` — the pin is how a fresh `/sprint-build` session finds its work. Build 3.4.3 unpins on retire — GitHub caps pins at 3, so the slot must come back; if the pin fails on the cap → list the pinned issues, unpin a stale `build-order` if one exists, else surface the three pins to the user.

---

## 2.6 Phase close

**Goal:** hand off to build.

1. **Handoff (2.6.1).** Summarise the created issues (grouped, `#N`s) + the pinned build-order. Recommend running `/sprint-build` in a **fresh session** — the pinned build-order carries the handoff state; nothing from this conversation is needed (*phases don't share a session — artifacts are the bridge*).
