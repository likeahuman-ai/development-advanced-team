# commit-format

The shape of one **atomic commit** the session finishes (`jj describe` message) — one logical change, self-contained, tree left building. Authored across four phases: `docs(plan)` (Plan 1.3.2), one-per-ticket (Build 3.2.4), backlog `docs` (Review 4.6.1, conditional), one-per-finding `fix` + close-out `docs(spec)` (Refine 5.1.4 · 5.2.3). Read by Review to trace coverage — Ticket → Story → ADR → Depends-on by logical ID (*trust the artifact*: the linked facts are read as-given, never re-fetched).

This format defines the shape of **one** commit. The *set* of commits (a wave's, a PR's, the sprint's landed list — **Commits** plural in the Artifacts table) is a separate concern owned by the commit graph, not by any message field — see `## The set`.

## Shape

```
type(scope): imperative subject

[optional body — change-local "why" with no other artifact home]

Trailer: value
Trailer: value
```

- Conventional subject, blank line, then trailers. Body optional, between (also blank-line-separated).
- One honest conventional subject (`type(scope): summary`, no "and") → one commit; split if the message needs "and".
- References only: trailers carry logical IDs (`#N` · `US-###` · `ADR-###`), never SHAs, never copies — git preserves the point-in-time artifact (`git show <commit>:.adr/ADR.md`).

## Subject

`type(scope): summary` — conventional, imperative, lowercase, no trailing period, no "and".

`type` ∈ `feat` · `fix` · `docs` · `test` · `chore` · `refactor` · `style`. `scope` = the touched area (package/module). Worker-suggested (Build) / reviewer-suggested via arbitration (Review/Refine); **session-owned** — the session is sole committer (*hands-not-authors*).

## Body

Optional. Only change-local rationale below artifact granularity — the "why" with no other artifact home. Anything an artifact owns (story intent, decision, spec section) is linked by trailer, never restated here. Omit entirely when the subject + trailers say it all.

## Trailers

`Key: value`, one per line, repeatable keys.

| Trailer | Value | Source | When present |
|---|---|---|---|
| `Ticket:` | `#N` | the issue | Build (always) · Refine fix + close-out `docs(spec)` (per what the change touches) |
| `Story:` | `US-###` | `.stories` | when the change traces to a story |
| `ADR:` | `ADR-###` | `.adr` | when a decision governs the change |
| `Depends-on:` | `#N` | build-order | Build hard-dep only — cites **earlier** tickets in build-order (backward refs; establishes closure for partition 3.3.1) |
| `Assisted-by:` | `<role> <model>` | the writing agent, or the session | **always** — the queryable audit trail; **never** `Co-Authored-By:` (a model can't hold copyright or sign a CLA). **Authored in the `describe` message from a structured fact** — a dispatched commit derives it from the dispatch record (the agent's role + the model id passed at dispatch); a session-authored commit uses role `session` + the session's own runtime model id — never a jj config, never recalled from memory |

Repeatable: a commit satisfying two stories carries two `Story:` lines; one depending on two earlier tickets carries two `Depends-on:` lines.

**`Assisted-by:` grammar — one canonical token shape.** `<role> <model>`, role first, single space. `<role>` is a bare role token from the closed set — `explorer` · `architect` · `implementer` · `reviewer` · `arbiter` · `spec-writer` · `session` (lowercase, the role's own spelling); this list is the canonical set for the `Assisted-by:` trailer. The first six are dispatched agents the writing maps to; **`session`** is the seventh — for a commit the **session itself authors** with no dispatched writer (`docs(plan)`/`docs(brief)` at Plan 1.3.2, the Review backlog `docs` at 4.6.1), paired with the **session's own** runtime model id. Without it those session-authored docs commits had no token in the set and the role was guessed from precedent. A Refine fix commit's writer is a fix-agent dispatch — an `implementer` dispatch — so its token is `implementer`, not `fix-agent`. `<model>` is the **full runtime model id verbatim**, including any context-window suffix (`claude-opus-4-8[1m]`, not normalized to `claude-opus-4-8`) — the audit keys on the exact id that ran. No title-case, no reordering, no synonym; the same token shape is queryable across the whole graph. The session reads both fields off the **dispatch record** — the `agentType` it launched and the model id it passed to that dispatch — so the token is derived from a structured fact at fold time, never reconstructed from memory (memory-reconstruction was the fragility the dropped `commit_trailers` config tried, and failed, to avoid).

**`Ticket:` cardinality — many commits, one realizer.** A ticket legitimately spans more than one commit across phases: the Build feat **realizes** `#N` (3.2.4) and a later Refine fix or close-out `docs(spec)` **touches** `#N` (5.1.4 · 5.2.3). All carry `Ticket: #N` — the trailer is the same logical pointer; it is **not** overloaded to also mark *realizes vs touches*. That role split is recovered from the `type`+phase, never from a second field: the **realizing** commit is the Build `feat`/`refactor`, the touching ones are the Refine `fix`/`docs(spec)`. Coverage accounting (5.3.1) keys on the realizer — `Ticket: #N` on a `feat` → Issue `#N` → PR — and reads the `fix`/`docs(spec)` lines as same-ticket follow-ups, not as a duplicate realization. (The format adds no role/phase trailer to disambiguate: the type+phase already carries it, and each fact lives once.)

**`Depends-on:` referent — the ticket, not a commit.** The dep is on the logical **ticket** (`#N`), so its closure is "ticket #N's commits all land before this one." When a ticket spans more than one commit (a Build feat + a later Refine fix both on `#504`), every dependent still cites `#504` — the build-order's partition (3.3.1) already orders the whole ticket ahead, so the per-commit referent is never needed.

## Example

Build, wave 2, a ticket depending on two wave-1 tickets:

```
feat(auth): add refresh-token rotation on session renewal

Reuse-detection window is 10s to absorb client clock skew —
below the spec's grace bound, no artifact owns the constant.

Ticket: #42
Story: US-007
ADR: ADR-003
Depends-on: #38
Depends-on: #40
Assisted-by: implementer claude-opus-4-8[1m]
```

## The set

The *set* of **Commits** (plural) — a wave's, a PR's, the sprint's landed list — is **not** a field of any message. The commit graph is its container (*Git is its own context layer*): boundary, count, **phase**, order, and verified/landed state are **graph facts**, never restated in-message. The message is the artifact for one node; the graph is the artifact for the set (*trust the artifact* points at the graph for set-facts, each living once). Where each set-fact lives:

- **Boundary + count** — each commit is one node, the set a revset (`jj log -r <bookmark>` / `git log <bookmark>`); no in-message delimiter, fence, or `1/N` sequence marker exists, because there is nothing between commits to write.
- **Phase** — which phase authored a commit (Plan / Build / Review / Refine — *one ticket in Build, one finding in Refine, one decision set in Plan*) lives in the **commit's graph position + its `type(scope)`**, never a phase marker in the message. The phase-to-shape map is fixed: Plan → `docs(plan)` / `docs(brief)` · Build → one `feat`/`fix`/`refactor`/… per ticket · Review → at most one `docs` backlog commit · Refine → `fix(scope):` per finding + one `docs(spec):` close-out per PR. A Build feat and a Refine fix on the same ticket are distinguished by **type + position in the landed list** (the Build commit predates the Refine one), not bare type alone — no `Phase:` trailer exists because the graph already carries it.
- **Order** — **build/landed order is the graph's parent→child topology**, never message text and **never the order this format lists commits in** (the Shape/Example/Other-phases ordering is expository, not chronological — commit order is never inferable from where a message sits in this file or any rendering). A `Depends-on:` cites the logical ticket; *commit* order lives in the DAG. Coverage accounting (5.3.1) walks the landed list on `development`, in graph order.
- **Verified + provenance — out-of-band by design.** That a commit is verified state (passed the 3.2.5 / 5.1.5 Verify gate, spec-review) is a **graph fact, not a message fact** — carried by the commit's **presence in the published/landed graph**. Gates approve content *before* the finish, and only verified state ever publishes, so being on the pushed bookmark *is* the proof. The message text holds none of it: no branch, push, gate, SHA, date, author, or sequence field belongs in the subject/body/trailers — that is the vcs layer's to record (`SHA` · change ID · bookmark · landed position), and duplicating it would violate *each fact lives once*.

## Other phases

**Plan (1.3.2)** — one `docs(plan): sprint-v{N}` bundling the `.sprint` plan + any `.stories`/`.adr` edits + the 1.0.3 lifecycle flips (annotation, no own commit). Trailers: `Story: US-###` (each captured ID, one per line) · `ADR: ADR-###` (each) · `Assisted-by: session <model>` (session-authored — no dispatched writer). **Greenfield:** the founding `.brief` splits out first as its own `docs(brief): …` commit via explicit fileset (also `Assisted-by: session <model>`).

**Review (4.6.1, conditional — 50–74 non-testable findings only)** — one `docs` commit writing the backlog to this PR's own `.sprint/findings-<g>.md` (a per-PR **file**, so sibling backlog commits sit on disjoint paths and never collide on rebase). Session-authored → trailer `Assisted-by: session <model>`. Individual findings get no own commit.

**Refine fix (5.1.4)** — `fix(scope): <finding description>`, **one commit per finding** (not per ticket — fixes subdivide past ticket boundaries). Trailers per what the finding touches: `Ticket:` / `Story:` / `ADR:` · `Assisted-by:`. A `testable`-tagged finding bundles its regression test into the **same** commit (the test proves the fix); fixes are never bundled with each other.

**Refine close-out (5.2.3)** — `docs(spec): <the delta>` (or conventional docs type), one per PR. Its trailer set is **closed**, not a minimum: exactly the **logical IDs the spec delta documents** — `Ticket: #N` (each ticket whose landed change the delta records) · `ADR: ADR-###` (each decision the delta encodes) · `Assisted-by:`. **No `Story:`** — and the absence is meaningful, not an oversight: the spec is a claim about *code*, so the delta records ticket+decision coverage, never story satisfaction; story satisfaction is recovered from the **realizing** Build commit's `Story:` (above), and restating it here would duplicate a fact that already lives on the feat. Without the closed set the close-out would drop out of coverage accounting (5.3.1 traces each landed commit's `Ticket:` → Issue → spec sections), so a spec delta for the OAuth2 guard carries `Ticket: #504` · `ADR: ADR-019` and no story line. On the sprint's **final** PR the `.sprint` plan `draft → built` flip rides this commit as an annotation — the flip and the fact become true together; never its own commit.

## Rules

- **Atomic boundary is logical, not hunk-shaped.** Scoped by reason-to-change, never by file or hunk; the trailers form the closure.
- **The per-commit trailer layer is the carried knowledge.** One message + its trailers per atomic change; the layer survives only as long as the commit does. History is rewritable on the private sprint chain and append-only once it lands at the trunk — the format's stake is only that the layer stays one-trailer-set-per-change, never collapsed (squashing finished commits destroys the per-ticket trailer layer).
- **Conflict heal touches no message.** Subject, body, and trailers stay untouched through a recorded-conflict heal (the heal mechanism is skill-owned process, not message shape).
- **Gates sit on content, not the commit.** A gate accepts an artifact's content; the commit publishing it follows autonomously — acceptance precedes the finish. No status edit gets its own commit — it annotates the commit that makes it true.
