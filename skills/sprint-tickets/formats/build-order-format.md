# build-order-format

Shape of the **build-order** issue: a GitHub Issue body, Markdown, written at Tickets 2.5.6, labelled `build-order` + `v{N}`, pinned at 2.5.7. It is **the pin** — how a fresh `/sprint-build` session finds its work. Read by Build (3.1.3 · 3.2.1 · 3.3.1 · 3.4.1) and Refine (5.1.5) as **authoritative — trust it, never recompute** (*Trust the artifact*).

The body opens with **one required header line**, then carries **exactly four sections, in this order**: `## Parallel Waves` · `## PR Grouping` · `## Scope` · `## Verify`. No others.

**Header (mandatory, first line of the body):**

```
**sprint v{N}**
```

`v{N}` (from the `.sprint/sprint-v{N}.md` filename / issue label) is load-bearing — Build forms `feat/sprint-v{N}-<g>` (3.4.1), so it must be recoverable from the body itself, not only the labels (a context-less reader may hold the body alone). No approval/status token rides here: the build-order's *existence as the pinned issue* is itself the go-signal (2.5.6 creates it only from the approved breakdown), and plan-lifecycle status is owned by the `.sprint` artifact — restating it here would duplicate a fact no Build step reads.

## What lives elsewhere — reference, never copy

A ticket owns its objective, requirements, AC, and `.spec`/`.adr` pointers — this artifact points at it by `#N` (Build reads the full body via `gh issue view`, 3.1.4). Never restate ticket prose, acceptance criteria, or `US-###`/`ADR-###` content here.

**Authority.** `## Parallel Waves` is **authoritative** — the executable wave plan, trusted as-written and never recomputed from the per-ticket detail. That detail under each wave (complexity, hard deps) is **audit-only**: it records *why* a wave is shaped as it is, never a source the waves are recomputed from.

**No per-ticket file attribution.** A ticket's touched-file set is **not** recorded here — no `creates:`/`modifies:`/touched-paths field. Worktree isolation + 3-way apply absorb file overlap, and implementers return diffs the session finishes, so wave ordering needs **hard deps only** (2.5.1/2.5.2); per-file attribution is inert and is deliberately omitted. A rare same-line overlap is not pre-empted by a path list — it surfaces at authoring as a recorded conflict (the `note:` line below).

## `## Parallel Waves`

Hard-dependency-sorted topological waves (2.5.2): a wave is every ticket whose hard deps all sit in **earlier** waves. Hard deps only — soft deps dropped, false/name deps dissolved by worktrees. One ticket per line, grouped by wave header.

Per ticket, on its line: `#N` · short label · complexity code. Under it (audit-only, indented):
- `deps:` — the `#N`s this ticket hard-depends on (HARD only; `—` if none)
- `note:` — optional; a recorded-at-authoring signal (see below)

**Complexity legend** (a single code per ticket, owned by the ticket, recorded here for context): `S` · `M` · `L` = the AI resource cost of the build, **not** wall-clock effort. It is an **advisory sizing signal, not an ordering input** — `L` does not mean "build last"; order is carried by the waves alone.

A recorded conflict noticed at authoring is **data, never silenced** — record it as a `note:` line naming the coupling signal (which tickets, what surface), not a file list; the wave is still trusted (trust-once, verify-on-contact).

## `## PR Grouping`

Tickets grouped into PRs by **coupling** (shared runtime boundary — ship one behaviour, neither half reviews alone, 2.5.3) **and dependency-closed** (the group includes everything it hard-depends on, or depends only on `development`). Each group carries a deterministic **slug `<g>`** — Build names its branch `feat/sprint-v{N}-<g>` (3.4.1) and validates closure by clean `jj duplicate` (3.3.1). One group → no suffix.

The slug is the one load-bearing branch token, so it gets its own **explicit single-token field — never inferred from prose**. Per group:
- `### <g>` header — the slug as the literal section title
- `slug:` — the canonical branch token, restated as a bare single token so no other branch-like string in the body (e.g. `development` in the coupling line) can be mistaken for it; the `### ` title and the `slug:` value must match exactly
- `members:` — the group's `#N`s
- `coupling:` — a one-line rationale (the shared boundary — why they ship together); the *why*, not restated requirements

The slug must be branch-safe: lowercase, hyphen-separated, no spaces (`auth-core`, not `Auth Core` or `PR: auth`) — it is exactly the string Build substitutes into `feat/sprint-v{N}-<g>`, nothing further derived, normalised, or prefixed at read time.

**Derivation — deterministic, not free choice.** The slug is *derived* from the group's defining boundary so two authoring runs over the same breakdown converge on the same name without coordination (3.4.1 depends on this — the branch token must be reproducible, not invented per run):
- group maps 1:1 to a kept `epic:<x>` / `feature:<x>` level (2.4.3) → slug is that label's value, branch-safed (`epic:auth-core` → `auth-core`).
- group spans/crosses labels, or the level was collapsed → slug is the **shared subsystem of its `coupling:` boundary** (the one runtime boundary the members ship), branch-safed.
- two groups would derive the same slug → disambiguate by appending the distinguishing subsystem (`auth-core`, `auth-mfa`), never a bare counter (`auth-1`) — the counter carries no recoverable meaning.

The derivation rule, not the author's taste, is what makes the slug deterministic; record the resulting token in `slug:` so a reader takes it verbatim and never re-derives.

**Member order is arbitrary** — list the `#N`s in any stable order; membership is the only signal, sequence carries none. Build/land order is owned by `## Parallel Waves`, never by how members are listed here — so no commit or merge sequence may be read into the listing.

## `## Scope`

A **decision Build can execute without asking** (2.5.4) — never a menu, never a condition Build can't evaluate from the body alone. State which tickets build; every ticket resolves to **include or exclude** with no further question. No options list, no "choose between".

A stretch/optional ticket is allowed **only as an already-resolved decision**, expressed one of two ways:
- a **definite include/exclude** — the default disposition stated outright (`#X is in` / `#X is out — defer to next sprint`)
- a **machine-checkable defer criterion** — a condition Build can decide from facts in *this* body or the repo (e.g. "skip `#X` if its only hard-dep `#Y` is descoped"). Never a condition with no stated yardstick — "if there's room", "if time permits", "if the wave isn't full" are **forbidden**: the body carries no capacity, budget, or concurrency limit, so Build cannot evaluate them and would have to ask, which this section exists to prevent.

## `## Verify`

**Two real, runnable, repo-matched commands — never placeholders** (2.5.5). Each in a fenced code block, scoped to the touched package(s), never workspace-wide.

- **provision** — install/sync project deps; what a fresh worktree runs first (consumed at Build 3.2.1 / 3.2.5, Refine 5.1.5). If wrong/absent, self-verify leaks the parent's `node_modules` (unsound on dep changes) or fails outright.
- **verify** — the single authoritative "did we break anything" command; **identical across every use** (Build 3.2.1 implementer prompts · 3.2.5 integration gate · 3.3.1 per divided tip · 5.1.5 Refine fixed tip).
- **deferred** — any check the per-wave gate deliberately does *not* run, recorded as an explicit decision so a consumer never has to guess whether an omission is intentional or an authoring error. Two distinct cases, each its own line; write only the lines that apply, and write the line whenever the case holds — silence is reserved for "no such case exists", never for an unstated decision:
  - `deploy-deferred:` — suites that only run post-deploy (e2e on a preview env); the gate can't cover them.
  - `gate-excluded:` — an in-scope check that *could* run at the gate but is deliberately left out (e.g. an e2e **test run** when the verify line only typechecks that package). State the check and the reason in one breath — this resolves a real coverage decision that "omit if none" would otherwise collapse into ambiguous silence.

---

## Template

```markdown
**sprint v7**

## Parallel Waves

### Wave 1
- #41 auth-session-store · M
  - deps: —
- #42 rate-limit-config · S
  - deps: —

### Wave 2
- #43 login-handler · L
  - deps: #41, #42
  - note: shares the auth session-entry surface with #44 — possible same-line overlap, record at authoring, don't pre-empt
- #44 logout-handler · S
  - deps: #41

### Wave 3
- #45 session-ui-banner · M
  - deps: #43, #44

## PR Grouping

### auth-core
- slug: auth-core
- members: #41, #42, #43, #44
- coupling: one auth-session boundary — handlers share the store + rate-limit config; split, neither half reviews alone. Dependency-closed (all deps internal).

### session-ui
- slug: session-ui
- members: #45
- coupling: presentation layer over auth-core; depends on #43/#44 → joins nothing else, lands after auth-core is on `development`.

## Scope

Build all five — every ticket is in. #45 (session-ui-banner) is the only optional one and the decision is resolved: include it; defer to next sprint only if its hard-dep #43 is itself descoped.

## Verify

provision:
```
pnpm install --frozen-lockfile
```

verify:
```
pnpm --filter @likeahuman-ai/auth test && pnpm --filter @likeahuman-ai/auth typecheck
```

deploy-deferred: `pnpm --filter web e2e` (preview env only)
gate-excluded: the `@repo/e2e` integration test run — the gate only typechecks it (`pnpm -F @repo/e2e typecheck`); the suite runs in CI, deliberately not per-wave
```

## Field reference

A terse field → section → consumer-step index — *where each field is read*, not what it means (its meaning lives once, in the section above).

| Field | Section | Read by |
|---|---|---|
| `v{N}` | Header | Build 3.4.1 |
| Wave header + members | Parallel Waves | Build 3.2.2 |
| complexity (`S`/`M`/`L`) | Parallel Waves | Build (context) |
| `deps:` | Parallel Waves | Build 3.3.1 |
| `note:` | Parallel Waves | (audit) |
| `### <g>` header · `slug:` | PR Grouping | Build 3.4.1 |
| `members:` | PR Grouping | Build 3.3.1 |
| `coupling:` | PR Grouping | Build (context) |
| Scope decision | Scope | Build 3.1.3 |
| provision | Verify | Build 3.2.1 · 3.2.5 · Refine 5.1.5 |
| verify | Verify | Build 3.2.1 · 3.2.5 · 3.3.1 · Refine 5.1.5 |
| deploy-deferred · gate-excluded | Verify | (none — informational) |
