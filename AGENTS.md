# Velnorr AI Engineering Quality Gate

This file is binding for every AI coding agent working in this repository. It is
the minimum delivery standard, not optional guidance. Apply it to every task,
including small fixes. Scale the amount of evidence to the risk of the change,
but never silently skip a gate.

The objective is production-grade work: understand the system, make the smallest
correct change, prove the result, protect existing behavior, and report facts.

## 1. Non-negotiable rules

An agent MUST:

1. Read this file before changing the repository.
2. Inspect the relevant implementation, callers, tests, lifecycle, and user-facing
   behavior before editing code.
3. Run `git status --short` before and after the task. Treat pre-existing changes
   as user-owned and preserve them.
4. State the task contract before implementation: scope, acceptance criteria,
   invariants, risks, and validation plan.
5. Fix root causes where reasonably possible. Do not hide symptoms with delays,
   retries, broad exception handling, or duplicated code paths.
6. Keep the diff focused. Do not mix unrelated refactors, formatting, renames,
   dependency updates, or generated artifacts into the task.
7. Add or update tests for changed behavior. A bug fix should normally include a
   regression test that fails before the fix and passes after it.
8. Run all applicable quality checks and report their exact commands and outcomes.
9. Review the final diff as if reviewing another engineer's pull request.
10. Report limitations, skipped checks, remaining risks, and failed experiments
    explicitly. Never fabricate success or imply a check ran when it did not.
11. Create one focused Git commit after every completed logical task, following
    the mandatory commit gate in this document.

An agent MUST NOT:

- Delete, revert, overwrite, stage, or commit user changes unless explicitly asked.
- Weaken tests, assertions, compiler settings, error handling, or success criteria
  merely to make validation pass.
- Introduce force unwraps, unchecked casts, data races, retain cycles, unbounded
  caches, orphan tasks, unmanaged observers, or infinite polling without a written
  and validated justification.
- Claim performance, memory, responsiveness, security, or reliability improvement
  without relevant evidence.
- Call work `complete` while a required gate is failing or unverified.
- Change public behavior, appearance, localization semantics, settings meaning,
  permissions, entitlements, or minimum OS support unless the task requires it.
- Leave temporary logging, personal data, profiling captures, build products,
  commented-out code, or TODO placeholders as a substitute for implementation.

## 2. Completion states

Every final report MUST use exactly one of these states:

- `COMPLETE`: every applicable acceptance criterion and quality gate passed.
- `PARTIALLY VERIFIED`: implementation is present, but one or more validations
  could not be completed. List each missing validation and why.
- `FAILED`: the attempted solution does not meet acceptance criteria. Preserve
  useful evidence and explain the failure; do not disguise it as completion.
- `BLOCKED`: safe progress requires missing authority, information, credentials,
  hardware, or resolution of a user-owned conflict.

Compilation alone is not completion. Passing tests alone is not proof of runtime
behavior or performance. A code diff alone is not proof that the problem is solved.

## 3. Gate 0 — Repository and task reconnaissance

Before implementation, the agent MUST:

- Read `README.md`, `CONTRIBUTING.md`, this file, and any task-specific document.
- For performance work, read the relevant sections of `PERFORMANCE_AUDIT.md` and
  obey its stricter performance quality gate.
- Record `git status --short` and identify pre-existing modifications.
- Locate all relevant code and tests with repository search.
- Trace the affected flow end to end: owner, creation, state updates, consumers,
  cleanup, error paths, cancellation, and restart behavior.
- Identify externally visible behavior that must remain unchanged.
- Identify compatibility constraints: Swift 6, macOS 13 minimum, AppKit/SwiftUI
  lifecycle, permissions, entitlements, localization, and packaging.
- Assign a risk level: low, medium, or high.
- Define a rollback boundary: the exact files or logical change that can be removed
  to restore prior behavior without touching unrelated work.

The agent MUST produce this short contract before editing:

```text
Task:
Root cause or hypothesis:
In scope:
Out of scope:
Files expected to change:
Behavior to preserve:
Acceptance criteria:
Risk level and main risks:
Validation plan:
Pre-existing user changes:
Rollback boundary:
```

Do not implement if the requested behavior depends on an unresolved product choice,
if a user-owned overlapping change cannot be preserved safely, or if required
permissions/entitlements are not understood. Report the blocker precisely.

## 4. Gate 1 — Design readiness

Before writing production code, verify all applicable items:

- The proposal addresses the identified cause, not only the visible symptom.
- Ownership is explicit for services, state, tasks, timers, event taps, observers,
  processes, callbacks, caches, and run-loop sources.
- Every started resource has a symmetric stop, cancellation, removal, or release
  path, including error paths and application shutdown.
- Repeated `start`/`stop`, view recreation, multi-window, and multi-display flows
  cannot duplicate work.
- Swift concurrency isolation is correct. Main-thread work is limited to UI/state
  mutation and platform APIs that explicitly require it.
- Cancellation reaches child work and canceled results cannot mutate live state.
- Failure behavior is bounded: no infinite retry loop, hanging child process,
  silent data loss, or permanent inconsistent state.
- New caching has an invalidation strategy, memory/cost limit, and a reason it is
  preferable to recomputation.
- Polling has a documented interval and lifecycle, and is stopped when the feature
  is inactive. Prefer event-driven updates where the platform supports them.
- New abstractions earn their complexity and do not leave an old parallel path.
- User privacy is preserved; logs must not expose track titles, artists, URLs,
  device identifiers, artwork bytes, or other personal content.
- Accessibility, Reduce Motion, localization, keyboard behavior, and permissions
  are considered where UI or system integration changes.

If an item is not applicable, mark it `N/A` with a one-line reason. Do not omit it
silently.

## 5. Gate 2 — Implementation discipline

During implementation, the agent MUST:

1. Make one logical change at a time and keep the patch minimal.
2. Prefer a failing regression test or measurable reproduction before the fix.
3. Follow existing project structure, naming, formatting, and API conventions.
4. Avoid broad rewrites unless the task explicitly requires one and the evidence
   shows a smaller change cannot safely solve the issue.
5. Handle success, failure, cancellation, restart, and teardown paths.
6. Avoid publishing or rendering unchanged state at high frequency.
7. Keep blocking I/O, process execution, decoding, and expensive computation off
   the main actor unless a platform contract requires otherwise.
8. Preserve existing public and visual behavior unless the acceptance criteria say
   otherwise.
9. Write comments for non-obvious constraints and intent, not line-by-line syntax.
10. Update documentation when behavior, architecture, setup, or limitations change.

For lifecycle-managed resources, explicitly check the relevant pair:

```text
start / stop
addObserver / removeObserver
createTask / cancelTask and clear reference
createTimer / invalidateTimer
createEventTap / disable, remove, and release
launchProcess / timeout, terminate, and collect result
populateCache / invalidate or evictCache
```

## 6. Gate 3 — Required validation

Run validation from narrowest to broadest. Fix failures introduced by the task.
Do not modify unrelated user code to force a green result.

### 6.1 Static and diff checks

- Inspect all changed lines and their surrounding control flow.
- Check for concurrency violations, retain cycles, leaked lifecycle resources,
  unsafe optionals/casts, repeated work, privacy leaks, and dead code.
- Run:

```sh
git diff --check
git diff --stat
git status --short
```

### 6.2 Focused tests

Run the smallest relevant test target or test case first. New behavior MUST cover,
as applicable:

- successful path;
- error/fallback path;
- cancellation and stale-result suppression;
- repeated start/stop or recreation;
- disabled-feature behavior;
- multi-instance or multi-display behavior;
- boundary and malformed-input cases.

### 6.3 Full test suite

For production code changes, run:

```sh
swift test
```

All tests must pass for `COMPLETE` status.

### 6.4 Release build

For production code, build-system, resource, or packaging changes, run:

```sh
swift build -c release
```

A Debug-only build is not production validation.

### 6.5 Runtime verification

When behavior depends on AppKit, SwiftUI rendering, permissions, media players,
displays, event taps, battery/Bluetooth state, sleep/wake, or packaging, perform an
app-level smoke test where the environment permits it. Record:

- exact scenario and build type;
- expected result;
- observed result;
- negative/fallback scenarios exercised;
- anything not testable in the current environment.

Do not convert an unavailable runtime check into an assumed pass.

## 7. Change-type gates

In addition to the universal gates, apply the matching gate below.

### 7.1 Bug fix

- Reproduce or prove the defect before editing.
- Identify the root cause and affected paths.
- Add a regression test whenever technically feasible.
- Verify the original reproduction no longer fails.
- Check adjacent behavior for regression.

### 7.2 Feature or behavior change

- Write observable acceptance criteria before implementation.
- Cover enabled, disabled, empty, error, and restart states.
- Preserve accessibility and localization.
- Verify settings persistence and migration if stored state changes.
- Update user-facing documentation when needed.

### 7.3 Refactor

- State the invariant that must not change.
- Keep behavior tests green before and after.
- Do not bundle behavior changes into a refactor.
- Demonstrate why the new structure reduces a concrete risk or duplication.

### 7.4 Performance work

- Follow `PERFORMANCE_AUDIT.md`, especially its `AI Quality Gate` section.
- Write a falsifiable hypothesis.
- Capture a comparable baseline before editing.
- Use the same Release build, device, screen count, application state, scenario,
  duration, and measurement method before and after.
- Take at least three runs and report medians when measuring noisy metrics.
- Measure the resource actually targeted: CPU, idle wakeups, main-thread stalls,
  memory footprint, process/call/decode count, or scaling by display count.
- Treat a 1–3% difference as measurement noise unless stronger statistical evidence
  exists.
- Do not claim an improvement if the target metric did not improve reproducibly.

### 7.5 Concurrency or lifecycle work

- Validate actor isolation and `Sendable` assumptions under Swift 6.
- Test cancellation before start, during work, and immediately before result apply.
- Prove repeated start/stop does not multiply timers, observers, tasks, processes,
  event taps, or callbacks.
- Verify teardown and deinitialization.
- Ensure sleep/wake and application activation do not duplicate services.

### 7.6 Security, privacy, permissions, or entitlement work

- Define assets, trust boundaries, and misuse/failure cases.
- Use least privilege and preserve secure defaults.
- Never commit credentials, tokens, personal content, or sensitive diagnostics.
- Verify denied, revoked, and unavailable permission states.
- Document entitlement or privacy-description changes and packaging impact.

### 7.7 Documentation-only work

- Verify every command, path, file name, metric, and code reference against the
  repository.
- Clearly separate measured facts, static-analysis findings, assumptions, and
  recommendations.
- Run Markdown/diff checks where available. Code tests may be marked `N/A` only
  because no executable code changed, with that reason recorded.

## 8. Gate 4 — Final reviewer pass

Before reporting completion, reread the final diff and answer all of these:

- Does every changed line contribute to an acceptance criterion?
- Were any user-owned changes overwritten or accidentally included?
- Is there a smaller, clearer solution with equal correctness?
- Are old and new implementations accidentally running in parallel?
- Are cleanup, error, cancellation, and restart paths complete?
- Can state be applied after it becomes stale or canceled?
- Can a cache, retry, timer, task, process, or queue grow without a bound?
- Does multi-display or repeated view creation multiply service work?
- Did public behavior, layout, animation, settings, localization, permission usage,
  or minimum macOS support change unintentionally?
- Do tests prove behavior rather than mirror implementation details?
- Are comments and documents accurate after the change?
- Is the working tree free of temporary artifacts and sensitive data?
- Are all claims in the final report backed by command output or observation?

Any `no`, `unknown`, or unverified answer blocks `COMPLETE` status until resolved or
reported under a non-complete status.

## 9. Gate 5 — Mandatory atomic task commit

Every completed logical task that changes repository files MUST end with a focused
Git commit. The commit is part of the deliverable, not an optional follow-up.

### 9.1 Commit safety

Before staging, the agent MUST:

1. Run `git status --short` and compare it with the pre-task status recorded in
   Gate 0.
2. Identify exactly which changed paths belong to the current task.
3. Stage only those explicit paths, for example:

```sh
git add -- Sources/Velnorr/RelevantFile.swift Tests/VelnorrTests/RelevantTests.swift
```

4. Never use `git add .`, `git add -A`, wildcard staging, or another broad staging
   command in a working tree containing pre-existing or unrelated changes.
5. Never stage, modify, revert, or commit a user-owned or unrelated change.
6. Review the complete staged patch before committing:

```sh
git diff --cached --check
git diff --cached --stat
git diff --cached
```

7. If the staged patch contains anything outside the task contract, unstage only
   the agent-owned path or hunk safely and correct the staging set before commit.
8. Do not use `git commit --amend`, rebase, reset, squash, force-push, or push unless
   the user explicitly requests that separate operation.
9. Do not create an empty commit when the task produced no repository change.

### 9.2 Commit granularity

- One completed logical task should normally produce one atomic commit.
- Production code, its focused tests, and directly related documentation belong in
  the same commit when they form one behavior change.
- Unrelated fixes MUST be split into separate tasks and separately validated commits.
- Do not commit knowingly broken, incomplete, generated-only, or unvalidated state.
- A `PARTIALLY VERIFIED` change may be committed only when it is internally coherent,
  safe to retain, and the missing verification depends on an unavailable external
  environment. The commit body and final report MUST state the missing validation.
- `FAILED` or `BLOCKED` work MUST NOT be committed unless the user explicitly asks
  to preserve a diagnostic or work-in-progress state.

### 9.3 Commit title

Use this format:

```text
<type>(<optional-scope>): <imperative summary>
```

Allowed types:

- `feat`: user-visible capability
- `fix`: defect correction
- `perf`: measured performance improvement
- `refactor`: internal restructuring without behavior change
- `test`: test-only change
- `docs`: documentation or repository instruction change
- `build`: build or packaging change
- `ci`: continuous-integration change
- `chore`: narrowly scoped maintenance not covered above

Title requirements:

- Use an imperative, specific summary that describes the outcome.
- Keep the title at or below 72 characters.
- Do not use vague titles such as `update`, `changes`, `fix stuff`, `improvements`,
  `work in progress`, or an issue number without a description.
- Use a scope only when it makes the affected subsystem clearer.

Good examples:

```text
perf(mouse): stop fallback polling while the event monitor is active
fix(media): discard stale artwork results after cancellation
docs(agents): require atomic commits for completed tasks
```

### 9.4 Commit body

Every commit MUST include a concise body that explains context and evidence, using
this structure:

```text
Why:
- The concrete problem, risk, or requirement.

What:
- The implementation outcome and important design decision.

Validation:
- Exact commands or runtime scenarios that passed.
- Any unavailable check, only when status is PARTIALLY VERIFIED.
```

The body must explain why the change exists; it must not merely repeat the diff.
Performance commits MUST include before/after measurements in `Validation`, or state
truthfully why runtime measurement was unavailable and avoid claiming improvement.

### 9.5 Post-commit verification

After committing, the agent MUST run:

```sh
git status --short
git show --stat --oneline --decorate HEAD
```

Then verify that:

- the commit contains only files belonging to the task;
- pre-existing user changes remain present and uncommitted;
- the commit title and body accurately describe the result;
- the final report includes the commit hash and title.

If commit creation fails, the task cannot be reported as `COMPLETE`. Report the
failure and preserve the safely staged or unstaged task changes without destructive
recovery commands.

## 10. Definition of Done

A task is `COMPLETE` only when every applicable checkbox is satisfied:

- [ ] Repository instructions and relevant task documents were read.
- [ ] Pre-existing user changes were recorded and preserved.
- [ ] Scope, acceptance criteria, invariants, risks, and validation plan were stated.
- [ ] Root cause or implementation hypothesis was established.
- [ ] The diff is minimal and contains no unrelated work.
- [ ] Ownership, cleanup, cancellation, errors, and restart behavior are correct.
- [ ] Focused tests were added or a concrete reason for not adding them is recorded.
- [ ] Focused tests pass.
- [ ] `swift test` passes for production code changes.
- [ ] `swift build -c release` passes where applicable.
- [ ] Runtime behavior was verified where applicable.
- [ ] Negative and fallback scenarios were checked.
- [ ] Performance claims have comparable before/after evidence where applicable.
- [ ] Accessibility, privacy, localization, and compatibility were preserved.
- [ ] Final diff reviewer pass completed.
- [ ] `git diff --check` passes.
- [ ] No temporary artifacts or sensitive data remain.
- [ ] Remaining risks and skipped checks are explicit.
- [ ] Only task-owned paths were staged after inspecting the staged patch.
- [ ] An atomic commit with a specific title and explanatory body was created.
- [ ] The commit was inspected and pre-existing user changes remain uncommitted.

An unchecked applicable item means the task is not `COMPLETE`.

## 11. Mandatory final report

Every implementation task MUST end with this structure:

```text
Task:
Status: COMPLETE / PARTIALLY VERIFIED / FAILED / BLOCKED

Outcome:

Root cause or design rationale:

Changed files:
- path: change and reason

Preserved behavior:

Validation:
- command or scenario: exact result

Commit:
- hash and title:
- committed paths:

Quality gates:
- Gate 0 — reconnaissance: PASS / FAIL / N/A (reason)
- Gate 1 — design: PASS / FAIL / N/A (reason)
- Gate 2 — implementation: PASS / FAIL / N/A (reason)
- Gate 3 — validation: PASS / FAIL / N/A (reason)
- Gate 4 — reviewer pass: PASS / FAIL / N/A (reason)
- Gate 5 — atomic commit: PASS / FAIL / N/A (reason)

Remaining risks and skipped checks:

Suggested follow-up, if any:
```

Avoid vague claims such as "optimized", "should work", "production-ready", or
"tests look good". Report exact test counts, commands, scenarios, measurements, and
limitations. Evidence is part of the deliverable.
