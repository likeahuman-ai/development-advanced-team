# finding-report-format

The shape of one **finding report** — the in-flight object a specialist returns at 4.3.1, the session collects at 4.3.2, and the Opus arbitrator reads at 4.4.1. **No file.** These are session-internal objects, never a persisted `.sprint` artifact — analogous to a system prompt, a contract a producer fills and a consumer reads, not a stored document. After arbitration (4.4.1) they become PR comments (`finding-format`, 4.5.2) and backlog entries (`.sprint/findings.md`, 4.5.1).

## The artifact is one shape, filled in two stages

**The contract is a single finding object with two field blocks — finder-owned and arbiter-owned.** It is not two artifacts. The same object is filled in two stages: a finder writes the finder block on return (4.3.1), the arbitrator adds the arbiter block on read (4.4.1).

- **Finder block** (`where` · `what` · `evidence` · `agent` · `confidence` · `impact`) — present from 4.3.1, never mutated after.
- **Arbiter block** (`score` · `testable`) — **absent on return, present after 4.4.1**.

Presence is keyed to stage by contract, not optional: a finder emits the finder block only; a post-4.4.1 consumer (4.4.2 bucketing, 4.5.x) reads every field below as present.

## Container — the collected set

The session collects **one finding object per finding across all specialists into a single flat list** under a thin envelope (4.3.2). Review runs **per PR** — one arbitration per PR (SKILL 4.1.2 · 4.4.1 dispatches *Arbitrate PR #<n>*), so a set is exactly one PR's findings. The arbitrator reads that body as one whole (4.4.1) — provenance lives on each object's `agent` field, not in the container, so there is no per-agent nesting. Dedup (4.4.1) collapses cross-agent duplicates *within* the list (a flaw two specialists both raise is one finding); the list never groups by finder.

**Envelope.** The list sits under top-level keys that bound the set so the arbitrator can confirm it has everything before it culls (the cull is irreversible — dropped findings never come back): which sprint (`v{N}`), which PR was reviewed (`#N` — Review arbitrates one PR per call), and the expected-report count the session dispatched (4.3.1) so a short collection is detectable. These keys **point at facts owned elsewhere** — the sprint version (`.sprint/sprint-v{N}.md`), the PR identity (the forge), the specialist roster (4.2.1) — the envelope asserts only *this run's boundary*, never restating what those own.

**Ordering.** The collected list is **unordered** — the session appends in specialist-return order, which carries no meaning. Any priority ordering is the arbiter's to impose after scoring (4.4.1); the format mandates no sort and no tie-break, so `score` is not a position. A consumer that needs ranked findings sorts by `score` itself and treats equal scores as unordered (the arbiter calibrates relative priority, not a total order).

## Per-finding shape

```yaml
sprint: v{N}                             # which sprint (points at .sprint/sprint-v{N}.md)
pr: #N                                   # the PR reviewed (Review arbitrates one PR per call)
expected: 6                              # report count the session dispatched (4.3.1) — short collection is detectable
findings:
  # finder block — written at 4.3.1, never mutated
  - where: <file:line>                   # the one located site; primary site if the fix spans files
    cites: [<file:line>, …]              # optional — files the evidence references but isn't located at
    what: <terse, objective description> # the issue, one claim — no "and"
    evidence: |                          # backing facts; may cite code outside the diff — callers, types, tests, the whole function
      <snippet or explanation>
    agent: <finder>                      # which specialist found it (code-quality-reviewer, …) — sole provenance
    confidence: <0–100 | adjective>      # finder's self-rated sureness — signal, not binding
    impact: <0–100 | adjective>          # finder's self-rated consequence-if-unfixed — signal
    # arbiter block — added at 4.4.1 (arbiter-owned; presence-by-stage above)
    score: <0–100>                       # the binding priority (arbiter-owned; overrides the finder's self-assessment — see field rules)
    testable: <true | false>             # behavioural claim a test can express (factual, not severity)
```

The two `# block` comments are the structural separation of who authored which value: everything above the arbiter line is the finder's; `score` and `testable` are the arbitrator's. A consumer reading the merged set tells self-assessment from arbitration output by which block a field sits in.

## Field rules

Shape and value-domain only — the dedup, override, and tagging **mechanics are arbiter-owned (see 4.4.1)**, referenced here, never reproduced.

- **where** — `file:line`; **exactly one located site** — the primary site if a fix touches several. The dedup match key (arbiter-owned, 4.4.1). Files the evidence merely *references* go in `cites`, never here — so the located site is never ambiguous against cited ones. **The line is the real line in the local working tree at the PR head** (the 4.1.4 read-surface), read by grepping the symbol in the tree — **never a captured-diff hunk offset** (a `gh pr diff` line number counts diff rows, overshoots the file, and breaks the permalink). The diff is the seed; the tree is where the line resolves. Same rule for every `file:line` in `cites`.
- **cites** — optional `[file:line, …]`; the secondary files the evidence points at but the finding is **not** located at (a fix may touch `where` plus these). Structures the located-vs-referenced distinction the evidence prose would otherwise leave inferable; omit when the evidence stays within `where`.
- **what** — one objective claim, no severity adjectives, no "and" (a two-concern finding is two findings).
- **evidence** — the snippet or reasoning that grounds the claim. May reference code **outside the changed lines** — review reads past the diff into the whole function, callers, types, tests; name those files in `cites`. Multiline.
- **agent** — the finder's role name and the object's **sole provenance** for the finder block; carried unchanged through dedup so a merged finding keeps its origin.
- **confidence · impact** — the finder's self-assessment, **signal, never binding**. Kept in the finder block, **distinct from `score`** so the signal stays visible after the binding number lands; the arbiter weighs and may override them (arbiter-owned, 4.4.1).
- **score** — the binding 0–100 priority, **arbiter-owned, calibrated across the whole set** (4.4.1). An **independent global judgment that overrides the finder's self-assessment** — `score` may sit above, below, or between `confidence` and `impact` (exceeding both is the override working, never an error), and carries no per-finding derivation a consumer reconstructs. The consumer reads `score` as authoritative on its own and never recombines it with `confidence`/`impact`. Never the finder's to set.
- **testable** — `true | false`, **arbiter-owned**, present only after 4.4.1: does a test express this behavioural claim? A factual classification, not a severity (tagging mechanics arbiter-owned, 4.4.1).

## Example

The collected set **as the arbitrator receives it at 4.4.1** — the envelope plus three findings on one PR (#245, a payment + webhook change), finder blocks only, no arbiter block yet:

```yaml
sprint: v17
pr: #245
expected: 6                              # six specialist reports dispatched; all three findings below arrived under that boundary
findings:
  - where: src/components/PaymentForm.tsx:140
    cites: [src/lib/validation.ts:8]     # evidence reaches the validator, but the finding is located at the form
    what: submit handler skips the null-check before reading the parsed amount
    evidence: |
      PaymentForm.tsx:140 calls validateAmount(input) but reads .value on the
      result without checking the null branch validation.ts:8 returns on a
      non-numeric string — a blank field posts NaN to the charge endpoint.
    agent: code-quality-reviewer
    confidence: 90
    impact: 90

  - where: src/api/webhook.ts:31
    what: webhook handler trusts the unverified Stripe-Signature header
    evidence: |
      webhook.ts:31 parses the body before constructEvent verifies the
      signature — a forged event mutates order state. No timing-safe compare.
    agent: security-reviewer
    confidence: 85
    impact: 95

  - where: src/types/payment.ts:23
    cites: [src/components/PaymentForm.tsx:62]
    what: Amount type allows negative values the form never guards
    evidence: |
      payment.ts:23 types amount as number, no branded non-negative; the form
      at PaymentForm.tsx:62 binds it straight to charge() with no floor.
    agent: type-design-reviewer
    confidence: 90
    impact: 85
```

The same set **after 4.4.1** — the arbiter block added to each (the finder block untouched). The arbiter scored the null-check 92 — above *both* its conf 90 and impact 90 (the override exceeding the inputs, calibrated against the set, not an error and not derived) — and landed it level with the type finding at 92; the format leaves that tie unordered, so a ranking consumer sorts by `score` and treats the equal pair as unordered:

```yaml
sprint: v17
pr: #245
expected: 6
findings:
  - where: src/components/PaymentForm.tsx:140
    cites: [src/lib/validation.ts:8]
    what: submit handler skips the null-check before reading the parsed amount
    evidence: |
      PaymentForm.tsx:140 calls validateAmount(input) but reads .value on the
      result without checking the null branch validation.ts:8 returns on a
      non-numeric string — a blank field posts NaN to the charge endpoint.
    agent: code-quality-reviewer
    confidence: 90
    impact: 90
    score: 92
    testable: true

  - where: src/api/webhook.ts:31
    what: webhook handler trusts the unverified Stripe-Signature header
    evidence: |
      webhook.ts:31 parses the body before constructEvent verifies the
      signature — a forged event mutates order state. No timing-safe compare.
    agent: security-reviewer
    confidence: 85
    impact: 95
    score: 94
    testable: true

  - where: src/types/payment.ts:23
    cites: [src/components/PaymentForm.tsx:62]
    what: Amount type allows negative values the form never guards
    evidence: |
      payment.ts:23 types amount as number, no branded non-negative; the form
      at PaymentForm.tsx:62 binds it straight to charge() with no floor.
    agent: type-design-reviewer
    confidence: 90
    impact: 85
    score: 92
    testable: false
```

The arbitrator never restates the finding standard, platform-as-fact, or the diff — specialists already held those as context (4.3.1). The set carries only the envelope and the findings with their two field blocks.
