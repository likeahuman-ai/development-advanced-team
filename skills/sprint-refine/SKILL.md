---
name: sprint-refine
description: "Refines and lands the sprint's PR(s), per PR — fixes the published review findings via worktree-isolated fix agents, patches the system .spec through spec-writer, then lands each PR on the trunk by rebase + fast-forward (never a merge); a conflicted land parks for a paired session while everything else continues; closes the sprint once all PRs have landed. Runs on jj (colocated git) + GitHub via gh. Use when PR(s) carry needs-refine, or the user says 'fix these', 'address the review', 'refine the sprint', 'land the sprint', 'merge the PRs', 'ship it', 'close out the sprint', 'update the spec', or has reviewed PRs awaiting fixes and landing."
argument-hint: "PR number(s) or URL(s) (optional — defaults to `needs-refine` label discovery)"
---

# /sprint-refine — Fix, Patch the Spec, Land

Phase 5 of the sprint flow (Plan → Tickets → Build → Review → Refine). The per-PR spine: **fixes → spec delta → land** — each PR gets its findings fixed, its `.spec` delta written and accuracy-verified, then lands on `development` by rebase + fast-forward, per PR (the flow never merges). Once every PR has landed, close the sprint. Starts at PR discovery (5.0.1), ends at the summary (5.3.4). Promoting `development → main` is a separate release step — out of scope.

The latest `### Code Review` comment is this phase's **work order** — tickets drive Build, comments drive Refine. Never re-run Review's work, never re-check Tickets' or Build's decisions (*trust the artifact*).

**Initial request:** $ARGUMENTS

## You are the orchestrator, NOT the fixer

Discover the PRs, present findings, dispatch fix agents and `spec-writer`, author the commits, run the verify gate, land, clean up — never write a line of code or spec prose yourself. If you catch yourself editing source to fix a finding — STOP; that work belongs to a dispatched agent (*subagents are hands, not authors* — they return diffs; the session is the sole committer). Every dispatch runs Sonnet or Opus, never Haiku.

| Tool | Allowed | Purpose |
|------|---------|---------|
| Agent | YES | Fix agents (5.1.3, 5.1.5) and `spec-writer` (5.2.1) |
| Bash (`jj`, `gh`, the build-order provision/Verify commands) | YES | Discovery, positioning, finishes, the verify gate, publishes, the land, cleanup |
| Read / Grep / Glob | YES | Work orders, build-order, review-standard slices, plan status |
| Edit / Write | ONLY the 5.2.1 plan flip | The `.sprint` `draft → built` status edit — nothing else |

Subagents never run jj or git — all vcs motion (snapshots, describes, bookmarks, pushes) belongs to the session. Two agents write files (never the vcs), each inside its own jj workspace (worktree-isolated, like the fix-agents): `spec-writer` (5.2.1) writes the `.spec` delta in its workspace, and the marker fix-agent on a recorded conflict (5.1.4) writes the resolved markers in its. Both write files; the session owns all vcs motion.

**One human gate (ADR-016):** 5.2.4 (accept the PR against its DoD) — the genuine ship/no-ship call the model can't make for the user. The fix-set (5.1.2) and the `.spec` delta (5.2.2) run **autonomously**: 5.1.2 defaults to fix-all-published (the published set *is* Review's arbitrated must-fix set), and 5.2.2 self-verifies the delta's accuracy against the diff — gating either would rubber-stamp work the model can verify itself, which the rubric's own gate-ergonomics criterion forbids. The vcs motion after the gate runs autonomously — never gate a commit, a push, or the land itself.

**Parking is not solving.** A conflicted land rebase is recorded, never a halt — the PR parks (`conflict-parked`) for a **paired human session**; this skill never auto-resolves a land conflict, and the trunk never freezes: every other PR proceeds.

---

## 5.0 Phase setup

Goal: find the sprint's PR(s) under refine, then fan out per PR.

### 5.0.1 Find the sprint's PR(s)

- If `$ARGUMENTS` names PR number(s) → use exactly those.
- Else discover by label — the durable discovery key (under jj there is no current branch to infer from):

```bash
gh pr list --label needs-refine --state open --json number,title,url,headRefName,headRefOid,labels
```

if nothing found → stop and tell the user: no open PR carries `needs-refine` — pass a PR number, or run `/sprint-review` first.

Also read the sprint's build-order issue (an inline inspection feeding 5.1.3 and 5.1.5 — labels `build-order` + `v{N}`, closed at Build 3.4.3; derive `v{N}` from the `feat/sprint-v{N}(-<g>)` head refs): its `## Verify` section carries the **provision** and **Verify** commands.

```bash
gh issue list --label build-order --label "v{N}" --state closed --json number,title
gh issue view <number>
```

### 5.0.2 Iterate per PR — fixes fan out, the land serialises

**Fixes + spec fan out across PRs (ADR-014).** The old "single working copy = serial boundary" is lifted: each PR's fix-agents **and `spec-writer`** run in their **own jj workspaces** (Build 3.1.2's machinery), so the **slow work overlaps across PRs**. Mechanism: position `@` at a PR's tip (5.0.3) and dispatch *that* PR's fix batch — the create hook cuts its workspaces from `@-`, so each PR's batch must be cut while `@` sits on its tip — then move to the next PR and dispatch its batch; **once cut, the workspaces are independent, so all PRs' batches run concurrently** (creation is staggered, execution overlaps). **The spec delta fans out the same way:** a sprint's per-PR `spec-writer`s are emitted in **ONE batched dispatch** (5.2.1) — each cut from its own PR's tip while `@` sits there, so creation staggers but execution overlaps once cut. The session stays **sole committer**: it folds each returned workspace serially onto *that PR's own close-out chain* (folding is cheap; the dispatched agent work is what parallelises). Disjoint spec sections — the divided-PR common case (disjoint code → disjoint spec sections, 5.2.1) — fold clean; a rare same-section overlap between two PRs' deltas reconciles via the existing doc/spec path (5.2.5), **never a park**. *(Cross-PR dispatch shares the agent concurrency cap with each PR's own fix batch — it schedules, not free-doubles; still a win when one PR's batch finishes early.)*

**Land order.** **Peers** (`base: development`) are independent → land in **any order**. A **stack** (a PR whose `base:` is a prior in-sprint group) lands in **dependency order, base first** (5.2.5) — the dependent rebases onto the *landed* base. The land is **always serial** regardless: `development` is one resource and the stale-lease push is the concurrency control (5.2.5).

### 5.0.3 Re-assert position (per PR)

Sync in first — review's push may be from another session:

```bash
jj git fetch
```

Then set the work surface — `jj new <bookmark>` atop this PR's head, or confirm `@` already sits there (`jj log -r @- --no-graph -T commit_id` matches the PR's `headRefOid`). Fixes and the spec delta finish onto this position; the create hook bases each fix workspace on the last finished commit (`@-`; Build 3.1.2) — keep `@` empty at dispatch.

if foreign uncommitted state sits in `@` → surface it to the user, don't blind-switch over another session's work.

### 5.0.4 Check eligibility (per PR)

Read the **latest** `### Code Review` comment on this PR — it is this PR's work order (`gh pr view <number> --json comments`, take the newest comment carrying the marker):

- if no `### Code Review` comment → not reviewed → skip this PR (record why for the end-of-run report, 5.2.6).
- if already refined → skip (fix/close-out commits postdating the latest comment are the usual evidence).
- if zero published findings → skip 5.1 entirely, straight to 5.2 — the spec delta and the land still run.
- if the PR carries `conflict-parked` → straight to 5.2.5 to resume the land: if healed (`jj log -r 'conflicts()'` empty) → re-verify the healed tip → FF + push → remove the label → continue at 5.2.6 (cleanup); if not healed → it still awaits the paired session — report and continue with the other PRs.

---

## 5.1 Fixes (per PR)

Goal: apply this PR's must-fix findings — the published set in its comment (the findings backlog stays in the repo, untouched here).

### 5.1.1 Present findings

Present this PR's published findings from the latest `### Code Review` comment (shaped per `finding-format`) — scores + `testable` tags exactly as published, no re-scoring, no severity labels.

### 5.1.2 Select the fix-set (autonomous)

**Default: fix all published findings (ADR-016).** The published set already *is* Review's Opus-arbitrated must-fix set (`≥75` ∨ `≥50`∧testable), so "which to fix" is a computable default, not a decision needing a human — gating it would rubber-stamp work the model can verify itself. Narrowing the fix-set is **opt-in**, never a blocking stop: if the user has *already* asked to defer a tier, honour it; otherwise proceed with fix-all-published. if the published set is empty → straight to 5.2 (the spec delta + land still run; distinct from 5.0.4's zero-findings skip).

### 5.1.3 Dispatch fixes (parallel)

**First, group the picked findings by target file (ADR-018).** Read each picked finding's target file from its `finding-format` field — the published comment's `Files:` edited-path list, the authoritative source for this partition. Then the **unit of dispatch is the file, not the finding**:

- **One worker per distinct target file** — not one per finding. Partition the picked set by `Files:` and fan out exactly one fix worker for each distinct file.
- **A file carrying multiple findings is ONE worker** — that worker runs all of that file's findings within itself (serial within-file). Inject the per-finding payload (description · evidence · permalink · its review-standard slice · the `testable` → regression-test rule) for **each** finding the worker owns.
- **A finding spanning multiple files** reduces to within-worker serial on the involved files — note it so the same finding isn't double-dispatched across those files' workers.

Partitioning by file makes parallel workers touch disjoint files by construction — the §5.1.4 fold-conflict heal drops to the safety net (it was the routine path before the partition).

Dispatch fix agents in ONE parallel batch — one general-purpose subagent per distinct target file, `isolation: worktree`, cut off this PR's tip (5.0.3 positioned `@` there — `@-` is the cut point). Fix agents have no agent file — each is a general subagent briefed with `fix-prompt`.

Inject per agent: each finding the worker owns (description · evidence · permalink) + that finding's slice of the review standard. if a finding is tagged `testable` → the agent also writes a **regression test** covering it (test-after; test-first is an upgrade) — else a plain description-based fix.

**The Build 3.2.1 worktree contract applies in full — state it in the prompt:**

- the isolated copy is a jj workspace — **never run git or jj** (git there hits the *main* repo); just write files
- it ships **no project deps** → run the build-order's **provision** command first, then its **Verify** command, and self-verify to green — never rely on JS's leaking parent `node_modules` (fragile, unsound on dep changes)
- **return status + summary + working directory** — no diff; the session snapshots and folds the workspace

### 5.1.4 Finish the fixes (per finding)

Barrier — collect every fix-agent's **status + summary + working directory**. For each `SUCCESS`, the session **snapshots** its workspace (`jj status` run inside it lands the fix in `<name>@`), then **folds one atomic commit per finding** on this PR's chain, `fix(scope): <finding>`:

```bash
( cd <worker-working-dir> && jj status >/dev/null )       # snapshot the fix into <name>@
jj describe '<name>@' -m "<message + trailers per commit-format>"
jj rebase -r '<name>@' -d '<prev-tip>'                    # fold onto this PR's tip (the first fix is already on it)
jj new                                                     # after the last finding
```

Message worker-suggested, session-owned; trailers carry `Assisted-by: <agent> <model>` (never `Co-Authored-By:`) plus pointers to artifact-owned facts by logical ID (`Ticket:`/`Story:`/`ADR:`/`Depends-on:`), never copies. A `testable` finding's fix + its regression test = **ONE commit** — the test proves the fix. Never bundle fixes into one commit.

**Safety net — residual overlaps only (ADR-018).** §5.1.3 partitions the batch by target file, so parallel workers touch disjoint files by construction and a same-file fold collision should not occur on the normal path. This heal stays only for the residual overlap the partition couldn't foresee — e.g. a finding whose true edit set wasn't fully captured by its target-file field. When such an overlap does surface → Build 3.2.4's mechanism: the `jj rebase` of an overlapping fix **records** a conflict (not a halt) → `jj edit` the conflicted commit, dispatch a fix agent (solo-heal) to fix the markers — `jj status` amends it in place, message + trailers untouched (*hands-not-authors*: the session writes no code) → resume the fold.

Tail — forget the fix workspaces (spent resource, Build 3.2.6's mechanics): per workspace under `.claude/worktrees/` — `jj workspace forget <name>` + `rm` the directory (the WorktreeRemove hook does this at teardown, but Claude Code may skip it — claude-code#37611 — so the session runs it explicitly; idempotent). The 5.3.3 sweep is only the safety net.

### 5.1.5 Verify the fixed tip

**The explicit gate.** jj runs no git hooks — push is NEVER the gate; the gate is this step. The session re-runs the build-order **Verify** command on this PR's fixed tip AND asserts no recorded conflicts:

```bash
<the build-order Verify command>
jj log -r 'conflicts()'          # must be empty
```

The fixes are fresh code, and the new regression tests run inside Verify's scope — the fix proves itself.

if Verify fails → Build 3.2.5's loop: dispatch a fix agent off the fixed tip (fresh workspace, same contract) → the session snapshots + folds it → re-gate. **Bounded, then escalate** — never loop indefinitely; a repeating failure is a signal for the user, not something to paper over.

### 5.1.6 Push

Publish the verified tip — push only verified state (5.1.5 just certified it):

```bash
jj bookmark set <headRefName> -r @-
jj git push --bookmark <headRefName>   # existing bookmark (set just above); jj 0.42 needs no --allow-new
```

---

## 5.2 Spec delta + land (per PR)

Goal: `spec-writer` patches `.spec` for this PR's diff, then the PR is accepted and landed.

### 5.2.1 Spec delta

Dispatch `spec-writer` with `isolation: worktree`, cut off this PR's tip — the same Build 3.1.2 / 5.1.3 machinery the fix-agents use (`@-` is the cut point; keep `@` empty at dispatch per 5.0.3). It applies ADDED/MODIFIED/REMOVED hunks over **this PR's** diff in place, scoped (divided PRs touch disjoint code → disjoint spec sections), per `spec-format`. A sprint's per-PR `spec-writer`s are dispatched in one batched turn (5.0.2) — each cut from its own PR's tip, folded serially onto that PR's close-out by the session.

**The 5.1.3 worktree contract applies in full — state it in the dispatch prompt:**

- the isolated copy is a jj workspace — **never run git or jj** (a `git`/`jj` command there silently acts on the *main* repo); it applies the spec hunks in place over this PR's diff and writes nothing else
- **return status + summary + working directory** — no diff; the session snapshots and folds the workspace onto this PR's close-out chain

if this is the sprint's **final unlanded PR** (every sibling `feat/sprint-v{N}(-<g>)` PR already landed — check the forge) → the **session** (not `spec-writer`) flips the `.sprint` plan `draft → built`. The flip is an annotation, never its own commit — it rides this PR's close-out commit (5.2.3) and lands with it: flip and fact become true together; a PR that never lands → neither lands.

### 5.2.2 Verify the `.spec` delta (autonomous)

**Spec-accuracy check, not a sign-off (ADR-016).** The delta is `spec-writer` reflecting this PR's shipped diff — its faithfulness is *mechanically checkable*, not a human judgment: re-derive the spec sections this PR's diff touches and assert the delta records exactly them — nothing dropped, nothing invented, no untouched section rewritten. if the check fails → back to 5.2.1 (re-dispatch `spec-writer` with the discrepancy); if it passes → 5.2.3, autonomously. The plan flip (when this is the final PR) is automatic once the sprint lands (5.2.1) — no separate approval. The human ship decision is **5.2.4** (accept-vs-DoD), not this derivable check.

### 5.2.3 Finish + push the close-out bundle

One publication motion — deliberately fused so nothing intervenes between 5.2.2's accuracy-verify and publication (both ops stay named). The delta (+ flip) is already snapshotted in `@`:

```bash
jj describe -m "<docs commit per commit-format>"
jj new
jj bookmark set <headRefName> -r @-
jj git push --bookmark <headRefName>   # existing bookmark (set just above); jj 0.42 needs no --allow-new
```

Doc-only — the code tip was verified at 5.1.5; no re-verify.

### 5.2.4 Gate — accept this PR

The user gives go/no-go on this PR against the **per-PR DoD** — the `.brief` DoD applied to what this PR delivers. Acceptance gates the content; the land op follows autonomously — never gate the land itself.

### 5.2.5 Land this PR

```bash
jj git fetch
jj rebase -b <headRefName> -o development@origin
```

The rebase **completes even on conflict** — a conflict is recorded in the commit, never a halt (*the integration point never freezes*).

**Clean rebase** → fast-forward and push:

```bash
jj bookmark set development -r <rebased tip>
jj git push --bookmark development   # existing trunk bookmark; jj 0.42 needs no --allow-new
```

The bookmark move is forward-only — the FF; jj refuses a backward move. if the push rejects on a **stale lease** → that rejection IS the concurrency control: `jj git fetch` · re-rebase · retry. The PR then closes — its commits landed under fresh SHAs, change-ids preserved.

**Stacked PRs (ADR-014) — base-first, retarget before delete.** When a PR is a stack (its `base:` ≠ `development`):

- Land the **base group first** — it lands as a normal peer onto `development` (above). Only then land each dependent, in `base:` order.
- Before landing a dependent, **retarget its PR base to `development`** — `gh pr edit <number> --base development` — *before* 5.2.6 deletes the base group's branch (else GitHub orphans the dependent PR). Then land it: `jj git fetch` · `jj rebase -b <headRefName> -o development@origin` (the base group's commits are already on `development` by change-id, so only the dependent's own commits move; descriptions + trailers + change-ids preserved — **never a squash**) · **re-run the build-order Verify on the rebased tip** (its base changed — a fix that landed on the base may have shifted a seam) · FF + push as above.
- A conflict at the dependent's restack is the same path below — a **code** conflict parks, a **doc/spec** overlap is the spec-writer exception.

**Conflicted rebase → park, don't block — and NEVER auto-resolve:**

- apply the label + a details comment: `gh pr edit <number> --add-label conflict-parked` + `gh pr comment` listing the conflicting change-IDs · the files · the landed sprint it crosses · @both devs.
- suspend this PR's land and move on — everything else continues; other PRs proceed. Parked state is recomputable (both sides are published), so `jj undo` is equally valid to back the rebase out.
- resolution is a **paired human session** at the clone holding the conflict — not this skill: `jj edit <conflicted>` → fix the markers together (the snapshot amends **in place** — same message, same trailers) → descendants auto-rebase → re-verify the healed tip → resume the land (FF + push) → remove `conflict-parked`.

**Exception — a doc/spec overlap is NOT a park (5.2.1's rule).** Parking is for **code** conflicts only; a doc conflict is the spec-writer's remit. This same path covers **both** overlap cases: (a) a `.spec` overlap surfacing at the land rebase against `development@origin`, and (b) a same-section overlap between two in-sprint PRs' **batched** spec deltas (5.0.2) folding onto their respective close-outs — the rare case the divided-PR disjoint-section scoping (5.2.1) doesn't avert. Either way: `jj edit` the conflicted commit → re-dispatch `spec-writer` to reconcile the spec hunks. Name its **inputs** (the agent owns the *how*): this PR's `.spec` delta (the close-out hunks being folded/landed) · the conflicting `.spec` delta (the landed sprint it crosses, or the sibling PR's overlapping delta) · the **conflicted tip** carrying the recorded conflict markers. It amends in place — message + trailers untouched → `jj new` back → assert `conflicts()` empty → continue. This is a doc/spec reconcile, not a code conflict, so it never parks.

### 5.2.6 Clean up (per PR)

Delete the landed PR's bookmarks, local + remote — the rebase-land never uses the merge button, so GitHub's auto-delete never fires; the session deletes them itself:

```bash
jj bookmark delete <headRefName>
jj git push --deleted
```

Then remove the PR's flow labels (`gh pr edit <number> --remove-label needs-refine`).

if PRs remain → next PR (back to 5.0.3). if all PRs landed → 5.3. if any PR is parked or skipped → after the processed PRs, present the **end-of-run report** — each PR's end state (landed · parked, awaiting the paired session · skipped, with why) — and stop: sprint close (5.3) waits until every PR has landed, and the 5.3.3 sweep must never touch a parked PR's bookmarks (both published sides are what make parked state recomputable).

---

## 5.3 Sprint close

Goal: once all PRs have landed — inspect coverage, sweep leftovers, summarise. **Inspect-only: no land gate, no commit** — completion is a forge fact; the plan flipped `built` on the final PR's close-out commit (5.2.1 → 5.2.3).

### 5.3.1 Coverage view

Derive `US-### → Issue → PR → .spec`. Did the landed PRs meet the sprint's single Goal (the `.sprint` plan, Plan 1.2.6)? **A gap is a planning miss, not a block** — it stays visible as the open tickets (unbuilt tickets legitimately stay open, Build 3.4.4's invariant) or feeds the next `/sprint-plan`. Inspect, not a gate — landed PRs already shipped.

### 5.3.2 Confirm completion (forge)

All this sprint's PRs landed — the forge **is** the completion record (built tickets were closed at Build 3.4.3; unbuilt ones legitimately stay open). Confirm the plan flip landed with the final PR — **inspect only, no commit ever**. if the plan still reads `draft` → an irregular close: report it — the next sprint's backstop (Plan 1.0.3) catches it; never commit a flip here.

### 5.3.3 Sweep workspaces + bookmarks

Safety net — normally a no-op (Build 3.2.6 cleaned per wave, 5.1.4 per fix batch, 5.2.6 per PR):

- survivor workspaces under `.claude/worktrees/` → `jj workspace forget <name>` + `rm`
- leftover PR bookmarks → `jj bookmark delete <name>` + `jj git push --deleted`
- any completed `[Epic]` issue still open whose child tickets all closed (Build 3.4.3 should have closed it at build) → `gh issue close <epic-N>` — safety net for an epic Build 3.4.3 should have closed

### 5.3.4 Present summary

This step only runs once every PR has landed (5.2.6's condition), so the summary shows landed PRs only — a run that stopped early reported parked/skipped state at 5.2.6 instead:

```
## Sprint Refine — v{N}

PR #<a> <title> — <f> findings fixed · spec patched · landed
PR #<b> <title> — clean review · spec patched · landed

Coverage: US-### → #issue → PR → .spec   (gaps: <open tickets / next-plan input>)
Plan: sprint-v{N} → built (landed with PR #<last>)
```

Then recommend the next step — *phases don't share a session; artifacts are the bridge*: the landed trunk, the closed PRs, and the `built` plan carry the state. Next: `/sprint-plan` in a fresh session.

---

## Key principles

- **Parking is not solving** — a conflicted land records, the PR parks for a paired human session, and everything else continues; this skill never auto-resolves a land conflict. Doc/spec overlaps re-dispatch `spec-writer` instead — never a parked pair.
- **Fixes fan out, the land serialises (ADR-014)** — each PR's fix-agents + `spec-writer` run in their own jj workspaces (worktree-isolated), so the slow work overlaps across PRs (not one PR at a time); a sprint's per-PR spec deltas fan out in one batched dispatch (5.0.2 · 5.2.1), and the session folds each serially onto its PR's close-out as sole committer. Peers land any order, a stack lands base-first; the land itself is always serial (one trunk, stale-lease control).
- **Session is the sole author** — fix agents and `spec-writer` are hands, not authors: diffs in, session-authored commits out; workers never commit, never run jj.
- **One atomic commit per finding** — `fix(scope): <finding>`; a testable fix + its regression test is one commit; fixes are never bundled.
- **Verify is a step, not a push side effect** — jj runs no git hooks; 5.1.5 is the explicit gate (Verify + `conflicts()` empty), and only then does 5.1.6 publish.
- **One human gate, on content, never vcs ops (ADR-016)** — accept the PR against its DoD (5.2.4); the fix-set (5.1.2, default fix-all-published) and the spec delta (5.2.2, self-verified for accuracy) run autonomously, and every commit, push, and land follows autonomously.
- **The trunk only moves forward** — land = fetch → rebase → bookmark FF → lease push, per PR (a **stack** base-first: retarget the dependent's base to `development` before deleting the base branch, then rebase + FF); a stale lease means fetch · re-rebase · retry; the flow never merges.
- **Flip rides the fact** — the `.sprint` `draft → built` flip is an annotation on the final PR's close-out commit, made by the session; 5.3.2 only confirms it, never commits.
- **Bookmark deletion is manual** — rebase-land never fires GitHub's auto-delete; 5.2.6 deletes local + remote.
- **Trust the artifact** — the latest `### Code Review` comment is the work order; never re-review, never re-score, never re-check Tickets/Build decisions.
- **No Haiku, ever** — Sonnet or Opus on every dispatch.
- **Ends at the trunk** — `development → main` promotion is out of scope; this skill spans no other phase.
