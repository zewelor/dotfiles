<!-- context7 -->
Use Context7 when a task depends on the documented behavior of an external library, framework, SDK, API, CLI tool, or cloud service, especially for:

- exact API, configuration, or CLI syntax
- version-specific behavior, migrations, deprecations, or breaking changes
- setup instructions or library-specific errors
- unfamiliar or uncertain library behavior
- explicit requests for current documentation

Do not use Context7 merely because a dependency is mentioned. Skip it for refactoring, code review, business logic, general programming concepts, or when the
relevant information is already provided by the user or was fetched earlier in the current task.

Determine the installed version from the repository when possible. Reuse an already resolved library ID. Start with one focused documentation query and make
additional queries only when the first result is insufficient.

Do not rely solely on model memory when behavior may be version-sensitive or recently changed. Prefer Context7 over web search for library documentation.
<!-- context7 -->

## Git Output

- For automated analysis, commit-message generation, and command substitutions, use `git --no-pager` for commands that can page or render through delta.
- Prefer `git --no-pager diff --staged`, `git --no-pager diff --stat`, and `git --no-pager show --stat` when reading Git output for your own reasoning.
- Do not set or export `GIT_PAGER` globally to change agent behavior. Interactive human shells use Git config (`core.pager = delta`) for delta output.
- Use plain `git diff` only when the user explicitly asks for human-facing pager output.

## Testing

- For behavior changes needing new coverage, use Red/Green/Refactor: define expected behavior and failure cases,
  write a test and verify it fails on pre-change code for the intended reason; implement the minimum fix, then refactor.
  If the new test already passes, check whether it exposes a real coverage gap before keeping it.
- Test observable behavior and realistic failure paths. Avoid tests that mirror implementation, assert source
  text, or merely detect that code changed. Reuse existing coverage; add a regression test only for a real gap.
- Prefer E2E tests for complex features, with realistic scenarios of medium or high complexity beyond the simplest
  happy path and a reproducible artifact. Before testing a system in isolation, identify its failure modes. Use focused tests during development
  and run the full E2E suite at the end.
- For documentation, formatting, or other changes without runtime behavior, use relevant syntax, link, or reference
  checks instead of inventing behavior tests. Report checks actually run and any unverified behavior.

## Subagent delegation

The main agent owns intent, requirements, scope, decomposition, dependencies,
ordinary technical decisions, integration, final diff inspection, decisive
validation, and final claims. The main agent normally works directly. Freely
delegate bounded work to default subagents when expected savings in effort,
context, or elapsed time outweigh handoff, verification, and likely rework.
Zero subagents is valid; do not spawn to satisfy a quota or offload a single
quick command.

Use default subagents for general tasks such as log analysis, running checks,
documentation cleanup, bounded routine implementation and tests, mechanical
edits, and evidence collection. These tasks need not fit a specialist role.
Delegate coding when the intended change, owned files, and expected result are
clear and focused validation can check the result. Keep work local when it
requires tightly coupled reasoning or handing over existing context would cost
more than doing it directly. Saving main-agent effort or context is sufficient;
no specialist escalation is required. A cheaper model alone does not justify
delegation. Length, difficulty, completion, repeated errors, generic thoroughness,
or wanting a second opinion alone do not justify specialist escalation or review.

Parallelism is useful but not required: sequential delegation is valid when a
bounded task saves effort or context, even if the main agent needs its result
next. Keep tightly coupled reasoning, decisions, and shared edits local. Prefer
direct searches and checks when handing off would cost more than doing the work.

Use named roles when their specialization helps: explorer/researcher for focused
evidence collection, worker for implementation within its configured scope, and
reviewer for independent inspection of a stable result when a named security,
concurrency, migration, regression, or public-contract risk justifies it. Use the
configured defaults for general tasks rather than selecting worker just because
the task involves execution. Final verification belongs to the main agent; no
role is a mandatory lifecycle checkpoint.

Use architect when the user explicitly requests it, or when the main agent
names a concrete design question or structural concern and the expected benefit
of independent judgement. For a deeper assessment, choose by its purpose:
design, scope, responsibilities, boundaries, state models, or contracts belong
to architect; code correctness belongs to the main agent or a risk-justified
reviewer. A request for a deeper review alone does not choose the role.
Such assessment may challenge an existing design; it does not require an
unresolved high-risk decision. Give architect a bounded, read-only assignment
with concrete questions, current code and requirements. Large plans, repeated
errors, finished work, and long tasks alone are not triggers. Debug repeated
errors with new evidence and checked assumptions.

Use at most one broad independent review of a stable result when risk justifies
it. After fixes, prefer tests and targeted verification of the specific findings,
normally in the same reviewer. Another broad pass needs a new evidenced risk or
material scope change; a previous reviewer finding alone does not justify it.
Bound specialized audit workflows before starting and disclose incomplete proof
if their requirements cannot be met within that bound. Do not silently omit proof.

Give each delegate a compact capsule: goal; exact scope/ownership and write paths
(or read-only); relevant context; constraints/non-goals; acceptance criteria;
validation/evidence; expected output; stop condition. Require files/findings,
actual check results, blockers, uncertainty, and skipped work, not a transcript.
Prefer fork_turns="none" where supported. Include current requirements and
authorizations explicitly; use selected turns only when necessary and full
history only with a concrete reason. Reuse a child only for the same scope;
independent review gets a fresh compact context without the primary conclusions.

Use the smallest justified fan-out; the runtime slot count is a ceiling, not a
target. One active writer per file/ownership area, including the main agent.
Allow bounded routine implementation, tests, and mechanical edits in explicitly
assigned files, with clear expected results and validation. Keep shared edits
with the main agent; preserve each role's write restrictions.
Account for shared runners, caches, services, Git index, and live state before
parallel work. Subagents may delegate bounded parts of their assignment when
useful, under the same scope, permissions, ownership, and specialist-escalation
rules.
Keep commits, pushes, deployments, security-sensitive edits, and final integration
with the main agent. Delegation never expands authorization.

Use configured role models and effort; do not raise effort or invoke Astra just
because a task is difficult. Check actual child runtime evidence when model or
permission guarantees matter; role descriptions and TOML are not runtime proof.
Apply this delegation policy to skill workflows unless the user explicitly
requests a different bounded orchestration policy; preserve required safety and
verification evidence and report conflicts rather than inventing completion.

## Deferred follow-ups

- For verification, confirmation, or cleanup deferred to a future date/event, create or update a Google Task using
  the `gog` skill; no extra approval. Use the agreed or schedule-derived date; ask if unknown.
  Do available work now and reuse existing follow-ups.
- Include a clear title; notes: current state, resources/repository, steps, completion and cleanup prerequisites,
  canonical links, and verified session ID plus `codex resume <id>` when available.
- Follow `gog` auth/dry-run/write guidance; read back title/date/notes/status and report the link or failure.
  A reminder does not authorize destructive work or bypass prerequisites.

## Coding style

- Prefer simple, readable, explicit code. Apply YAGNI: add abstractions
  and configuration only when current requirements justify them.
- Prefer existing conventions and a single source of truth.
  Reduce duplication when it improves clarity.
- Fail fast and loudly on unexpected errors and invalid states.
  Keep required recovery explicit; never silently hide failures.
