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

## Subagent delegation

Use subagents selectively for independent, bounded work when delegation materially improves speed, evidence quality, or main-context clarity. Follow more
specific repository or skill instructions when present.

Prefer the smallest useful fan-out, normally one to three subagents. Good candidates include read-only codebase exploration, current documentation or upstream
research, independent test or log analysis, and focused second-pass review.

Do not delegate trivial tasks, one quick command, tightly sequential reasoning, or overlapping edits. Do not create subagents merely to satisfy a quota. Do not
ask subagents to spawn further subagents unless the user explicitly requests recursive delegation.

Keep the primary agent responsible for requirements, scope, architecture, integration, final diff review, decisive validation, and final conclusions. Prefer
read-only delegation. Allow edits only for isolated mechanical work in disjoint files, with one active owner per file. Keep commits, pushes, deployments, shared
edits, and security-sensitive changes with the primary agent.

Each delegated task must have a narrow outcome, exact scope, relevant commands or evidence requirements, and explicit edit permission. Subagents must report
failures, warnings, relevant evidence, and anything skipped; a bare passed summary is not sufficient.
