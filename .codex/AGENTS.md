<!-- context7 -->
Use Context7 when a task depends on the documented behavior of an external
library, framework, SDK, API, CLI tool, or cloud service, especially for:

- exact API, configuration, or CLI syntax
- version-specific behavior, migrations, deprecations, or breaking changes
- setup instructions or library-specific errors
- unfamiliar or uncertain library behavior
- explicit requests for current documentation

Do not use Context7 merely because a dependency is mentioned. Skip it for
refactoring, code review, business logic, general programming concepts, or
when the relevant information is already provided by the user or was fetched
earlier in the current task.

Determine the installed version from the repository when possible. Reuse an
already resolved library ID. Start with one focused documentation query and
make additional queries only when the first result is insufficient.

Do not rely solely on model memory when behavior may be version-sensitive or
recently changed. Prefer Context7 over web search for library documentation.
<!-- context7 -->

## Git Output

- For automated analysis, commit-message generation, and command substitutions, use `git --no-pager` for commands that can page or render through delta.
- Prefer `git --no-pager diff --staged`, `git --no-pager diff --stat`, and `git --no-pager show --stat` when reading Git output for your own reasoning.
- Do not set or export `GIT_PAGER` globally to change agent behavior. Interactive human shells use Git config (`core.pager = delta`) for delta output.
- Use plain `git diff` only when the user explicitly asks for human-facing pager output.
