---
name: sprint-refine
description: "Refines and lands the sprint's PR(s), per PR — fixes the published review findings via worktree-isolated fix agents, patches the system .spec through spec-writer, then lands each PR on the trunk by rebase + fast-forward (never a merge); a conflicted land parks for a paired session while everything else continues; closes the sprint once all PRs have landed. Runs on jj (colocated git) + GitHub via gh. Use when PR(s) carry needs-refine, or the user says 'fix these', 'address the review', 'refine the sprint', 'land the sprint', 'merge the PRs', 'ship it', 'close out the sprint', 'update the spec', or has reviewed PRs awaiting fixes and landing."
argument-hint: "PR number(s) or URL(s) (optional — defaults to `needs-refine` label discovery)"
---

# /sprint-refine — Fix, Patch the Spec, Land

Phase 5 of the sprint flow (Plan → Tickets → Build → Review → Refine). The per-PR spine: **fixes → spec delta → land** — each PR gets its findings fixed, its `.spec` delta written and approved, then lands on `development` by rebase + fast-forward, per PR (the flow never merges). Once every PR has landed, close the sprint. Starts at PR discovery (5.0.1), ends at the summary (5.3.4). Promoting `development → main` is a separate release step — out of scope.

The latest `### Code Review` comment is this phase's **work order** — tickets drive Build, comments drive Refine. Never re-run Review's work, never re-check Tickets' or Build's decisions (*trust the artifact*).

**Initial request:** $ARGUMENTS

## You are the orchestrator, NOT the fixer

Discover the PRs, present findings, dispatch fix agents and `spec-writer`, author the commits, run the verify gate, land, clean up — never write a line of code or spec prose yourself. If you catch yourself editing source to fix a finding — STOP; that work belongs to a dispatched agent (*subagents are hands, not authors* — they return diffs; the session is the sole committer). Every dispatch runs Sonnet or Opus, never Haiku.

| Tool | Allowed | Purpose |
|------|---------|---------|
| Agent | YES | Fix agents (5.1.3, 5.1.5) and `spec-writer` (5.2.1) |
| Bash (`jj`, `gh`, `git apply`, `git worktree`, `git branch -D`, the build-order provision/Verify commands) | YES | Discovery, positioning, finishes, the verify gate, publishes, the land, cleanup |
| Read / Grep / Glob | YES | Work orders, build-order, review-standard slices, plan status |
| Edit / Write | ONLY the 5.2.1 plan flip | The `.sprint` `draft → built` status edit — nothing else |

Subagents never run jj or git — all vcs motion (snapshots, describes, bookmarks, pushes) belongs to the session. Two agents do write the main tree's files (never the vcs): `spec-writer` (5.2.1, the solo writer) and the marker fix-agent on a recorded conflict (5.1.4).

**Three human gates, all on acceptance of content:** 5.1.2 (pick the findings), 5.2.2 (approve the `.spec` delta / close-out bundle), 5.2.4 (accept the PR against its DoD). The vcs motion after each gate runs autonomously — never gate a commit, a push, or the land itself.

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

### 5.0.2 Iterate per PR

Run 5.1–5.2 **per PR, one PR at a time, any order** — divided PRs are independent peers. The single working copy is the work surface — the serial boundary: parallelism lives ONLY inside a PR's fix batch, never across PRs. Never refine two PRs concurrently.

### 5.0.3 Re-assert position (per PR)

Sync in first — review's push may be from another session:

```bash
jj git fetch
```

Then set the work surface — `jj new <bookmark>` atop this PR's head, or confirm `@` already sits there (`jj log -r @- --no-graph -T commit_id` matches the PR's `headRefOid`). Fixes and the spec delta finish onto this position; `worktree.baseRef: "head"` (Build 3.1.2's precondition) makes the last finished commit (`@-`) the cut point for fix worktrees — keep `@` empty at dispatch.

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

### 5.1.2 Gate — pick findings to fix

The user picks which published findings to fix — the fix-set is theirs to scope. if the user picks none → straight to 5.2 (the spec delta + land still run; distinct from 5.0.4's zero-findings skip).

### 5.1.3 Dispatch fixes (parallel)

Dispatch fix agents in ONE parallel batch — one general-purpose subagent per picked finding, `isolation: worktree`, cut off this PR's tip (5.0.3 positioned `@` there — `@-` is the cut point). Fix agents have no agent file — each is a general subagent briefed with `fix-prompt`.

Inject per agent: the finding (description · evidence · permalink) + its slice of the review standard. if the finding is tagged `testable` → the agent also writes a **regression test** covering it (test-after; test-first is an upgrade) — else a plain description-based fix.

**The Build 3.2.1 worktree contract applies in full — state it in the prompt:**

- the worktree is plain git, tracked files only — **never commit, never run jj**
- the worktree shares the machine's tools but ships **no project deps** → run the build-order's **provision** command first, then its **Verify** command, and self-verify to green — never rely on JS's leaking parent `node_modules` (fragile, unsound on dep changes)
- **return the diff + a suggested message** — the session authors the commit; report status

### 5.1.4 Finish the fixes (per finding)

Barrier — collect every diff. Then the session finishes **one atomic commit per finding** on this PR's chain, `fix(scope): <finding>`:

```bash
git apply --3way <the diff>
jj describe -m "<message + trailers per commit-format>"   # jj snapshots the applied changes into @ here
jj new
```

Message worker-suggested, session-owned; trailers carry `Assisted-by: <agent> <model>` (never `Co-Authored-By:`) plus pointers to artifact-owned facts by logical ID (`Ticket:`/`Story:`/`ADR:`/`Depends-on:`), never copies. A `testable` finding's fix + its regression test = **ONE commit** — the test proves the fix. Never bundle fixes into one commit.

if fixes overlap → Build 3.2.4's mechanism: `git apply --3way` absorbs plain file overlap; a true same-line overlap rejects → author that fix on the base and `jj rebase` it onto the tip — the conflict **records, not halts** → `jj edit` the conflicted commit, dispatch a fix agent to fix the markers — the snapshot amends in place, message + trailers untouched (*hands-not-authors*: the session writes no code) → `jj new` back to the tip.

Tail — remove the fix worktrees (spent resource, Build 3.2.6's mechanics): per worktree under `.claude/worktrees/` — `git worktree unlock` **then** `git worktree remove --force` (harness worktrees are locked; a plain remove is refused) + delete the scratch branch (`git branch -D`). The 5.3.3 sweep is only the safety net.

### 5.1.5 Verify the fixed tip

**The explicit gate.** jj runs no git hooks — push is NEVER the gate; the gate is this step. The session re-runs the build-order **Verify** command on this PR's fixed tip AND asserts no recorded conflicts:

```bash
<the build-order Verify command>
jj log -r 'conflicts()'          # must be empty
```

The fixes are fresh code, and the new regression tests run inside Verify's scope — the fix proves itself.

if Verify fails → Build 3.2.5's loop: dispatch a fix agent off the fixed tip (fresh worktree, same contract) → collect the diff → finish → re-gate. **Bounded, then escalate** — never loop indefinitely; a repeating failure is a signal for the user, not something to paper over.

### 5.1.6 Push

Publish the verified tip — push only verified state (5.1.5 just certified it):

```bash
jj bookmark set <headRefName> -r @-
jj git push --bookmark <headRefName>
```

---

## 5.2 Spec delta + land (per PR)

Goal: `spec-writer` patches `.spec` for this PR's diff, then the PR is accepted and landed.

### 5.2.1 Spec delta

Dispatch `spec-writer` — the solo writer: it mutates the main tree but runs alone, so no worktree. It applies ADDED/MODIFIED/REMOVED hunks over **this PR's** diff, scoped (divided PRs touch disjoint code → disjoint spec sections), per `spec-format`.

if this is the sprint's **final unlanded PR** (every sibling `feat/sprint-v{N}(-<g>)` PR already landed — check the forge) → the **session** (not `spec-writer`) flips the `.sprint` plan `draft → built`. The flip is an annotation, never its own commit — it rides this PR's close-out commit (5.2.3) and lands with it: flip and fact become true together; a PR that never lands → neither lands.

### 5.2.2 Gate — approve `.spec` delta

The user approves this PR's **close-out doc bundle** — the `.spec` delta, plus the plan flip when this is the final PR. Everything 5.2.3 will commit is what's shown here. if the user wants edits → back to 5.2.1.

### 5.2.3 Finish + push the close-out bundle

One publication motion — deliberately fused so nothing intervenes between the 5.2.2 gate and publication (both ops stay named). The delta (+ flip) is already snapshotted in `@`:

```bash
jj describe -m "<docs commit per commit-format>"
jj new
jj bookmark set <headRefName> -r @-
jj git push --bookmark <headRefName>
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
jj git push --bookmark development
```

The bookmark move is forward-only — the FF; jj refuses a backward move. if the push rejects on a **stale lease** → that rejection IS the concurrency control: `jj git fetch` · re-rebase · retry. The PR then closes — its commits landed under fresh SHAs, change-ids preserved.

**Conflicted rebase → park, don't block — and NEVER auto-resolve:**

- apply the label + a details comment: `gh pr edit <number> --add-label conflict-parked` + `gh pr comment` listing the conflicting change-IDs · the files · the landed sprint it crosses · @both devs.
- suspend this PR's land and move on — everything else continues; other PRs proceed. Parked state is recomputable (both sides are published), so `jj undo` is equally valid to back the rebase out.
- resolution is a **paired human session** at the clone holding the conflict — not this skill: `jj edit <conflicted>` → fix the markers together (the snapshot amends **in place** — same message, same trailers) → descendants auto-rebase → re-verify the healed tip → resume the land (FF + push) → remove `conflict-parked`.

**Exception — a doc/spec overlap at the land rebase is NOT a park (5.2.1's rule).** Parking is for **code** conflicts only; a doc conflict is the spec-writer's remit: `jj edit` the conflicted close-out commit → re-dispatch `spec-writer` to reconcile the spec hunks. Name its **inputs** (the agent owns the *how*): this PR's `.spec` delta (the close-out hunks being landed) · the conflicting `.spec` delta already on `development@origin` (the landed sprint it crosses) · the **rebased tip** carrying the recorded conflict markers. It amends in place — message + trailers untouched → `jj new` back → assert `conflicts()` empty → continue the land (FF + push).

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

### 5.3.3 Sweep worktrees + bookmarks

Safety net — normally a no-op (Build 3.2.6 cleaned per wave, 5.1.4 per fix batch, 5.2.6 per PR):

- survivor worktrees + scratch branches under `.claude/worktrees/` → `git worktree unlock` → `git worktree remove --force` → `git branch -D`
- leftover PR bookmarks → `jj bookmark delete <name>` + `jj git push --deleted`

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
- **Serial per PR, parallel within a PR** — the single working copy is the work surface; parallelism lives only inside a PR's fix batch.
- **Session is the sole author** — fix agents and `spec-writer` are hands, not authors: diffs in, session-authored commits out; workers never commit, never run jj.
- **One atomic commit per finding** — `fix(scope): <finding>`; a testable fix + its regression test is one commit; fixes are never bundled.
- **Verify is a step, not a push side effect** — jj runs no git hooks; 5.1.5 is the explicit gate (Verify + `conflicts()` empty), and only then does 5.1.6 publish.
- **Gates on content, never vcs ops** — pick findings (5.1.2), approve the delta (5.2.2), accept the PR (5.2.4); every commit, push, and land follows autonomously.
- **The trunk only moves forward** — land = fetch → rebase → bookmark FF → lease push, per PR; a stale lease means fetch · re-rebase · retry; the flow never merges.
- **Flip rides the fact** — the `.sprint` `draft → built` flip is an annotation on the final PR's close-out commit, made by the session; 5.3.2 only confirms it, never commits.
- **Bookmark deletion is manual** — rebase-land never fires GitHub's auto-delete; 5.2.6 deletes local + remote.
- **Trust the artifact** — the latest `### Code Review` comment is the work order; never re-review, never re-score, never re-check Tickets/Build decisions.
- **No Haiku, ever** — Sonnet or Opus on every dispatch.
- **Ends at the trunk** — `development → main` promotion is out of scope; this skill spans no other phase.
