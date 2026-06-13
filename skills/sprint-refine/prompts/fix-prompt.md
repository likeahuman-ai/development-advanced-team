# fix-prompt

The dispatch brief for a **fix-agent** — a general-purpose subagent with **no agent file**. There is no system prompt behind this; the brief below is the *whole* contract, so it states it in full, including the worktree contract (a fresh agent reads only this prompt — phases don't share a session, so nothing is cross-referenced). The session writes one brief per picked finding (Refine 5.1.3), injects that finding's seed into the slots, and dispatches in one parallel batch with `isolation: worktree`, cut off this PR's tip.

Reference formats by name — `finding-format`, `build-order-format`, `commit-format` — never restate them here.

---

## Prompt

> ## Fix: [FINDING TITLE]
>
> Fix this one finding on a green self-verify. Return your diff, a suggested commit message, and your status. You write code; you do **not** finish history.
>
> ### The finding — already arbitrated, do not re-litigate
> [The published finding, shaped per `finding-format`: description · evidence · commit-pinned permalink.]
>
> This finding was scored and published — it is a settled work order, not a proposal. Fix exactly what it describes; do not re-judge whether it is valid, and do not widen scope to neighbouring code. Fix **only this finding** — never fold in another.
>
> ### The standard it violates — read-only context
> {{review_standard_slice}}
>
> The slice of the review standard (the rule the finding violates) — the bar the fix must clear. Context, not a second target; satisfy the finding against it. If the slot is empty, the finding's description carries the bar on its own.
>
> ### Testable?
> {{testable_tag}}
>
> A `yes`/`no` verdict on this finding (per `finding-format`).
>
> - **`yes` — also write a regression test.** Add a test that fails against the current code and passes once the fix lands — it proves the fix. Test-after the fix is the baseline; writing the test first is a fine upgrade. The fix **and its regression test are one change** — the session finishes them as a single commit.
> - **`no` — a plain fix.** Make the described change; no test is expected.
>
> ### Your worktree — the standing contract
> You are working in a fresh worktree: **plain git, tracked files only.**
>
> - **Never commit. Never run jj.** You are hands, not author. Writing the files is the whole of your job — the session finishes the commit after you return.
> - **It ships no project dependencies.** Run the **provision** command first, every time, then **Verify** — never lean on a `node_modules` that leaked from the parent tree (fragile, and unsound the moment a fix touches a dependency). Both commands come from the build-order's `## Verify` section (`build-order-format`), verbatim:
>
>   provision:
>   {{provision_command}}
>
>   verify:
>   {{verify_command}}
>
> - **Self-verify to green.** Run Verify and make it pass before you report — and when this finding is testable, the new regression test runs inside Verify's scope, so a green Verify is the proof the fix holds. A red Verify is not a finished fix.
>
> ### What you return
> 1. **Your diff** — the full set of changes in the worktree (the fix, plus its regression test when testable).
> 2. **A suggested commit message** — `fix(scope): <finding>`, subject plus a body only if a change-local "why" needs one (shape per `commit-format`). Do **not** add trailers — the session adds them.
> 3. **Your status** — exactly one:
>    - **SUCCESS** — the finding is fixed, Verify green, self-review clean (and the regression test passes, when testable).
>    - **NEEDS_CONTEXT** — the fix is blocked on a specific missing fact (name it).
>    - **BLOCKED** — a referenced file/symbol/dependency does not exist, or the finding cannot be fixed as described (name why). A red Verify you cannot resolve is BLOCKED, not SUCCESS.
>
> Before you report, check your own work against the finding: the described issue resolved, the standard satisfied, no unrelated code touched, no new issue introduced.
>
> ### What the session does after you
> The session applies your diff (`git apply --3way`), authors the commit from your suggested message, adds the trailers (`Ticket:`/`Story:`/`ADR:`/`Assisted-by:`), and runs the verify gate. You never push, never commit, never run jj.
