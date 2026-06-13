---
name: sprint-build
description: "Implements the sprint's tickets wave by wave — worktree-isolated implementers return diffs, the session finishes every commit in jj — then partitions the integration chain into divided PR chain(s), publishes, opens draft PRs, and retires the sprint's issues. Use when the user says 'start coding', 'implement this', 'build the tickets', or 'start building' — normally after /sprint-tickets has pinned a build-order; ticket numbers may be passed directly when no pin exists."
argument-hint: "Ticket numbers (e.g. '#203 #204') — only needed when no pinned build-order exists (degraded path)"
---

# /sprint-build — Build (Phase 3): waves → finish → partition → publish

**Goal: build the approved tickets and open the PR(s).** Implement the build-order's tickets wave by wave with worktree-isolated implementers, finish one atomic commit per ticket onto the integration chain, partition into the divided PR chain(s), publish, open draft PRs, retire the sprint's issues, and hand off to `/sprint-review`.

*Trust the artifact.* The pinned build-order issue from `/sprint-tickets` is the approved plan — `## Parallel Waves` · `## PR Grouping` · `## Scope` · `## Verify` are decided. Execute them as written: never recompute waves, never re-derive the grouping, never re-open the scope. Use the provision and Verify commands verbatim. Deviate only when faithful execution would actually break (a referenced issue, file, or symbol does not exist; two instructions directly contradict) — then stop and escalate. Never diverge silently.

Formats referenced as `<name>-format` live at `skills/sprint-build/formats/<name>.md`; prompts referenced as `<name>-prompt` at `skills/sprint-build/prompts/<name>.md` (under `${CLAUDE_PLUGIN_ROOT}`).

**No human gates in this phase.** Build runs autonomously from the build-order to the draft PRs; its gates are agent/verify checks, which ride inline (they are not their own named steps). Pause only to escalate.

**The session is the sole author of history** (*subagents are hands, not authors*). Implementers never commit and never run jj — they return diffs plus a suggested message. The session finishes every commit, owns every jj/gh motion, and writes no code itself.

**Initial request:** $ARGUMENTS

---

## 3.1 Phase setup

**Goal:** re-assert the chain position, check preconditions, find the build-order + read its tickets.

### 3.1.1 Re-assert the position

Identify the sprint from the latest `.sprint/sprint-v{N}.md` draft, then confirm `@` sits on the v{N} integration chain:

```bash
jj log -r '::@ & description(glob:"docs(plan)*")'
```

A match for the v{N} plan must exist in the ancestry.

- if no chain holds the `docs(plan)` commit → **stop** — the plan never crossed onto a chain (Plan 1.3.2 never ran): route back to `/sprint-plan`. Never silently cut a fresh chain.
- The working copy is shared mutable state — another session can move `@`. if foreign state sits in `@` → surface it, don't blind-switch over another session's work.

### 3.1.2 Check worktree preconditions

One-time repo facts, checked at point of need — Build breaks without them:

- **`worktree.baseRef: "head"`** (a Claude Code setting, `.claude/settings.json`) — colocated git `HEAD` = `@-`, so worker worktrees cut from the **last finished commit = the chain tip**, not `origin/HEAD`. Keep `@` **empty** at dispatch — the finish discipline (3.2.4's closing `jj new`) guarantees it.
- **`.claude/worktrees/` gitignored** — doubly load-bearing under jj: jj auto-snapshots every non-ignored path, so un-ignored worktrees would be swept into `@`.
- **Build-needed gitignored config (`.env`, secrets) listed in `.worktreeinclude`** (repo root, `.gitignore` syntax) — it copies gitignored matches into each worktree; tracked files are never duplicated.

if a precondition is missing → set it before any dispatch (one-time repo setup, not a deviation).

### 3.1.3 Find the build-order issue

Find the pinned build-order issue — **authoritative**: `## Parallel Waves` · `## PR Grouping` · `## Scope` · `## Verify` (the provision + Verify commands). Trust it; never recompute.

- if no pin → **degraded path**: identify the tickets from `$ARGUMENTS`, generate the order in-session, and **flag it** — the order normally exists; a missing pin is a signal, not routine.

### 3.1.4 Read the listed tickets

Read the full issue bodies the build-order references by `#`:

```bash
gh issue view <N> --json number,title,body,labels
```

Objective, requirements, AC, `.spec`/`.adr` pointers — the raw material for the implementer briefs (3.2.1).

---

## 3.2 Execute — the wave loop

**Goal:** implement the tickets wave by wave, verified. **Loop 3.2.1–3.2.7 per wave until all waves are built, then → 3.3.**

| Step | Act | Output |
|---|---|---|
| 3.2.1 | prepare one `implementer-prompt` brief per ticket | dispatch briefs |
| 3.2.2 | dispatch implementers, `isolation: worktree` | one worktree per ticket, cut off the integration tip |
| 3.2.3 | barrier — collect diffs + statuses | diffs to author |
| 3.2.4 | finish one atomic commit per ticket, in build-order | the chain grows |
| 3.2.5 | the gate — Verify + spec-review + `conflicts()` empty | certified wave tip |
| 3.2.6 | remove the wave's worktrees | clean `.claude/worktrees/` |
| 3.2.7 | no push — loop or finalize | waves remain → 3.2.1 · done → 3.3 |

### 3.2.1 Prepare dispatch prompts

Write each implementer's brief from `implementer-prompt` — *direction from the session, discretion to the agent*: inject only the cheap context the session already holds; the agent expands it at its own discretion. The session hands in:

- the **full ticket body** (3.1.4)
- the ticket's **`.spec` slice** (from `.spec/spec.md` — skip if absent)
- the governing **`.adr` Y-statement** (skip if absent or the ticket names no ADR)
- the **coding-standards pointer** (if installed)
- the build-order's **provision + Verify commands**, verbatim

The prompt owns the worktree contract — reference it, never restate it. The invariants the session relies on: the worker never commits and never runs jj; it runs provision before Verify; it self-verifies to green; it returns its diff + a suggested message and reports status.

### 3.2.2 Dispatch implementers (worktree-isolated)

Dispatch one `implementer` per ticket in the wave — a **general-purpose subagent briefed with `implementer-prompt`** (no agent file exists) — with **`isolation: worktree`**, fanning the wave's independent tickets out in one parallel batch. Every dispatch runs on a capable tier (Sonnet or Opus, never Haiku).

- The harness cuts each linked worktree off the **integration tip** — the 3.1.2 `baseRef` precondition makes the last finished commit the cut point. Note that commit: it is the **wave base** (3.2.4's overlap path authors on it).
- Dispatch the wave **as written** in `## Parallel Waves` — a hard-dep wave, nothing to recompute. Each implementer writes its own tree → no clobber.

### 3.2.3 Collect & triage results

Wait for the wave (barrier); collect each implementer's **diff + status** — the worktree's changes; there is no branch to collect.

- if `NEEDS_CONTEXT` / `BLOCKED` → re-dispatch with the gap filled — **bounded, then escalate** (3.2.5's pattern).
- A failed / blocked / verify-fail implementer's diff is **never authored** — discard its worktree (3.2.6 mechanics) and drop its scratch branch.

### 3.2.4 Finish the wave's commits

The session finishes **one atomic commit per ticket, in build-order** — the sole committer.

**Happy path** — per ticket:

```bash
git apply --3way <ticket-diff>   # absorbs plain file overlap
jj describe -m "<message>"       # worker-suggested, session-owned, + trailers — commit-format
jj new                           # open the next; leaves @ empty for the next finish
```

The applied edits auto-snapshot into `@` on the next jj command; `jj describe` names the commit per `commit-format` (conventional message + trailers). One ticket = one commit.

**Same-line overlap (rare)** — the apply rejects:

1. Author that ticket on the **wave base**: `jj new <wave-base>` → clean apply → finish.
2. `jj rebase -r <it> -o <chain tip>` — the conflict is **recorded, not a halt**.
3. `jj edit` the conflicted commit; dispatch a **fix-agent** (an implementer dispatch — `implementer-prompt`, solo-heal variant: edits the main tree in place — no worktree, no provision, no returned diff; fix the markers only). The snapshot amends **in place** — message + trailers untouched; the session writes no code (*hands-not-authors*).
4. `jj new` back to the chain tip.
5. **Bounded, then escalate.** Log the overlap as a **coupling signal** — it feeds decomposition.

**Dep-change ticket** — exclude the lockfile hunks from the apply; apply the manifest, then **regenerate** the lockfile with the repo-matched tool — never line-merge a lockfile:

```bash
npm install --package-lock-only   # · pnpm install · cargo generate-lockfile · …
```

### 3.2.5 Post-integration verify — the gate

The independent, un-gameable gate — agent checks, riding inline rather than as their own named steps:

1. **Verify** — re-run the build-order's Verify command on the **integration tip**. The writers can't touch the command — this catches gamed self-verifies and semantic integration breakage (applies clean, breaks on build).
2. **Spec-review** — per built ticket, dispatch a read-only reviewer with `spec-review-prompt`, handing in the ticket body (its AC) + its `.spec` slice + the ticket's finished commit; one parallel batch. It judges: built *what was asked*, not just "passes". if no `.spec` → the reviewer judges against the ticket's AC alone.
3. **No recorded conflicts remain** on the chain — empty over the sprint range:

```bash
jj log -r 'conflicts() & (development@origin..@)'
```

Branches:

- if **Verify fails** → dispatch a **fix-agent** in a fresh worktree off the integration tip (it sees the whole wave; `implementer-prompt` applies in full — provision, self-verify, return diff) → the session finishes its diff (3.2.4 mechanics) → re-gate. **Bounded, then escalate** — a structural failure is a signal, not papered over.
- if **spec-review fails** → **escalate, never auto-fix** — built-the-wrong-thing is a ticket/decomposition signal; an agent guessing the intended behaviour compounds the miss.
- PASS (all three) → 3.2.6.

### 3.2.6 Remove the wave's worktrees

After the gate passes — per worktree under `.claude/worktrees/` (the 3.1.2 location):

```bash
git worktree unlock <path>           # harness worktrees are LOCKED — a plain remove is refused
git worktree remove --force <path>
git branch -D <scratch-branch>       # diffs were collected, nothing rides on them; clears the imported jj bookmarks
```

Removal is **explicit** — a worktree holding changes is not auto-removed; `cleanupPeriodDays` only sweeps unchanged ones. Never push the workers' transient `worktree-*` branches.

### 3.2.7 Loop or finalize

**No per-wave push** — durability is local; the integration chain accumulates commits in place. The first push is publication (3.4.1).

- if waves remain → next wave (3.2.1)
- else → 3.3

---

## 3.3 Finalize

**Goal:** partition into the divided PR chain(s) from the verified integration tip.

### 3.3.1 Partition into PR chain(s)

From the build-order's `## PR Grouping` (coupling + dependency-closed — decided at Tickets 2.5.3, trust it):

**One group → no surgery.** The integration chain *is* the PR chain → 3.4.

**N groups → partition.** Per group, its commits in wave order:

```bash
jj duplicate <group-revs> -o development@origin
```

- A **clean duplicate self-validates dependency-closure**. if a duplicate records a conflict → the group wasn't dependency-closed → **flag, don't force** — never resolve it into existence.
- Once all groups cut clean → `jj abandon` the original chain's head — consumed by the duplicates (nothing lost; keeps `jj log` honest).
- Then run the build-order **Verify on each duplicated tip** — a clean duplicate proves only *textual* independence; a group can apply clean and **break standalone** (3.2.5 gated only the combined tip). if a tip fails → flag the grouping (a Tickets 2.5.3 signal), **don't push**.

---

## 3.4 Phase close

**Goal:** publish the chain(s), open the PR(s), retire the forge objects, hand off to review.

### 3.4.1 Name + push the chain(s)

**Publication** — per PR chain:

```bash
jj git push --named feat/sprint-v{N}(-<g>)=<tip>
```

`<g>` = the group's slug from `## PR Grouping` — deterministic, two runs name alike; one group → no `-<g>`. The name exists only from here, and nothing was pushed before — durability was local. **jj runs no git hooks** — the gates already ran (3.2.5 on the combined tip; 3.3.1 per divided tip); push is transport, not a gate.

### 3.4.2 Create the PR(s)

One **draft** PR per PR chain, body per `pr-format`:

```bash
gh pr create --draft --base development --head feat/sprint-v{N}(-<g>) --label needs-review --title "..." --body-file <pr-body>
```

**Draft blocks the UI merge buttons** — the machine guard against the catastrophic accident: a squash-merge click collapsing the atomic chain. Review lifts draft at 4.1.3. `needs-review` is the flow state; draft is the machine guard — apply both.

### 3.4.3 Retire the sprint's issues

**Closed = built.** Tickets are Build's work orders, as review comments are Refine's; acceptance + completion live on the PR — the link in each closed issue carries the trail (an abandoned PR → reopen by hand, exceptional).

```bash
gh issue close <N> --comment "Built in <PR URL>"
gh issue unpin <build-order-N>
gh issue close <build-order-N> --comment "Build complete. PR(s): <URLs>"
```

- Close every **built** ticket issue with its PR link.
- Unpin + close the build-order issue with the PR link(s) — the pin slot comes back (Tickets 2.5.7).

### 3.4.4 Handoff

Summarise what was built — the PR URL(s) + their groups — and what wasn't: **unbuilt/descoped tickets simply stay open** — the open issue is the durable not-built record (Refine 5.3.1 reads it). Recommend running `/sprint-review` in a **fresh session** — the PR(s) + `needs-review` carry the handoff state.

---

## Key principles

- **Orchestrate, never implement** — every code write is a dispatched subagent (implementers, fix-agents); the session authors history, not code (*subagents are hands, not authors*).
- **The session finishes every commit** — apply → `jj describe` → `jj new`; one atomic commit per ticket, in build-order. Workers never commit, never run jj — they return diffs; there is no worker branch to merge or cherry-pick.
- **Trust the build-order** (*trust the artifact*) — waves, grouping, scope, provision, Verify are decided upstream; never recompute. if faithful execution would actually break → stop and escalate; never diverge silently.
- **Conflicts record, never halt** (*the integration point never freezes*) — a recorded conflict is data on a commit; heal in place with `jj edit` + a fix-agent; message + trailers are never in play.
- **Push is publication** — not durability (local commits carry that) and not a gate (jj runs no git hooks; the gates are explicit verify steps). Nothing pushes before 3.4.1; push only verified, finished state.
- **Provision unconditionally** — a fresh worktree is write-isolated, not build-isolated.
- **Bounded, then escalate** — re-dispatch with the gap filled, a few rounds at most; a repeating failure is a signal. Spec-review failure escalates immediately — never auto-fix.
- **Capability over cost** — every dispatch runs on a capable tier: Sonnet or Opus, never Haiku.
- **Stay in phase** — `/sprint-tickets` produced the build-order; `/sprint-review` consumes the PRs. Hand off at the boundaries; never execute their work.
