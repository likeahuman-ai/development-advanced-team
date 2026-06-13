# finding-format

The shape of the **`### Code Review` PR comment** — the published review output. Review 4.5.2 formats it (one per PR, posted at 4.6.3); Refine reads it as this PR's work order (5.0.4 eligibility, 5.1.1 fix-set). The literal `### Code Review` heading is the parse anchor both skills key off (its exact-text rule is below, in *Field rules*).

Contents = the **published set** only: findings scoring `≥75`, plus `50–74` testable. The `50–74` non-testable backlog lives in `.sprint/findings.md` (4.5.1), never here — the comment is silent about bucketing. The arbitration (4.4.1) already happened: the binding score and `testable` verdict are reported as-given and **never mutated** here.

A consumer parses this comment for, per finding: binding score · `testable` verdict · description + evidence · commit-pinned permalink · `Files:` paths · finder. **Every recovered fact is a labeled field** — `Score:`, `Testable:`, `Found by:`, `Files:`, `Refs:` — so a context-less reader recovers each AS what it is, never inferring meaning from a bare number, word, or position. Format dense for that single parse pass — no severity labels (gone by design), no sign-off ceremony, no restated diff/standard/context.

## Template

````markdown
### Code Review

<one-line scope: what was reviewed — the PR's change in a phrase>
Score 0–100, arbitrated priority. Published: ≥75, or ≥50 when Testable. <N> published.

**<terse finding title>**
Score: <0–100 integer> · Testable: <yes|no> · Found by: <finder>
<description — one claim, what + where + why in code>
Evidence: <backing facts; may cite code outside the diff — callers, types, tests, the whole function>
[permalink](https://github.com/<owner>/<repo>/blob/<40-char-sha>/<path>#L<start>-L<end>)
Files: `<edited-path>`, `<edited-path>`, …
Refs: `<cited-path>` — <why cited; only when a non-edited path is named in the evidence>

**<next finding title>**
Score: <0–100 integer> · Testable: <yes|no> · Found by: <finder>
…
````

The `Score: <n> · Testable: <yes|no> · Found by: <finder>` line is the **labeled metadata strip** — one tagged line per finding, every value labeled (`Score:` · `Testable:` · `Found by:`), so each recovers AS its own kind from the label, never from position. The label semantics live once in *Field rules* below.

**Zero published findings** — the comment is still posted, so a context-less reader distinguishes "reviewed clean" (marker present, the explicit zero-line below) from "not reviewed" (no marker at all). No metadata strip, no findings — the literal `0 published.` count plus the zero-line is the whole signal:

````markdown
### Code Review

<one-line scope: what was reviewed>
Score 0–100, arbitrated priority. Published: ≥75, or ≥50 when Testable. 0 published.

No published findings. <one line on what the specialists covered.>
````

## Field rules

- **`### Code Review`** — verbatim, exact case, the literal parse anchor (5.0.4 discovery, 5.1.1). Never a variant.
- **scope line** — one line naming the reviewed change; orients the reader, restates nothing the PR body owns.
- **legend line** — directly under the scope line, one verbatim line making the score self-describing: the scale (`0–100`, arbitrated priority) **and** the publish thresholds (`≥75, or ≥50 when Testable`), then the published `<N>` count. Carried once in the header so a context-less reader reconstructs *why* each finding cleared the bar (and, with the count, whether any were published at all) — never repeated per finding.
- **`Score:`** — the binding `0–100` integer from 4.4.1, after an explicit `Score:` label. Reported as-given; never recomputed, never mutated. The sole priority signal — a bare integer; the header legend line supplies the scale and thresholds it reads against, so the field reads AS a score, never as a confidence percentage or a severity.
- **`Testable:`** — an explicit `yes` or `no` per finding, after the `Testable:` label — a **verdict on the finding** (a behavioural claim expressible as a test, 4.4.1), present on **every** published finding regardless of score. Never inferred from an omitted field, never read off the `Files:` list (a test file there is unrelated metadata). A factual verdict, never a confidence adjective ("likely"/"probably").
- **No severity labels** — never `[Critical]`/`[Important]`/`[Minor]` or any variant. Priority lives in the `Score:` integer alone, by design.
- **`Found by:`** — the producing specialist's role name after the `Found by:` label (a role from the 4.3.1 specialist roster — the dispatched agent's own name); attribution survives arbitration's dedup. Labeled so it reads AS attribution, never as a tag or category.
- **description** — one objective claim, what/where/why in code; no "and" (two concerns = two findings).
- **Evidence** — the facts grounding the claim; may cite code **outside the changed lines** — review reads past the diff into callers, types, tests, the whole function.
- **permalink** — a **commit-pinned** GitHub blob URL with the **full 40-char head SHA** (`headRefOid` from 4.1.4): `https://github.com/<owner>/<repo>/blob/<40-char-sha>/<path>#L<start>-L<end>`. `<owner>/<repo>` is **read from the repo's own remote** (the PR's repo, e.g. `gh repo view --json nameWithOwner` / the `origin` URL) — never inferred from the example, a directory name, or any other source. Pinned to the SHA so it survives PR head moves and land (never a branch-ref or `#files` PR-diff URL, which rot on rebase). The line anchor is **always** `#L<start>-L<end>` — a single-line finding renders as `#L<n>-L<n>` (start == end), never collapsed to `#L<n>`, so the anchor form is one shape across every producer.
- **`Files:`** — comma-separated backtick-quoted, every path the fix **edits** — and *only* edited paths (a test the fix adds/changes is edited, so it belongs here; a doc cited only as the governing contract does not). Metadata only (no grouping-from-content job — a test path here says nothing about the `Testable:` verdict). The authoritative edited-path list for Refine 5.1.3 grouping; a path cited but not edited must never appear here or it corrupts that grouping.
- **`Refs:`** — present **only when** the evidence names a path the fix does **not** edit (a governing `ADR-###` file, a caller, a type the change is judged against — review reads past the diff into the wider system); backtick-quoted with a terse why. Kept off `Files:` so the contract/cited paths are recoverably distinct from the edited set — a reader (and 5.1.3) never mistakes a cited doc for a path to change.
- **zero-findings comment** — when nothing publishes, still post the marker plus the header (scope + legend line ending `0 published.`) plus a literal `No published findings.` line and one line on coverage; no metadata strip is emitted (this is the signal that distinguishes a clean review from an unreviewed PR — *Zero published findings* above).
- **ordering** — by `Score:`, highest first.

## Example

A PR with three published findings. Two more findings existed but never reach the comment: a `58` non-testable maintainability note went to the backlog (`.sprint/findings.md`), and a `40` was dropped — the comment is silent about both; the bucketing logic lives at 4.4.2, invisible to the reader.

````markdown
### Code Review

Reviewed PR #214 — token refresh + session TTL handling in the auth module.
Score 0–100, arbitrated priority. Published: ≥75, or ≥50 when Testable. 3 published.

**Token refresh swallows the network error, returns a stale session**
Score: 86 · Testable: yes · Found by: code-quality-reviewer
On a failed refresh the catch returns the cached token; callers treat it as fresh, so a 401 from the refresh endpoint silently re-uses an expired token until the next reload.
Evidence: `src/auth/session.ts:88` does `} catch { return this.cached; }`; `src/api/client.ts:24` consumes the return as a live token with no freshness check.
[permalink](https://github.com/likeahuman-ai/claude-mastery/blob/3f2a9c1d4b8e6705a1c2d3e4f5061728394a5b6c/src/auth/session.ts#L84-L90)
Files: `src/auth/session.ts`, `src/api/client.ts`

**Missing-scope check lets a non-admin reach the token-rotate path**
Score: 78 · Testable: no · Found by: security-reviewer
The rotate handler authenticates the caller but never checks the `admin` scope, so any valid session can rotate another user's refresh token, violating ADR-008's privilege-boundary rule.
Evidence: `src/auth/rotate.ts:31` reads `req.session` but the guard at `:28` only asserts presence, not scope; the admin gate at `src/auth/guards.ts:14` is never invoked on this path.
[permalink](https://github.com/likeahuman-ai/claude-mastery/blob/3f2a9c1d4b8e6705a1c2d3e4f5061728394a5b6c/src/auth/rotate.ts#L31-L31)
Files: `src/auth/rotate.ts`
Refs: `src/auth/guards.ts` — the admin gate this path bypasses (not edited); ADR-008 — the privilege-boundary contract

**Refresh path has no test for the failure branch**
Score: 72 · Testable: yes · Found by: test-coverage-reviewer
The success path is covered but the catch branch (`session.ts:88`) has no test, so the stale-token regression above can land unnoticed.
Evidence: `src/auth/session.test.ts` exercises only the happy refresh; no case forces the endpoint to 401.
[permalink](https://github.com/likeahuman-ai/claude-mastery/blob/3f2a9c1d4b8e6705a1c2d3e4f5061728394a5b6c/src/auth/session.test.ts#L40-L58)
Files: `src/auth/session.test.ts`
````

Worked points the example demonstrates: against the header legend, the `78` clears `≥75` and the `72` clears `≥50 when Testable`, while the backlogged `58` clears neither; the `72` is `Testable: yes` even though its `Files:` lists `session.test.ts` (the path is metadata, not the verdict's source); the single-line `rotate.ts:31` finding pins `#L31-L31`; its `Refs:` keeps `guards.ts` and ADR-008 off `Files:`, so Refine 5.1.3 groups on `rotate.ts` alone. The two omitted findings appear nowhere — a reader never learns a finding was dropped or backlogged from this comment.

A reviewed-clean PR (zero published findings):

````markdown
### Code Review

Reviewed PR #218 — the documentation-only README and changelog updates.
Score 0–100, arbitrated priority. Published: ≥75, or ≥50 when Testable. 0 published.

No published findings. The doc changes were checked against the spec and brief; no behavioural or quality issues at or above the publish threshold.
````
