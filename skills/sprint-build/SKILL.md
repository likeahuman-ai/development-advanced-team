---
name: sprint-build
description: "Implements the sprint's tickets wave by wave — worktree-isolated implementers write files and self-verify, the session snapshots each workspace and folds one atomic commit per ticket in jj — then partitions the integration chain into divided PR chain(s), publishes, opens draft PRs, and retires the sprint's issues. Use when the user says 'start coding', 'implement this', 'build the tickets', or 'start building' — normally after /sprint-tickets has pinned a build-order; ticket numbers may be passed directly when no pin exists."
argument-hint: "Ticket numbers (e.g. '#203 #204') — only needed when no pinned build-order exists (degraded path)"
---

# /sprint-build — Build (Phase 3): waves → finish → partition → publish

**Goal: build the approved tickets and open the PR(s).** Implement the build-order's tickets wave by wave with worktree-isolated implementers, finish one atomic commit per ticket onto the integration chain, partition into the divided PR chain(s), publish, open draft PRs, retire the sprint's issues, and hand off to `/sprint-review`.

*Trust the artifact.* The pinned build-order issue from `/sprint-tickets` is the approved plan — `## Parallel Waves` · `## PR Grouping` · `## Scope` · `## Verify` are decided. Execute them as written: never recompute waves, never re-derive the grouping, never re-open the scope. Use the provision and Verify commands verbatim. Deviate only when faithful execution would actually break (a referenced issue, file, or symbol does not exist; two instructions directly contradict) — then stop and escalate. Never diverge silently.

Formats referenced as `<name>-format` live at `skills/sprint-build/formats/<name>-format.md`; prompts referenced as `<name>-prompt` at `skills/sprint-build/prompts/<name>-prompt.md` (under `${CLAUDE_PLUGIN_ROOT}`) — the filename keeps the `-format`/`-prompt` suffix.

**No human gates in this phase.** Build runs autonomously from the build-order to the draft PRs; its gates are agent/verify checks, which ride inline (they are not their own named steps). Pause only to escalate.

**The session is the sole author of history** (*subagents are hands, not authors*). Implementers never commit and never run git or jj — they write files, self-verify, and return their status, a summary, and their working directory. The session snapshots each workspace, finishes every commit, owns every jj/gh motion, and writes no code itself.

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

- **The plugin's worktree hooks are active** (`hooks/hooks.json` → `scripts/jj-worktree-{create,remove}.sh`, auto-loaded on install). They make subagent `isolation: worktree` jj-safe: on a jj repo **create** makes a `jj workspace` based on the chain tip (`@-`) instead of a git worktree, and **teardown** is `jj workspace forget` — no `git branch -D`, no `jj git import`, so the anonymous sprint chain is never re-based onto the trunk seed or orphaned (ADR-013). On a non-jj repo the hooks fall through to the default `git worktree add`/`remove`. Keep `@` **empty** at dispatch — the finish discipline (3.2.4's closing `jj new`) guarantees `@-` is the last finished commit, which is what the create hook bases each worker on. (Claude Code's own `worktree.baseRef` is not consulted on the jj path — the hook owns basing.)
- **`.claude/worktrees/` gitignored in the *committed* `.gitignore`** — doubly load-bearing under jj: jj auto-snapshots every non-ignored path, so un-ignored workspaces would be swept into `@`. Plan 1.0.2 writes this at bootstrap; if it's absent here (or sits only in machine-local `.git/info/exclude`), add it to the **committed** `.gitignore` so isolation is reproducible on a fresh clone, not rediscovered + re-verified each Build.
- **Build-needed gitignored config (`.env`, secrets) listed in `.worktreeinclude`** (repo root, `.gitignore` syntax) — a jj workspace, like a git worktree, checks out only *tracked* files, so the create hook copies `.worktreeinclude` matches into each worker tree; tracked files are never duplicated.

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
| 3.2.2 | dispatch implementers, `isolation: worktree` | one jj workspace per ticket, based on the integration tip |
| 3.2.3 | barrier — collect statuses; snapshot each workspace | worker files captured in `<name>@` |
| 3.2.4 | finish one atomic commit per ticket (describe + fold), in build-order | the chain grows |
| 3.2.5 | the gate — Verify + spec-review + `conflicts()` empty | certified wave tip |
| 3.2.6 | forget the wave's workspaces + assert chain integrity | clean tree, chain intact |
| 3.2.7 | no push — loop or finalize | waves remain → 3.2.1 · done → 3.3 |

### 3.2.1 Prepare dispatch prompts

Write each implementer's brief from `implementer-prompt` — *direction from the session, discretion to the agent*: inject only the cheap context the session already holds; the agent expands it at its own discretion. The session hands in:

- the **full ticket body** (3.1.4)
- the ticket's **`.spec` slice** (from `.spec/spec.md` — skip if absent)
- the governing **`.adr` Y-statement** (skip if absent or the ticket names no ADR)
- the **coding-standards pointer** (if installed)
- the build-order's **provision + Verify commands**, verbatim

The prompt owns the worktree contract — reference it, never restate it. The invariants the session relies on: the worker never runs git or jj (its tree is a jj workspace — git there silently hits the *main* repo); it runs provision before Verify; it self-verifies to green; and it returns its **status + summary + working directory** — no diff, because the session collects by folding the workspace (3.2.3–3.2.4).

### 3.2.2 Dispatch implementers (worktree-isolated)

Dispatch one `implementer` per ticket in the wave — a **general-purpose subagent briefed with `implementer-prompt`** (no agent file exists) — with **`isolation: worktree`**, fanning the wave's independent tickets out in one parallel batch. Every dispatch resolves a **pinned capable tier from the ticket's size** (`S`/`M` → sonnet, `L` → opus — Sonnet or Opus, never Haiku; no inherit, no contingent path) and records the resolved model: the commit's `Assisted-by:` trailer (3.2.4 / `commit-format`) IS the per-dispatch tier record, so every implementer commit shows the Capable tier it ran on — none a silent inherit.

- The plugin's WorktreeCreate hook bases each worker's `jj workspace` on the **integration tip** (`@-` — the last finished commit; see 3.1.2). Note that commit: it is the **wave base** — every worker in the wave is parented on it, and 3.2.4 folds them into a linear chain on top of it.
- Dispatch the wave **as written** in `## Parallel Waves` — a hard-dep wave, nothing to recompute. Each implementer writes its own workspace → no clobber.

### 3.2.3 Collect results & snapshot the workspaces

Wait for the wave (barrier); collect each implementer's **status + summary + working directory**. There is no diff and no branch — the changes live on disk in each worker's `jj workspace`.

jj only records a workspace's on-disk edits when a jj command runs **inside that workspace**, so for each `SUCCESS` worker the session **snapshots** its tree — materialising the worker's files into that workspace's commit (`<name>@`, where `<name>` is the workspace = `basename` of the reported working directory):

```bash
( cd "<worker-working-dir>" && jj status >/dev/null )   # snapshots edits into <name>@
```

- if `NEEDS_CONTEXT` / `BLOCKED` → re-dispatch with the gap filled — **bounded, then escalate** (3.2.5's pattern).
- A failed / blocked / verify-fail worker is **never snapshotted or folded** — its workspace is discarded at 3.2.6 (an unsnapshotted `<name>@` is empty and drops on forget).

### 3.2.4 Finish the wave's commits

The session finishes **one atomic commit per ticket, in build-order** — the sole author. Each snapshotted workspace commit (`<name>@`, from 3.2.3) already sits on the wave base; the session names it and folds the wave into a linear chain. No textual patch, no `git apply` — the worker's changes are already a jj commit; the session only describes and re-parents it.

**Happy path** — per ticket, in build-order:

```bash
jj describe '<name>@' -m "<message>"     # worker-suggested subject, session-owned, + trailers — commit-format
jj rebase -r '<name>@' -d '<prev-tip>'   # fold onto the previous ticket's commit
```

`<prev-tip>` is the wave base for the first ticket — which is **already its parent, so skip its rebase** — and each just-finished ticket's commit for every one after, so the wave lands as a linear, one-commit-per-ticket chain in build-order. After the last ticket:

```bash
jj new '<last-tip>'   # open the next; leaves @ empty on the new chain tip for the next finish
```

**Same-line overlap (rare)** — folding a ticket whose change touches the same lines as an earlier one makes the `jj rebase` **record a conflict** (it does not halt — *the integration point never freezes*):

1. `jj log -r 'conflicts() & (development@origin..@)'` shows the conflicted commit.
2. `jj edit '<conflicted>@'`; dispatch a **fix-agent** (an `implementer-prompt` solo-heal dispatch: resolve the conflict markers in place on the main tree — no workspace, no provision, no returned diff; fix the markers only).
3. `jj status` snapshots the resolution — the commit amends **in place**, message + trailers untouched; the session writes no code (*hands-not-authors*).
4. Resume folding the remaining tickets onto the healed commit; the closing `jj new '<last-tip>'` happens once, after the last ticket.
5. **Bounded, then escalate.** Log the overlap as a **coupling signal** — it feeds decomposition.

**Dep-change ticket** — needs no special handling: the worker ran provision **inside its workspace** (per its brief), so a regenerated lockfile is already part of the files snapshotted into `<name>@` and folds like any other change. Never line-merge a lockfile.

### 3.2.5 Post-integration verify — the gate

The independent, un-gameable gate — agent checks, riding inline rather than as their own named steps:

1. **Verify** — re-run the build-order's Verify command on the **integration tip**. The writers can't touch the command — this catches gamed self-verifies and semantic integration breakage (applies clean, breaks on build).
2. **Spec-review** — per built ticket, dispatch a read-only reviewer with `spec-review-prompt`, handing in the ticket body (its AC) + its `.spec` slice + the ticket's finished commit; one parallel batch. It judges: built *what was asked*, not just "passes". if no `.spec` → the reviewer judges against the ticket's AC alone.
3. **No recorded conflicts remain** on the chain — empty over the sprint range:

```bash
jj log -r 'conflicts() & (development@origin..@)'
```

Branches:

- if **Verify fails** → dispatch a **fix-agent** in a fresh workspace off the integration tip (it sees the whole wave; `implementer-prompt` applies in full — provision, self-verify, report status) → the session snapshots + folds it (3.2.3–3.2.4 mechanics) → re-gate. **Bounded, then escalate** — a structural failure is a signal, not papered over.
- if **spec-review fails** → **escalate, never auto-fix** — built-the-wrong-thing is a ticket/decomposition signal; an agent guessing the intended behaviour compounds the miss.
- PASS (all three) → 3.2.6.

### 3.2.6 Forget the wave's workspaces + assert chain integrity

After the gate passes — per workspace under `.claude/worktrees/` (the 3.1.2 location). The plugin's WorktreeRemove hook does this at subagent teardown, but Claude Code may skip that hook (claude-code#37611), so the session runs it **explicitly** as the load-bearing cleanup — idempotent either way:

```bash
jj workspace forget <name>           # drops tracking; a folded ticket's commit (3.2.4) is left untouched
rm -rf <path>                        # remove the workspace directory
```

A `SUCCESS` worker's commit was folded into the chain (3.2.4), so forgetting its workspace leaves that commit in place; a discarded/blocked worker's `<name>@` was never snapshotted, so it is empty and drops on forget. If a non-empty straggler survives — `jj log -r '(development@origin..) ~ ::@'` shows it — abandon that specific revision (`jj abandon -r <change-id>`) or escalate; never blanket-abandon.

**Post-cleanup chain-integrity assert.** Confirm the founding `docs(brief)`/`docs(plan)` commits and every prior wave's commit still sit on the chain with correct parents — none orphaned or re-based onto the trunk seed:

```bash
jj log -r '::@'                                      # founding docs + every finished ticket present, in build-order
jj log -r 'conflicts() & (development@origin..@)'    # empty — no recorded conflict survived the wave
```

if a founding or prior-wave commit is missing, re-parented onto the seed, or orphaned → **STOP and escalate**: isolation corrupted the chain (a regression — never rationalise it as intact). On a healthy run the chain reads trunk tip → all finished tickets → the empty `@`.

### 3.2.7 Loop or finalize

**No per-wave push** — durability is local; the integration chain accumulates commits in place. The first push is publication (3.4.1).

- if waves remain → next wave (3.2.1)
- else → 3.3

---

## 3.3 Finalize

**Goal:** partition into the divided PR chain(s) from the verified integration tip.

### 3.3.1 Partition into PR chain(s)

From the build-order's `## PR Grouping` (coupling + dependency-closed — decided at Tickets 2.5.3, trust it). Each group is marked **peer** (depends only on what's already on `development`) or **stacked** (hard-depends on a prior group *in this sprint*) — read that mark, never recompute it.

**One group → no surgery.** The integration chain *is* the PR chain → 3.4.

**>1 group → reorder to group-coherent first (ADR-015).** Build integrated **by wave** (3.2), so the chain is wave-ordered and a group's commits are **interleaved** with other groups' — non-contiguous. Naming a stacked group's tip on that chain (or duplicating a peer's scattered revs) bleeds other groups' diffs into the PR. So before any peer/stacked mechanics, **gather each group into a contiguous block**, groups in **base→dependent order** (a stacked group after the group it depends on; peers in any stable order):

```bash
jj rebase -r <group-revs> -d <prior-group-tip | development@origin>   # per group, base→dependent order
```

Dependency-safe — groups are dependency-closed, so base→dependent group order is a valid topological order; no hard dep is violated. It rewrites only **unpushed** commits (nothing was pushed before 3.4.1): subjects, trailers, and change-ids are preserved (it's `jj rebase`, never squash) — the end-state invariant is untouched, and `docs(plan)` rides the first group. if the reorder records a conflict → Build 3.2.4's heal-in-place (`jj edit` → fix-agent → snapshot amends, message/trailers intact), never a force-merge. The chain is now contiguous group blocks in dependency order — peer/stacked mechanics below run on *that*.

**Peer groups → duplicate** (each is independently based on `development`). Per peer group, its now-contiguous commits:

```bash
jj duplicate <group-revs> -o development@origin
```

- A **clean duplicate self-validates peer independence**. if a *peer* duplicate records a conflict → the group wasn't dependency-closed → **flag, don't force** — never resolve it into existence.
- Once the peer groups cut clean → `jj abandon` the original chain's head **only if no stacked group still rides it** (consumed by the duplicates; keeps `jj log` honest).

**Stacked groups → keep the chain, never duplicate (ADR-014).** A stacked group depends on a prior group *still in this sprint*, so it does **not** rebase onto bare `development` — duplicating it there records a conflict *because of the real dependency, not a closure gap*. **Do not misread that as un-closed and refuse to publish** (the old peer-only failure mode). Leave the now group-coherent chain (reordered above) intact: note each group's tip and its base — the first group's base is `development` (it carries `docs(plan)`), each later group's base is the prior group's tip (clean because the reorder made each group's commits contiguous — its tip no longer rides another group's diffs). The names are created at push (3.4.1); a mixed sprint duplicates its peers and leaves its stack in place.

**Per-group standalone Verify.** Run the build-order Verify on each group's tip — a peer's duplicated tip, or a stacked group's tip *on the chain* (which includes its base groups — the state it is reviewed in). A clean cut proves only *textual* independence; a group can apply clean and **break standalone** (3.2.5 gated only the combined tip). if a tip fails → flag the grouping (a Tickets 2.5.3 signal), **don't push**.

---

## 3.4 Phase close

**Goal:** publish the chain(s), open the PR(s), retire the forge objects, hand off to review.

### 3.4.1 Name + push the chain(s)

**Publication** — per PR chain, in build-order (a stack's base group first):

```bash
jj git push --named feat/sprint-v{N}(-<g>)=<tip>   # jj 0.42: --named auto-creates the bookmark; never --allow-new (not a valid flag)
```

`<tip>` is the group's tip — a **peer**'s duplicated tip (3.3.1) or a **stacked** group's tip on the verified chain. `<g>` = the group's slug from `## PR Grouping` — deterministic, two runs name alike; one group → no `-<g>`. The name exists only from here, and nothing was pushed before — durability was local. For a stack, pushing the base tip and each later group's tip publishes **one linear history under several refs** — no duplication, no force (each is a fresh named bookmark). **jj runs no git hooks** — the gates already ran (3.2.5 on the combined tip; 3.3.1 per divided/stacked tip); push is transport, not a gate.

### 3.4.2 Create the PR(s)

One **draft** PR per PR chain, body per `pr-format`. The `--base` follows the group's mark (3.3.1):

```bash
# peer group, or a stack's base group → based on development
gh pr create --draft --base development --head feat/sprint-v{N}(-<g>) --label needs-review --title "..." --body-file <pr-body>
# a stack's dependent group → based on the prior group's branch
gh pr create --draft --base feat/sprint-v{N}-<prior-g> --head feat/sprint-v{N}-<g> --label needs-review --title "..." --body-file <pr-body>
```

A stacked PR's `--base` is the prior group's branch — so GitHub diffs it against that base, showing only the dependent group's delta, and Refine lands the stacked chain base-first (5.x). **Draft blocks the UI merge buttons** — the machine guard against the catastrophic accident: a squash-merge click collapsing the atomic chain. Review lifts draft at 4.1.3. `needs-review` is the flow state; draft is the machine guard — apply both.

### 3.4.3 Retire the sprint's issues

**Closed = built.** Tickets are Build's work orders, as review comments are Refine's; acceptance + completion live on the PR — the link in each closed issue carries the trail (an abandoned PR → reopen by hand, exceptional).

```bash
gh issue close <N> --comment "Built in <PR URL>"
gh issue unpin <build-order-N>
gh issue close <build-order-N> --comment "Build complete. PR(s): <URLs>"
gh issue close <epic-N> --comment "Epic complete — all child tickets built."   # ONLY epics whose children are ALL now closed
```

- Close every **built** ticket issue with its PR link.
- Unpin + close the build-order issue with the PR link(s) — the pin slot comes back (Tickets 2.5.7).
- **Close completed epics.** After the ticket + build-order closes, close each `[Epic]` issue whose child tickets (the issues threaded `Part of #<epic>`, Tickets 2.4.4) are **all** now closed — *close-when-last-child-closes*, so an epic spanning sprints with unbuilt children stays open. Without this, shipped epics linger open forever and `gh issue list --state open` stops reflecting work actually in progress.

### 3.4.4 Handoff

Summarise what was built — the PR URL(s) + their groups — and what wasn't: **unbuilt/descoped tickets simply stay open** — the open issue is the durable not-built record (Refine 5.3.1 reads it). Recommend running `/sprint-review` in a **fresh session** — the PR(s) + `needs-review` carry the handoff state.

---

## Key principles

- **Orchestrate, never implement** — every code write is a dispatched subagent (implementers, fix-agents); the session authors history, not code (*subagents are hands, not authors*).
- **The session finishes every commit** — snapshot the workspace (`jj status` inside it) → `jj describe '<name>@'` → `jj rebase` onto the prior tip → `jj new`; one atomic commit per ticket, in build-order. Workers never run git or jj and return no diff — collection is the session's jj-fold of each workspace; there is no worker branch or patch to merge.
- **Trust the build-order** (*trust the artifact*) — waves, grouping, scope, provision, Verify are decided upstream; never recompute. if faithful execution would actually break → stop and escalate; never diverge silently.
- **Conflicts record, never halt** (*the integration point never freezes*) — a recorded conflict is data on a commit; heal in place with `jj edit` + a fix-agent; message + trailers are never in play.
- **Push is publication** — not durability (local commits carry that) and not a gate (jj runs no git hooks; the gates are explicit verify steps). Nothing pushes before 3.4.1; push only verified, finished state.
- **Provision unconditionally** — a fresh workspace is write-isolated, not build-isolated; it ships no project dependencies.
- **Bounded, then escalate** — re-dispatch with the gap filled, a few rounds at most; a repeating failure is a signal. Spec-review failure escalates immediately — never auto-fix.
- **Capability over cost** — every dispatch runs on a capable tier: Sonnet or Opus, never Haiku.
- **Stay in phase** — `/sprint-tickets` produced the build-order; `/sprint-review` consumes the PRs. Hand off at the boundaries; never execute their work.
