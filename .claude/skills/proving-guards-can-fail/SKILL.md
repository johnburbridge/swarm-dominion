---
name: proving-guards-can-fail
description: Use when writing a test, invariant, drift guard, lint or CI check, or when introducing a tuned constant — anything whose job is to catch a future mistake. Provides the procedure for proving a check can actually fail, rather than assuming it can. Also use when asked to "verify the tests actually test something", "check for vacuous assertions", or before claiming a constant or decision is pinned.
---

# Proving a Guard Can Fail

A check that cannot fail is worse than no check: it reports safety it does not provide,
and it survives review because everything is green.

## The failure mode this exists to stop

Not carelessness. The trap is **correlated verification** — generating the mutations that
test a guard from the same mental model that produced the guard. When the model has a
blind spot, the mutation set inherits it and the verification comes back green for the
same reason the design was wrong.

You cannot fix this by being more careful. Being careful is the thing that already failed.
The only reliable break is to source the mutations from outside yourself.

Four real cases from this repo:

| Built | Verified by | Blind spot |
|---|---|---|
| `assert_lte(dot, 0.0)` for "unit is behind" | one hand-picked heading | perpendicular headings make it vacuous — 2 of 5 loop iterations asserted nothing |
| `REAR_FAN_STEP = TAU / 10` | nothing | reverting the constant left the suite fully green |
| Controls drift guard | adding an action; removing a doc mention | both mutations changed the action-*name* set — the only dimension the guard could see. Rebinding a key stayed green. |
| A comment warning that `ui_*` actions are exempt from the guard | nothing | one was already live: `ui_cancel` (Escape) pauses the game and was undocumented |

The last one matters most: the blind spot was correctly identified *in writing* and still
shipped, because nothing checked whether the stated limitation was already violated.

## Procedure

Steps 1–5 are a checklist. Step 6 is the one that actually breaks the correlation — do not
skip it for anything whose purpose is catching future drift.

### 1. Name the drift space

Before writing the check, list the dimensions along which the guarded thing can change.
For an input binding: name, key, modifiers, *number of bindings*, event type, which code
reads it. For a geometric predicate: each degenerate configuration (parallel,
perpendicular, zero-length, exactly-on-boundary).

### 2. Mark which dimensions the check observes

Every unobserved dimension is either a bug or a documented limitation. There is no third
option, and "I'll remember" is not a limitation.

### 3. Check every stated limitation against current reality — now

A limitation you wrote down and did not verify is not documentation, it is a prediction.
Grep for it. `ui_cancel` shipped undocumented underneath a comment describing exactly that
hole.

### 4. Watch each assertion fail, not each test

A test failing at RED proves *something* in it works. Loop bodies and multi-assert tests
need per-assertion evidence. Tighten `assert_lte` to `assert_lt`, or temporarily invert
each assertion, and confirm each one is reached and can fail.

### 5. Perturb every constant that encodes a decision

If flipping the sign, halving the value, or reverting it to the previous constant leaves
the suite green, the constant is unpinned regardless of how many tests mention it.

### 5b. Commit before you mutate

`git checkout <file>` restores to **HEAD**, not to your working state. Mutating uncommitted
work and then "restoring" it destroys the very thing you were verifying — and the run still
goes green, because it is now testing the old code. Commit a checkpoint (amend or squash it
later) or copy the file aside before the first mutation.

### 5c. Read the test count after every mutation run, not the summary

GUT prints "All tests passed" while silently skipping a file it could not parse, so a
mutation that breaks compilation reads as success. Every mutation run must confirm the
count is what it was before. A run whose count dropped proves nothing and must be redone.

This is also why a mutation that changes *nothing* deserves a second look: it may mean the
thing you mutated was already inert. A `(?s)` flag on a pattern containing no `.` survived
exactly that way — mutating it changed no result because it never did anything.

### 6. Have someone else generate the mutations

For any guard — a drift check, an invariant, a CI rule — dispatch a subagent before
finalising. Do not write the mutation list yourself; that is the step that failed.

```
Here is a check I wrote: <paste the check>
Here is what it is supposed to guard: <describe the thing and where it lives>

List every change to the guarded thing that this check would NOT notice.
Include: changes to dimensions it never reads, values that satisfy it
degenerately, and states it would accept that a reader would consider wrong.
Do not evaluate whether the check is good. Only enumerate its blind spots.
```

Then close or document each one. This is cheap — one small agent, no repo mutation.

## Traps in the verification itself

The procedure above has its own failure modes, all observed while running it:

| Symptom | Cause | What it looks like |
|---|---|---|
| Mutation run passes | the test file did not compile and was skipped | test count dropped; summary still says all passed |
| Mutation run passes | the restore wiped your uncommitted changes | test count dropped to the pre-work number |
| Mutation changes nothing | you mutated something inert | no test moves in either direction |

All three present identically — a green run — and none of them means the check is sound.

## Project-specific traps that let vacuous checks survive here

- **GUT silently skips a test file with a parse error** and still prints "All tests
  passed." Always confirm the Tests count rose by the number you added. See `run-tests`.
- **`-gtest=<file>` is ignored** because `.gutconfig.json` sets `dirs`. Run the whole
  suite and grep.
- **CI lints `scripts/` only**, not `tests/`, so a test file can drift from house style
  and from the lint rules indefinitely.
- A test whose expected value equals the *default* state (a `visible = false` authored in
  the `.tscn`, art that already points north at rotation 0) passes against an empty
  implementation. Choose fixtures that differ from the default.

## When to stop

Steps 1–5 apply to any assertion. Step 6 applies to guards — checks whose value is
entirely in catching a *future* change. A single behaviour test asserting a function
returns 3 does not need an adversarial agent; a check that claims "the docs can never
drift from the input map" does.
