---
name: sprint-plan
description: "Create a Sprint Plan, capture ADRs, and write or update the living Brief and Stories through guided discovery, codebase exploration, and architecture discussion. Use when user has an idea for what to build, says 'I want to build', 'let's plan', 'I have a project idea', wants to start a new sprint, or wants to resume an unfinished sprint plan."
argument-hint: "Brief description of what to build (optional)"
---

# /sprint-plan — Intent to an Approved Sprint Plan

Phase 1 of the flow: turn intent into an approved, committed `.sprint` plan (+ `.brief`/`.stories`/`.adr`). Drive the sub-phases in order — 1.0 Sprint setup → 1.1 Discovery → 1.2 Author → 1.3 Phase close. Three human gates, all on **content acceptance** (1.1.3 discovery summary · 1.2.5 ADR fidelity · 1.3.1 the plan); a gate approves an artifact's content, never a vcs op — the commit/push that publishes it follows autonomously. Never gate a commit or a push.

Four artifacts, separated by rate of change:

- `.brief` — the living product charter; slowest-changing, written once, edited scarcely (`brief-format`)
- `.stories` — the living set of wants, `US-###` IDs (`stories-format`)
- `.adr` — the append-only decision log, `ADR-###` (`adr-format`)
- `.sprint/sprint-v{N}.md` — this sprint's versioned objective, the primary write target (`sprint-format`)

`.spec` is read-only here — it is a claim about code, patched by Refine (5.2.1), never by this skill.

This skill's formats (`brief-format` · `stories-format` · `adr-format` · `sprint-format`) live at `${CLAUDE_PLUGIN_ROOT}/skills/sprint-plan/formats/<name>-format.md`; dispatch prompts at `${CLAUDE_PLUGIN_ROOT}/skills/sprint-plan/prompts/<name>-prompt.md` — the filename keeps the `-format`/`-prompt` suffix. `commit-format` is owned by Build: `${CLAUDE_PLUGIN_ROOT}/skills/sprint-build/formats/commit-format.md`.

Boundaries that hold for the whole phase:

- **All vcs through jj.** The session never runs raw git for flow ops; `gh` drives the forge through Bash — on-demand CLIs, never MCP servers (an MCP server front-loads its whole tool catalogue and rots context).
- **No push anywhere in this phase** (1.3.3). Plan is local-only; publication (name + push) is Build-close (3.4.1). Sole exemption: 1.0.2's bootstrap scaffolding (repo create · trunk seed · protection) — scaffolding, not flow history.
- **The chain stays anonymous.** No branch name exists at Plan — jj-native; the name `feat/sprint-v{N}` arrives at publication (Build 3.4.1).
- **Every dispatch runs on a capable tier** — Sonnet or Opus, never Haiku (a misread at a gate or cull corrupts everything downstream).
- **Commits carry `Assisted-by: <agent> <model>`** — never `Co-Authored-By:` (a model can't hold copyright).
- **Dispatch, don't do.** The big exploration belongs to `codebase-explorer` agents; the session steers the conversation, gates the content, and finishes the commits.

**Initial request:** $ARGUMENTS

## Preflight

Before anything else, verify the two tools the phase rests on:

- `jj --version` — present and ≥ 0.42; missing or older → **stop** with install guidance (`brew install jj` on macOS, or the Jujutsu install docs), re-run once installed
- `gh auth status` — authenticated; not → **stop**: `gh auth login`, then re-run

---

## 1.0 Sprint setup

**Goal:** ready the workspace, repo, and plan version.

### 1.0.1 List existing context

List what exists — **no reads**:

- file artifacts — which of `.brief` / `.stories` / `.spec` / `.adr` / `.sprint` exist
- repo — git? colocated jj (`.jj` present)? remote?
- → greenfield or existing project

Existence only — content (versions, statuses, history) is read fresh by the step that needs it (`.sprint` statuses → 1.0.3).

### 1.0.2 Prepare workspace

Bootstrap on first contact — one homogeneous bundle (same kind of acts, each act visible), each a no-op when already done:

- if no repo, or git-only → `jj git init --colocate`
- configure jj:
  - identity if unset (one-time per machine — jj doesn't read `.gitconfig`): `jj config set --user user.name "<name>"` · `jj config set --user user.email "<email>"`
  - the append-only guard — history is append-only at the trunk; this is the client-side half (the forge protection at 1.0.2 is the server-side half):
    ```bash
    jj config set --repo 'revset-aliases."immutable_heads()"' 'builtin_immutable_heads() | present(development@origin)'
    ```
- if no remote → `gh repo create <owner>/<repo> --private --source=. --remote=origin` (provisional bootstrap)
- if no `development` anywhere (greenfield) → **seed the trunk** (jj 0.42):
  ```bash
  jj new 'root()'                                  # quote root() — bare () is a shell syntax error
  jj describe -m "chore: seed development"
  jj bookmark create development -r @
  jj git push --bookmark development               # --bookmark auto-tracks a new bookmark in jj 0.42; no --allow-new
  ```
  Bootstrap scaffolding, exempt from the no-push doctrine (like `gh repo create` itself) — 1.0.4/1.0.5 need the trunk to exist.
- protect `development` — **require linear history + block force pushes**, never "require a pull request" (Refine 5.2.5 pushes the trunk directly); applies once the trunk exists:
  ```bash
  echo '{"required_linear_history":true,"allow_force_pushes":false,"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":null,"restrictions":null}' \
    | gh api -X PUT "repos/{owner}/{repo}/branches/development/protection" --input -
  ```
  if it fails (plan limits on private repos, insufficient token scopes) → warn the user it must be set by hand, record nothing, continue — the client-side jj guard above still holds
- create missing folders — `.sprint` / `.adr` / `.stories`, + `.brief` when none exists

### 1.0.3 Enforce the `.sprint` lifecycle

Read the existing plans (`.sprint/sprint-v{N}.md` — `status` frontmatter), then decide, **in this order**:

1. **A surviving draft** — a `draft` whose sprint is genuinely unfinished → **resume it**: keep its version number, no new version, no cascade — skip straight onward.
2. **Explicit override only** — the user explicitly asks to drop a surviving draft → warn first, then flip it to `abandoned` and fall through to 3. Never abandon on your own initiative.
3. **Otherwise** — set the next `v{N}`; **cascade** — archive everything older on the new draft; **backstop** — a previous draft whose PRs all landed but still reads `draft` is an irregular close (the flip normally rode its own sprint's close-out commit, Refine 5.2.1) → forge-verify via `gh`: every PR with head `feat/sprint-v{M}` or `feat/sprint-v{M}-*` (divided chains) is closed *because landed* — its commits reachable from `development@origin`; an abandoned PR also reads closed and doesn't count → flip `draft → built` here.

Hold the one-draft rule — at most one `status: draft` in `.sprint/` at any time. Status edits are **annotations, not changes** — they ride 1.3.2's `docs(plan)` bundle, never their own commit; apply the file edits after the chain is cut (1.0.5 leaves prior `@` content behind — edits written before the cut would strand there).

### 1.0.4 Fetch the trunk

`jj git fetch` — refresh `development@origin`; no checkout, `@` floats. if no origin → skip.

### 1.0.5 Cut the sprint chain

Cut the chain off the fetched trunk, before any authoring:

```bash
jj new development@origin
```

Ungated (the gate is plan approval, 1.3.1) and **anonymous** — no name exists until publication (Build 3.4.1). Prior `@` content stays behind as its own commit — no stash. if no origin → `jj new development` (the local bookmark seeded at 1.0.2). if resuming a surviving draft (1.0.3) whose `docs(plan)` commit already sits on a chain → don't cut a second chain — `jj new <that chain's tip>` instead.

---

## 1.1 Discovery

**Goal:** understand the intent and map the touched code.

### 1.1.1 Discuss with user

Open context-aware — three openings, same interview style for all:

1. greenfield project — what are we building, from zero?
2. brownfield project — first contact with an existing codebase
3. new sprint — artifacts exist; what's this sprint for?

Then intent-driven — ask the intent, infer + confirm the rest (not a questionnaire):

1. **Intent** — what's this sprint for?
2. → `.stories` or architecture — user-facing want vs technical work
3. → `.adr` — decisions the approach forces
4. → `.brief` check — still fits north-star / non-goals? (mostly silent)

Interview style: one question at a time, each with a recommended answer; explore the codebase instead of asking where it can answer (quick inline lookups to steer the conversation — the big sweep is 1.1.2); challenge + sharpen the user's terms.

### 1.1.2 Codebase exploration

Once the intent is clear, the big sweep: dispatch `codebase-explorer` agents (parallel, `codebase-explorer-prompt`) to map only the touched modules — grounds the discussed intent in the actual code. *Direction from the session, discretion to the agent*: seed each with what the session already holds — the discussed intent, the modules to map, the `.spec` slice if present — then latitude: each expands its exploration to what its task needs, no rigid procedure.

if `.spec` exists → explorers read its slice first — the spec scopes + frames the sweep, the code carries the detail. if greenfield (no code yet) → skip.

### 1.1.3 Gate — confirm discovery

Present the discovery summary — sized to the sprint, no fixed length: the intent as understood, the touched-code map, anything 1.1.1 sharpened. The user confirms it captures their intent → proceed to Author; corrections → fold in, re-present.

---

## 1.2 Author

**Goal:** decide the approach, then write the sprint's artifacts.

### 1.2.1 Create / edit `.brief`

if no `.brief` yet (greenfield, or brownfield first contact) → write the founding `.brief` per `brief-format` — the charter + the DoD home. Otherwise edit **only** when Discovery's `.brief`-check (1.1.1) surfaced a project-level discrepancy or add-on — scarce by design, the slowest-changing artifact.

### 1.2.2 Create / edit `.stories`

Add/edit `US-###` per `stories-format`. if a new want conflicts with an existing story → resolve it and route the WHY to `.adr` (1.2.4) — the decision log holds the reasoning, not the stories file.

### 1.2.3 Discuss the architecture

Discuss the approach with the user — how the sprint fits the existing architecture, what's new, which patterns hold, what the alternatives are. Let the discussion run naturally; note decisions as they emerge — formal capture is 1.2.4, don't interrupt the flow with paperwork.

### 1.2.4 Capture `.adr`

Capture the decisions in `.adr` per `adr-format` — **append-only**: never edit or delete an existing record. The bar is **judgment**, guided by Pocock's three tests — hard to reverse · surprising without context · a real trade-off — not a hard all-three checklist; when in doubt, the reasoning can stay in the plan. Check each new decision once against `.brief` principles (north-star / non-goals): deviation → flag to the user, never block. Downstream trusts the record (*trust the artifact*) — write it to be consumed.

### 1.2.5 Gate — approve `.adr`

The user confirms the written records say what 1.2.3 decided — **capture fidelity, not re-deciding**; mismatch → fix in 1.2.4, re-present. The commit gate stays 1.3.1.

### 1.2.6 Write the `.sprint` plan

Write `.sprint/sprint-v{N}.md` per `sprint-format` — the sprint's single pass/fail **Goal** + scope + epics + the `US-###` slice + success metric + DoD-ref; `status: draft`. This is the exact contract Tickets 2.0.2 reads. References, never copies — the `US-###` slice points at `.stories`, the DoD-ref at `.brief`.

---

## 1.3 Phase close

**Goal:** persist the work + hand off.

### 1.3.1 Gate — approve the `.sprint` plan

The user accepts the sprint — approves the plan's **Goal + scope**. The gate sits on content acceptance, never on a vcs op: once accepted, 1.3.2 runs autonomously — no "shall I commit?" follow-up. Edits → fold in, re-present.

### 1.3.2 Finish documentation artifacts

Finish **one** atomic commit of the documentation artifacts. Everything is already auto-snapshotted into `@` — the finish is describe + new.

- **Greenfield first** — the founding charter is its own change: split `.brief` out via explicit fileset (editor-free — the interactive form is banned by the commit model):
  ```bash
  jj split -m "docs(brief): <project> founding charter" .brief
  ```
  The remaining docs stay in `@` for the plan commit below.
- **The bundle** — the `.sprint` plan + any `.stories`/`.adr` edits + the 1.0.3 lifecycle flips: one logical change — *plan the sprint*, portfolio management included.
- **The finish** — message shape per `commit-format`:
  ```bash
  jj describe -m "docs(plan): sprint-v{N}

  Story: US-0XX, US-0YY
  ADR: ADR-0ZZ
  Assisted-by: <agent> <model>"
  jj new
  ```
  Trailers carry the captured `Story:`/`ADR:` pointers by ID (never a copy) plus `Assisted-by:` authored explicitly per commit-format — session-derived from the dispatch (`<role> <model>`), never config-appended.

Follows the 1.3.1 acceptance — the gate approved the content; the commit is autonomous.

### 1.3.3 No push (local until Build-close)

Plan finishes locally only — **no push**. Durability is local (the commits carry it), and the chain has no name yet — publication (name + push) is Build-close (3.4.1).

### 1.3.4 Handoff

Summarise what was captured: the plan's Goal + version, `.stories` touched (IDs + one-liners), ADRs (titles), the Brief if founded, and where the chain sits (`jj log` inline is fine). Recommend running `/sprint-tickets` in a **fresh session** — clean context; the artifacts carry the intent (*phases don't share a session — artifacts are the bridge*). This phase ends here — never start ticketing.

---

## Key principles

- **Gates sit on content, ops run autonomously** — three gates, zero op confirmations.
- **The chain is private clay, anonymous** — no name, no push, until Build publishes it.
- **One `docs(plan)` commit** — lifecycle flips are annotations riding it; greenfield's `docs(brief)` splits out first.
- **Quality is owned at creation** — downstream consumes these artifacts as-given, in a fresh session; write them for a context-less reader, each fact in one place, referenced not restated.
- **Thin orchestration** — explorers own the exploration, the user owns the decisions; the session steers, gates, and finishes.
