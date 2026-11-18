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

## Sandbox and environment

- If a sandbox may hide a resource needed for an authorized task, such as credentials, a tool, or network access, use the required approval mechanism to check outside it before declaring the resource unavailable or asking the user to configure it.

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
  and run the full E2E suite when repository rules require it or focused checks cannot verify the affected integration paths.
- For documentation, formatting, or other changes without runtime behavior, use relevant syntax, link, or reference
  checks instead of inventing behavior tests. Report checks actually run and any unverified behavior.

## Subagent delegation

The main agent owns scope, technical decisions, integration, final verification,
and claims. Delegate bounded work when the expected savings justify the handoff;
handle quick lookups and tightly coupled decisions directly. Use default agents
for routine work and a named role when its specialty helps. Use architect on
explicit request or for a concrete design question that benefits from independent
judgement. Use configured models and effort; verify actual runtime settings
when a guarantee matters.

Give each delegate the goal, owned files or read-only scope, constraints,
acceptance evidence and stopping condition. Prefer fresh compact context
(`fork_turns="none"`); share history only when needed. Use one writer per area,
account for shared resources, and reuse a delegate only within its assignment.
These boundaries also apply to nested delegation. Keep commits, pushes,
deployment and security-sensitive edits with the main agent.

Use one independent review of a stable result for a concrete risk or a required
review. Give the reviewer fresh context without the implementer's conclusions.
Verify fixes with focused checks or the same reviewer. Another broad pass
requires a new evidenced risk or material scope change. Bound specialized
audits upfront and disclose missing proof. Apply these defaults to skills
unless the user explicitly selects a different bounded workflow. Preserve
required evidence and report conflicts. Delegation never expands authorization.

## Deferred follow-ups

- For verification, confirmation, or cleanup deferred to a future date/event, create or update a Google Task using
  the `gog` skill; no extra approval. Use the agreed or schedule-derived date; ask if unknown.
  Do available work now and reuse existing follow-ups.
- Include a clear title; notes: current state, resources/repository, steps, completion and cleanup prerequisites,
  canonical links, and verified session ID plus `codex resume <id>` when available.
- Follow `gog` auth/dry-run/write guidance; read back title/date/notes/status and report the link or failure.
  A reminder does not authorize destructive work or bypass prerequisites.

## Coding style

- From the start of implementation, choose the simplest readable, explicit
  solution that meets the requirements. Apply YAGNI: add abstractions and
  configuration only when current requirements justify them.
- Before adding custom logic or validation, inspect existing helpers and the
  documented behavior of standard commands. Reuse behavior that already enforces
  the requirement; add checks only for missing guarantees. Preserve required
  safety and visible failures when removing duplication. Moving code to another
  file alone does not simplify its logic.
- Prefer existing conventions and a single source of truth.
  Generate schemas from existing types or metadata.
  Document manual exceptions for tool limits or different contracts.
- Name new read-only database users and roles `<app>_ro`, for example `app_ro`, instead of `<app>_reader`. Preserve externally required names; rename existing deployed roles only when explicitly requested.
- Fail fast and loudly on unexpected errors and invalid states.
  Keep required recovery explicit; never silently hide failures.

## Linear issues

- If the user has identified a Linear issue in this conversation, reconcile its description, checklist and status with the result when wrapping up the agreed scope of work, not after each chat turn. Make only necessary, concise edits to existing information; skip writes if it is already current. Do not append a work history. Add a comment only on explicit request or optionally as a short closing summary. Do not automatically search for or update other issues.
- Re-read that issue and verify all acceptance criteria against current work, including required delivery/runtime checks. If all are met, mark it Done; otherwise keep it open with an accurate status and state the missing evidence or decision. Get the user's approval before relaxing acceptance criteria to close an issue.
- Read back the saved update and status. If the write fails or Linear is unavailable, report the failure and pending update in the final response.

- Every issue must have a label identifying its project or area. When creating or updating an issue, inspect team and workspace labels and related issues; apply the existing project label using its exact name. If the issue clearly spans multiple projects or areas, apply each relevant label.
- If the project or area is unclear, or its label is missing or ambiguous, ask the user which label to use or whether to create one. Do not guess or automatically create labels.
- Add an existing type label such as `Bug`, `Improvement`, or `Feature` when it clearly fits. Leave it unset when none applies; ask if the choice is ambiguous.
- A Linear project is a separate field and does not replace the project label. Assign a Linear project when the user requests it or an existing project clearly covers the work; do not create one merely to categorize an issue.
